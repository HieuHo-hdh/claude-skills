# Project structure

Shared rule referenced by every `be-*` skill that writes files (`be-setup`, `be-boilerplate`, `be-auth`, `be-test`, `be-rate-limit`).

Scope: folder layout under `source-code/<project-name>-be/src/`. Deviations: state a reason inline.

## Contents

**Layout** - where files live.
- [Top-level folders](#top-level-folders) - one folder per layer, created on first file.
- [Colocation](#colocation) - tests + helpers next to the code they cover.
- [Entity file map](#entity-file-map) - the five files every resource touches.

**Boundaries** - who imports whom.
- [Layering](#layering) - imports point down the table.
- [Barrels](#barrels) - never at a directory root.

**Anti-patterns**
- [Anti-patterns - reject on sight](#anti-patterns---reject-on-sight)

## Top-level folders

Create a folder when its first file arrives, not before - except the ones `be-setup` seeds (`config/`, `lib/`, `middleware/`, `constants/`, `types/`).

| Folder            | Holds                                                                 | Notes                                                                  |
| ----------------- | --------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `config/`         | `env.ts` (Zod-parsed `process.env`)                                   | Only file in the codebase that reads `process.env`.                    |
| `constants/`      | `error-codes.ts`, `error-messages.ts`, other `as const` registries    | SCREAMING_SNAKE values. No runtime logic.                              |
| `controllers/`    | One file per resource (`user.ts`) exporting `<entity>Controller`      | Three lines in the common case - parse → service → send.               |
| `lib/`            | Framework glue - `prisma.ts`, `logger.ts`, `redis.ts`, `response.ts`, `app-error.ts`, `cookies.ts`, `mailer.ts` | kebab-case files. No business logic.                   |
| `middleware/`     | Express middleware - `error-handler.ts`, `auth.ts`, `rate-limit.ts`   | May import `lib` + `constants`. Never `services` / `repositories`.     |
| `repositories/`   | One file per resource (`user.ts`) exporting `<entity>Repo`            | Only place that imports the DB client.                                 |
| `routes/`         | One `Router` per resource (`user.ts`) exporting `<entity>Router`      | Mounts controllers + middleware; no business logic.                    |
| `schemas/`        | Zod schemas + inferred types, one file per domain                     | Hoisted to module scope. Shared across controller / service / repo.   |
| `services/`       | One file per resource (`user.ts`) exporting `<entity>Service`         | Business logic. Throws `AppError`. No `req` / `res`.                   |
| `stubs/`          | Temporary fixtures, one subfolder per concern (`stubs/auth/`)         | Must be deletable in one `rm -r` when the real impl lands.             |
| `types/`          | Ambient `.d.ts` (e.g. `express.d.ts` extending `Request`)             | No runtime exports.                                                    |
| `app.ts`          | `createApp()` factory - middleware wiring + router mounts             | Exports the app; does not bind a port.                                 |
| `index.ts`        | Entry - calls `createApp().listen(env.PORT)`                          | Only file allowed to call `.listen`.                                   |

Integration / supertest specs live in `tests/` at the project root, outside `src/`. Prisma schema + migrations live in `prisma/` at the project root.

## Colocation

- **Unit tests** live in `__tests__/` subfolders next to the code they cover: `src/controllers/__tests__/user.test.ts`, `src/services/__tests__/user.test.ts`, `src/schemas/__tests__/user.test.ts`. See `be-test`.
- **Helpers used by one layer** stay in that layer: a `src/services/user-helpers.ts` is fine if only `user.ts` imports it. Used by two services → promote to `lib/`.
- **Resource-specific types** live in `src/schemas/<entity>.ts` (inferred from the Zod schema), not in a parallel `types/` tree.

## Entity file map

One entity (`user`) touches the same five files in every project. Contents vary by ORM; the file names and exports do not.

```text
src/schemas/user.ts                      ← Zod schemas + inferred types (userCreateSchema, UserCreate)
src/repositories/user.ts                 ← userRepo - DB access only, omits sensitive fields
src/services/user.ts                     ← userService - business logic, throws AppError
src/controllers/user.ts                  ← userController - parse req, call service, send res
src/routes/user.ts                       ← userRouter - mounts controller methods + middleware
src/{schemas,services,controllers}/__tests__/user.test.ts  ← one unit test per layer (see be-test)
```

The router is mounted once in `src/app.ts`:

```ts
app.use('/users', userRouter)
```

## Layering

Imports point **down** the table, never up. The error middleware is the only cross-cutter - every layer may throw `AppError` and the middleware converts.

| Layer           | May import                                                         | Must not import                                       |
| --------------- | ------------------------------------------------------------------ | ----------------------------------------------------- |
| `routes/`       | `controllers`, `middleware`                                        | `services`, `repositories`                            |
| `controllers/`  | `services`, `schemas`, `lib`, `constants`                          | `repositories`, `routes`, `req`/`res` into services   |
| `services/`     | `repositories`, `schemas`, `lib`, `constants`                      | `controllers`, `routes`, `middleware`, `req` / `res`  |
| `repositories/` | `@/lib/prisma` (DB client), `schemas` (types only)                 | `services`, `controllers`, `routes`                   |
| `middleware/`   | `lib`, `constants`                                                 | `services`, `repositories` (auth middleware is itself the service boundary) |
| `schemas/`      | `zod`, other `schemas` (types only)                                | everything else                                       |
| `lib/`          | external packages, `config`, `constants`                           | `services`, `repositories`, `controllers`, `routes`   |
| `config/`       | `zod`, `dotenv`                                                    | everything else                                       |
| `constants/`    | `constants` (type-only cross-refs)                                 | everything else                                       |

Full invariants per layer: `.claude/rules/be-coding-conventions.md` → *Controller / Service / Repository / Schema rules*.

## Barrels

A per-resource re-export (`src/routes/index.ts` that collects every router) is allowed when `src/app.ts` grows past ~6 `app.use` lines - see `be-boilerplate` → *Routes wiring*. A barrel at a layer root (`src/services/index.ts`, `src/repositories/index.ts`) is not - it defeats tree-shaking, hides import origin, and makes grep for a specific service require two hops.

## Anti-patterns - reject on sight

- Files at the repo root or in a sibling project - see `fe-workspace-layout.md` (Path B applies verbatim to BE).
- `utils/`, `helpers/`, `common/`, `misc/` folders - name the concern (`lib/`, `schemas/`, `constants/`) or colocate.
- DB client imported from a service / controller / route - route all DB access through `repositories/`.
- A route handler calling `prisma` / `drizzle` / `mongoose` directly - put it in a service, let the controller call the service.
- `services/` importing from `controllers/` or `routes/` - the dependency points the other way.
- `repositories/` returning a user / token entity without `omit`-ing the hash - sensitive data leaks through the one layer that was supposed to scope it.
- A second stubs-style folder (`mocks/`, `fixtures/`) for the same throwaway data - one folder per concern under `stubs/`.
- A `*.test.ts` sibling to the source file (`src/services/user.test.ts`) instead of under `__tests__/` - breaks the colocation convention and the layer `ls` stops being just source.
- `src/index.ts` doing anything other than `createApp().listen(...)` - middleware and router wiring belong in `src/app.ts` so `be-test` can import the app without binding a port.
- A barrel at a layer root (`src/services/index.ts`) - hides origin and defeats tree-shaking.
