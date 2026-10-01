---
name: fe-boilerplate
description: Use after fe-setup to scaffold starter pages. Offers three combinable options - landing page, admin portal, or a user-described custom template. Auth pages are scaffolded as stubs unless fe-auth already ran; fe-auth swaps them for the real client later.
---

# fe-boilerplate

Assumes `fe-setup` has picked framework / UI library / router / state. Runs **before** `fe-auth` in the `fe-setup` flow - auth pages are scaffolded as stubs by default. Only when `fe-auth` has already wired a client (standalone re-run) are they real.

## Contents

**Setup** - preconditions and shared rules.
- [Prerequisites](#prerequisites) - upstream skills, MCPs, deps.
- [Working directory](#working-directory) - target project under `source-code/`.
- [Shared conventions](#shared-conventions) - responsive, a11y, coding, structure rules.

**Workflow** - what to scaffold and in what order.
- [0. Style tokens](#0-style-tokens-before-any-ui) - ask direction, derive tokens before any UI.
- [1. Choose starter(s)](#1-choose-starters) - landing / admin / custom, auth mode auto-detected.
- [2. Landing page](#2-landing-page) - Header → Hero → Features → CTA → Footer.
- [3. Public shell](#3-public-shell-always-emit) - shared layout, always emitted.
- [4. Admin portal](#4-admin-portal) - shell, SideNav, Header, Body, Footer.
- [5. Custom template](#5-custom-template) - user-described sections + styling.

**Auth handling** - stubbed default, real path when `fe-auth` already ran.
- [Auth stubs](#auth-stubs-default) - fixture pages under `src/stubs/auth/`, swapped by `fe-auth`.
- [Auth guard](#auth-guard-when-fe-auth-already-ran) - store-hydrated guard, optional `?next=` handling.

**Conventions** - forms and routes.
- [Form conventions](#form-conventions) - schema-first, inline errors, disabled submit.
- [Routes wiring](#routes-wiring-admin-portal) - React Router / Next App Router examples.

**I/O & verification** - closing loop.
- [Input](#input) - `fe-setup` selections, optional `fe-auth` client.
- [Output](#output) - starters, shells, guard, routes, stubs.
- [Verification](#verification) - typecheck, build, anchor / stub sweeps.

## Prerequisites

- **`fe-setup` has run** - project scaffolded at `source-code/<project-name>/` with `CLAUDE.md` capturing framework, UI library, router, state, and an empty Style section stub.
- **shadcn/ui projects:** `pnpm dlx shadcn@latest add …` runs on demand - no pre-install needed, but network access is required the first time.

## Working directory

Runs inside `source-code/<project-name>/` - the project scaffolded by `fe-setup`. Before scaffolding pages: confirm the current directory, read that project's `CLAUDE.md` for framework / UI library / Style tokens, and if multiple projects exist under `source-code/`, ask which one first. All generated files (`src/app/…`, `src/components/…`, `src/stubs/auth/…`) go under that project only.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B (inside an existing project).

## Shared conventions

- **Responsive:** `.claude/rules/fe-responsive.md` - mobile-first, breakpoint scale, touch targets.
- **A11y:** `.claude/rules/fe-a11y.md` - landmarks, keyboard operability, focus, contrast.
- **Coding conventions:** `.claude/rules/fe-coding-conventions.md` - naming, imports, TS rules.
- **Project structure:** `.claude/rules/fe-project-structure.md` - where pages / layouts / stubs live.

## 0. Style tokens *(before any UI)*

Every generated component reads from the Style section in `CLAUDE.md`. Before scaffolding anything:

1. Check `CLAUDE.md` for a populated Style section.
2. If empty, ask the user to pick a direction - a **seed**, not a locked template. Present the options below, then refine the tokens against the actual subject.

   - **Refined minimal** - generous whitespace, 8pt spacing scale, one accent color, hairline borders, restrained motion. Good for SaaS, docs, portfolios.
   - **Editorial** - serif display + clean sans body, strong type scale, asymmetric layout, pull quotes, long line-height. Good for blogs, content sites.
   - **Glass / Aurora** - translucent layers, backdrop blur, soft gradient mesh, subtle borders, luminous highlights. Good for landing pages, dashboards with a hero.
   - **Bento grid** - modular tiles of varied sizes, consistent gutters, one hero tile, mixed content types. Good for feature overviews.
   - **Neo-brutalist** - thick outlines, hard offset shadows, flat saturated colors, oversized type, no gradients. Good for creative tools, youth brands.
   - **Dark / Terminal** - near-black surfaces, monospace accents, single neon accent, grid or noise texture, focus glows. Good for dev tools, dashboards.
   - **Soft / Clay** - rounded 3D-ish surfaces, pastel palette, inner shadows, friendly rounded type. Good for consumer apps, onboarding.
   - **Themed (commit-heavy)** - pick one world (retro-futurist, RPG, print, brutal industrial) and commit to its materials and type. Good for games, brand sites.
   - **Custom (brief-driven)** - skip presets; describe subject + audience, then derive tokens from scratch.

   Produce:
   - 4–6 color hexes with names.
   - Type families + roles.
   - Layout concept + alignment guidance.
   - Motion rule.
   - 2–3 principles specific to the subject.
3. Write the derived tokens into `CLAUDE.md`'s Style section, and into the UI library's theme (`tailwind.config.ts` / Antd `ConfigProvider` theme / MUI `createTheme`) so components consume them by variable, not by hardcoded hex.
4. Only then generate landing / admin / custom pages, honoring the tokens.

If the Style section is already populated, **reuse it** - do not regenerate. Deviations must go through `fe-restyle`, not ad-hoc edits.

## 1. Choose starter(s)

Ask the user which starter(s) to scaffold. **Options are combinable** (e.g., landing + admin):

- **Landing page** - public marketing page.
- **Admin portal** - authenticated dashboard shell.
- **Custom** - user describes what they want; ask for sections and styling preferences, then scaffold.

Do not ask about auth. Detect it: if `src/api/` already has an auth client from `fe-auth`, emit real auth pages; otherwise scaffold them as stubs under `src/stubs/auth/` with placeholder handlers and fixture data. `fe-auth` replaces the stubs afterwards.

## 2. Landing page

Sections in order: **Header** (logo + nav links) → **Hero** → **Features** (3–6 tiles) → **CTA** → **Footer**.

Generate using the UI library the project picked in `fe-setup`. Do not hand-roll:

- **shadcn/ui + Tailwind:** compose from shadcn blocks (Hero, Feature grid, CTA, Footer).
- **Antd:** use Antd's `Layout`, `Row`/`Col` grid, `Card`, and `Typography` primitives.
- **MUI:** use MUI templates and `Container` / `Grid` / `Card` / `Typography`.

**No dead nav links.** Every Header / Footer entry must resolve to a real section on the same page (anchor like `#features`) or a real route. Bare `#` placeholders are not acceptable - either wire the target or remove the link.

**Anchor navigation must work.** If the Header is sticky (default) and any nav link targets a same-page `#section`, the theme layer must set both:

```css
html {
  scroll-behavior: smooth;
  scroll-padding-top: <sticky-header-height + ~12px>; /* e.g. 76px for h-16 */
}
@media (prefers-reduced-motion: reduce) {
  html { scroll-behavior: auto; }
}
```

Without `scroll-padding-top`, anchor targets land at `y=0` and the sticky header covers the section eyebrow / heading - the reader lands blind. Set this once in `globals.css` / `index.css`, not per-section. Verify one anchor click with Playwright (or manually): the target's `getBoundingClientRect().top` should be `≥ header.bottom` after the scroll settles.

## 3. Public shell *(always emit)*

Emit a shared `PublicShell` layout regardless of whether landing / admin / custom / auth stubs are picked. It owns the `min-h-screen`, max-width wrapper, and centered card frame - prevents the three auth pages (and the landing page, if any) from each duplicating layout scaffolding.

## 4. Admin portal

Pages:

- `/` - home page, rendered inside the admin layout, guarded by auth (stub guard by default; real guard if `fe-auth` already ran).
- `/login`, `/register`, `/forgot-password` - public, wrapped in `PublicShell`. Stubs by default; real forms if `fe-auth` already ran.

Layout:

```text
┌────────────┬──────────────────────────────┐
│            │           Header             │
│            ├──────────────────────────────┤
│  SideNav   │                              │
│            │            Body              │
│            │                              │
│            ├──────────────────────────────┤
│            │           Footer             │
└────────────┴──────────────────────────────┘
```

- **SideNav** - full-height left rail, collapses to icons on `< md`, hides behind a drawer on `< sm`. Highlights the active route.
- **Header** - sticky top strip. Shows current user (email / avatar) and a logout button that calls `authClient.post('/logout')` then clears the store.
- **Body** - routed page. Use `<Outlet />` (React Router) or `children` (Next.js App Router).
- **Footer** - thin static strip: version, copyright.

Use the UI library's layout primitives:

- **Antd:** `Layout` + `Layout.Sider` + `Layout.Header` + `Layout.Content` + `Layout.Footer`.
- **MUI:** `Drawer` + `AppBar` + `Toolbar` + `Container`.
- **shadcn/ui:** compose from Sidebar / Sheet / NavigationMenu blocks.

## 5. Custom template

Ask the user:

1. What sections / pages they want.
2. Styling preferences (color palette, dense vs airy, minimal vs marketing-rich).
3. Any references (existing sites, screenshots).

Scaffold with the UI library from `fe-setup` and match the styling notes. If the user is vague, propose a section list back for confirmation before generating.

## Auth stubs (default)

Location: `src/stubs/auth/` - one folder for all stub pieces so they can be deleted together.

- `src/stubs/auth/users.json` - fixture users for local testing.
- `src/stubs/auth/handlers.ts` - fake `login`, `register`, `forgotPassword`, `logout` functions that resolve after a short delay and write a fake user to the stub store.
- `src/stubs/auth/guard.tsx` - stub guard that treats any resolved fake user as "authenticated".

The stub store persists the fake session (Zustand `persist` → `localStorage`) so a reload keeps the admin guard demo working.

Pages import from `src/stubs/auth/` instead of a real `authClient`. When `fe-auth` runs later, it swaps the stub imports for the real client and deletes `src/stubs/auth/` - see its stub → real swap checklist.

## Auth guard (when fe-auth already ran)

Wrap the admin layout route in a guard that:

1. Reads auth state from the store.
2. If unauthenticated → redirect to `/login`. Appending `?next=<original path>` is optional (return-to-origin); default is a plain `/login`.
3. If authenticated → render the layout.

Do **not** guard by "token present" alone; guard by "store hydrated + user object present". Cold reload path: on app mount, call `/auth/refresh` once; if it fails, treat as logged out.

**Next.js `useSearchParams` requires `<Suspense>`.** If `?next=` is enabled, any login page that reads it must wrap the inner form in a `<Suspense>` boundary - otherwise `next build` fails on static prerender.

## Form conventions

- Validation: schema-first (Zod / Yup) with the form library picked in `fe-setup`.
- Submit button disables while the request is in flight.
- API errors surface inline under the relevant field (map `error.details` from the backend envelope) with a fallback banner for non-field errors.
- Password fields use `type="password"` with a show/hide toggle.
- `/forgot-password` shows the same confirmation whether or not the email exists.

## Routes wiring (admin portal)

React Router example:

```text
/login              → PublicShell → LoginPage
/register           → PublicShell → RegisterPage
/forgot-password    → PublicShell → ForgotPasswordPage
/                   → AuthGuard → AdminLayout → HomePage
```

Next.js App Router example:

```text
app/(public)/login/page.tsx
app/(public)/register/page.tsx
app/(public)/forgot-password/page.tsx
app/(admin)/layout.tsx       ← AuthGuard + AdminLayout
app/(admin)/page.tsx         ← HomePage
```

## Input

- `fe-setup` selections (framework, UI library, router, state).
- `fe-auth` client + store (optional - only present on a standalone re-run after auth).

## Output

- Chosen starter(s): landing page, admin portal, and/or a custom template.
- Shared `PublicShell` layout (always emitted).
- If admin: admin layout, auth guard component, route wiring.
- Default: stub login / register / forgot-password pages + `src/stubs/auth/` folder for fixture data.
- If `fe-auth` already ran: real login / register / forgot-password pages.

## Verification

Run from `source-code/<project-name>/`. Stop and fix on first failure.

```bash
pnpm typecheck
pnpm lint
pnpm build
pnpm dev     # smoke every scaffolded route once
```

- Every Header / Footer link resolves - no bare `href="#"`, no dead routes.
- Sticky-header + `#section` anchor click lands with `getBoundingClientRect().top >= header.bottom` (Playwright preferred).
- Admin routes redirect to `/login` when unauthenticated.
- If `?next=` is enabled: the param is same-origin (starts with `/`, no `//`, no protocol) - validate before navigating to prevent open redirect.
- If auth was stubbed: `src/stubs/auth/` folder exists and is imported only by scaffolded pages. After `fe-auth` runs, grep sweep:

  ```bash
  rg -n 'stubs/auth' src
  ```

  Zero results means real auth has fully replaced the stubs.
