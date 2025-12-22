/**
 * Test stub for the pi package, resolved via agents/pi/tsconfig.json paths
 * when bun runs the unit tests. Pi itself resolves the real specifier
 * through jiti aliases when it loads an extension, and the nix build-time
 * API check (flake `pi-fence-api-check`) asserts the pinned pi really
 * exports these. Wiring tests inject their own factories into wireFence;
 * these placeholders exist only so the static import in
 * ../extensions/pi-fence.ts resolves under bun, and throw if called.
 */
export function createBashTool(): never {
	throw new Error("pi-coding-agent stub: createBashTool called outside pi");
}
export function createLocalBashOperations(): never {
	throw new Error("pi-coding-agent stub: createLocalBashOperations called outside pi");
}
export type ExtensionAPI = any;
export type ExtensionContext = any;
