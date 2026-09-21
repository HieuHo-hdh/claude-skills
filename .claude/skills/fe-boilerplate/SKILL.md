---
name: fe-boilerplate
description: Use after fe-setup to scaffold starter pages. Offers three combinable options — landing page, admin portal, or a user-described custom template. Auth pages are stubbed if fe-auth was skipped.
---

# fe-boilerplate

Assumes `fe-setup` has picked framework / UI library / router / state. `fe-auth` is optional — if it has not run, auth pages are scaffolded as stubs.

## 1. Choose starter(s)

Ask the user which starter(s) to scaffold. **Options are combinable** (e.g., landing + admin):

- **Landing page** — public marketing page.
- **Admin portal** — authenticated dashboard shell.
- **Custom** — user describes what they want; ask for sections and styling preferences, then scaffold.

Then ask: "Wire real auth pages now (invoke `fe-auth`), or scaffold auth pages as stubs?" Stubs live under `src/stubs/auth/` with placeholder handlers and fixture data — safe to remove once real auth is wired.

## 2. Landing page

Sections in order: **Header** (logo + nav links) → **Hero** → **Features** (3–6 tiles) → **CTA** → **Footer**.

Generate using the UI library the project picked in `fe-setup`. Do not hand-roll:

- **shadcn/ui + Tailwind:** compose from shadcn blocks (Hero, Feature grid, CTA, Footer).
- **Antd:** use Antd's `Layout`, `Row`/`Col` grid, `Card`, and `Typography` primitives.
- **MUI:** use MUI templates and `Container` / `Grid` / `Card` / `Typography`.

**No dead nav links.** Every Header / Footer entry must resolve to a real section on the same page (anchor like `#features`) or a real route. Bare `#` placeholders are not acceptable — either wire the target or remove the link.

## 3. Public shell *(always emit)*

Emit a shared `PublicShell` layout regardless of whether landing / admin / custom / auth stubs are picked. It owns the `min-h-screen`, max-width wrapper, and centered card frame — prevents the three auth pages (and the landing page, if any) from each duplicating layout scaffolding.

## 4. Admin portal

Pages:

- `/` — home page, rendered inside the admin layout, guarded by auth (real guard if `fe-auth` ran; stubbed guard otherwise).
- `/login`, `/register`, `/forgot-password` — public, wrapped in `PublicShell`. Real forms if `fe-auth` ran; stubs otherwise.

Layout:

```
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

- **SideNav** — full-height left rail, collapses to icons on `< md`, hides behind a drawer on `< sm`. Highlights the active route.
- **Header** — sticky top strip. Shows current user (email / avatar) and a logout button that calls `authClient.post('/logout')` then clears the store.
- **Body** — routed page. Use `<Outlet />` (React Router) or `children` (Next.js App Router).
- **Footer** — thin static strip: version, copyright.

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

## Auth guard (when fe-auth is wired)

Wrap the admin layout route in a guard that:

1. Reads auth state from the store.
2. If unauthenticated → redirect to `/login` with `?next=<original path>`.
3. If authenticated → render the layout.

Do **not** guard by "token present" alone; guard by "store hydrated + user object present". Cold reload path: on app mount, call `/auth/refresh` once; if it fails, treat as logged out.

**Next.js `useSearchParams` requires `<Suspense>`.** Any login page that reads `?next=` must wrap the inner form in a `<Suspense>` boundary — otherwise `next build` fails on static prerender.

## Auth stubs (when fe-auth is skipped)

Location: `src/stubs/auth/` — one folder for all stub pieces so they can be deleted together.

- `src/stubs/auth/users.json` — fixture users for local testing.
- `src/stubs/auth/handlers.ts` — fake `login`, `register`, `forgotPassword`, `logout` functions that resolve after a short delay and store a fake user in memory.
- `src/stubs/auth/guard.tsx` — stub guard that treats any resolved fake user as "authenticated".

Pages import from `src/stubs/auth/` instead of a real `authClient`. When `fe-auth` runs later, swap the stub imports for the real client and delete `src/stubs/auth/`.

## Form conventions

- Validation: schema-first (Zod / Yup) with the form library picked in `fe-setup`.
- Submit button disables while the request is in flight.
- API errors surface inline under the relevant field (map `error.details` from the backend envelope) with a fallback banner for non-field errors.
- Password fields use `type="password"` with a show/hide toggle.

## Routes wiring (admin portal)

React Router example:

```
/login              → PublicShell → LoginPage
/register           → PublicShell → RegisterPage
/forgot-password    → PublicShell → ForgotPasswordPage
/                   → AuthGuard → AdminLayout → HomePage
```

Next.js App Router example:

```
app/(public)/login/page.tsx
app/(public)/register/page.tsx
app/(public)/forgot-password/page.tsx
app/(admin)/layout.tsx       ← AuthGuard + AdminLayout
app/(admin)/page.tsx         ← HomePage
```

## Input files

- `fe-setup` selections (framework, UI library, router, state).
- `fe-auth` client + store (optional).

## Output

- Chosen starter(s): landing page, admin portal, and/or a custom template.
- Shared `PublicShell` layout (always emitted).
- If admin: admin layout, auth guard component, route wiring.
- If auth was wired: real login / register / forgot-password pages.
- If auth was skipped: stub pages + `src/stubs/auth/` folder for fixture data.

## Recommendations

- Use the UI library's primitives / block templates — do not hand-roll Button / Input / Form / Card / Layout / Hero / Feature grid.
- Keep pages presentational; move API (or stub) calls into hooks (`useLogin`, `useRegister`, `useForgotPassword`) that own the loading + error state.
- The `?next=` redirect param must be a same-origin path — validate before navigating to prevent open-redirect.
- Do not reveal whether an email exists on `/forgot-password`.
- Delete `src/stubs/auth/` once real auth replaces it — leaving stubs risks accidental production use.
