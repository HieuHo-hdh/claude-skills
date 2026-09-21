---
name: fe-restyle
description: Use when the user asks to change the visual style of an existing project — e.g., "restyle to Neo-brutalist", "swap to a Dark / Terminal look", or provides a fresh brief / reference. Derives new tokens via frontend-design, updates CLAUDE.md's Style section, then migrates existing UI to the new tokens.
---

# fe-restyle

Applies a new visual direction to an existing project. Assumes `fe-setup` has already run and a Style section exists in `CLAUDE.md`.

## When to invoke

- The user names a direction from the `fe-setup` menu (Refined minimal, Editorial, Glass / Aurora, Bento grid, Neo-brutalist, Dark / Terminal, Soft / Clay, Themed).
- The user provides a fresh brief (subject, audience, tone) and wants the UI to match.
- The user hands over a reference (screenshot, URL, mood board).

**Not for one-off component tweaks** — for those, edit inline and reuse the tokens already in `CLAUDE.md`.

## Workflow

### 1. Confirm scope

Ask:

- Which style direction (or brief / reference) to follow.
- Whether to migrate **all** existing UI or a subset (specific routes / components).
- Whether to keep any current tokens (brand color, logo, hero copy).

Echo back the target direction + scope for explicit approval before touching files.

### 2. Derive new tokens

Invoke `frontend-design`. Use the target direction as the seed and run its **plan → review-against-brief** step. Produce:

- 4–6 color hexes with names.
- Type families + roles (display, body, mono if used).
- Layout concept + alignment guidance.
- Motion rule (one line).
- 2–3 principles specific to the subject.

If any part reads like a generic default (see `frontend-design`'s calibration list), revise and note why.

### 3. Update CLAUDE.md

Rewrite the Style section with the new tokens. Append a short changelog line at the bottom:

```
Restyle: <old direction> → <new direction> (YYYY-MM-DD).
```

### 4. Migrate UI (least → most disruptive)

1. **Theme first.** Update the UI library's theme (`tailwind.config.ts` / Antd `ConfigProvider` theme / MUI `createTheme`) with the new palette, type, spacing, radii, shadows. Components consume tokens by variable — do not migrate component-by-component before the theme is in place.
2. **Layout primitives.** `PublicShell`, admin layout, `SideNav`, `Header`, `Footer`.
3. **Landing sections** (if present): Hero, Features, CTA, Footer.
4. **Pages** one at a time. Run `pnpm build` after each to catch prerender-time regressions.
5. **Primitive extensions.** If the direction needs primitives the UI library does not cover well (e.g., Neo-brutalist hard offset shadows, Glass backdrop blur), extend at the theme layer, not per-component.

After each stage: take a screenshot if the environment supports it, critique against `frontend-design`'s "restraint and self-critique" section (Chanel rule — remove one accessory), adjust.

### 5. Verify

- `pnpm typecheck` and `pnpm build` pass.
- Every route renders without console errors.
- Auth-page tests still pass (see `fe-boilerplate` Output).
- Sweep the codebase for hardcoded old-palette hexes — should be **zero**.
- Manual visual sweep: no broken alignment, no orphaned tokens, no dead nav links reintroduced.

## Input files

- `CLAUDE.md` — current Style section, subject/audience notes, selections.
- Theme config (`tailwind.config.ts` / Antd theme / MUI `createTheme`).
- Any references the user provided (screenshots, URLs, mood boards).

## Output

- Updated `CLAUDE.md` Style section with new tokens + changelog line.
- Updated theme config.
- Migrated layouts, pages, and components — all consuming the new tokens.

## Recommendations

- Migrate the theme **before** any component — new tokens must exist before consumption.
- Extend the UI library's theme layer instead of forking primitives.
- If the user provides a screenshot / URL, describe back what you see (palette, type, motion cues) so they can correct before you build.
- After migration, `grep` for old-palette hex strings — expect zero matches.
- Old-style visual snapshots need regeneration; regenerate deliberately after a visual review, not blindly.
- Do not restyle piecemeal without updating the changelog line — future readers need to know when and why the direction moved.
