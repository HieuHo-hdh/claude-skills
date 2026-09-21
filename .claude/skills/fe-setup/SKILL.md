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

**Router:** Next.js file-based (default when Next is chosen), React Router v6 (default when React + Vite), or Vue Router (when Vue).

**State / storage:** Zustand + TanStack Query (default), Redux Toolkit + RTK Query, or Context + fetch.

**Linter / formatter:** ESLint (flat config) + Prettier (default). Ask whether to add `eslint-plugin-import` for import ordering.

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
- Testing setup (Vitest / Jest, Playwright / Cypress).

Verify: dev server boots, typecheck passes, first component renders.

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

Create `CLAUDE.md` at project root capturing: selections from step 1, path alias rule, folder layout, auth status (wired now / deferred, link to `fe-auth`), and don'ts.

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
