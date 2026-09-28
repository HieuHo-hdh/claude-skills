---
name: fe-page
description: Use when building one full page / route from a spec - e.g., "build the /dashboard page", "wire the /settings/profile route". Gathers spec, registers the route, composes the layout, wires data with loading/error/empty/success, ships a smoke test. Not for a single reusable widget (use fe-component) or theme changes (use fe-restyle).
---

# fe-page

Builds one page (route): spec, route registration, layout composition, data + four states (loading / error / empty / success), a11y sweep, responsive check, smoke test. Reuses components from `src/components/` and layouts from `src/layouts/` - does not hand-roll primitives.

## Prerequisites

- **`fe-setup` has run** - framework / router / UI library / state / test runner recorded in `CLAUDE.md`.
- **Style section is populated** - this skill consumes tokens. Empty → run `fe-boilerplate`'s Style tokens step first.
- **`fe-boilerplate` has run** (or the equivalent) - `PublicShell`, `AdminLayout`, and `AuthGuard` (if the page is guarded) already exist under `src/layouts/`. If missing, invoke `fe-boilerplate` first - do not scaffold shells inline.
- **`fe-auth` has run** *only if* the page is behind auth - needs the client, store, and guard component.
- **Testing library installed** - Vitest or Jest + Testing Library from `fe-setup`.

## Working directory

Runs inside `source-code/<project-name>/`. Read `CLAUDE.md` for framework / router / state / auth-storage / Style tokens before generating anything. All files go under that project.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B.

## Shared conventions

- **Responsive:** `.claude/rules/fe-responsive.md` - mobile-first, breakpoint scale, three-width sanity check.
- **A11y:** `.claude/rules/fe-a11y.md` - semantic landmarks, focus on route change, contrast, keyboard operability.
- **Coding conventions:** `.claude/rules/fe-coding-conventions.md` - naming, imports, TypeScript, error handling.
- **Project structure:** `.claude/rules/fe-project-structure.md` - where pages live, where data-fetching hooks live, one-folder-per-component rule.
- **Style tokens:** the Style section of `CLAUDE.md` - consume by variable, not by hex.

## Workflow

### 1. Gather spec

Ask (or read from context) - one section at a time:

- **Route** - path (`/dashboard`, `/settings/profile`, `/blog/[slug]`). Static or dynamic segment?
- **Title / meta** - browser tab title, meta description, og-image if it matters.
- **Auth requirement** - public, authenticated, or role-gated. Which roles?
- **Layout** - `PublicShell`, `AdminLayout`, `AuthLayout`, or a new one (rare - push back).
- **Sections in order** - a bulleted outline (`Header stat cards`, `Recent activity table`, `Notifications panel`).
- **Data sources** - one line per endpoint (`GET /api/dashboard/summary`, `GET /api/activity?limit=20`). What are the query params?
- **Empty state** - what does the page show when the primary data is empty? *Do not skip this - empty is a first-class state.*
- **Error state** - recoverable (retry button) or terminal (support link)?
- **Interactions** - mutations on this page (POST / PATCH / DELETE), and what they refresh after success.

If any answer is "I don't know", stop and ask. Wrong spec → wrong page.

### 2. Register the route

**Next.js App Router.** Create the file. Group segment folders in parentheses for shells:

```
src/app/(admin)/dashboard/page.tsx        → /dashboard
src/app/(admin)/settings/profile/page.tsx → /settings/profile
src/app/(public)/blog/[slug]/page.tsx     → /blog/:slug
```

`layout.tsx` inside `(admin)` owns the `AuthGuard + AdminLayout` wrap - the page itself is just the body. Do not re-wrap layouts inside `page.tsx`.

**React Router v6 (Vite).** Add the route to `src/router.tsx`:

```tsx
{
  path: '/dashboard',
  element: <AuthGuard><AdminLayout /></AuthGuard>,
  children: [{ index: true, element: <DashboardPage /> }],
}
```

Page component lives at `src/pages/Dashboard/DashboardPage.tsx` - one folder per page, mirroring the component convention.

