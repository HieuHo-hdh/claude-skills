# Project structure

Shared rule referenced by every `fe-*` skill that writes files (`fe-setup`, `fe-boilerplate`, `fe-auth`, `fe-page`, `fe-component`).

Scope: folder layout under `source-code/<project-name>/src/`. Deviations: state a reason inline.

## Top-level folders

Create a folder when its first file arrives, not before - except the ones `fe-setup` seeds.

| Folder           | Holds                                                   | Notes                                                                  |
| ---------------- | ------------------------------------------------------- | ---------------------------------------------------------------------- |
| `api/`           | HTTP client + one module per entity (`users.ts`)        | No React imports. Zod-parse every response.                            |
| `components/`    | Reusable UI, one folder per component                   | `<Name>/<Name>.tsx`, `<Name>.test.tsx`, `index.ts`.                    |
| `components/ui/` | shadcn-added primitives                                 | shadcn projects only. Written by `shadcn add` - compose, do not fork.  |
| `hooks/`         | `use-*.ts` data + interaction hooks                     | One hook per query / mutation.                                         |
| `layouts/`       | `PublicShell`, `AdminLayout`, `AuthGuard`               | Applied at route level, never inside a page.                           |
| `lib/`           | Pure utilities (`cn.ts`, `query-client.ts`)             | kebab-case files. No JSX.                                              |
| `pages/`         | Route components (Vite / Vue)                           | One folder per page: `pages/Dashboard/DashboardPage.tsx`.              |
| `app/`           | Route segments (Next.js App Router)                     | `(public)` and `(admin)` groups.                                       |
| `schemas/`       | Zod schemas + inferred types, one file per domain       | Hoisted to module scope.                                               |
| `store/`         | Redux store + slices, or Zustand stores                 | Redux / Zustand projects only. Patterns: `fe-state-management.md`.     |
| `theme/`         | MUI `createTheme` / Antd token config                   | MUI / Antd projects only.                                              |
| `stubs/`         | Temporary fixtures, one subfolder per concern           | `stubs/auth/`. Must be deletable in one `rm -r`.                       |
| `test/`          | Test setup (`setup.ts`)                                 |                                                                        |

Playwright specs live in `tests/` at the project root, outside `src/`.

## Colocation

- Used by one page → lives in that page's folder (`pages/Dashboard/use-dashboard.ts`).
- Used by two or more → promote to `hooks/`, `components/`, or `lib/`.
- A component's hook, types, and subcomponents stay inside its folder (`components/DataTable/useDataTable.ts`).

## Layering

Imports point down the table, never up.

| Layer                 | May import                                   | Must not import                        |
| --------------------- | -------------------------------------------- | -------------------------------------- |
| `pages` / `app`       | everything below                             |                                        |
| `layouts`             | `components`, `hooks`, `store`, `lib`        | `pages`                                |
| `components`          | `components`, `hooks`, `lib`, `schemas`      | `pages`, `layouts`, `api`, `store`     |
| `hooks`               | `api`, `store`, `schemas`, `lib`             | `components`, `layouts`, `pages`       |
| `store`               | `api`, `schemas`                             | `components`, `hooks`, `layouts`       |
| `api`                 | `schemas`, `lib`                             | React, `store`, `hooks`                |
| `schemas`, `lib`      | `schemas` (types only)                       | everything else                        |

## Entity file map

One entity (`user`) touches the same files in every project. Library-specific contents: `fe-state-management.md`.

```text
src/schemas/user.ts          ← Zod schema + inferred type
src/api/users.ts             ← fetchUsers, createUser, ... (axios + Zod parse)
src/hooks/use-users.ts       ← TanStack / RTK Query / Context hook
src/store/users-slice.ts     ← Redux slice-per-entity only
```

## Barrels

A per-component `index.ts` (`components/Button/index.ts`) is allowed. A barrel at a directory root (`components/index.ts`) is not - see `fe-coding-conventions.md` anti-patterns.

## Anti-patterns - reject on sight

- Files at the repo root or in a sibling project - see `fe-workspace-layout.md`.
- `utils/`, `helpers/`, `common/`, `misc/` folders - name the concern (`lib/`, `schemas/`) or colocate.
- Fetch calls in `components/` or `pages/` bodies - go through `hooks/`.
- `api/` importing from `store/` or `hooks/` - the dependency points the other way.
- A second `stubs/`-style folder (`mocks/`, `fixtures/`) for the same throwaway data - one folder per concern under `stubs/`.
- A page importing another page - extract the shared piece into `components/` or `hooks/`.
