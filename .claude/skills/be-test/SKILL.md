---
name: be-test
description: Use after be-boilerplate (or on-demand) to add Vitest + Supertest unit tests, route-level smokes, and an optional Postman collection to a Node.js backend under source-code/<name>-be/. Writes test files per layer (`schemas`, `services`, `controllers`), seeds three route-level smoke specs under `tests/`, splits the tsconfig so `@/*` resolves in both `src/` and `tests/`, and adds a disposable `postgres-test` service to docker-compose. Postman section is opt-in and generates a Postman v2.1 collection + a local environment file for manual API exploration.
---

# be-test

Default: **colocate unit tests under a `__tests__/` subfolder in each layer; no DB coupling.** Repository + full-router happy-path tests are deferred to a future DB-coupled test skill.

## Contents

**Setup** - preconditions and target.
- [Prerequisites](#prerequisites) - upstream skills, deps already installed.
- [Working directory](#working-directory) - must be `source-code/<name>-be/`.

**Workflow** - test harness → test files → optional Postman.
- [1. Test harness](#1-test-harness) - tsconfig split, silenced logger, test DB in compose.
- [2. Layer map](#2-layer-map) - which layer gets which test file.
- [3. Schema tests](#3-schema-tests) - happy parse + rejection per schema.
- [4. Service tests](#4-service-tests) - mock repo, cover AppError branches.
- [5. Controller tests](#5-controller-tests) - mock service, Supertest the handler + envelope.
- [6. Route-level smokes](#6-route-level-smokes) - three files under `tests/`.
- [7. Postman collection](#7-postman-collection-optional) - exportable JSON + environment.

**Boundaries** - what this skill does not cover.
- [What this skill does not test](#what-this-skill-does-not-test) - repositories + CRUD happy paths.

**I/O & verification**
- [Input](#input) - existing `be-boilerplate` output.
- [Output](#output) - files written.
- [Verification](#verification) - typecheck + full `pnpm test`.

**Anti-patterns**
- [Anti-patterns - reject on sight](#anti-patterns---reject-on-sight)

## Prerequisites

- `be-setup` has installed Vitest + Supertest + `vite-tsconfig-paths`.
- `be-boilerplate` has run - at least one resource exists under `src/{schemas,services,controllers}/` and `src/app.ts` exports `createApp()`.
- Error envelope files exist (`src/constants/error-codes.ts`, `src/lib/app-error.ts`, `src/middleware/error-handler.ts`).

## Working directory

Must be `source-code/<project-name>-be/`. Confirm:

```bash
pwd                            # must end in source-code/<name>-be
ls CLAUDE.md src/app.ts        # both must exist
```

If either fails, stop - the project was not scaffolded by `be-setup` + `be-boilerplate`.

## 1. Test harness

**Split `tsconfig` so tests resolve `@/*` without breaking build `rootDir`.**

```json
// tsconfig.json
{ "compilerOptions": { "rootDir": "src", ... }, "include": ["src"] }
```

```json
// tsconfig.test.json
{ "extends": "./tsconfig.json", "compilerOptions": { "rootDir": "." }, "include": ["src", "tests"] }
```

Point the Vitest paths plugin at the test config:

```ts
// vitest.config.ts
plugins: [tsconfigPaths({ projects: ['./tsconfig.test.json'] })],
test: { globals: true, environment: 'node', include: ['src/**/*.test.ts', 'tests/**/*.test.ts'] },
```

Extend the typecheck script to cover both configs:

```json
"typecheck": "tsc --noEmit && tsc --noEmit -p tsconfig.test.json"
```

**Silence logs under test** - gate the pino level on `env.NODE_ENV`:

```ts
// src/lib/logger.ts
const level = env.NODE_ENV === 'test' ? 'silent' : env.NODE_ENV === 'production' ? 'info' : 'debug'
```

Vitest sets `NODE_ENV=test` automatically; `env.ts` already allows `'test'` as a valid value.

**Add a test database to `docker-compose.yml`** - sibling to the dev service, `tmpfs` so it resets on container restart:

```yaml
postgres-test:
  image: postgres:16-alpine
  container_name: <project>-postgres-test
  environment:
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: postgres
    POSTGRES_DB: <project>_test
  ports: ['5435:5432']
  tmpfs: ['/var/lib/postgresql/data']
  healthcheck:
    test: ['CMD-SHELL', 'pg_isready -U postgres']
    interval: 5s
    timeout: 5s
    retries: 10
```

The test DB is seeded here for the future DB-coupled test skill; this skill writes no tests that touch it, so `pnpm test` passes with the container stopped.

## 2. Layer map

**Colocate unit tests under a `__tests__/` subfolder in each layer.** Vitest's include (`src/**/*.test.ts`) picks them up with no config change.

| Layer           | Test file                                      | Mock boundary                                                        | Needs DB? |
| --------------- | ---------------------------------------------- | -------------------------------------------------------------------- | --------- |
| `schemas/`      | `src/schemas/__tests__/<name>.test.ts`         | none - pure Zod parse / safeParse                                    | no        |
| `services/`     | `src/services/__tests__/<name>.test.ts`        | `vi.mock('@/repositories/<name>')`                                   | no        |
| `controllers/`  | `src/controllers/__tests__/<name>.test.ts`     | `vi.mock('@/services/<name>')` + Supertest on a one-controller app   | no        |
| `repositories/` | *(deferred)* - needs real DB + migrations      | —                                                                    | yes       |
| route-level     | `tests/<name>.test.ts`                         | Supertest on full `createApp()`                                      | no (gate / 400 only) |

## 3. Schema tests

One happy parse + one rejection per schema file. No framework code:

```ts
// src/schemas/__tests__/user.test.ts
import { describe, expect, it } from 'vitest'
import { userCreateSchema } from '../user'

describe('userCreateSchema', () => {
  it('accepts a minimal valid payload', () => {
    expect(userCreateSchema.parse({ email: 'a@b.com', name: 'Alice' })).toEqual({
      email: 'a@b.com',
      name: 'Alice',
    })
  })
  it('rejects an invalid email', () => {
    expect(userCreateSchema.safeParse({ email: 'not-email', name: 'Alice' }).success).toBe(false)
  })
})
```

## 4. Service tests

Mock the repository with `vi.mock` at module scope, then dynamic-import the service so the mock applies before load. Cover the business-logic branches that throw `AppError`:

```ts
// src/services/__tests__/user.test.ts
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { ERROR_CODES } from '@/constants/error-codes'

vi.mock('@/repositories/user', () => ({
  userRepo: { list: vi.fn(), byId: vi.fn(), byEmail: vi.fn(), create: vi.fn() },
}))

const { userRepo } = await import('@/repositories/user')
const { userService } = await import('../user')

beforeEach(() => vi.resetAllMocks())

describe('userService.get', () => {
  it('throws NOT_FOUND when the user is missing', async () => {
    vi.mocked(userRepo.byId).mockResolvedValue(null)
    await expect(userService.get('x')).rejects.toMatchObject({
      code: ERROR_CODES.NOT_FOUND,
      httpStatus: 404,
    })
  })
})

describe('userService.create', () => {
  it('throws EMAIL_ALREADY_EXISTS on duplicate email', async () => {
    vi.mocked(userRepo.byEmail).mockResolvedValue({ id: '1' } as never)
    await expect(
      userService.create({ email: 'a@b.com', name: 'Alice' }),
    ).rejects.toMatchObject({ code: ERROR_CODES.EMAIL_ALREADY_EXISTS, httpStatus: 409 })
  })
})
```

If the service imports other repositories, mock those too (even if unused by the branch under test) so the service module never pulls them from disk.

## 5. Controller tests

Build a one-route Express app with just the controller under test + the shared `errorHandler`. Mock the service; assert status codes, response envelope, and (for auth) that cookies are set.

```ts
// src/controllers/__tests__/user.test.ts
import express from 'express'
import request from 'supertest'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { errorHandler } from '@/middleware/error-handler'

vi.mock('@/services/user', () => ({
  userService: { create: vi.fn(), remove: vi.fn() },
}))

const { userService } = await import('@/services/user')
const { userController } = await import('../user')

const buildApp = () => {
  const app = express()
  app.use(express.json())
  app.post('/', userController.create)
  app.delete('/:id', userController.remove)
  app.use(errorHandler)
  return app
}

beforeEach(() => vi.resetAllMocks())

describe('userController.create', () => {
  it('returns 201 with the created entity in the envelope', async () => {
    vi.mocked(userService.create).mockResolvedValue({ id: 'u1', email: 'a@b.com' } as never)
    const res = await request(buildApp()).post('/').send({ email: 'a@b.com', name: 'Alice' })
    expect(res.status).toBe(201)
    expect(res.body).toMatchObject({ status: 'success', data: { id: 'u1', email: 'a@b.com' } })
  })

  it('returns 400 VALIDATION_FAILED on empty body', async () => {
    const res = await request(buildApp()).post('/').send({})
    expect(res.status).toBe(400)
    expect(res.body).toMatchObject({ status: 'error', error: { code: 'VALIDATION_FAILED' } })
  })
})
```

## 6. Route-level smokes

Three files exercise seams that colocated tests can't cover without a DB - router mount order, the full-app error pipeline, and the auth middleware. Keep them small; they are not CRUD coverage.

```ts
// tests/health.test.ts            - router mount + success envelope
// tests/auth-validation.test.ts   - Zod → error-handler → VALIDATION_FAILED on POST /auth/register {}
// tests/users-unauthorized.test.ts - requireAuth → 401 on GET /users with no cookie
```

Each is one `createApp()` instance, one request, one assertion block.

## 7. Postman collection *(optional)*

Only if the user asks. Scaffolds a Postman v2.1 collection + a local environment file so the API is clickable without hand-crafting requests. Lives at the project root:

```text
postman/
├── <project>.postman_collection.json
└── <project>.postman_environment.json
```

**Mirror the router mount tree.** One folder per router under `src/routes/`, one request per endpoint. Add or drop folders to match the actually-scaffolded routers.

**Collection shape** - canonical skeleton:

```json
{
  "info": {
    "name": "<project>",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "variable": [
    { "key": "baseUrl", "value": "http://localhost:3000" },
    { "key": "email", "value": "demo@example.com" },
    { "key": "password", "value": "password123" },
    { "key": "userId", "value": "" }
  ],
  "item": [
    {
      "name": "Auth",
      "item": [
        {
          "name": "POST /auth/register",
          "event": [{
            "listen": "test",
            "script": { "exec": [
              "pm.test('201 Created', () => pm.response.to.have.status(201))",
              "pm.collectionVariables.set('userId', pm.response.json().data.user.id)"
            ]}
          }],
          "request": {
            "method": "POST",
            "header": [{ "key": "Content-Type", "value": "application/json" }],
            "body": { "mode": "raw", "raw": "{\"email\":\"{{email}}\",\"password\":\"{{password}}\",\"name\":\"Demo\"}" },
            "url": { "raw": "{{baseUrl}}/auth/register", "host": ["{{baseUrl}}"], "path": ["auth", "register"] }
          }
        }
      ]
    }
  ]
}
```

**Cookies-first auth.** `be-auth` ships HttpOnly cookies (`at`, `rt`). Postman's cookie jar captures them from `POST /auth/register` / `POST /auth/login` and attaches them to subsequent requests on the same host - no manual `Authorization` header. Document this in the Auth folder description so users don't paste a Bearer token.

**Capture IDs with a `pm.test` script.** Create requests (`POST /users`, `POST /roles`, `POST /permissions`) write the returned id into a collection variable (`userId`, `roleId`, `permissionId`); subsequent GET / PATCH / DELETE requests reference `{{userId}}` in the URL. Keeps the collection runnable top-to-bottom.

**Environment file** - one `*.postman_environment.json` per deployment target. Scaffold `local` only; the user duplicates it for `staging` / `prod`:

```json
{
  "name": "<project> (local)",
  "values": [
    { "key": "baseUrl", "value": "http://localhost:3000", "enabled": true },
    { "key": "email", "value": "demo@example.com", "enabled": true },
    { "key": "password", "value": "password123", "enabled": true }
  ],
  "_postman_variable_scope": "environment"
}
```

**Verify the files parse** before closing the step:

```bash
node -e "JSON.parse(require('fs').readFileSync('postman/<project>.postman_collection.json','utf8'))"
node -e "JSON.parse(require('fs').readFileSync('postman/<project>.postman_environment.json','utf8'))"
```

**Upgrade path - generate from OpenAPI.** If the project opted into OpenAPI docs in `be-boilerplate` §4, regenerate the collection from the spec instead of hand-maintaining it:

```bash
pnpm add -D openapi-to-postmanv2
```

```json
"postman:generate": "openapi2postmanv2 -s src/lib/openapi.ts -o postman/<project>.postman_collection.json -p"
```

Rerun after schema changes. The environment file stays hand-written.

**Do not commit tokens.** The environment file holds a sample email / password - never real credentials. Add `postman/*.local.json` to `.gitignore` for user-specific overrides.

## What this skill does not test

- **Repositories** - they talk to Postgres. Scaffolding tests here without migrating the test DB produces red tests on first run. A dedicated DB-test skill owns this: `.env.test` → migrate `postgres-test` → transaction-per-test rollback.
- **Full CRUD happy paths through the router** - same DB coupling. The route-level smokes cover the error paths that don't touch Postgres.

## Input

- `be-boilerplate` output: resource files, `src/app.ts` factory, error envelope.
- User answer: Postman collection yes / no.

## Output

Files written:

- `tsconfig.test.json` *(if not already split)*
- `vitest.config.ts` *(update include + plugin projects)*
- `src/lib/logger.ts` *(gate level on `NODE_ENV`)*
- `docker-compose.yml` *(add `postgres-test` service)*
- `src/schemas/__tests__/<name>.test.ts` + `src/services/__tests__/<name>.test.ts` + `src/controllers/__tests__/<name>.test.ts` *(per resource)*
- `tests/health.test.ts` + `tests/auth-validation.test.ts` + `tests/<resource>-unauthorized.test.ts`
- If Postman: `postman/<project>.postman_collection.json` + `postman/<project>.postman_environment.json`

**Rename to match renamed entities.** If the sample resource is `post` instead of `user`, every `user.test.ts` becomes `post.test.ts`.

## Verification

Run from `source-code/<project-name>-be/`. Stop and fix on first failure.

```bash
pnpm typecheck
pnpm test -- --run     # colocated + route-level smokes all pass, no DB required
```

- Every scaffolded `__tests__/<name>.test.ts` and every `tests/*.test.ts` passes without a database running.
- `pnpm test` with `NODE_ENV=test` produces no pino output - logger is silent.
- If Postman asked: both JSON files parse (`node -e "JSON.parse(...)"`); importing the collection into Postman shows one folder per router and every request fires against `{{baseUrl}}` without a 404 from a stale path.

## Anti-patterns - reject on sight

- A `*.test.ts` sibling to the source file (`src/services/user.test.ts`) instead of under `__tests__/` - breaks the colocation convention and the `ls` of `services/` stops being just source.
- Repository tests scaffolded here - they need a migrated DB and belong to the DB-test skill.
- `vi.mock` placed below the dynamic `import` - the mock registers after the module loads and the real repo gets pulled in.
- `createApp()` reused inside a controller unit test - it drags in every router, defeating the "one controller + one errorHandler" boundary.
- `pm.collectionVariables.set` reading a field the envelope does not expose (`pm.response.json().user.id` when the body is `{ status: 'success', data: { user: { id } } }`) - the chain breaks on first request.
- Real credentials committed in the Postman environment file - secrets leak via git history.
- A fourth route-level smoke added "while we're here" for a CRUD happy path - it will go red on the first CI run without the DB.
