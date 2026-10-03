# Responsive layout

Shared rule referenced by every UI-emitting `fe-*` skill (`fe-component`, `fe-page`, `fe-boilerplate`, `fe-restyle`).

Scope: layout, breakpoints, units, touch targets, focus. Deviations: state a reason inline.

## Mobile-first default

Write base styles for the smallest expected screen. Layer on larger-viewport rules with **`min-width`** breakpoints. Do not use `max-width` unless you are surgically overriding a rare desktop-only case.

```tsx
// ✅ mobile-first
<div className="flex flex-col gap-4 md:flex-row md:gap-8">

// ❌ desktop-first
<div className="flex flex-row gap-8 max-md:flex-col max-md:gap-4">
```

## Breakpoint scale

Use the UI library's tokens - do not invent per-component breakpoints:

| Framework       | Scale                                          |
| --------------- | ---------------------------------------------- |
| Tailwind        | `sm` 640, `md` 768, `lg` 1024, `xl` 1280, `2xl` 1536 |
| Antd            | `xs` 480, `sm` 576, `md` 768, `lg` 992, `xl` 1200, `xxl` 1600 |
| MUI             | `xs` 0, `sm` 600, `md` 900, `lg` 1200, `xl` 1536 |

Reference these by name in code, not by px value.

## Units - `rem` first, `px` for hairlines

Sizes that should scale with the user's root font-size - typography, spacing, radii, layout widths - use **`rem`**. Browser zoom and OS text-size settings scale `rem`-based UI but ignore `px`, which breaks WCAG 1.4.4 (Resize Text) and 1.4.10 (Reflow).

- Prefer the framework token scale first. Tailwind's default scale is already in `rem` (`w-44` → `11rem` → `176px` at the default root). MUI's `theme.spacing()` returns `rem`. Antd emits `px` but exposes CSS variables for overrides.
- `px` is fine for **1:1 device-pixel details** - hairline borders, focus-ring width, image intrinsic sizes, sub-`2px` shadow radii.
- Arbitrary `rem` values in code (`w-[11.25rem]`) are tolerated **once**. On the second occurrence, promote the value to the theme scale - see the coding-conventions anti-pattern on duplicated design tokens.

```tsx
// ✅ theme scale
<div className="w-44 gap-2 text-sm" />

// ✅ px hairline
<div className="border border-slate-200" />

// ✅ one-off arbitrary rem
<div className="w-[11.25rem]" />

// ❌ arbitrary px - ignores user zoom
<div className="w-[180px]" />

// ❌ same arbitrary value in two places - extract to theme
<div className="w-[11.25rem]" /> … <div className="w-[11.25rem]" />
```

## Container queries - when to reach for them

Use **`@container`** when a component's layout depends on the **container it sits in**, not the viewport. Example: a card that reflows differently in a sidebar (narrow) vs. a main grid (wide) on the same viewport. Do not swap all media queries for container queries - most page-level layout is still viewport-driven.

```css
.card { container-type: inline-size; }
@container (min-width: 32rem) { .card-title { font-size: 1.5rem; } }
```

## Touch targets

Anything a finger taps must be **at least 44×44 CSS px**. That includes icon-only buttons in nav headers, table row actions, close X buttons, etc. Padding counts toward the target; the visual icon may be smaller.

## Hover / focus semantics

`:hover` does not exist on touch. Never rely on it for critical information:

- Every interactive element must have a visible **`:focus-visible`** state (outline, ring, or background change).
- `:hover` is polish, not a requirement. Use `@media (hover: hover)` to scope hover-only decorations away from touch.

```css
@media (hover: hover) {
  .btn:hover { background: var(--color-accent-hover); }
}
.btn:focus-visible { outline: 2px solid var(--color-accent); outline-offset: 2px; }
```

## Fluid typography

For hero / display text, use `clamp()`:

```css
h1 { font-size: clamp(2rem, 5vw + 1rem, 4rem); }
```

Body text can stay fixed with a media-query bump if needed - do not over-clamp small text (readability suffers).

## Viewport-height traps

- **`100vh` is broken on iOS Safari** - the URL bar's collapse animates the number. Use **`100dvh`** (dynamic viewport height) instead, or `min-h-screen` in Tailwind v4 which now maps to `100dvh`.
- **`100vw` scrolls sideways** when a scrollbar is present. Prefer `100%` on `<html>` / `<body>` for full-width.

```css
.hero { min-height: 100dvh; }
```

## Density modes

Apps often have two surfaces:

- **Public / marketing** - airier, larger type, more whitespace.
- **Admin / dashboard** - denser, tighter line-height, more compact spacing.

If a project has both, state the density rule in the Style section principles so components render correctly per surface.

## Testing - the three-width sanity check

Every new page or component gets a quick eyeball at:

- **375 px** (small phone - iPhone SE class).
- **768 px** (tablet portrait).
- **1280 px** (desktop laptop).

Chrome DevTools' device toolbar covers all three in under 30 seconds. If any of them breaks alignment / overflows / hides critical content, fix before marking the task done.

## Anti-patterns - reject on sight

- `display: none` used to "hide on tablet+" - the DOM node still exists and confuses assistive tech. Use conditional rendering or `hidden md:block` with intent.
- Fixed pixel heights on containers with growable content (`h-96` on a comment thread).
- `overflow-x: hidden` on `<body>` as a band-aid for a stray element pushing width - find the actual overflow and fix it.
- Mobile-only content stripped without a replacement ("we hide the sidebar on mobile" - but where does its content go?).
- Hover-only tooltips carrying required information (invisible on touch).
- Text at `< 14 px` for body copy on mobile (readability floor).

## Framework-specific notes

| Framework          | Responsive tool                                                                                                       |
| ------------------ | --------------------------------------------------------------------------------------------------------------------- |
| Tailwind v4        | Utilities mobile-first by default; `md:flex-row` = "flex-row from 768px up." No config needed.                        |
| Antd               | `<Row>` / `<Col>` with responsive props (`xs`, `sm`, `md`, `lg`), or `Grid.useBreakpoint()` for JS-level branching.   |
| MUI                | `sx={{ display: { xs: 'none', md: 'flex' } }}` or the `useMediaQuery(theme.breakpoints.up('md'))` hook.               |
| Next.js App Router | Server components render at the requested viewport once; runtime breakpoint switching still needs CSS or client hooks. |
