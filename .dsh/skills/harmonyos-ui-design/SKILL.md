---
name: harmonyos-ui-design
description: Use when designing, reviewing, or implementing HarmonyOS ArkUI screen UI in this project - adaptive layout and breakpoints, design tokens and theming, component selection, typography, motion, safe areas, and immersive/landscape game surfaces. Targets HarmonyOS 6.0.0 / API 26.
whenToUse: A screen, layout, theme, visual style, or interaction needs to be designed or reviewed in a HarmonyOS app.
---

# HarmonyOS UI design

Design for **one codebase, many devices** (一多). Every screen must read correctly on phone, tablet and 2in1 at once. This project targets **HarmonyOS 6.0.0 (API 26)**, stage model, ArkUI declarative UI.

## Non-negotiable rules

1. **No hard-coded colors, radii, font sizes or spacing.** Every visual constant comes from resources: `$r('app.color.…')`, `$r('app.float.…')`, `$r('app.string.…')`.
2. **Every screen must survive the three sizes.** If a layout only works at 360vp wide, it is not done.
3. **Touch targets are at least 48vp** in both dimensions. Icon buttons get `.width(48).height(48)` or a wrapping `padding`.
4. **Text scales.** Use `fp` units and cap with `.maxLines()` plus `.textOverflow({ overflow: TextOverflow.Ellipsis })`. Never let a label push a layout off-screen.
5. **Dark mode is a resource, not a code branch.** Put light values in `resources/base/element/` and dark values in `resources/dark/element/` under the same key.
6. **Respect safe areas and the keyboard.** Full-bleed surfaces must either avoid the notch and gesture bar or explicitly `.expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])`.

## Adaptive layout (一多)

HarmonyOS sizes screens by **vp width**, not by device name.

| Bucket | vp width | Columns (GridRow, API 20+) |
|---|---|---|
| xs | < 320 | 2 |
| sm | 320 - 599 | 4 |
| md | 600 - 839 | 8 |
| lg | 840 - 1199 | 12 |
| xl | 1200 - 1599 | 12 |
| xxl | >= 1600 | 12 |

Two ways to be adaptive, in order of preference:

1. **`GridRow` / `GridCol`** - declarative, automatic, no media queries:

~~~typescript
GridRow({ columns: { sm: 4, md: 8, lg: 12 }, gutter: { x: 12, y: 12 } }) {
  GridCol({ span: { sm: 4, md: 4, lg: 6 } }) { BoardView() }
  GridCol({ span: { sm: 4, md: 4, lg: 6 } }) { ChatPanel() }
}
~~~

2. **`mediaquery`** - only when you must switch *structure*, not just width:

~~~typescript
import { mediaquery } from '@kit.ArkUI';
private listener = mediaquery.matchMediaSync('(width >= 840vp)');
// in aboutToAppear: this.listener.on('change', (r) => this.isWide = r.matches)
~~~

Container choice:

- `Column` / `Row` - linear layout, the default.
- `Stack` - overlay: HUD on top of a game canvas, badge on an avatar.
- `RelativeContainer` - anchors between elements (alignRules); good for complex cards.
- `Flex` - only when wrapping is genuinely needed; otherwise prefer Grid.
- `List` + `LazyForEach` - any list that can grow unbounded.
- `Scroll` - a single long page; never nest scrolling containers.
- `Tabs` - top-level sections on phone; convert to a side rail at lg.
- `Navigation` - the only sanctioned page-stack mechanism. Do **not** start new work with the deprecated `router`.

## Design tokens and theming

Keep `resources/base/element/color.json` as the single palette source and mirror it in `resources/dark/element/color.json`:

~~~json
{
  "color": [
    { "name": "bg_page",      "value": "#F1F3F5" },
    { "name": "bg_surface",   "value": "#FFFFFF" },
    { "name": "text_primary", "value": "#E6000000" },
    { "name": "brand",        "value": "#0A59F7" },
    { "name": "danger",       "value": "#E84026" }
  ]
}
~~~

Spacing and shape belong in `float.json` so gaps stay consistent: `space_xs=4, space_s=8, space_m=16, space_l=24, space_xl=32, radius_card=16`.

For a game, express board/sidebar widths as fractions of the container (`.width('62%')`, `layoutWeight(1)`) rather than absolute vp, so the same screen works in split-screen and on a tablet.

## Component selection

| Need | Use |
|---|---|
| Primary / secondary action | `Button` with `ButtonType.Capsule`; one primary action per screen |
| Text entry | `TextInput` / `TextArea` / `Search`, with `.placeholderColor()` from tokens |
| Settings row | `List` + `ListItem` with `Toggle` / `Select` |
| Transient choice | `bindSheet` (half-modal) |
| Blocking decision | `promptAction.showDialog` or `bindContentCover` |
| Toast | `promptAction.showToast` - never for errors the user must act on |
| Context actions | `bindMenu` / `bindContextMenu` |
| Progress | `Progress` (determinate) or `LoadingProgress` (indeterminate) |
| Empty state | Illustration + one-line cause + one action button |

## States: design all four

Every data-driven screen is designed in **loading, empty, error and content** states before it is built. Loading uses skeleton shapes at the real element's size, not a spinning modal that blocks the page. Errors are inline and actionable ("服务器未启动，检查 http://192.168.x.x:8080" plus a retry button), and never a raw exception string.

## Motion

Use `animateTo` for state-driven movement and `transition` for appearance:

~~~typescript
animateTo({ duration: 200, curve: Curve.FastOutSlowIn }, () => { this.panelOpen = true; });
~~~

- 150-250 ms for feedback, 250-400 ms for surfaces.
- Animate opacity and transform only; animating `width` / `height` / `layoutWeight` on a large subtree drops frames.
- The same information must still be reachable with animation off.

## Immersive and landscape surfaces (games, boards, canvases)

~~~typescript
import { window } from '@kit.ArkUI';

onWindowStageCreate(windowStage: window.WindowStage): void {
  windowStage.getMainWindow().then((win: window.Window) => {
    win.setWindowLayoutFullScreen(true);
    win.setWindowKeepScreenOn(true);
    win.setPreferredOrientation(window.Orientation.LANDSCAPE);
  });
}
~~~

- Declare orientation once in the ability, not per page.
- Compute board geometry **from the measured container**, not from a constant: use `onAreaChange` to capture the size, then derive cell size with `Math.floor(Math.min(w, h) / 10)` for a 10-column Tetris board.
- `setWindowKeepScreenOn` is mandatory for turn-based play; without it the device sleeps mid-turn.

## Review checklist

- [ ] No literal colors, sizes or spacing outside resource files.
- [ ] Verified at sm, md and lg widths.
- [ ] Dark mode checked in both themes.
- [ ] All tap targets >= 48vp; icon-only controls have `accessibilityText`.
- [ ] Long text truncates instead of overflowing.
- [ ] Loading, empty, error and content states all exist.
- [ ] Page-stack navigation uses `Navigation`, not `router`.
- [ ] Keyboard does not cover the focused input.
- [ ] Game surfaces: full-screen, keep-screen-on, orientation fixed, board derived from measured size.
