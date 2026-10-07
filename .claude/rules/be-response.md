# API response envelope

Shared rule referenced by every `be-*` skill (`be-setup`, `be-boilerplate`, `be-auth`).

Scope: HTTP response shape for JSON APIs under `source-code/<project-name>-be/`. Deviations: state a reason inline.

## Contents

**Envelope** - the shared wire shape.
- [Shape](#shape) - `{ status, data | error, meta? }` discriminated union.
- [HTTP status codes](#http-status-codes) - real codes on the response, never mirrored in the body.
- [Success](#success) - `sendOk` / `sendCreated` + optional `meta`.
- [Error](#error) - `{ code, message, detail? }`, throw-and-catch via `AppError`.
- [Pagination](#pagination) - `meta.pagination = { page, pageSize, total, totalPages }`.

**Error registry** - codes + messages live in one place.
- [Error codes](#error-codes) - `ERROR_CODES` as const object.
- [Error messages](#error-messages) - `ERROR_MESSAGES: Record<ErrorCode, { message, httpStatus }>`.
- [Validation](#validation) - Zod error → `VALIDATION_FAILED` + `detail = flatten()`.

**Security** - MUST rules for response bodies.
- [Sensitive fields](#sensitive-fields) - never return `password` / `passwordHash` / `tokenHash` / `resetTokenHash`.

**File map** - where each piece lives.
- [File map](#file-map) - types, constants, lib, middleware.

**Anti-patterns**
- [Anti-patterns - reject on sight](#anti-patterns---reject-on-sight)

## Shape

Every JSON response is a **discriminated union** on `status`:

```ts
type SuccessResponse<T> = { status: 'success'; data: T; meta?: Meta }
type ErrorResponse      = { status: 'error';   error: ApiErrorBody; meta?: Meta }

type Meta = { requestId?: string; timestamp?: string; pagination?: Pagination }
type Pagination = { page: number; pageSize: number; total: number; totalPages: number }
type ApiErrorBody = { code: ErrorCode; message: string; detail?: unknown }
```

`204 No Content` ships no body (delete success). Everything else carries the envelope.

## HTTP status codes

Real HTTP status on the response (`res.status(200)`, `res.status(404)`, …). **Never mirror the status in the body** - the client reads `res.status` plus `body.status`; duplicating the number drifts.

- Success: `200` default, `201` on create, `204` on delete (no body).
- Error: comes from the error-code registry (see [Error messages](#error-messages)). The middleware calls `res.status(spec.httpStatus)` before writing the envelope.

## Success

Controllers never hand-build the body. Use the helpers from `@/lib/response`:

```ts
import { buildPagination, sendCreated, sendOk } from '@/lib/response'

// single entity
sendOk(res, user)                                   // 200 { status: 'success', data: user }
sendCreated(res, user)                              // 201 { status: 'success', data: user }

// list with pagination
sendOk(res, items, { pagination: buildPagination(page, pageSize, total) })
```

Signatures:

```ts
sendOk<T>(res: Response, data: T, meta?: Meta, httpStatus = 200): void
sendCreated<T>(res: Response, data: T, meta?: Meta): void
buildPagination(page: number, pageSize: number, total: number): Pagination
```

## Error

Services throw `AppError`; the global error middleware converts to the envelope.

```ts
import { ERROR_CODES } from '@/constants/error-codes'
import { AppError } from '@/lib/app-error'

if (!user) throw new AppError(ERROR_CODES.NOT_FOUND)
if (dup)   throw new AppError(ERROR_CODES.EMAIL_ALREADY_EXISTS)
```

`AppError` signature:

```ts
new AppError(code: ErrorCode, detail?: unknown, overrideMessage?: string)
```

- `code` → looked up in `ERROR_MESSAGES` for `message` + `httpStatus`.
- `detail` → optional structured payload (field errors, offending id, upstream shape). Serialized through to `error.detail`.
- `overrideMessage` → only when the default is wrong for one call site. Prefer adding a new code.

**Controllers never `try/catch`.** They parse (Zod) → call the service → `sendOk`. Thrown errors flow to the middleware.

## Pagination

List endpoints always return rows in `data` and the pager in `meta.pagination`:

```json
{
  "status": "success",
  "data": [ { "id": "...", "email": "..." }, ... ],
  "meta": {
    "pagination": { "page": 1, "pageSize": 20, "total": 137, "totalPages": 7 }
  }
}
```

- **Query**: `?page=1&pageSize=20`. `pageSize` max 100. Parse with Zod at the controller.
- **Service** returns `{ items, total }`. The controller calls `buildPagination` and passes it as meta.
- **Zero total** → `totalPages: 0`, `data: []`. Still a success envelope, not an error.

## Error codes

Codes live in `src/constants/error-codes.ts` as an `as const` object. The `ErrorCode` type is derived; TypeScript catches typos.

```ts
export const ERROR_CODES = {
  AUTH_INVALID_CREDENTIALS: 'AUTH_INVALID_CREDENTIALS',
  AUTH_UNAUTHORIZED: 'AUTH_UNAUTHORIZED',
  AUTH_FORBIDDEN: 'AUTH_FORBIDDEN',
  AUTH_ACCOUNT_DISABLED: 'AUTH_ACCOUNT_DISABLED',
  AUTH_INVALID_TOKEN: 'AUTH_INVALID_TOKEN',
  VALIDATION_FAILED: 'VALIDATION_FAILED',
  NOT_FOUND: 'NOT_FOUND',
  EMAIL_ALREADY_EXISTS: 'EMAIL_ALREADY_EXISTS',
  INVALID_ROLE: 'INVALID_ROLE',
  SERVICE_NOT_READY: 'SERVICE_NOT_READY',
  INTERNAL_ERROR: 'INTERNAL_ERROR',
} as const

export type ErrorCode = (typeof ERROR_CODES)[keyof typeof ERROR_CODES]
```

Add new codes when a client needs to branch on the failure. Do not reuse a code across unrelated conditions - clients then cannot act on it.

## Error messages

Messages + HTTP status live in `src/constants/error-messages.ts`, keyed by code:

```ts
import { ERROR_CODES, type ErrorCode } from '@/constants/error-codes'

export const ERROR_MESSAGES: Record<ErrorCode, { message: string; httpStatus: number }> = {
  [ERROR_CODES.AUTH_INVALID_CREDENTIALS]: { message: 'Invalid email or password', httpStatus: 401 },
  [ERROR_CODES.AUTH_UNAUTHORIZED]:        { message: 'Unauthorized',             httpStatus: 401 },
  [ERROR_CODES.AUTH_FORBIDDEN]:           { message: 'Forbidden',                httpStatus: 403 },
  [ERROR_CODES.NOT_FOUND]:                { message: 'Resource not found',       httpStatus: 404 },
  [ERROR_CODES.EMAIL_ALREADY_EXISTS]:     { message: 'Email already exists',     httpStatus: 409 },
  [ERROR_CODES.VALIDATION_FAILED]:        { message: 'Validation failed',        httpStatus: 400 },
  [ERROR_CODES.INTERNAL_ERROR]:           { message: 'Internal server error',    httpStatus: 500 },
  // ...
}
```

Messages are user-safe strings. Never embed stack traces, SQL, or raw upstream payloads here - that's what `detail` is for, and even `detail` must be scrubbed.

## Validation

Zod errors bypass the code registry - the middleware special-cases them:

```ts
if (err instanceof ZodError) {
  return res.status(400).json({
    status: 'error',
    error: {
      code: ERROR_CODES.VALIDATION_FAILED,
      message: ERROR_MESSAGES[ERROR_CODES.VALIDATION_FAILED].message,
      detail: err.flatten(),
    },
  })
}
```

Controllers call `schema.parse(req.body)` and let Zod throw. Do not wrap in `try/catch`.

## Sensitive fields

**MUST never appear in a response body:**

- `password`, `passwordHash`
- `tokenHash`, `resetTokenHash`, raw refresh / reset tokens (except in the one-time response that issues them)
- any API key, private key, or secret stored on the entity

**Enforcement** - at the ORM query layer, not downstream.

- **Prisma** - `omit: { passwordHash: true }` on every read / write that doesn't need the hash. The field never leaves the DB layer, so there's nothing to strip later.

  ```ts
  prisma.user.findUnique({ where: { id }, omit: { passwordHash: true }, include: { role: true } })
  ```

- **The only exceptions**: login (needs the hash to `argon2.verify`) and password reset (needs to write a new hash). Both go through dedicated repo methods (`byEmail`, `byEmailWithRole`, `setPasswordHash`) and the hash never flows further than the service that reads it.
- **Drizzle / Mongoose** - achieve the same via explicit `select` lists / `.select('-passwordHash')` projections at the repo. Same rule: hash is scoped to the two methods that need it.

Reviewers should treat *any* new repo method that returns a full entity without `omit` as a bug.

## File map

```text
src/
├── types/response.ts              # SuccessResponse, ErrorResponse, Meta, Pagination
├── constants/
│   ├── error-codes.ts             # ERROR_CODES as const, ErrorCode type
│   └── error-messages.ts          # ERROR_MESSAGES: Record<ErrorCode, { message, httpStatus }>
├── lib/
│   ├── app-error.ts               # AppError class
│   └── response.ts                # sendOk, sendCreated, buildPagination
└── middleware/
    └── error-handler.ts           # maps AppError / ZodError / unknown → envelope
```

Services import from `@/lib/app-error` and `@/constants/error-codes`. Controllers import from `@/lib/response`. The error handler is wired once in `src/index.ts` as the last middleware.

## Anti-patterns - reject on sight

- Returning the raw entity (`res.json(user)`) - breaks the discriminated-union contract clients rely on.
- Mirroring the HTTP status into the body (`{ status: 200, data: ... }` where `status` is a number) - two sources of truth that drift. `status` is the envelope discriminator (`'success'` / `'error'`), not an HTTP code.
- `try/catch` around a service call in the controller - the error middleware already handles everything.
- Hand-building `{ status: 'error', ... }` in a controller - throw `AppError` and let the middleware emit it.
- Reusing `AppError(code, 'inline message')` to override the default on every call - add a new code to the registry instead.
- Any repo method returning a user / token entity without `omit`-ing the hash - the one path through login is the exception, everything else leaks.
- Logging raw errors into `error.detail` - stack traces, SQL, upstream payloads belong in the server log, not the response.
- Separate `isLoading` / `error` envelopes for the same resource - one envelope per response, period.
- A new resource that invents its own list envelope (`{ data: { rows, cursor } }`) when the project already has one - converge on `data: []` + `meta.pagination`.