**Vue Router.** Add to `src/router/index.ts`; component at `src/pages/Dashboard.vue`.

**Never use bare `<a href>` for internal navigation.** Use the framework's `<Link>` (Next.js `next/link`, React Router `<Link>` / `<NavLink>`, Vue `<RouterLink>`) so the router handles it.

### 3. Compose the layout

The page component is **thin**. It:

1. Reads params / search params.
2. Calls data hook(s).
3. Renders a `<Sections>` composition - one `<section>` per bulleted item from step 1.

The shell (`AdminLayout`, `PublicShell`) is applied at the route level, **not** inside the page. Do not import `AdminLayout` inside `DashboardPage.tsx`.

Each section renders reusable components from `src/components/`. If a section needs a component that does not exist yet, stop and invoke `fe-component` - do not hand-roll.

### 4. Data fetching - four states, always

Every page that loads data handles **loading, error, empty, success** - explicitly. Skipping any of them is a bug that ships:

| State     | What renders                                                                                    |
| --------- | ----------------------------------------------------------------------------------------------- |
| loading   | Skeleton or spinner. Preserve layout - do not reflow when data arrives.                         |
| error     | Human message + retry button (recoverable) or support link (terminal). Never a raw stack trace. |
| empty     | Illustration or icon + one-line explanation + primary action ("Create your first project").    |
| success   | The real UI.                                                                                    |

Location of the fetch depends on state library (from `fe-setup`):

- **TanStack Query** - `useQuery` in a hook: `src/hooks/use-dashboard-summary.ts` or `src/pages/Dashboard/use-dashboard.ts` (if only the page uses it).
- **Redux Toolkit + RTK Query** - `dashboardApi.useGetSummaryQuery()`.
- **Context + fetch** - a custom hook that calls `apiClient.get(...)` and returns `{ data, isLoading, error, refetch }`. Wrap error handling in the hook, not the component.

**Never** fetch directly in the page component body - always through a hook.

**Zod-validate every server response.** Undocumented shape drift silently breaks pages otherwise.

**Mutations** - one hook per mutation (`useUpdateProfile`, `useDeleteInvite`). On success, invalidate the affected query and surface a toast (or inline confirmation). On error, surface inline (validation) or as a banner (network).

### 5. Build sections one at a time

For each bulleted section from step 1:

1. Wrap in a semantic `<section>` with an accessible name (`aria-labelledby="section-recent-activity"`).
2. Render the components. Pass data down as props - no prop-drilling more than one level; if it goes deeper, colocate the fetch or lift into a page-local Context.
3. Stub the section's data with a loading skeleton on first pass - verify layout works, then wire the data hook.
4. Verify the section at 375 / 768 / 1280 before moving to the next.

Do not build all sections then wire data - the loading / empty / error paths get skipped that way.

### 6. Meta / SEO

- **Next.js App Router** - export `metadata` from `page.tsx`:

  ```ts
  export const metadata = {
    title: 'Dashboard - Acme',
    description: 'Overview of your projects and recent activity.',
  }
  ```

  Dynamic pages use `generateMetadata`.

- **React Router / Vue Router** - use `react-helmet-async` / `unhead` or set `document.title` in an effect. Include an `og:image` if the page is publicly linkable.

### 7. Auth guard (if the page is guarded)

Wrap the route (not the page) with `AuthGuard`. The guard:

1. Reads auth from the store.
2. If not hydrated → render a full-screen loader (not the redirect - hydration flash is a bug).
3. If unauthenticated → redirect to `/login?next=<encoded original path>`.
4. If authenticated → render the layout.

Role-gated pages get a second check inside the guard or a `<RoleGate roles={['admin']}>` wrapper - do not scatter role checks through the JSX.

### 8. A11y sweep

Before verifying:

