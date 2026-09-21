---
name: fe-setup
description: Use when scaffolding a new frontend project from scratch. Walks through language / framework / UI / router / state / lint / test selections, prefers the framework's official CLI, and optionally hands off to fe-auth and fe-boilerplate.
---

# fe-setup

Default: **pin every dependency to its latest stable version at install time.** No caret ranges for the initial scaffold — reproducible installs first.

## Workflow

### 1. Selections

Ask the user each of the following, one section at a time, and record their answer. Present the default and a 1-line tradeoff for the alternatives — do not just dump a list.

**Project name and package manager:** Ask for the project name. Ask for the package manager: **pnpm** (default), npm, yarn, or bun.

**Language:** TypeScript (default) or JavaScript.

**Framework:** Next.js (App Router, default), React + Vite, or Vue + Vite.

**UI library:** Antd (default), MUI, or shadcn/ui + Tailwind. Pick one — do not mix.

**Visual style / direction:** Pick a starting direction — a **seed** for `frontend-design`, not a locked template. `fe-boilerplate` invokes `frontend-design` to refine tokens against the actual subject before generating any UI.

- **Refined minimal** — generous whitespace, 8pt spacing scale, one accent color, hairline borders, restrained motion. Good for SaaS, docs, portfolios.
- **Editorial** — serif display + clean sans body, strong type scale, asymmetric layout, pull quotes, long line-height. Good for blogs, content sites.
- **Glass / Aurora** — translucent layers, backdrop blur, soft gradient mesh, subtle borders, luminous highlights. Good for landing pages, dashboards with a hero.
- **Bento grid** — modular tiles of varied sizes, consistent gutters, one hero tile, mixed content types. Good for feature overviews.
- **Neo-brutalist** — thick outlines, hard offset shadows, flat saturated colors, oversized type, no gradients. Good for creative tools, youth brands.
- **Dark / Terminal** — near-black surfaces, monospace accents, single neon accent, grid or noise texture, focus glows. Good for dev tools, dashboards.
- **Soft / Clay** — rounded 3D-ish surfaces, pastel palette, inner shadows, friendly rounded type. Good for consumer apps, onboarding.
- **Themed (commit-heavy)** — pick one world (retro-futurist, RPG, print, brutal industrial) and commit to its materials and type. Good for games, brand sites.
- **Custom (brief-driven)** — skip presets; describe subject + audience, then `frontend-design`'s plan step derives tokens from scratch.

**Router:** Next.js file-based (default when Next is chosen), React Router v6 (default when React + Vite), or Vue Router (when Vue).

**State / storage:** Zustand + TanStack Query (default), Redux Toolkit + RTK Query, or Context + fetch.

**Linter / formatter:** ESLint (flat config) + Prettier (default). Ask whether to add `eslint-plugin-import` for import ordering — if yes, pin **`eslint@^9`** (v10 breaks the plugin). For projects already on ESLint 10, use the successor `eslint-plugin-import-x` instead.

**Unit testing:** Vitest + Testing Library (default) or Jest + Testing Library.

**E2E testing:** Playwright (default), Cypress, or none.

### 2. Confirmation

Echo the full selection back as a bullet list and get explicit approval before running any install command.

### 3. Scaffold

**Prefer the framework's official CLI first.** Only add what it does not already cover.

Run the CLI with the chosen name and package manager (examples use `pnpm` — swap for the chosen PM):

- **Next.js:** `pnpm create next-app@latest <name> --yes` (drop `--yes` if the user wants the interactive prompts).
- **React + Vite:** `pnpm create vite <name> --template react-ts` (or `react` for JS).
- **Vue + Vite:** `pnpm create vue@latest <name>`.

After the CLI finishes, install and configure whatever is still missing:

- Path aliases: `@/*` → `src/*` in `tsconfig.json` and the build-tool config (`vite.config.ts` / `next.config.js`).
- Chosen UI library (theme provider, tokens).
- State / storage libraries.
- ESLint + Prettier configs (only if the CLI did not already set them up).
- Testing setup (Vitest / Jest, Playwright / Cypress). If Vitest is picked, install `vite-tsconfig-paths` and add it to `vitest.config.ts` `plugins` so `@/*` resolves from `tsconfig.json` — do **not** duplicate the alias into `resolve.alias`.

**Next.js 16 callout:** if Next.js was picked, add a note to `CLAUDE.md`: Next 16 has breaking changes vs. training-data patterns (Turbopack default, `next build` no longer lints, `next typegen` needed for route types, `AGENTS.md` auto-regenerated). Consult `node_modules/next/dist/docs/` before writing route/data patterns from memory.

Verify: dev server boots, typecheck passes, `pnpm build` succeeds (catches prerender-time issues that dev hides), and the first component renders.

### 4. Authentication decision *(optional)*

Ask: "Wire authentication now, or defer?" Auth is **optional at setup time** — you can skip it and invoke `fe-auth` later.

- If **now** → invoke `fe-auth` to wire storage, client, and interceptors.
- If **deferred** → note "auth deferred; run `fe-auth` when needed" in `CLAUDE.md`.

Storage recommendation per framework (full table in `fe-auth`):

- **Next.js App Router:** both tokens in HttpOnly cookies (BFF pattern).
- **React SPA:** access token in memory, refresh token in HttpOnly cookie.
- **Simple SPA (not recommended):** both in `localStorage` — only with explicit user consent.

### 5. Boilerplate pages *(optional)*

Invoke `fe-boilerplate` to scaffold starter pages (landing page, admin portal, or a custom description — combinable). If auth was skipped, auth pages are scaffolded as stubs under `src/stubs/auth/` and can be removed later.

### 6. CLAUDE.md

Create `CLAUDE.md` at project root capturing:

- Selections from step 1 (including the chosen **Visual style** direction).
- Path alias rule, folder layout.
- Auth status (wired now / deferred, link to `fe-auth`).
- **Style section** — populated during `fe-boilerplate` via `frontend-design`. Fields:
  - Direction name (from step 1).
  - 4–6 color hexes with names.
  - Type families + roles (display, body, mono if used).
  - Layout concept (one sentence + alignment guidance).
  - Motion rule (one line).
  - Principles (2–3 bullets — what makes this design specific to the subject).
  - **Consistency rule:** *"Read this section before writing any new UI. New components must reuse these tokens. To change the direction, run `fe-restyle` — do not deviate ad hoc."*
- Don'ts.

## Input files

- None (greenfield).

## Output

- New project skeleton scaffolded via the official framework CLI.
- `tsconfig.json` + build-tool config with `@/*` alias.
- ESLint + Prettier configs.
- `CLAUDE.md` at project root.
- (Optional, via `fe-auth` + `fe-boilerplate`) auth client, store, starter pages, admin layout.

## Recommendations

- If a UI library is chosen, do not hand-roll primitives (Button, Modal, Table, Form, Select) — the library covers them.
- Prefer library theming (Antd tokens / MUI theme / Tailwind theme) over inline styles.
- Do not mix UI libraries.
- Set up path aliases **before** writing any imports.
- Avoid storing tokens in `localStorage` — only with explicit user consent; see `fe-auth`.
