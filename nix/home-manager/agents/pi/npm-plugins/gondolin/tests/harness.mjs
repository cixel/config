// The extension is the packaged TypeScript, not a reimplementation. Pi's
// registration/tool factories are the only stubs needed by the hardware test.
import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { constants } from "node:fs";
import fs from "node:fs/promises";
import { createRequire, registerHooks, stripTypeScriptTypes } from "node:module";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { createContext, SourceTextModule, SyntheticModule } from "node:vm";

export const readJSON = async (file) => JSON.parse(await fs.readFile(file, "utf8"));

export async function inputs(args = process.argv.slice(2)) {
  const [major, minor] = process.versions.node.split(".").map(Number);
  assert.ok(major > 22 || (major === 22 && minor >= 19), "Node >=22.19 is required");
  const [root, image, liveExtension] = args;
  assert.ok(root && image, "usage: SCRIPT PACKAGE_ROOT IMAGE_PATH [LIVE_EXTENSION_PATH]");
  const packageRoot = path.resolve(root);
  const imagePath = path.resolve(image);
  assert.match(imagePath, /^\/nix\/store\/[^/]+$/, "use a baked image store directory");
  const extensionPath = path.join(packageRoot, "extensions/pi-gondolin.ts");
  const source = await fs.readFile(extensionPath, "utf8");
  return { packageRoot, imagePath, extensionPath, source, liveExtension };
}

export async function importSDK(packageRoot) {
  // Resolve from the packaged extension's dependencies, never a test/global SDK.
  const require = createRequire(path.join(packageRoot, "package.json"));
  return import(pathToFileURL(require.resolve("@earendil-works/gondolin")).href);
}

function registration(cwd) {
  const hooks = new Map();
  const tools = new Map();
  const notifications = [];
  const ctx = {
    ui: {
      setStatus() {},
      notify(...args) { notifications.push(args); },
      theme: { fg: (_style, text) => text },
    },
  };
  const factory = (name) => (_cwd, { operations } = {}) => ({
    name,
    operations,
    async execute(_id, params) {
      assert.ok(operations, "unconfigured host tool must never execute");
      if (name === "read" || name === "edit") return operations.readFile(params.path);
      if (name === "write") return operations.writeFile(params.path, params.content);
      return operations.exec(params.command, cwd, { onData() {} });
    },
  });
  return {
    factories: {
      createReadTool: factory("read"),
      createWriteTool: factory("write"),
      createEditTool: factory("edit"),
      createBashTool: factory("bash"),
    },
    api: {
      on(name, handler) {
        assert.ok(!hooks.has(name), `duplicate hook: ${name}`);
        hooks.set(name, handler);
      },
      registerTool(tool) {
        assert.ok(!tools.has(tool.name), `duplicate tool: ${tool.name}`);
        tools.set(tool.name, tool);
      },
    },
    tools, notifications,
    emit(name, event = {}) {
      assert.ok(hooks.has(name), `missing extension hook: ${name}`);
      return hooks.get(name)(event, ctx);
    },
    execute(name, params) {
      return tools.get(name).execute("test", params, undefined, undefined, ctx);
    },
  };
}

export async function loadExtension({
  extensionPath,
  source,
  sdk,
  cwd = "/host/project",
}) {
  const pi = registration(cwd);
  const context = createContext({
    AbortController, Buffer, setTimeout, clearTimeout,
    process: {
      cwd: () => cwd,
      get env() { throw new Error("extension must not consult environment image overrides"); },
    },
  });
  const exportsByModule = {
    "node:fs": { constants },
    "node:path": { default: path },
    "@earendil-works/gondolin": { VM: sdk.VM, RealFSProvider: sdk.RealFSProvider },
    "@earendil-works/pi-coding-agent": pi.factories,
  };
  const javascript = stripTypeScriptTypes(source, { sourceUrl: extensionPath });
  const module = new SourceTextModule(javascript, { context, identifier: extensionPath });
  const modules = new Map();
  await module.link((specifier) => {
    assert.ok(Object.hasOwn(exportsByModule, specifier), `unexpected import: ${specifier}`);
    if (!modules.has(specifier)) {
      const exports = exportsByModule[specifier];
      modules.set(specifier, new SyntheticModule(Object.keys(exports), function () {
        for (const [name, value] of Object.entries(exports)) this.setExport(name, value);
      }, { context }));
    }
    return modules.get(specifier);
  });
  await module.evaluate();
  module.namespace.default(pi.api);
  return pi;
}

export async function loadNativeExtension({ extensionPath, source, cwd }) {
  // cbor2 dispatches on object.constructor. SourceTextModule's cross-realm
  // array literals become CBOR maps, so hardware tests must use native ESM.
  // Intercept only Pi; SDK/builtins resolve normally from the actual package.
  const pi = registration(cwd);
  const key = `gondolin-test-pi-${randomUUID()}`;
  const slot = Symbol.for(key);
  globalThis[slot] = pi.factories;
  const piSource = Object.keys(pi.factories).map((name) =>
    `export const ${name} = globalThis[Symbol.for(${JSON.stringify(key)})].${name};`,
  ).join("\n");
  const piURL = `data:text/javascript,${encodeURIComponent(piSource)}`;
  const extensionURL = `${pathToFileURL(extensionPath).href}?gondolin-test=${randomUUID()}`;
  const hooks = registerHooks({
    resolve(specifier, context, nextResolve) {
      if (specifier === "@earendil-works/pi-coding-agent") {
        return { url: piURL, shortCircuit: true };
      }
      return nextResolve(specifier, context);
    },
    load(url, context, nextLoad) {
      if (url === extensionURL) {
        return {
          format: "module",
          source: stripTypeScriptTypes(source, { sourceUrl: extensionPath }),
          shortCircuit: true,
        };
      }
      return nextLoad(url, context);
    },
  });
  try {
    const extension = await import(extensionURL);
    extension.default(pi.api);
    return pi;
  } finally {
    hooks.deregister();
    delete globalThis[slot];
  }
}

export async function mockExtension(input, { cwd, createError } = {}) {
  const calls = { create: [], fs: [], exec: [], closed: 0 };
  const guest = {
    fs: Object.fromEntries(["readFile", "access", "writeFile", "mkdir"].map((name) => [
      name, async (...args) => {
        calls.fs.push([name, ...args]);
        return name === "readFile" ? Buffer.from("guest content") : undefined;
      },
    ])),
    exec(command, options) {
      calls.exec.push({ command: Array.from(command), options });
      const result = Promise.resolve({ ok: true, exitCode: 0, stdout: "text/plain" });
      result.output = async function* () { yield { data: Buffer.from("guest output") }; };
      return result;
    },
    async close() { calls.closed += 1; },
  };
  class RealFSProvider {
    constructor(root) { this.root = root; }
  }
  const VM = {
    async create(options) {
      calls.create.push(options);
      if (createError) throw createError;
      return guest;
    },
  };
  return {
    ...await loadExtension({ ...input, cwd, sdk: { VM, RealFSProvider } }),
    calls,
  };
}
