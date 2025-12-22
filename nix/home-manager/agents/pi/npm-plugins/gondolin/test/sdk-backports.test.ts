// Regression tests for the SDK backports applied to
// @earendil-works/gondolin 0.13.0 (see sdk-patches/):
//
//   0001-fsrpc-serialize:  upstream 02ab792 — fs-rpc requests must be
//     processed strictly in arrival order so a pipelining guest cannot win
//     a path-validation TOCTOU race against RealFSProvider.
//   0002-chmod-forwarding: upstream 0705083 (host side) — the chmod fs-rpc
//     op dispatches to providers; RealFSProvider drops setuid/setgid bits.
//
// These tests exercise the *compiled dist* of the SDK (what Pi actually
// loads). They skip cleanly when the SDK is not installed (plain
// `npm test` without node_modules); the nix check always provides it via
// PI_GONDOLIN_SDK_DIR.

import assert from "node:assert/strict";
import { createRequire } from "node:module";
import { mkdtempSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { pathToFileURL } from "node:url";
import test from "node:test";

function locateSdk(): string | null {
  if (process.env.PI_GONDOLIN_SDK_DIR) return process.env.PI_GONDOLIN_SDK_DIR;
  try {
    const req = createRequire(import.meta.url);
    return dirname(req.resolve("@earendil-works/gondolin/package.json"));
  } catch {
    return null;
  }
}

const sdkDir = locateSdk();

async function importSdk(): Promise<{
  FsRpcService: any;
  MemoryProvider: any;
  RealFSProvider: any;
}> {
  // Import the self-contained vfs submodules directly: the package root
  // (index.js) transitively imports runtime deps like undici, which the
  // patched-SDK derivation deliberately does not carry.
  const vfs = await import(
    pathToFileURL(join(sdkDir!, "dist", "src", "vfs", "rpc-service.js")).href
  );
  const node = await import(
    pathToFileURL(join(sdkDir!, "dist", "src", "vfs", "node", "index.js")).href
  );
  return {
    FsRpcService: vfs.FsRpcService,
    MemoryProvider: node.MemoryProvider,
    RealFSProvider: node.RealFSProvider,
  };
}

const skip = sdkDir === null ? { skip: "gondolin SDK not installed" } : {};

function delay(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

function fsRequest(id: number, op: string, req: Record<string, unknown>) {
  return { v: 1, t: "fs_request", id, p: { op, req } };
}

test("sdk: fs-rpc requests are processed strictly in arrival order", skip, async () => {
  const { FsRpcService, MemoryProvider } = await importSdk();
  const base = new MemoryProvider();
  base.writeFileSync("/a.txt", "a");
  base.writeFileSync("/b.txt", "b");

  let releaseFirst!: () => void;
  const firstBlocked = new Promise<void>((resolve) => {
    releaseFirst = resolve;
  });
  const events: string[] = [];
  const provider = new Proxy(base, {
    get(target: any, prop: string | symbol, receiver: any) {
      if (prop === "lstat") {
        return async (p: string) => {
          events.push(`start ${p}`);
          if (p === "/a.txt") await firstBlocked;
          events.push(`end ${p}`);
          return target.lstat(p);
        };
      }
      return Reflect.get(target, prop, receiver);
    },
  });
  const service = new FsRpcService(provider);

  const first = service.handleRequest(
    fsRequest(1, "lookup", { parent_ino: 1, name: "a.txt" }),
  );
  const second = service.handleRequest(
    fsRequest(2, "lookup", { parent_ino: 1, name: "b.txt" }),
  );
  await delay(20);
  assert.deepEqual(
    events,
    ["start /a.txt"],
    "second request must not start while the first is in flight",
  );
  releaseFirst();
  const [r1, r2] = await Promise.all([first, second]);
  assert.equal(r1.p.err, 0);
  assert.equal(r2.p.err, 0);
  assert.deepEqual(events, [
    "start /a.txt",
    "end /a.txt",
    "start /b.txt",
    "end /b.txt",
  ]);
  await service.close();
});

test("sdk: chmod op dispatches to providers (mode masked to 0o7777)", skip, async () => {
  const { FsRpcService, MemoryProvider } = await importSdk();
  const base = new MemoryProvider();
  base.writeFileSync("/f.txt", "x");
  const service = new FsRpcService(base);

  const lookup = await service.handleRequest(
    fsRequest(1, "lookup", { parent_ino: 1, name: "f.txt" }),
  );
  assert.equal(lookup.p.err, 0);
  const ino = lookup.p.res.entry.ino;

  const res = await service.handleRequest(
    fsRequest(2, "chmod", { ino, mode: 0o4755 }),
  );
  assert.equal(res.p.err, 0, `chmod failed: ${JSON.stringify(res.p)}`);
  const attr = await service.handleRequest(
    fsRequest(3, "getattr", { ino }),
  );
  assert.equal(attr.p.err, 0);
  // 0o4755 & 0o7777 keeps setuid at the RPC layer; RealFSProvider drops it.
  assert.equal(attr.p.res.attr.mode & 0o7777, 0o4755);
  await service.close();
});

test("sdk: unknown provider chmod keeps working (ENOSYS contract)", skip, async () => {
  const { FsRpcService, MemoryProvider } = await importSdk();
  // A provider without chmod: the RPC layer must answer ENOSYS, matching
  // the old-guest/new-host compatibility contract.
  const base = new MemoryProvider();
  base.writeFileSync("/f.txt", "x");
  const provider = new Proxy(base, {
    get(target: any, prop: string | symbol, receiver: any) {
      if (prop === "chmod" || prop === "chmodSync") return undefined;
      return Reflect.get(target, prop, receiver);
    },
  });
  const service = new FsRpcService(provider);
  const lookup = await service.handleRequest(
    fsRequest(1, "lookup", { parent_ino: 1, name: "f.txt" }),
  );
  const ino = lookup.p.res.entry.ino;
  const res = await service.handleRequest(
    fsRequest(2, "chmod", { ino, mode: 0o755 }),
  );
  assert.notEqual(res.p.err, 0, "chmod on a non-chmod provider must error");
  await service.close();
});

test("sdk: RealFSProvider chmod never applies setuid/setgid bits", skip, async () => {
  const { RealFSProvider } = await importSdk();
  const dir = mkdtempSync(join(tmpdir(), "gondolin-chmod-"));
  writeFileSync(join(dir, "target.sh"), "#!/bin/sh\n");
  const provider = new RealFSProvider(dir);
  // Attempt setuid + rwxr-xr-x; host file must end up without set-id bits.
  await provider.chmod("/target.sh", 0o4755);
  const mode = statSync(join(dir, "target.sh")).mode & 0o7777;
  assert.equal(mode, 0o755, `expected 0755, got ${mode.toString(8)}`);
});
