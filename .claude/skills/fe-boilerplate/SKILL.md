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
- [Antd + Tailwind integration](#antd--tailwind-integration-antd-projects-only) - `StyleProvider` lets Tailwind style Antd directly.
- [Icon library convention](#icon-library-convention) - one package per app, picked at `fe-setup`.
- [i18n wiring](#i18n-wiring-optional) - resource files, provider init, language picker.
- [Theme toggle wiring](#theme-toggle-wiring-optional) - `theme` field, Antd algorithm swap or `.dark` class.
- [Animation](#animation-optional) - delegate to `fe-motion`.

**Workflow** - what to scaffold and in what order.
- [0. Style tokens](#0-style-tokens-before-any-ui) - ask direction, derive tokens before any UI.
- [1. Choose starter(s)](#1-choose-starters) - landing / admin / custom, auth mode auto-detected.
- [2. Landing page](#2-landing-page) - Header → Hero → Features → CTA → Footer.
- [3. Public routes](#3-public-routes-always-emit) - shared route wrapper, always emitted.
- [4. Admin portal](#4-admin-portal) - `PrivateRoutes`, SideNav, Header, Body, Footer.
- [5. Custom template](#5-custom-template) - user-described sections + styling.

**Auth handling** - stubbed default, real path when `fe-auth` already ran.
- [Auth stubs](#auth-stubs-default) - fixture pages under `src/stubs/auth/`, swapped by `fe-auth`.
- [Auth guard](#auth-guard-when-fe-auth-already-ran) - inlined into `PrivateRoutes`, optional `?next=` handling.

**Conventions** - forms and routes.
- [Form conventions](#form-conventions) - schema-first, inline errors, disabled submit.
- [Routes wiring](#routes-wiring-admin-portal) - React Router / Next App Router examples.

**I/O & verification** - closing loop.
- [Input](#input) - `fe-setup` selections, optional `fe-auth` client.
- [Output](#output) - starters, route wrappers, stubs.
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
- **Motion:** `.claude/rules/fe-motion.md` - jank-safe properties, duration budget, reduced motion.

## Antd + Tailwind integration *(Antd projects only)*

When the UI library is **Antd** and the project also uses **Tailwind**, install (or ensure) `@ant-design/cssinjs` and wrap the app root in `StyleProvider` so Tailwind utility classes can style Antd components directly - no `style` prop needed for routine layout / spacing / typography tweaks.

```tsx
// src/main.tsx
import { StyleProvider } from '@ant-design/cssinjs'
import { ConfigProvider, App as AntdApp } from 'antd'

<StyleProvider layer>
  <ConfigProvider theme={antdTheme}>
    <AntdApp>…</AntdApp>
  </ConfigProvider>
</StyleProvider>
```

- `layer` (preferred) - emits Antd's styles into a lower CSS cascade layer so Tailwind utilities (higher layer) override cleanly. Pairs naturally with Tailwind v4's `@layer` model.
- `hashPriority="high"` (fallback) - lowers Antd's selector specificity so a plain Tailwind class in the same `className` wins. Use when the toolchain cannot opt into layers.

**Resulting convention for Antd projects:**

- **Default to Tailwind classes on Antd components** for layout, spacing, flex / grid, typography scale, borders. `<Button className="w-full">`, `<Menu className="px-2">`, `<Layout.Header className="sticky top-0 z-10 flex items-center justify-end gap-3">`.
- **Reserve the Antd `style` prop and `ConfigProvider` tokens** for:
  - Runtime-computed values (`style={{ '--progress': `${pct}%` }}`).
  - Fine-grained component tokens the theme exposes (`Button.borderRadius`, `Menu.itemHeight`, `Layout.siderBg`).
  - Internals Tailwind cannot reach (nested Antd DOM like `.ant-table-cell` hover, `Layout.Sider` inner shadow).

This refines `fe-coding-conventions.md` → *One styling system per project* for Antd: `ConfigProvider` owns component **shape** (colors, radii, motion curves) via tokens; Tailwind owns **composition** (where things sit, how much they breathe) via utilities on the same Antd element. Never both for the same visual attribute - do not override an Antd token with a Tailwind class and vice versa.

Record this decision in the project's `CLAUDE.md` once (one line under the Style section) so future UI work doesn't drift back to inline `style` dictionaries.

## Icon library convention

The icon package was picked at `fe-setup` time and recorded in `CLAUDE.md` (`@ant-design/icons`, `lucide-react`, `@phosphor-icons/react`, etc.). Every scaffolded component imports icons from that **one** package - never mix two libraries in the same app (two visual languages, double the tree-shaking cost, inconsistent stroke weights).

- SideNav icons, Header icons, empty-state icons - all from the chosen package.
- Antd + non-Antd-icons: still fine; Antd's internal icons (caret, close X in Modal) are bundled with `antd` itself and are visually neutral enough to coexist with Lucide / Phosphor in user code.
- MUI + non-mui-icons: same - MUI internals stay, user code uses the chosen package.

If a page needs an icon the chosen library does not ship, prefer picking an adjacent one from the same package over reaching into a second library. If a swap is truly necessary, replace the project-wide choice through a focused refactor, not an ad-hoc import.

## i18n wiring *(optional)*

Only if `fe-setup` enabled i18n (locales recorded in `CLAUDE.md`). Emit:

```text
src/i18n/
├── index.ts          ← initializes i18next, registers detector, lists resources
├── en.json           ← default locale (required)
├── vi.json           ← optional; one JSON per extra locale
└── types.d.ts        ← augments `react-i18next` with the resource keyspace
```

- `src/i18n/index.ts` calls `i18next.use(LanguageDetector).use(initReactI18next).init({ fallbackLng: 'en', resources: { en, vi }, detection: { order: ['localStorage', 'navigator'], caches: ['localStorage'] } })`.
- `src/main.tsx` imports `./i18n` **once**, before `<App />` renders.
- Pages read strings via `const { t } = useTranslation()` and `t('home.greeting')`. No raw user-visible strings in JSX for scaffolded pages.
- Admin Header hosts a language picker (Antd `<Select size="small">`, MUI `<Select>`, shadcn `<Select>`) that calls `i18n.changeLanguage(code)`. The detector + `localStorage` cache preserves the choice across reloads.
- Scaffolded resource files include the keys the generated pages actually use (`home.title`, `login.email`, `common.save`, …) - no empty namespaces.

Keep the key space flat and task-oriented (`login.password`, `home.recentUsers`), not component-oriented (`LoginPage.password`). Component names change; task language is stable.

## Theme toggle wiring *(optional)*

Only if `fe-setup` enabled the toggle. Emit the slice field + bootstrap effect + Header toggle button.

**Store** (Redux example - Zustand mirror is the same shape):

```ts
// src/store/ui-slice.ts
type ThemeMode = 'light' | 'dark'
const seed = (): ThemeMode => {
  const saved = localStorage.getItem('ui-theme')
  if (saved === 'light' || saved === 'dark') return saved
  return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light'
}
initialState: { isSideNavOpen: true, theme: seed() }
reducers: {
  setTheme(state, action: PayloadAction<ThemeMode>) {
    state.theme = action.payload
    localStorage.setItem('ui-theme', action.payload)
  },
  toggleTheme(state) {
    state.theme = state.theme === 'light' ? 'dark' : 'light'
    localStorage.setItem('ui-theme', state.theme)
  },
}
```

**UI-library theme swap:**

- **Antd:** `ConfigProvider` reads `theme.algorithm` from the slice.
  ```tsx
  const mode = useAppSelector(selectTheme)
  <ConfigProvider theme={{ algorithm: mode === 'dark' ? antdTheme.darkAlgorithm : antdTheme.defaultAlgorithm, token }}>
  ```
  Keep the token palette monochrome enough to read in both modes, or supply two token objects.
- **MUI:** `createTheme({ palette: { mode } })` memoized on `mode`.
- **shadcn / Tailwind:** a root effect `document.documentElement.classList.toggle('dark', mode === 'dark')`; `src/index.css` defines `.dark { … }` with the same token names remapped to dark values.

**Header toggle:**

```tsx
<Button
  type="text"
  icon={mode === 'dark' ? <SunOutlined /> : <MoonOutlined />}
  onClick={() => dispatch(toggleTheme())}
  aria-label={mode === 'dark' ? 'Switch to light theme' : 'Switch to dark theme'}
/>
```

Swap `<SunOutlined />` / `<MoonOutlined />` for the equivalent icon from the chosen icon library. The button lives in `PrivateRoutes` Header, next to the language picker.

## Animation *(optional)*

If `fe-setup` enabled animation, do **not** emit motion wiring here - **delegate to `fe-motion`**. That skill installs `motion`, writes `src/lib/motion-presets.ts` with a reduced-motion short-circuit, and applies `fadeInUp` + `stagger` to the landing page's Hero / Features / CTA. Rules live in `.claude/rules/fe-motion.md`.

Rule of thumb from `fe-motion.md`: landing pages animate, admin dashboards do not. Entrance ≤ 400ms, hover ≤ 150ms, transforms limited to opacity / translate / scale, every preset short-circuits under `prefers-reduced-motion: reduce`. See the skill for the applied pattern.

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

If **animation** is enabled, apply the `fadeInUp` / `stagger` presets from `src/lib/motion-presets.ts` to Hero, Features, and CTA on this page - see [Animation wiring](#animation-wiring-optional) for the applied pattern.

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

## 3. Public routes *(always emit)*

Emit a shared `PublicRoutes` route wrapper at `src/layouts/PublicRoutes.tsx` (React Router) or the equivalent group layout (Next App Router) regardless of whether landing / admin / custom / auth stubs are picked. It owns the `min-h-dvh`, max-width wrapper, and centered card frame via an `<Outlet />` - prevents the three auth pages (and the landing page, if any) from each duplicating layout scaffolding.

Name is `PublicRoutes`, not `PublicShell` / `PublicLayout` - matches the role it plays in `<Routes>` wiring (`<Route element={<PublicRoutes />}>`) and pairs cleanly with `PrivateRoutes` below.

## 4. Admin portal

Pages:

- `/` - home page, rendered inside `PrivateRoutes`, guarded by auth (stub guard by default; real guard if `fe-auth` already ran).
- `/login`, `/register`, `/forgot-password` - public, wrapped in `PublicRoutes`. Stubs by default; real forms if `fe-auth` already ran.

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
- **Header** - sticky top strip. Shows current user (email / avatar) and a logout button that calls `authClient.post('/logout')` then clears the store. If i18n is enabled, hosts the language picker; if theme toggle is enabled, hosts the sun / moon toggle button. All three (language, theme, user menu) sit right-aligned with `gap-3`.
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
- `src/stubs/auth/api.ts` - fake `stubLogin`, `stubRegister`, `stubForgotPassword`, `stubLogout` functions that resolve after a short delay.
- `src/stubs/auth/auth-slice.ts` *(Redux projects)* - stub slice with `{ user, status, error }` shape and `login` / `register` / `logout` thunks that call the fake API. Persists to `localStorage` so a reload keeps the admin guard demo working.
- `src/stubs/auth/store.ts` *(Zustand projects)* - stub store with the same shape, persisted via Zustand's `persist` middleware.

The guard is **not** a separate stub file - `PrivateRoutes` reads the stub slice / store directly, so the demo works end-to-end before `fe-auth` runs.

Pages import from `src/stubs/auth/` instead of a real `authClient`. When `fe-auth` runs later, it swaps the stub imports for the real client, replaces `stubs/auth/auth-slice.ts` with `src/store/auth-slice.ts`, and deletes `src/stubs/auth/` - see its stub → real swap checklist.

## Auth guard (when fe-auth already ran)

The guard **lives inside `PrivateRoutes.tsx`** - no separate `AuthGuard` component. `PrivateRoutes` reads the auth slice and either renders the private shell (`<Outlet />`) or redirects:

1. Read auth state from the store (`useAppSelector(selectAuthUser)` for Redux, `useAuthStore((s) => s.user)` for Zustand).
2. If unauthenticated → `<Navigate to="/login" replace />`. Appending `?next=<original path>` is optional (return-to-origin); default is a plain `/login`.
3. If authenticated → render the sidebar / header / footer frame around `<Outlet />`.

Do **not** guard by "token present" alone; guard by "store hydrated + user object present". Cold reload path: on app mount, call `/auth/refresh` once; if it fails, treat as logged out.

Keeping the guard inlined into `PrivateRoutes` means one component per route group - the public group has `PublicRoutes`, the private group has `PrivateRoutes`, and the two names tell the whole access story at the `<Routes>` level.

**Next.js `useSearchParams` requires `<Suspense>`.** If `?next=` is enabled, any login page that reads it must wrap the inner form in a `<Suspense>` boundary - otherwise `next build` fails on static prerender.

## Form conventions

- Validation: schema-first (Zod / Yup) with the form library picked in `fe-setup`.
- Submit button disables while the request is in flight.
- API errors surface inline under the relevant field (map `error.details` from the backend envelope) with a fallback banner for non-field errors.
- Password fields use `type="password"` with a show/hide toggle.
- `/forgot-password` shows the same confirmation whether or not the email exists.

## Routes wiring (admin portal)

React Router example (`src/App.tsx`):

```tsx
<Routes>
  <Route element={<PublicRoutes />}>
    <Route path="/login" element={<LoginPage />} />
    <Route path="/register" element={<RegisterPage />} />
    <Route path="/forgot-password" element={<ForgotPasswordPage />} />
  </Route>
  <Route element={<PrivateRoutes />}>
    <Route index element={<HomePage />} />
  </Route>
</Routes>
```

```text
/login              → PublicRoutes  → LoginPage
/register           → PublicRoutes  → RegisterPage
/forgot-password    → PublicRoutes  → ForgotPasswordPage
/                   → PrivateRoutes → HomePage   (guard inlined in PrivateRoutes)
```

Next.js App Router example (segment-group layouts play the same role):

```text
app/(public)/layout.tsx       ← PublicRoutes equivalent
app/(public)/login/page.tsx
app/(public)/register/page.tsx
app/(public)/forgot-password/page.tsx
app/(admin)/layout.tsx        ← PrivateRoutes equivalent (guard + shell)
app/(admin)/page.tsx          ← HomePage
```

## Input

- `fe-setup` selections (framework, UI library, router, state).
- `fe-auth` client + store (optional - only present on a standalone re-run after auth).

## Output

- Chosen starter(s): landing page, admin portal, and/or a custom template.
- Shared `PublicRoutes` route wrapper (always emitted).
- If admin: `PrivateRoutes` route wrapper (auth guard + admin shell inlined), route wiring in `src/App.tsx`.
- If Antd + Tailwind: `StyleProvider` wired in `src/main.tsx` so Tailwind utilities style Antd components directly.
- If i18n enabled: `src/i18n/index.ts` + `src/i18n/<locale>.json` resource files + language picker in `PrivateRoutes` Header.
- If theme toggle enabled: `theme` field on `ui-slice` / `ui-store` (persisted, seeded from `prefers-color-scheme`), UI-library theme swap wired, sun / moon button in `PrivateRoutes` Header.
- If animation enabled: `src/lib/motion-presets.ts` + landing page Hero / Features / CTA wired to `fadeInUp` + `stagger`.
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
