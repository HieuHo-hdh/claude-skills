---
name: fe-setup
description: Use when scaffolding a new frontend project from scratch. Walks through language / framework / UI / router / state / lint / test selections, prefers the framework's official CLI, and optionally hands off to fe-auth and fe-boilerplate.
---

# fe-setup

Default: **pin every dependency to its latest stable version at install time.** No caret ranges for the initial scaffold - reproducible installs first.

## Contents

**Setup** - preconditions and target location.
- [Prerequisites](#prerequisites) - Node, package manager, `source-code/`, network.
- [Working directory](#working-directory) - target project under `source-code/`.

**Workflow** - selections → confirm → scaffold → auth → boilerplate → CLAUDE.md.
- [1. Selections](#1-selections) - language / framework / UI / router / state / lint / test / style seed.
- [2. Confirmation](#2-confirmation) - echo selection and get approval.
- [3. Scaffold](#3-scaffold) - CLI, path aliases, UI library, state, HTTP, lint, tests.
- [4. Authentication decision](#4-authentication-decision-optional) - wire now via `fe-auth` or defer.
- [5. Boilerplate pages](#5-boilerplate-pages-optional) - hand off to `fe-boilerplate`.
- [6. CLAUDE.md](#6-claudemd) - record selections + Style section stub.

**I/O & verification** - closing loop.
- [Input](#input) - none (greenfield).
- [Output](#output) - skeleton, config, `CLAUDE.md`.
- [Verification](#verification) - dev / typecheck / lint / test / build.
- [Recommendations](#recommendations) - guardrails.

## Prerequisites

- **Node.js** - LTS or newer on PATH (`node -v`).
- **Package manager** - one of `pnpm` (default), `npm`, `yarn`, `bun` installed globally. Verify with `<pm> -v` before scaffolding.
- **`source-code/` directory** at repo root - create it if missing (all projects live under it, never at the repo root).
- **Network access** - the framework CLIs (`pnpm create next-app`, `pnpm create vite`, `pnpm create vue`) fetch templates from the registry on first run.
- No MCPs required at this stage.

## Working directory

Scaffold into `source-code/<project-name>/` - never at the repo root. Short version:

- Confirm `source-code/` exists at the repo root (create if missing).
- Confirm `source-code/<project-name>/` does not exist yet - if it does, ask (new name / resume / overwrite).
- `cd source-code` **before** invoking the framework CLI so it writes into `source-code/<name>/`.
- After scaffold, `cd source-code/<name>/`; all further commands run there.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path A (creating a new project). Read it once before scaffolding.

## Workflow

### 1. Selections

Ask the user each of the following, one section at a time, and record their answer. Present the default and a 1-line tradeoff for the alternatives - do not just dump a list.

**Project name and package manager:** Ask for the project name. Ask for the package manager: **pnpm** (default), npm, yarn, or bun.

**Language:** TypeScript (default) or JavaScript.

**Framework:** Next.js (App Router, default), React + Vite, or Vue + Vite.

**UI library:** Antd (default), MUI, or shadcn/ui + Tailwind. Pick one - do not mix.

**Visual style / direction:** Pick a starting direction - a **seed**, not a locked template. `fe-boilerplate` refines the tokens against the actual subject before generating any UI.

- **Refined minimal** - generous whitespace, 8pt spacing scale, one accent color, hairline borders, restrained motion. Good for SaaS, docs, portfolios.
- **Editorial** - serif display + clean sans body, strong type scale, asymmetric layout, pull quotes, long line-height. Good for blogs, content sites.
- **Glass / Aurora** - translucent layers, backdrop blur, soft gradient mesh, subtle borders, luminous highlights. Good for landing pages, dashboards with a hero.
- **Bento grid** - modular tiles of varied sizes, consistent gutters, one hero tile, mixed content types. Good for feature overviews.
- **Neo-brutalist** - thick outlines, hard offset shadows, flat saturated colors, oversized type, no gradients. Good for creative tools, youth brands.
- **Dark / Terminal** - near-black surfaces, monospace accents, single neon accent, grid or noise texture, focus glows. Good for dev tools, dashboards.
- **Soft / Clay** - rounded 3D-ish surfaces, pastel palette, inner shadows, friendly rounded type. Good for consumer apps, onboarding.
- **Themed (commit-heavy)** - pick one world (retro-futurist, RPG, print, brutal industrial) and commit to its materials and type. Good for games, brand sites.
- **Custom (brief-driven)** - skip presets; describe subject + audience, then derive tokens from scratch during `fe-boilerplate`.

**Router:** Next.js file-based (default when Next is chosen), React Router v6 (default when React + Vite), or Vue Router (when Vue).

**State / storage:** Zustand + TanStack Query (default), Redux Toolkit + RTK Query, or Context + fetch.

**Linter / formatter:** ESLint (flat config) + Prettier (default). Ask whether to add `eslint-plugin-import` for import ordering - if yes, pin **`eslint@^9`** (v10 breaks the plugin). For projects already on ESLint 10, use the successor `eslint-plugin-import-x` instead.

**Unit testing:** Vitest + Testing Library (default) or Jest + Testing Library.

**E2E testing:** Playwright (default), Cypress, or none.

### 2. Confirmation

Echo the full selection back as a bullet list and get explicit approval before running any install command.

### 3. Scaffold

**Prefer the framework's official CLI first.** Only add what it does not already cover.

Run the CLI **from `source-code/`** with the chosen name and package manager (examples use `pnpm` - swap for the chosen PM):

- **Next.js:** `cd source-code && pnpm create next-app@latest <name> --yes` (drop `--yes` if the user wants the interactive prompts).
- **React + Vite:** `cd source-code && pnpm create vite <name> --template react-ts` (or `react` for JS).
- **Vue + Vite:** `cd source-code && pnpm create vue@latest <name>`.

The project lands at `source-code/<name>/`. All further steps in this skill run inside that directory.

After the CLI finishes, `cd source-code/<name>` and run the commands matching each selection. Commands use `pnpm` - for `npm`/`yarn`/`bun` swap `pnpm add` → `npm i` / `yarn add` / `bun add` and `pnpm dlx` → `npx` / `yarn dlx` / `bunx`.

**Path aliases (`@/*` → `src/*`):**

Add to `tsconfig.json`:
```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": { "@/*": ["src/*"] }
  }
}
```

For **Vite** projects also install and wire the resolver:
```bash
pnpm add -D vite-tsconfig-paths
```
Add `tsconfigPaths()` to `plugins` in `vite.config.ts`. Do **not** duplicate the alias into `resolve.alias`.

For **Next.js** the alias in `tsconfig.json` is enough - Next reads it directly.

**UI library:**

- **Antd (default):**
  ```bash
  pnpm add antd @ant-design/icons
  ```
  Next.js App Router also needs the SSR bridge:
  ```bash
  pnpm add @ant-design/nextjs-registry
  ```
  Wrap `app/layout.tsx` children in `<AntdRegistry>`. Configure tokens through `<ConfigProvider theme={{ token: {...} }}>`.

- **MUI:**
  ```bash
  pnpm add @mui/material @emotion/react @emotion/styled @mui/icons-material
  ```
  Next.js App Router additionally:
  ```bash
  pnpm add @mui/material-nextjs
  ```

- **shadcn/ui + Tailwind:**
  ```bash
  pnpm add -D tailwindcss @tailwindcss/postcss postcss
  pnpm dlx shadcn@latest init
  ```
  Add primitives on demand: `pnpm dlx shadcn@latest add button input card dialog`.

**State / storage:**

- **Zustand + TanStack Query (default):**
  ```bash
  pnpm add zustand @tanstack/react-query
  pnpm add -D @tanstack/react-query-devtools
  ```

- **Redux Toolkit + RTK Query:**
  ```bash
  pnpm add @reduxjs/toolkit react-redux
  ```

- **Context + fetch:** no install.

**Router:**

- **Next.js:** built-in - no install.
- **React + Vite:** `pnpm add react-router-dom`.
- **Vue + Vite:** the `create vue` prompts add `vue-router`; if skipped, `pnpm add vue-router`.

**HTTP + validation (used by every project):**
```bash
pnpm add axios zod
```

Also add the form library that pairs with the UI choice:
- shadcn/ui: `pnpm add react-hook-form @hookform/resolvers`
- Antd / MUI: their built-in `Form` primitives - no install.

**Lint / format (only if the CLI did not already set them up):**

```bash
pnpm add -D eslint@^9 prettier eslint-config-prettier eslint-plugin-prettier
```

If the user opted in to import ordering, add:
```bash
pnpm add -D eslint-plugin-import
```
For projects already pinned to ESLint 10, swap `eslint-plugin-import` → `eslint-plugin-import-x` instead.

**Unit testing:**

- **Vitest + Testing Library (default):**
  ```bash
  pnpm add -D vitest @vitest/ui @testing-library/react @testing-library/jest-dom @testing-library/user-event jsdom vite-tsconfig-paths
  ```
  Add `"test": "vitest"` to `package.json` scripts. In `vitest.config.ts`, add `tsconfigPaths()` to `plugins` so `@/*` resolves - do **not** duplicate the alias into `resolve.alias`.

- **Jest + Testing Library:**
  ```bash
  pnpm add -D jest @types/jest ts-jest @testing-library/react @testing-library/jest-dom @testing-library/user-event jest-environment-jsdom
  ```

**E2E testing:**

- **Playwright (default):**
  ```bash
  pnpm create playwright@latest
  ```
  Answers: TypeScript, `tests/`, GitHub Actions no (unless asked), install browsers yes.

- **Cypress:**
  ```bash
  pnpm add -D cypress
  pnpm dlx cypress open
  ```

- **None:** skip.

**Next.js 16 callout:** if Next.js was picked, add a note to `CLAUDE.md`: Next 16 has breaking changes vs. training-data patterns (Turbopack default, `next build` no longer lints, `next typegen` needed for route types, `AGENTS.md` auto-regenerated). Consult `node_modules/next/dist/docs/` before writing route/data patterns from memory.

Once install completes, run [Verification](#verification) before moving on.

### 4. Authentication decision *(optional)*

Ask: "Wire authentication now, or defer?" Auth is **optional at setup time** - you can skip it and invoke `fe-auth` later.

- If **now** → invoke `fe-auth` to wire storage, client, and interceptors.
- If **deferred** → note "auth deferred; run `fe-auth` when needed" in `CLAUDE.md`.

Storage recommendation per framework (full table in `fe-auth`):

- **Next.js App Router:** both tokens in HttpOnly cookies (BFF pattern).
- **React SPA:** access token in memory, refresh token in HttpOnly cookie.
- **Simple SPA (not recommended):** both in `localStorage` - only with explicit user consent.

### 5. Boilerplate pages *(optional)*

Invoke `fe-boilerplate` to scaffold starter pages (landing page, admin portal, or a custom description - combinable). If auth was skipped, auth pages are scaffolded as stubs under `src/stubs/auth/` and can be removed later.

### 6. CLAUDE.md

Create `CLAUDE.md` at project root capturing:

- Selections from step 1 (including the chosen **Visual style** direction).
- Path alias rule, folder layout.
- Auth status (wired now / deferred, link to `fe-auth`).
- **Style section** - populated during `fe-boilerplate`. Fields:
  - Direction name (from step 1).
  - 4–6 color hexes with names.
  - Type families + roles (display, body, mono if used).
  - Layout concept (one sentence + alignment guidance).
  - Motion rule (one line).
  - Principles (2–3 bullets - what makes this design specific to the subject).
  - **Consistency rule:** *"Read this section before writing any new UI. New components must reuse these tokens. To change the direction, run `fe-restyle` - do not deviate ad hoc."*
- Don'ts.

## Input

- None (greenfield).

## Output

- New project skeleton scaffolded via the official framework CLI.
- `tsconfig.json` + build-tool config with `@/*` alias.
- ESLint + Prettier configs.
- `CLAUDE.md` at project root.
- (Optional, via `fe-auth` + `fe-boilerplate`) auth client, store, starter pages, admin layout.

## Verification

Run in order from `source-code/<name>/` - stop and fix on first failure.

```bash
pnpm dev             # dev server boots on the expected port
pnpm typecheck       # or: pnpm exec tsc --noEmit
pnpm lint
pnpm test -- --run   # if Vitest is wired
pnpm build           # catches prerender-time issues that dev hides
```

- `pwd` ends with `source-code/<name>` (not the repo root, not a sibling).
- `@/*` alias resolves in both source and tests (import a stub via `@/lib/...` in a test).
- `CLAUDE.md` exists at project root with selections + auth status recorded.

## Recommendations

- If a UI library is chosen, do not hand-roll primitives (Button, Modal, Table, Form, Select) - the library covers them.
- Prefer library theming (Antd tokens / MUI theme / Tailwind theme) over inline styles.
- Do not mix UI libraries.
- Set up path aliases **before** writing any imports.
- Avoid storing tokens in `localStorage` - only with explicit user consent; see `fe-auth`.
