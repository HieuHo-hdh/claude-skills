---
name: fe-motion
description: Use when wiring animation into a project scaffolded by fe-setup. Installs `motion`, emits a shared presets file with reduced-motion short-circuits, and applies entrance / hover / press to the landing page only. Scope stays narrow - landing-page polish, not page transitions or admin dashboards.
---

# fe-motion

Default: motion is **off** until explicitly asked. When enabled, scope is **landing-page entrance + hover / press feedback** - nothing more. Admin tables, data lists, and dashboards do not animate.

## Contents

**Setup** - preconditions and shared rules.
- [Prerequisites](#prerequisites) - upstream skills, deps.
- [Working directory](#working-directory) - target project under `source-code/`.
- [Shared conventions](#shared-conventions) - motion rules, a11y, coding.

**Workflow** - install → presets → apply → feedback → record.
- [1. Install](#1-install) - `motion` package.
- [2. Presets file](#2-presets-file) - `src/lib/motion-presets.ts` with reduced-motion branch.
- [3. Apply to landing page](#3-apply-to-landing-page) - Hero / Features / CTA pattern.
- [4. Hover and press feedback](#4-hover-and-press-feedback) - interactive polish, opt-in per element.
- [5. CLAUDE.md note](#5-claudemd-note) - record the capability + scope.

**I/O & verification** - closing loop.
- [Input](#input) - `fe-setup` selections, optional landing page from `fe-boilerplate`.
- [Output](#output) - presets file + applied motion on landing page.
- [Verification](#verification) - reduced-motion sweep, typecheck, build.

## Prerequisites

- **`fe-setup` has run** - project scaffolded at `source-code/<project-name>/` with `CLAUDE.md`.
- **A landing page exists** (via `fe-boilerplate`) - preferred. Running `fe-motion` without a landing page is allowed but emits presets only; application happens on the next `fe-boilerplate` run.
- **No prior `motion` wiring** - if `src/lib/motion-presets.ts` already exists, read it before editing and preserve the shape.

## Working directory

Runs inside `source-code/<project-name>/`. Confirm the directory, read `CLAUDE.md` for the Style section (motion rule) and framework / state choices before writing. If multiple projects live under `source-code/`, ask which one first.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B.

## Shared conventions

- **Motion:** `.claude/rules/fe-motion.md` - jank-safe properties, duration budget, easing, reduced motion, anti-patterns. Read before writing presets.
- **A11y:** `.claude/rules/fe-a11y.md` → *Motion* - `prefers-reduced-motion`, no flashing, no autoplay-with-sound.
- **Coding conventions:** `.claude/rules/fe-coding-conventions.md` - naming, imports, no inline curves scattered across pages.
- **Project structure:** `.claude/rules/fe-project-structure.md` - presets live in `src/lib/`, no barrel.

## 1. Install

```bash
pnpm add motion
```

`motion` is the successor to `framer-motion` - same `motion.*` API, lighter bundle, React 19 compatible. Import paths are `motion/react` for the React bindings.

## 2. Presets file

Emit `src/lib/motion-presets.ts`. One module-load reduced-motion check derives every preset - page code imports presets, never re-checks the media query.

```ts
// src/lib/motion-presets.ts
import type { Variants, Transition } from 'motion/react'

const prefersReducedMotion =
  typeof window !== 'undefined' &&
  window.matchMedia('(prefers-reduced-motion: reduce)').matches

const base: Transition = prefersReducedMotion
  ? { duration: 0 }
  : { duration: 0.4, ease: [0.22, 1, 0.36, 1] }

export const fadeInUp: Variants = {
  hidden: { opacity: 0, y: prefersReducedMotion ? 0 : 16 },
  visible: { opacity: 1, y: 0, transition: base },
}

export const stagger: Variants = {
  visible: { transition: { staggerChildren: prefersReducedMotion ? 0 : 0.08 } },
}

export const hoverLift = prefersReducedMotion
  ? {}
  : { whileHover: { y: -2 }, transition: { duration: 0.15, ease: [0.22, 1, 0.36, 1] } }

export const tapPress = prefersReducedMotion ? {} : { whileTap: { scale: 0.98 } }
```

Rationale per preset (full rationale in `.claude/rules/fe-motion.md`):

- `fadeInUp` - entrance translate ≤ 16px, 400ms. Jank-safe transforms only.
- `stagger` - 80ms child delay, used by parents whose children are `fadeInUp`.
- `hoverLift` - 2px translate on hover, 150ms. Scoped out on touch via `motion`'s own hover-media handling.
- `tapPress` - 0.98 scale on press, instant feedback.

All four collapse to no-ops when reduced motion is set. Keep the easing curve single-sourced here - no inline `ease: [...]` arrays elsewhere.

## 3. Apply to landing page

Only if `fe-boilerplate` emitted a landing page. Pattern per section:

```tsx
// src/pages/Landing/sections/Hero.tsx
import { motion } from 'motion/react'
import { fadeInUp } from '@/lib/motion-presets'

export const Hero = () => (
  <motion.section variants={fadeInUp} initial="hidden" animate="visible">
    <h1>…</h1>
    <p>…</p>
    <PrimaryCTA />
  </motion.section>
)
```

```tsx
// src/pages/Landing/sections/Features.tsx
import { motion } from 'motion/react'
import { fadeInUp, stagger } from '@/lib/motion-presets'

export const Features = () => (
  <motion.ul
    variants={stagger}
    initial="hidden"
    whileInView="visible"
    viewport={{ once: true, margin: '-10%' }}
    className="grid gap-4 md:grid-cols-3"
  >
    {features.map((f) => (
      <motion.li key={f.id} variants={fadeInUp} className="rounded-lg border p-6">
        …
      </motion.li>
    ))}
  </motion.ul>
)
```

- **Hero / CTA** - animate on mount (`initial="hidden" animate="visible"`). Above the fold, no scroll trigger needed.
- **Features / mid-page sections** - `whileInView` with `viewport={{ once: true, margin: '-10%' }}`. Re-animating on repeated scrolls is motion-sickness bait.
- **Nothing on admin pages.** Dashboards and tables render instant; a returning user does not need re-reveal animations every pagination step.

## 4. Hover and press feedback

Opt-in per element. Apply the hover / press wrappers only to **primary interactive surfaces** - landing-page CTAs, feature cards that link somewhere, pricing tiles. Not to secondary buttons, nav links, or form inputs (the UI library already handles those).

```tsx
import { motion } from 'motion/react'
import { hoverLift, tapPress } from '@/lib/motion-presets'

<motion.div {...hoverLift} {...tapPress}>
  <PrimaryCTA />
</motion.div>
```

- **Antd / MUI buttons** already have built-in press feedback - do not stack `tapPress` on the button itself. Wrap a surrounding `motion.div` instead so the two feedback systems don't double up.
- **shadcn / Tailwind buttons** have no built-in press - `tapPress` directly on the button is fine.

## 5. CLAUDE.md note

Add one line under the "Optional capability status" area of `CLAUDE.md`:

```md
animation: motion (landing-page entrance + hover / press)
```

If a Style section already exists, confirm the motion rule line matches the presets' duration budget (≤ 400ms entrance, ≤ 150ms micro). If it drifts, update the Style section through `fe-restyle`, not ad hoc.

## Input

- `fe-setup` selections - framework, UI library, state (for provider patterns).
- `fe-boilerplate` landing page (optional) - presets apply here; without it, this skill emits presets only.

## Output

- `src/lib/motion-presets.ts` with `fadeInUp`, `stagger`, `hoverLift`, `tapPress` and a single reduced-motion short-circuit.
- Landing-page Hero / Features / CTA wired to `fadeInUp` + `stagger` (if landing page is present).
- Optional hover / press wrappers on primary CTAs.
- One-line capability status in `CLAUDE.md`.

## Verification

Run from `source-code/<project-name>/`. Stop and fix on first failure.

```bash
pnpm typecheck
pnpm lint
pnpm build
pnpm dev     # visual smoke
```

- **Reduced-motion sweep.** Toggle macOS *System Settings → Accessibility → Display → Reduce motion* (or Chrome DevTools → Rendering → Emulate CSS media feature `prefers-reduced-motion: reduce`) and reload the landing page. Every animation should render at its final state with no transform / opacity transition. If anything still animates, the preset bypassed the module-load check - fix in `src/lib/motion-presets.ts`, not in page code.
- **No inline curves.** Grep sweep:

  ```bash
  rg -n "ease: \[" src --glob '!src/lib/motion-presets.ts'
  ```

  Zero results - all easing lives in the presets file.
- **No admin-page motion.** Grep sweep:

  ```bash
  rg -n "from 'motion/react'" src/pages src/layouts
  ```

  Only landing-page files should match. Admin layouts (`PrivateRoutes.tsx`, dashboard pages, tables) stay motion-free.
- **Viewport reveal fires once.** Scroll the landing page down past Features, back up, and down again - the section should not re-animate. If it does, verify `viewport={{ once: true }}` on the parent.
