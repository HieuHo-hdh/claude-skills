# Workspace layout

Shared rule referenced by every `be-*` skill.

Scope: where backend projects live under `source-code/`. Read once per session before scaffolding or touching a project.

## Core rule

**All backend projects live under `source-code/<project-name>-be/`** at the repo root. This repo is a container for multiple backend services - **never** scaffold at the repo root, and never write across sibling projects in a single skill run.

The `-be` suffix is intentional: a frontend and backend for the same product sit as siblings (`source-code/word-family/` + `source-code/word-family-be/`), and the suffix keeps commands, Docker container names, and database names unambiguous.

```text
<repo-root>/
├── .claude/
├── source-code/
│   ├── word-family/        ← frontend sibling
│   ├── word-family-be/     ← this backend
│   ├── admin-be/           ← unrelated sibling backend
└── …
```

## Path A - creating a new project (used by `be-setup`)

Before invoking any framework CLI or package manager:

1. **Confirm `source-code/` exists** at the repo root. If missing, create it (`mkdir source-code`).
2. **Confirm `source-code/<project-name>-be/` does not already exist.** If it does, ask the user:
   - **Pick a new name** (default),
   - **Resume** into the existing folder, or
   - **Overwrite** (destructive - require explicit confirmation).
3. `cd source-code` **before** running the scaffolder (`pnpm init`, `pnpm create ...`) so files land in `source-code/<name>-be/`, not the repo root.
4. After scaffolding, `cd source-code/<name>-be/`. **All subsequent commands** - `pnpm install`, `pnpm dev`, `pnpm db:migrate`, `docker compose up`, config edits, writing `CLAUDE.md` - run inside that directory.

## Path B - working inside an existing project (used by every other `be-*` skill)

Before writing any file:

1. **Confirm the current working directory is `source-code/<project-name>-be/`** - not the repo root, not a sibling, not the FE sibling.
2. **Read `CLAUDE.md`** from that directory for the stack decisions made by `be-setup` (ORM, DB, auth status, Redis, mailer, etc.).
3. **All generated files** go under that project only - never into a sibling under `source-code/`, never at the repo root.

## Multiple projects present

If `source-code/` contains more than one backend (`word-family-be`, `admin-be`, …) and the current skill is **not** creating a new one, **ask the user which project to target** before touching any file. Do not guess by heuristic (last-modified, name similarity) - the wrong pick silently corrupts a sibling.

The FE/BE pair rule: a request like "add a /roles endpoint" targets the `-be` sibling. A request like "wire the roles page" targets the FE sibling. If the user says "both", run the BE skill first, then switch directory and run the FE skill - never cross-write from one skill run.

## Sibling isolation

Sibling projects are **independent codebases** with their own `package.json`, `CLAUDE.md`, `prisma/`, `docker-compose.yml`, and `.env`. Never:

- Copy files across siblings without explicit user approval.
- Reuse `prisma/schema.prisma` / migrations from a sibling - each backend derives its own schema.
- Share a Docker container name across siblings (`word-family-postgres` vs `admin-postgres`, not both `postgres`).
- Share a database or Redis instance across siblings in local dev - port-collide on purpose so the mistake surfaces loudly.
- Run `pnpm install` at the repo root - always inside the target project.

## Infra naming

Each project namespaces its own containers and env values so two backends can run side-by-side on one laptop:

- Docker Compose `container_name` prefixes the project (`word-family-postgres`, `word-family-redis`).
- Postgres `POSTGRES_DB` matches the project (`word_family`).
- Ports step by one across siblings - if `word-family-be` binds `5432`, `admin-be` binds `5433`. Record the bound ports in that project's `CLAUDE.md`.
- `.env` is per-project. Never symlink `.env` across siblings - a stale secret or a wrong `DATABASE_URL` on the "other" project is one of the loudest footguns.

## Verification

Before writing anything, a good defensive check is:

```bash
pwd                               # must end with source-code/<project-name>-be
ls CLAUDE.md package.json         # both should exist for Path B
ls prisma/schema.prisma           # expected for Prisma projects
```

If any fails, stop and re-anchor before proceeding.

## Anti-patterns - reject on sight

- Scaffolding at the repo root instead of under `source-code/<name>-be/`.
- Dropping the `-be` suffix - FE / BE siblings become ambiguous.
- Cross-project imports between a BE and its FE sibling - they talk over HTTP, not the module graph.
- Running `pnpm install` or `pnpm db:migrate` at the repo root - always inside the target project.
- Guessing the target project when siblings exist - ask the user.
- Copying `docker-compose.yml` / `prisma/schema.prisma` / `.env` between siblings - each project derives its own.
- Reusing a Docker `container_name` across siblings - the second `docker compose up` collides.