- Exactly one `<h1>` for the page.
- Landmarks: `<header>`, `<nav>` (in the shell), `<main>` around the page body, `<footer>`.
- Section headings step by one level (`h1` → `h2` → `h3`; no jumps).
- Route-change focus - after client-side navigation, focus the `<h1>` or announce the title via a visually hidden live region.
- Every interactive element reachable by keyboard alone.
- Skip-to-content link works and lands on `<main>`.

Full checklist: `.claude/rules/fe-a11y.md`.

### 9. Three-width sanity check

Load the route at **375 / 768 / 1280 px** (Chrome DevTools device toolbar). Check:

- No horizontal scroll.
- All sections readable - nothing clipped.
- Sticky header does not cover the first section (`scroll-padding-top` set - see `fe-restyle` Smooth page transitions).
- Touch targets ≥ 44×44 px on the mobile view.

Full rule: `.claude/rules/fe-responsive.md`.

### 10. Smoke test - one per page

Cover the contract, not every branch. One test file per page under the page folder:

```tsx
// src/pages/Dashboard/DashboardPage.test.tsx
import { render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { DashboardPage } from './DashboardPage'
import { server, rest } from '@/mocks/server'

describe('DashboardPage', () => {
  it('renders the summary once data resolves', async () => {
    server.use(
      rest.get('/api/dashboard/summary', (_, res, ctx) =>
        res(ctx.json({ projects: 3, alerts: 1 })),
      ),
    )
    render(<MemoryRouter><DashboardPage /></MemoryRouter>)
    await waitFor(() => {
      expect(screen.getByRole('heading', { level: 1, name: /dashboard/i })).toBeInTheDocument()
      expect(screen.getByText(/3 projects/i)).toBeInTheDocument()
    })
  })

  it('shows the empty state when there is no data', async () => {
    server.use(
      rest.get('/api/dashboard/summary', (_, res, ctx) =>
        res(ctx.json({ projects: 0, alerts: 0 })),
      ),
    )
    render(<MemoryRouter><DashboardPage /></MemoryRouter>)
    expect(await screen.findByText(/create your first project/i)).toBeInTheDocument()
  })
})
```

For Next.js App Router pages, render via the framework's testing helpers (or extract the presentational body into a client component and test that in isolation).

Jest projects swap `vi.fn()` → `jest.fn()` where relevant.

## Input

- `CLAUDE.md` - framework, router, state, Style section.
- Existing components under `src/components/` and layouts under `src/layouts/`.
- API client + endpoints at `src/api/`.

## Output

- Next.js: `src/app/<segment>/page.tsx` (+ `layout.tsx` if new).
- Vite + React Router: `src/pages/<Name>/<Name>Page.tsx` + `index.ts` + route entry in `src/router.tsx`.
- Vue: `src/pages/<Name>.vue` + route entry.
- Co-located data hooks (`use-<domain>.ts`) if the fetch is page-scoped.
- Smoke test co-located with the page.

## Verification

Run from `source-code/<project-name>/`. Stop and fix on first failure.

```bash
pnpm typecheck
pnpm lint
pnpm test <PageName>          # scoped to this page
pnpm build                    # catches prerender-time issues dev hides
pnpm dev                      # smoke the route manually
```

`pnpm build` matters especially for Next.js pages using `useSearchParams` - needs `<Suspense>` around the reader or the static prerender fails.

## Recommendations

- **Design the four states before writing JSX.** Empty state especially is the one most often skipped and most jarring in production.
- **Do not hand-roll layout shells.** Reuse `PublicShell` / `AdminLayout`. Missing? Invoke `fe-boilerplate` first.
- **Do not hand-roll components the page needs.** Missing? Invoke `fe-component`. This skill composes; it does not create primitives.
- **Fetch through a hook, always.** Pages that call `fetch` directly are the ones that leak abort handlers, race conditions, and error swallowing.
- **Reject color / size / breakpoint literals on self-review.** Same rule as `fe-component` - use tokens.
- **Auth guard wraps the route, not the page.** Wrapping the page duplicates guard logic across every route in the same shell.
- **Test one behavior per page** (`renders the primary data` + `renders the empty state`). Save exhaustive coverage for component tests.
