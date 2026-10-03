---
name: fe-restyle
description: Use when the user asks to change the visual style of an existing project - e.g., "restyle to Neo-brutalist", "swap to a Dark / Terminal look", or provides a fresh brief / reference. Derives new tokens, updates CLAUDE.md's Style section, then migrates existing UI to the new tokens.
---

# fe-restyle

Applies a new visual direction to an existing project. Assumes `fe-setup` has already run and a Style section exists in `CLAUDE.md`.

## Contents

**Setup** - preconditions and triggers.
- [Prerequisites](#prerequisites) - upstream skills, MCPs, deps.
- [Working directory](#working-directory) - target project under `source-code/`.
- [Shared conventions](#shared-conventions) - responsive, a11y, coding, structure rules.
- [When to invoke](#when-to-invoke) - direction change / brief / reference triggers.

**Migration** - what changes, in what order.
- [Workflow](#workflow) - confirm scope → derive tokens → update CLAUDE.md → migrate UI.
- [Smooth page transitions](#smooth-page-transitions) - theme-layer motion polish added during restyle.

**I/O & verification** - closing loop.
- [Input](#input) - CLAUDE.md, theme config, references.
- [Output](#output) - updated theme + migrated UI.
- [Verification](#verification) - grep sweep, typecheck, anchor check.
- [Recommendations](#recommendations) - guardrails.

## Prerequisites

- **`fe-setup` has run** - project scaffolded at `source-code/<project-name>/`.
- **Style section exists in `CLAUDE.md`** - if empty, there is nothing to restyle *from*; lock in an initial direction (run `fe-boilerplate`'s Style tokens step) before restyling.
- **Playwright (optional)** - used in Verification for the anchor-nav check when a sticky header + same-page anchors exist. If not installed, fall back to a manual click-through and DOM inspection.
- **Font-registry access (optional)** - if the new direction requires a custom font, `next/font` (Next.js) or `@fontsource-variable/<family>` (Vite) will fetch on install.

## Working directory

Runs inside `source-code/<project-name>/` - the project being restyled. Before touching files: confirm the current directory, read that project's `CLAUDE.md` for current Style section / UI library / framework, and if multiple projects exist under `source-code/`, ask which one first (never migrate siblings together). Theme edits, migrated pages, and screenshots all live under that project only.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B (inside an existing project).

## Shared conventions

- **Responsive:** `.claude/rules/fe-responsive.md` - mobile-first, touch targets, focus states must survive the restyle.
- **A11y:** `.claude/rules/fe-a11y.md` - new palette must clear contrast; new motion must respect `prefers-reduced-motion`.
- **Coding conventions:** `.claude/rules/fe-coding-conventions.md` - replace hexes with tokens, keep imports clean.
- **Project structure:** `.claude/rules/fe-project-structure.md` - theme edits live at the theme layer, not per-component.

## When to invoke

- The user names a direction from the `fe-setup` menu (Refined minimal, Editorial, Glass / Aurora, Bento grid, Neo-brutalist, Dark / Terminal, Soft / Clay, Themed).
- The user provides a fresh brief (subject, audience, tone) and wants the UI to match.
- The user hands over a reference (screenshot, URL, mood board).

**Not for one-off component tweaks** - for those, edit inline and reuse the tokens already in `CLAUDE.md`.

## Workflow

### 1. Confirm scope

Ask:

- Which style direction (or brief / reference) to follow.
- Whether to migrate **all** existing UI or a subset (specific routes / components).
- Whether to keep any current tokens (brand color, logo, hero copy).

Echo back the target direction + scope for explicit approval before touching files.

### 2. Derive new tokens

Use the target direction as the seed. Plan tokens, then review each against the brief (subject, audience, tone). Produce:

- 4–6 color hexes with names.
- Type families + roles (display, body, mono if used).
- Layout concept + alignment guidance.
- Motion rule (one line).
- 2–3 principles specific to the subject.

If any part reads like a generic default (bland palette, stock system font, no principle unique to the subject), revise and note why.

### 3. Update CLAUDE.md

Rewrite the Style section with the new tokens. Append a short changelog line at the bottom:

```text
Restyle: <old direction> → <new direction> (YYYY-MM-DD).
```

### 4. Migrate UI (least → most disruptive)

Run all commands from inside `source-code/<project-name>/`. Examples use `pnpm` - swap to your project's package manager.

1. **Theme first.** Update the UI library's theme with the new palette, type, spacing, radii, shadows. Components consume tokens by variable - do not migrate component-by-component before the theme is in place.

   - **Tailwind + shadcn/ui:** edit `tailwind.config.ts` (or `app/globals.css` `@theme` block for v4) and `src/app/globals.css` CSS variables. If a new theme direction needs primitives you have not installed yet, re-run:
     ```bash
     pnpm dlx shadcn@latest add <primitive>
     ```
   - **Antd:** edit the app-level `<ConfigProvider theme={{ token, algorithm }}>`. Optional dark algorithm:
     ```ts
     import { theme as antdTheme } from 'antd';
     algorithm: [antdTheme.darkAlgorithm]
     ```
   - **MUI:** edit `createTheme({ palette, typography, shape, shadows })` and pass to `<ThemeProvider>`.

   If the direction calls for a custom font, install and self-host once at the theme layer:
   - **Next.js:** use `next/font` (`import { Inter } from 'next/font/google'`) - no npm install.
   - **Vite:** `pnpm add @fontsource-variable/<family>` then `import '@fontsource-variable/<family>'` in `main.tsx`.

2. **Layout primitives.** `PublicShell`, admin layout, `SideNav`, `Header`, `Footer`.
3. **Landing sections** (if present): Hero, Features, CTA, Footer.
4. **Pages** one at a time. After each page migrated, run:
   ```bash
   pnpm typecheck
   pnpm build
   ```
   to catch prerender-time regressions before moving on.
5. **Primitive extensions.** If the direction needs primitives the UI library does not cover well (e.g., Neo-brutalist hard offset shadows, Glass backdrop blur), extend at the theme layer, not per-component.

After each stage: take a screenshot if the environment supports it, critique with restraint (Chanel rule - remove one accessory before shipping), adjust.

## Smooth page transitions

A restyle is the right moment to add page-level motion polish. Do all of these at the theme layer (`globals.css` / `index.css`), never per-component:

**1. Smooth anchor scroll + sticky-header offset.** Required whenever a sticky header coexists with same-page `#section` nav. Without `scroll-padding-top`, anchor targets scroll to `y=0` and the sticky header eats the section heading.

```css
html {
  scroll-behavior: smooth;
  scroll-padding-top: <header-height + ~12px>; /* e.g. 72px for a 60px sticky header */
}
@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
}
```

Use `scroll-padding-top` on the scroll root (`html`), **not** `scroll-margin-top` on every target - the former needs no per-section wiring, the latter is easy to forget on new sections. Setting both makes them stack (target lands at `header + margin` from the top, leaving a huge gap).

**2. Link colour transitions.** A quiet flourish that costs nothing:

```css
a {
  transition:
    color 180ms ease-out,
    background-color 180ms ease-out,
    border-color 180ms ease-out;
}
@media (prefers-reduced-motion: reduce) {
  a { transition: none; }
}
```

Match the timing to the theme's motion rule (Refined minimal → 180ms ease-out; Soft/Clay → 220ms; Neo-brutalist → snap, skip).

**3. Route transitions (optional).** For Next.js App Router, wrap the routed content in a `view-transition-name` or use the built-in `<ViewTransition>` primitive if the direction calls for cinematic route changes. Skip this for utility-grade admin portals - motion should serve the subject, not decorate it.

**Verify with Playwright** at least once per restyle: click a nav anchor, wait 800–1500ms for the animation, assert the target is not covered by the sticky header. One check catches the whole class of bugs.

## Input

- `CLAUDE.md` - current Style section, subject/audience notes, selections.
- Theme config (`tailwind.config.ts` / Antd theme / MUI `createTheme`).
- Any references the user provided (screenshots, URLs, mood boards).

## Output

- Updated `CLAUDE.md` Style section with new tokens + changelog line.
- Updated theme config.
- Migrated layouts, pages, and components - all consuming the new tokens.

## Verification

Run in order - stop and fix on first failure. All from `source-code/<project-name>/`:

```bash
pnpm typecheck
pnpm lint
pnpm test -- --run          # if Vitest is wired
pnpm build
pnpm dev                    # smoke every route once
```

Codebase sweeps:

```bash
# Hardcoded old-palette hexes anywhere in src/
rg -n '#(?:[0-9a-fA-F]{3}){1,2}\b' src | rg -v 'tailwind\.config|globals\.css|createTheme|ConfigProvider'

# Orphaned imports of removed tokens (adjust the pattern to the old token names)
rg -n 'old-token-name' src
```

Both greps should return zero rows. If hexes remain, they are hardcoded - replace with a token.

- Every route renders without console errors.
- Auth-page tests still pass (see `fe-boilerplate` Output).
- Manual visual sweep: no broken alignment, no orphaned tokens, no dead nav links reintroduced.
- **Anchor nav check.** If the landing has a sticky header + same-page `#section` nav links, click each one (Playwright preferred) and confirm the target's `getBoundingClientRect().top >= header.bottom` after the scroll settles. If the target lands at `y=0`, the theme is missing `scroll-padding-top` - see [Smooth page transitions](#smooth-page-transitions).

  ```bash
  pnpm exec playwright test tests/anchor-nav.spec.ts
  ```

## Recommendations

- Migrate the theme **before** any component - new tokens must exist before consumption.
- Extend the UI library's theme layer instead of forking primitives.
- If the user provides a screenshot / URL, describe back what you see (palette, type, motion cues) so they can correct before you build.
- After migration, `grep` for old-palette hex strings - expect zero matches.
- Old-style visual snapshots need regeneration; regenerate deliberately after a visual review, not blindly.
- Do not restyle piecemeal without updating the changelog line - future readers need to know when and why the direction moved.
