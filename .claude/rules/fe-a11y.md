# Accessibility (a11y)

Shared rule referenced by every UI-emitting `fe-*` skill (`fe-component`, `fe-page`, `fe-boilerplate`, `fe-restyle`).

Target: **WCAG 2.2 AA**. Deviations: state a reason inline.

## Contents

**Structure & semantics** - how the DOM is shaped so assistive tech can parse it.
- [Semantic HTML first](#semantic-html-first) - pick the right HTML element before reaching for ARIA.
- [Heading order](#heading-order) - one `<h1>`, no level skips.
- [Labels and names](#labels-and-names) - `<label>`, `aria-label`, required marker, error linkage.
- [Language](#language) - `<html lang>` and per-span overrides.

**ARIA & announcements** - filling gaps HTML doesn't cover; talking to the screen reader.
- [When ARIA is required](#when-aria-is-required) - roles, state attributes, live regions, relationships.
- [Screen-reader announcements](#screen-reader-announcements) - route change, toast, loading, modal open.

**Interaction** - how the user drives the UI without a mouse.
- [Keyboard operability](#keyboard-operability) - Tab order + WAI-ARIA key bindings per widget.
- [Focus management](#focus-management) - `:focus-visible`, ring style, focus on route change and modal close.
- [Touch and pointer](#touch-and-pointer) - 44×44 CSS px targets, no hover-only essential content.

**Perception** - what the user can see, hear, and tolerate.
- [Contrast](#contrast) - minimum ratios, never state-by-color-alone.
- [Motion](#motion) - `prefers-reduced-motion`, no autoplay-with-sound, no flashing.
- [Images and media](#images-and-media) - `alt`, SVG `role`, video captions and transcripts.

**Quality** - how we verify and what we never ship.
- [Testing](#testing) - axe / keyboard sweep / screen reader / 200% zoom.
- [Anti-patterns - reject on sight](#anti-patterns---reject-on-sight) - quick checklist of things to never ship.

## Semantic HTML first

Reach for the right element before reaching for ARIA:

| Intent                  | Element                                      | Do not use                       |
| ----------------------- | -------------------------------------------- | -------------------------------- |
| Click → action          | `<button type="button">`                     | `<div onClick>`, `<span onClick>` |
| Click → navigation      | `<a href="/route">`                          | `<button>` with `router.push`     |
| Text input              | `<input type="text">` inside `<label>`       | `<div contenteditable>`          |
| Long form text          | `<textarea>`                                 | multi-line `<input>`             |
| Grouped choice          | `<fieldset><legend>`                         | naked `<div>`                    |
| Section landmark        | `<header> / <nav> / <main> / <footer>`       | generic `<div>`                  |
| Modal / dialog          | `<dialog>` or a role="dialog" primitive      | absolutely-positioned `<div>`    |
| Ordered list            | `<ol>` / `<ul>` + `<li>`                     | `<div>` per row                  |

**ARIA is the second choice, not the first.** The rule: *no ARIA is better than bad ARIA.* If a semantic element covers the case, use it.

## Heading order

- Exactly **one `<h1>`** per page.
- Headings step by one level - do not jump `<h1>` → `<h4>`. Use CSS to change appearance without changing level.
- The visual size hierarchy should match the semantic level.

## Labels and names

- **Every form control has a label.** Prefer `<label htmlFor="id">` with a visible label; fall back to `aria-label` or `aria-labelledby` only when the visual design demands it and the meaning is otherwise clear.
- **Placeholder text is not a label.** It disappears on input and fails contrast in many browsers.
- **Required fields** are marked with more than color - asterisk, `(required)`, or `aria-required="true"` communicated in the label text.
- **Error messages** are linked to the field via `aria-describedby` and, for invalid state, `aria-invalid="true"`.
- **Icon-only buttons** have `aria-label`. If the button reveals a tooltip on hover / focus, `aria-labelledby` the tooltip.
- **Decorative icons** get `aria-hidden="true"` - do not read them out.

## Language

`<html lang="en">` (or the correct code) at the root. Segments in another language get `<span lang="fr">…</span>`. Screen readers switch pronunciation on this attribute.

## When ARIA is required

Use ARIA when the semantics do not exist in HTML:

- Custom widgets that HTML has no primitive for
  - `role="tablist" / tab / tabpanel`
  - `role="listbox" / option`
  - `role="menu" / menuitem`
  - `role="dialog"`, `role="alertdialog"`
- **State communication**
  - `aria-expanded` - disclosure triggers (accordion header, dropdown / menu button, combobox): open vs. closed.
  - `aria-selected` - options in a listbox, tabs in a tablist, treeitem, grid cell: which one is active in the set.
  - `aria-checked` - checkbox, radio, switch, `menuitemcheckbox` / `menuitemradio`: on / off / mixed.
  - `aria-current` - nav link for the current page, stepper step, sortable table header: "you are here" within a set.
  - `aria-disabled` - button / link / form control that is present but non-operable. Prefer over the `disabled` attribute when the element must stay focusable and announced.
  - `aria-invalid` - form field that failed validation. Pair with `aria-describedby` pointing to the error message.
- **Live regions**
  - `aria-live="polite"` - async updates the user should hear without stealing focus (background save confirmed, list re-sorted, filter applied).
  - `role="status"` - short, non-urgent confirmations (implicit `aria-live="polite"`, `aria-atomic="true"`); toast snackbar for success.
  - `role="alert"` - errors and warnings that need immediate attention (implicit `aria-live="assertive"`); form-level error banner, connection lost.
  - `aria-busy="true"` - region currently loading; pair with a visible spinner and drop the attribute when the content is ready.
- **Relationships**
  - `aria-labelledby` - element gets its accessible name from one or more other elements (dialog labelled by its heading, icon button labelled by an adjacent tooltip).
  - `aria-describedby` - element gets extra description beyond the label (input's help hint, error message, password requirements).
  - `aria-controls` - element controls another region (tab controls its tabpanel, disclosure trigger controls the collapsible panel, combobox controls its listbox).
  - `aria-owns` - logical parent–child relationship when the DOM order cannot express it. Use sparingly; restructure the DOM first.

Prefer a **library primitive** (Radix, Headless UI, Antd, MUI) that already implements ARIA + keyboard patterns correctly. Hand-rolled tab / menu / combobox widgets are one of the top sources of accessibility bugs - do not reinvent them.

## Screen-reader announcements

- **Route change** - announce the new page title via a visually hidden live region, or by focusing the `<h1>`.
- **Toast / snackbar** - `role="status"` (polite) for success; `role="alert"` (assertive) for errors.
- **Loading state** - `aria-busy="true"` on the region being loaded, plus a visible spinner. Announce completion via a status message.
- **Modal open** - focus the dialog, announce its heading, trap focus inside.

## Keyboard operability

**Every interactive element must be reachable and operable by keyboard alone.** No exceptions.

- **Tab order** follows visual reading order. Do not use `tabIndex` values > 0 to reorder - restructure the DOM instead.
- **`tabIndex="-1"`** removes from tab order but keeps focusability by script (used for focus management).
- **Standard key bindings** - implement the WAI-ARIA Authoring Practices pattern for the widget type:

  | Widget     | Keys                                                                 |
  | ---------- | -------------------------------------------------------------------- |
  | Button     | Enter, Space activate.                                               |
  | Link       | Enter activates.                                                     |
  | Checkbox   | Space toggles.                                                       |
  | Radio group | Arrow keys move + select; Tab moves out.                            |
  | Menu / menubutton | Down opens; arrows navigate; Esc closes, returning focus to trigger. |
  | Tabs       | Arrow keys move between tabs; Enter / Space activates (or activate-on-focus). |
  | Listbox / combobox | Arrows navigate; Enter selects; Esc closes.                  |
  | Dialog     | Focus trapped inside; Esc closes and returns focus to opener.        |

- **Escape hatches** - modals, popovers, and menus must close on Esc and return focus to the element that opened them.
- **No keyboard traps** outside of intentional focus traps (modals). If a user cannot Tab out, that is a bug.

## Focus management

- **`:focus-visible` must be present on every interactive element.** Default outline suppression (`outline: none`) is only acceptable when replaced by a visible ring - otherwise leave the browser default.
- **Ring style** - 2px outline (or ring) in the accent color, 2px offset. Consistent across the app.
- **Focus moves on route change** - after client-side navigation, move focus to the new page's `<h1>` or main landmark so screen-reader users know the page changed.
- **Focus returns on close** - dialogs, drawers, and menus restore focus to the trigger.
- **Skip-to-content link** - at the top of every layout: `<a href="#main">Skip to content</a>`. Visible when focused. Wire the target with `id="main"` on the primary landmark.

## Touch and pointer

- **Touch targets ≥ 44×44 CSS px** (see `.claude/rules/fe-responsive.md`).
- **Never require hover to reveal essential content** - touch users have no hover state. Reserve hover for polish.

## Contrast

Minimum ratios (WCAG AA):

- **Body text** - **4.5:1** against its background.
- **Large text (≥ 18pt / 24px, or ≥ 14pt / 18.66px bold)** - **3:1**.
- **UI graphics / icons that convey meaning** - **3:1** against adjacent color.

Test with the WebAIM contrast checker or DevTools' built-in checker. Do not eyeball - a "light grey on white" body text is almost always failing.

**Never communicate state by color alone.** Error red must also have an icon or label; success green pairs with a check icon; a "selected" row uses a checkmark plus a background tint, not just tint.

## Motion

- **Respect `prefers-reduced-motion: reduce`** - any animation longer than ~200ms, any parallax, any auto-playing video, any large translation. Provide a static or minimal-motion fallback.
- **Never auto-play video with sound.**
- **Never rely on flashing content** - anything flashing more than 3 times per second is a seizure trigger and violates WCAG.

```css
@media (prefers-reduced-motion: reduce) {
  * { animation-duration: 0.01ms !important; transition-duration: 0.01ms !important; }
  html { scroll-behavior: auto; }
}
```

## Images and media

- `<img>` requires `alt`. **Meaningful images** get a description; **decorative images** get `alt=""` (empty string, not omitted).
- **SVG icons** - inline SVG gets `role="img"` + `<title>` if meaningful, or `aria-hidden="true"` if decorative.
- **Video** - provide captions for spoken content; provide a transcript for long-form audio.

## Testing

Layered:

1. **Automated in CI** - `@axe-core/react` or `eslint-plugin-jsx-a11y` catches ~30% of issues (missing alt, bad ARIA, contrast where computable).
2. **Keyboard-only sweep** - unplug the mouse; Tab through the page; confirm every interactive element is reachable, visible when focused, and operable.
3. **Screen-reader spot-check** - VoiceOver (macOS) or NVDA (Windows) on the primary flows: sign-in, main task, error surface. If the reader announces nonsense or nothing, fix.
4. **Zoom test** - 200% zoom must not clip content or hide UI behind scroll (WCAG 1.4.10 reflow).

## Anti-patterns - reject on sight

- `aria-hidden` on a focusable element - screen-reader user hears nothing, keyboard user still lands on it.
- Auto-focusing an input on page load without a documented reason - screen-reader users lose orientation.
- `title` attribute used as a substitute for a label - invisible on touch, unreliable on desktop.
- Live regions used to shout every state change - noise fatigue trains users to ignore them.
- Focus rings styled to match the background - technically present, functionally invisible.
- Skip-link that is `display: none` when not focused instead of visually hidden - some browsers exclude it from tab order.
- Reordering focus with positive `tabIndex` values - fix the DOM order instead.
