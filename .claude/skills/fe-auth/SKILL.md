---
name: fe-auth
description: Use when wiring authentication into a frontend app. Covers token storage (SPA vs Next.js BFF), backend contract, Axios interceptor rules with a shared refresh promise, and a final checklist. Referenced by fe-setup and fe-boilerplate.
---

# fe-auth

The backend (see `be/`) issues a short-lived JWT access token and a rotating opaque refresh token, both delivered as cookies. This skill defines how the frontend consumes them.

## Storage

| Concern              | React SPA (default)                             | Next.js (App Router)                            | Simple SPA (localStorage — not recommended)     |
| -------------------- | ----------------------------------------------- | ----------------------------------------------- | ----------------------------------------------- |
| Access token (15 min)| In-memory (Zustand / Redux slice)               | HttpOnly cookie set by Next server              | `localStorage['at']`                            |
| Refresh token (7d)   | HttpOnly, Secure, SameSite=Lax, `Path=/auth`    | HttpOnly, Secure, SameSite=Lax, `Path=/auth`    | `localStorage['rt']`                            |
| CSRF                 | Not required (no cookie-based auth for API)     | Double-submit token on state-changing routes    | N/A (bearer only)                               |

Avoid the `localStorage` option unless the user has explicitly asked for it — tokens become reachable to any XSS on the page (XSS = full account takeover). Reserve it for internal tools or prototypes where the tradeoff is understood.

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

- `authClient` — `baseURL = /auth`, `withCredentials: true`. Used only for `login`, `register`, `refresh`, `logout`, `forgot-password`.
- `api` — `baseURL = /api`, sends `Authorization: Bearer <access>` from the Zustand store on each request.

Interceptor rules on `api`:

1. **Request:** attach `Authorization` from store.
2. **Response 401 + not `_retry`:** mark `_retry`, await the **single shared refresh promise** (create it if none is in flight), replay original request.
3. **Response 401 after retry:** clear store, redirect to `/login`.
4. **Response 403:** pass through — do not refresh (permission problem, not auth).

The shared refresh promise pattern prevents a burst of parallel 401s from firing N refresh calls.

## Next.js BFF client

- All API calls go to Next Route Handlers or Server Actions.
- The Next server holds the cookies, forwards to the backend, and rewrites `Set-Cookie` back onto the browser response.
- Middleware refreshes the access token when it's within 60s of expiry.
- Client components never see a token — they call `/api/*` on the Next origin.

## Checklist

- [ ] `at` never touches `localStorage` or a rendered DOM attribute.
- [ ] `rt` cookie has `HttpOnly`, `Secure` (in prod), `SameSite=Lax`, `Path=/auth`.
- [ ] Single shared refresh promise; parallel 401s coalesce.
- [ ] 403 does not trigger refresh.
- [ ] Logout clears both cookies via the API, then clears in-memory state.
- [ ] Reset-password token is single-use and expires.
- [ ] E2E covers: login → refresh (force expiry) → logout.

## Input files

- `be/src/modules/auth/` — source of truth for the backend contract.

## Output

- Auth client module (`src/lib/auth-client.ts` or equivalent).
- Auth store (Zustand slice / Redux slice / Next cookie helpers).
- Interceptor with the shared refresh promise.

## Recommendations

- Keep the auth client in a single file — do not scatter `withCredentials` across the codebase.
- The shared refresh promise lives on the module (module-scoped `let refreshInFlight: Promise | null`) — not inside the interceptor closure.
- Do not add an `Authorization` header fallback on `authClient`. It reads cookies only.
