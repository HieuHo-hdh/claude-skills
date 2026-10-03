# Workspace layout

Shared rule referenced by every `fe-*` skill.

Scope: where projects live under `source-code/`. Read once per session before scaffolding or touching a project.

## Core rule

**All frontend projects live under `source-code/<project-name>/`** at the repo root. This repo is a container for multiple frontend apps - **never** scaffold at the repo root, and never write across sibling projects in a single skill run.

```text
<repo-root>/
├── .claude/
├── source-code/
│   ├── admin/        ← sibling projects (unrelated)
│   ├── client/
└── …
```

## Path A - creating a new project (used by `fe-setup`)

Before invoking any framework CLI:

1. **Confirm `source-code/` exists** at the repo root. If missing, create it (`mkdir source-code`).
2. **Confirm `source-code/<project-name>/` does not already exist.** If it does, ask the user:
   - **Pick a new name** (default),
   - **Resume** into the existing folder, or
   - **Overwrite** (destructive - require explicit confirmation).
3. `cd source-code` **before** running the framework CLI (`pnpm create next-app <name>`, `pnpm create vite <name>`, etc.) so the CLI writes into `source-code/<name>/`, not the repo root.
4. After the CLI finishes, `cd source-code/<name>/`. **All subsequent commands** - `pnpm install`, `pnpm dev`, `pnpm build`, config edits, writing `CLAUDE.md` - run inside that directory.

## Path B - working inside an existing project (used by every other `fe-*` skill)

Before writing any file:

1. **Confirm the current working directory is `source-code/<project-name>/`** - not the repo root, not a sibling.
2. **Read `CLAUDE.md`** from that directory for the framework / UI library / state / auth-storage / Style-section decisions made by `fe-setup`.
3. **All generated files** go under that project only - never into a sibling under `source-code/`, never at the repo root.

## Multiple projects present

If `source-code/` contains more than one project (`admin`, `client`, …) and the current skill is **not** creating a new one, **ask the user which project to target** before touching any file. Do not guess by heuristic (last-modified, name similarity) - the wrong pick silently corrupts a sibling.

## Sibling isolation

Sibling projects are **independent codebases** with their own `package.json`, `CLAUDE.md`, and style tokens. Never:

- Copy files across siblings without explicit user approval.
- Reuse tokens or theme configs from a sibling - each project derives its own Style tokens.
- Run `pnpm install` at the repo root - always inside the target project.

## Verification

Before writing anything, a good defensive check is:

```bash
pwd    # must end with source-code/<project-name>
ls CLAUDE.md package.json    # both should exist for Path B
```

If either fails, stop and re-anchor before proceeding.

## Anti-patterns - reject on sight

- Scaffolding a project at the repo root instead of under `source-code/<name>/`.
- Cross-project imports - a file under `source-code/admin/` importing from `source-code/client/`.
- Running `pnpm install` (or the CLI equivalent) at the repo root - always inside the target project.
- Guessing the target project by heuristic (last-modified, name similarity) when siblings exist - ask the user.
- Copying `tailwind.config.ts` / token files between siblings instead of deriving tokens per project.
- Reusing a sibling's `CLAUDE.md` decisions in a new project - re-run `fe-setup` and derive fresh.
