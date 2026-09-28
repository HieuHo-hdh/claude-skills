---
name: fe-auth
description: Use when wiring authentication into a frontend app. Covers token storage (SPA vs Next.js BFF), backend contract, Axios interceptor rules with a shared refresh promise, and a final checklist. Referenced by fe-setup and fe-boilerplate.
---

# fe-auth

The backend (see `be/`) issues a short-lived JWT access token and a rotating opaque refresh token, both delivered as cookies. This skill defines how the frontend consumes them.

## Prerequisites

- **`fe-setup` has run** - framework, state library, and auth-storage decision recorded in `CLAUDE.md`.
- **Backend contract known** - either the `be/` folder is available in the same workspace, or the user can point to the auth-endpoint spec (routes, cookie names, TTLs). Without this, do not guess - ask.
- **`axios` installed** - added by `fe-setup` as a default HTTP dep. If missing, install before wiring the client.
- No MCPs required.

## Working directory

Runs inside `source-code/<project-name>/` - the project scaffolded by `fe-setup`. Before writing auth code: confirm the current directory, read that project's `CLAUDE.md` for framework / state library / auth-storage decision, and if multiple projects exist under `source-code/`, ask which one first. All generated files (`src/lib/auth-client.ts`, auth store slice, middleware, route handlers, tests) go under that project only.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B (inside an existing project).

## Shared conventions

- **Coding conventions:** `.claude/rules/fe-coding-conventions.md` - naming, imports, TS rules, error-handling at boundaries (auth interceptors are a boundary).
- **Project structure:** `.claude/rules/fe-project-structure.md` - auth client at `src/api/`, auth store under `src/stores/`, guard component under `src/layouts/`.
- **A11y:** `.claude/rules/fe-a11y.md` - auth forms need labeled inputs, visible focus, and non-color-only error state. (Form UI is emitted by `fe-boilerplate`; this skill wires the data path.)

## Storage

| Concern              | React SPA (default)                             | Next.js (App Router)                            | Simple SPA (localStorage - not recommended)     |
| -------------------- | ----------------------------------------------- | ----------------------------------------------- | ----------------------------------------------- |
| Access token (15 min)| In-memory (Zustand / Redux slice)               | HttpOnly cookie set by Next server              | `localStorage['at']`                            |
| Refresh token (7d)   | HttpOnly, Secure, SameSite=Lax, `Path=/auth`    | HttpOnly, Secure, SameSite=Lax, `Path=/auth`    | `localStorage['rt']`                            |
| CSRF                 | Not required (no cookie-based auth for API)     | Double-submit token on state-changing routes    | N/A (bearer only)                               |

Avoid the `localStorage` option unless the user has explicitly asked for it - tokens become reachable to any XSS on the page (XSS = full account takeover). Reserve it for internal tools or prototypes where the tradeoff is understood.

## Token shape

- **Access:** JWT, 15 min TTL, `{ sub, role, iat, exp }`.
- **Refresh:** opaque random (32+ bytes), rotating on every use, 7-day rolling window with 30-day absolute cap. Reuse of a revoked token revokes the whole family.

## Backend contract

- `POST /auth/register` → sets `at` + `rt` cookies.
- `POST /auth/login` → sets `at` + `rt` cookies.
- `POST /auth/refresh` → reads `rt`, rotates it, resets `at`.
- `POST /auth/logout` → clears both cookies.
- `POST /auth/forgot-password` → sends reset email.
- `POST /auth/reset-password` → consumes single-use token.

## React SPA client

Two Axios instances:

- `authClient` - `baseURL = /auth`, `withCredentials: true`. Used only for `login`, `register`, `refresh`, `logout`, `forgot-password`.
- `api` - `baseURL = /api`, sends `Authorization: Bearer <access>` from the Zustand store on each request.

Interceptor rules on `api`:

1. **Request:** attach `Authorization` from store.
2. **Response 401 + not `_retry`:** mark `_retry`, await the **single shared refresh promise** (create it if none is in flight), replay original request.
3. **Response 401 after retry:** clear store, redirect to `/login`.
4. **Response 403:** pass through - do not refresh (permission problem, not auth).

The shared refresh promise pattern prevents a burst of parallel 401s from firing N refresh calls.

## Next.js BFF client

- All API calls go to Next Route Handlers or Server Actions.
- The Next server holds the cookies, forwards to the backend, and rewrites `Set-Cookie` back onto the browser response.
- Middleware refreshes the access token when it's within 60s of expiry.
- Client components never see a token - they call `/api/*` on the Next origin.

## Next.js `?next=` handling

The login page reads `?next=<original path>` via `useSearchParams`. Two rules:

1. **Suspense boundary:** wrap the inner form in a `<Suspense>` boundary. Without it, `next build` fails on static prerender.
2. **Same-origin only:** run the value through a `safeNextPath()` helper before navigating (must start with `/`, no `//`, no protocol) - prevents open-redirect.

## Stub compatibility (when running alongside `fe-boilerplate` stubs)

If `fe-boilerplate` has already scaffolded `src/stubs/auth/`, the stub store uses `zustand/middleware`'s `persist` to `localStorage` so a browser reload keeps the fake session. Otherwise every admin-guard demo looks broken after F5.

### Stub → real swap checklist

When replacing stubs with the real client during `fe-auth`:

- [ ] Replace every `@/stubs/auth/...` import with the real client / store / guard.
- [ ] Grep the repo for `stubs/auth` - should be **zero** matches.
- [ ] Delete `src/stubs/auth/`.
- [ ] Re-run `pnpm typecheck` and `pnpm build` to confirm nothing lingers.

## Input

- `be/src/modules/auth/` - source of truth for the backend contract.

## Output

- Auth client module (`src/lib/auth-client.ts` or equivalent).
- Auth store (Zustand slice / Redux slice / Next cookie helpers).
- Interceptor with the shared refresh promise.

## Verification

- [ ] `at` never touches `localStorage` or a rendered DOM attribute.
- [ ] `rt` cookie has `HttpOnly`, `Secure` (in prod), `SameSite=Lax`, `Path=/auth`.
- [ ] Single shared refresh promise; parallel 401s coalesce.
- [ ] 403 does not trigger refresh.
- [ ] Logout clears both cookies via the API, then clears in-memory state.
- [ ] Reset-password token is single-use and expires.
- [ ] E2E covers: login → refresh (force expiry) → logout.

## Recommendations

- Keep the auth client in a single file - do not scatter `withCredentials` across the codebase.
- The shared refresh promise lives on the module (module-scoped `let refreshInFlight: Promise | null`) - not inside the interceptor closure.
- Do not add an `Authorization` header fallback on `authClient`. It reads cookies only.
