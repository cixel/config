/**
 * footer-status
 *
 * Problem: pi's built-in footer renders extension statuses (fence, guard, …)
 * on a third line of their own, joined by a bare space, while the right-hand
 * side of line 1 (next to the cwd) sits empty.
 *
 * This extension moves the statuses up into that empty space, right-aligned
 * and separated by " · ":
 *
 *     ~/.config (urrotmlm)            fence config · guard 12 allowed · …
 *     ↑1.2M ↓40k R3.1M $1.234 12.3%/200k (auto)          claude-… • high
 *
 * If they don't fit next to at least MIN_CWD columns of cwd, the stock
 * three-line layout is left alone, so narrow terminals lose nothing.
 *
 * How: same trick as jj-footer. `ctx.ui.setFooter()` hands its factory the
 * live FooterDataProvider and the TUI; we install a throwaway footer to grab
 * both, restore the built-in footer, then find the built-in FooterComponent
 * in the TUI tree (it is the component holding that same provider) and wrap
 * its `render` on the instance. Line content is never rebuilt, only moved.
 *
 * This leans on pi internals: the component tree shape, the `footerData`
 * field, and the stock footer being exactly [cwd, stats, statuses]. If any of
 * that changes, we either fail to find the footer (no-op) or see an
 * unexpected line count (pass through untouched).
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const GAP = 2;
const MIN_CWD = 20;

type Theme = { fg(color: string, text: string): string };
type StatusSource = { getExtensionStatuses(): ReadonlyMap<string, string> };
type Renderable = { render(width: number): string[] };
type Node = Renderable & { children?: unknown[]; footerData?: unknown };

/** Same normalisation the stock footer applies to status text. */
function sanitize(text: string): string {
	return text.replace(/[\r\n\t]/g, " ").replace(/ +/g, " ").trim();
}

function findFooter(node: unknown, provider: unknown, depth = 0): Node | undefined {
	if (!node || typeof node !== "object" || depth > 8) return undefined;
	const n = node as Node;
	if (n.footerData === provider && typeof n.render === "function") return n;
	for (const child of n.children ?? []) {
		const hit = findFooter(child, provider, depth + 1);
		if (hit) return hit;
	}
	return undefined;
}

/** Exported for tests. Returns `lines` unchanged when it can't help. */
export function relayout(lines: string[], statuses: ReadonlyMap<string, string>, width: number, theme: Theme): string[] {
	if (statuses.size === 0 || lines.length !== 3) return lines;
	const right = Array.from(statuses.entries())
		.sort(([a], [b]) => a.localeCompare(b))
		.map(([, text]) => sanitize(text))
		.filter(Boolean)
		.join(theme.fg("dim", " · "));
	const rightWidth = visibleWidth(right);
	const room = width - GAP - rightWidth;
	if (room < MIN_CWD) return lines;

	let cwd = lines[0]!;
	if (visibleWidth(cwd) > room) cwd = truncateToWidth(cwd, room, theme.fg("dim", "..."));
	const pad = " ".repeat(Math.max(GAP, width - visibleWidth(cwd) - rightWidth));
	return [cwd + pad + right, lines[1]!];
}

export default function (pi: ExtensionAPI) {
	let footer: Node | undefined;
	let wrapped: Renderable["render"] | undefined;

	function install(ctx: ExtensionContext) {
		let captured: { tui: unknown; theme: Theme; footerData: unknown } | undefined;
		ctx.ui.setFooter((tui, theme, footerData) => {
			captured = { tui, theme: theme as Theme, footerData };
			return { render: () => [], invalidate() {} };
		});
		ctx.ui.setFooter(undefined);
		if (!captured) return;

		const target = findFooter(captured.tui, captured.footerData);
		if (!target) return;
		const { theme } = captured;
		const provider = captured.footerData as StatusSource;
		const original = target.render;
		const fn = function (this: Node, width: number) {
			const lines = original.call(this, width);
			try {
				return relayout(lines, provider.getExtensionStatuses(), width, theme);
			} catch {
				return lines;
			}
		};
		target.render = fn;
		footer = target;
		wrapped = fn;
		(captured.tui as { requestRender?(): void }).requestRender?.();
	}

	function teardown() {
		// Drop our own-property shadow so the prototype method shows through.
		if (footer && wrapped && footer.render === wrapped) {
			delete (footer as Partial<Renderable>).render;
		}
		footer = wrapped = undefined;
	}

	pi.on("session_start", (_event, ctx) => {
		teardown();
		if (ctx.mode === "tui") install(ctx);
	});

	pi.on("session_shutdown", () => {
		teardown();
	});
}
