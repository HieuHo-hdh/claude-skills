---
name: fe-plan
description: Use before fe-implement to produce a durable plan file - acceptance criteria (Given/When/Then), affected artifacts (routes, components, hooks, APIs, types, tests), sequencing, risks, open questions. Consumed by fe-implement, fe-test, fe-review, fe-summary. Not for scaffolding a whole project (use fe-setup) or a single throwaway widget (go straight to fe-component).
---

# fe-plan

Produces one plan file per feature at `docs/plans/<slug>.md`. Downstream skills read it - if the plan is wrong, everything downstream is wrong. Bias toward asking the user over guessing.

## Contents

**Setup** - anchoring the plan in the right project and rules.
- [Prerequisites](#prerequisites) - what must exist before planning.
- [Working directory](#working-directory) - where the plan lives.
- [Shared conventions](#shared-conventions) - rules the plan must respect.

**Workflow** - the ordered pass that produces the plan.
- [1. Scope check](#1-scope-check) - feature or website slice.
- [2. Acceptance criteria](#2-acceptance-criteria) - Given / When / Then, one per behavior.
- [3. Reuse-first survey](#3-reuse-first-survey) - what exists, what to extend, what to create; blast-radius check on every Modify.
- [4. Break down artifacts](#4-break-down-artifacts) - routes, components, hooks, APIs, types, tests.
- [5. Sequence and dependencies](#5-sequence-and-dependencies) - build order, blockers.
- [6. Risks and open questions](#6-risks-and-open-questions) - explicit unknowns.
- [7. Write the plan file](#7-write-the-plan-file) - single artifact, canonical layout.

**Contract** - what the plan produces so downstream skills can consume it.
- [Plan file format](#plan-file-format) - required sections, in order.
- [Input](#input) - what this skill reads.
- [Output](#output) - what it writes.
- [Verification](#verification) - the plan is done when.

## Prerequisites

- **`fe-setup` has run** - `CLAUDE.md` records framework / router / state / test runner / auth-storage. Planning without these picks the wrong artifacts.
- **`source-code/<project-name>/` exists** and is the current directory. If the whole project does not exist yet, run `fe-setup` first - `fe-plan` does not scaffold projects.
- **User is available to answer questions.** This skill interviews; it does not guess spec.

## Working directory

Runs inside `source-code/<project-name>/`. Plan files go under `docs/plans/<slug>.md` inside that project - never at the repo root, never in a sibling project.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B.

## Shared conventions

- **Markdown style:** `.claude/rules/markdown-style.md` - the plan file itself must follow it (H1, scope line, tables over prose lists, no filler).
- **Coding conventions:** `.claude/rules/fe-coding-conventions.md` - the plan names artifacts using the project's naming rules (PascalCase components, `use*` hooks, kebab-case utility files).
- **Project structure:** wherever `fe-setup` recorded it in `CLAUDE.md` - the plan places artifacts against that structure.

## Workflow

Ask one section at a time. Do not batch questions. If any answer is "I don't know", stop and pull the user in - a guessed plan is worse than no plan.

### 1. Scope check

Establish size before spending interview budget:

| Scope | Signal | Plan size |
| --- | --- | --- |
| Single component | "add a `<Toast>`", "extract this widget" | Skip `fe-plan`. Go straight to `fe-component`. |
| Single page | "build `/settings/profile`" | Skip `fe-plan`. Go straight to `fe-page`. |
| Feature | Spans 2+ pages, or 1 page + new API + new hooks | Run `fe-plan`. |
| Website slice | Multiple features shipped together, or v1 launch | Run `fe-plan` per feature; link them with a parent plan. |

**Rule:** if the work touches more than one page **or** introduces a new API surface, plan it. Otherwise defer to the single-artifact skill.

### 2. Acceptance criteria

For every user-visible behavior, write one **Given / When / Then** bullet. These are the plan's contract - `fe-test` derives tests from them, `fe-summary` checks them off.

```md
- Given the user is signed in and on `/settings/profile`,
  when they change their display name and click **Save**,
  then the header greeting updates within one render and a success toast appears.

- Given the display name is empty,
  when the user clicks **Save**,
  then the field shows "Display name is required" and the request is not sent.
```

Rules:

- **One behavior per bullet.** If a bullet has two Whens, split it.
- **Cover all four data states per page** touched: loading, error, empty, success. Missing empty is the most common bug.
- **Cover the failure paths.** Network error, validation error, 401 mid-session, 403 (role denied). If the feature has no failure paths, name it explicitly - "no server calls, no criteria beyond render."
- **No implementation words** ("call the API", "dispatch action"). Criteria are observable behavior only.

### 3. Reuse-first survey

**Rule: reuse > extend > create.** Duplicated code is a bug that ships. Before naming any new artifact, prove the existing tree does not already cover it.

Walk the tree in this order and record every candidate that matches, even partially:

- **Routes** - grep the router file / `src/app/` tree for adjacent paths and route conventions.
- **Components** - `ls src/components/` and `grep -r "export" src/components/**/*.tsx` for anything the feature might reuse (`Modal`, `Table`, `Form`, `EmptyState`, `Input`, `Button`).
- **Hooks** - `ls src/hooks/` for existing data hooks, especially for the same API resource (`useProfile`, `useUser`).
- **API client** - `ls src/api/` for existing endpoint wrappers. Same resource → extend, do not fork.
- **Schemas / types** - grep for the resource name in `src/schemas/` and `src/types/`. If a `Profile` schema exists, derive from it - do not redeclare.
- **Utilities** - `ls src/lib/` and `src/utils/` for formatters, validators, `cn`, date helpers.
- **Style tokens** - the Style section of `CLAUDE.md`. Note any tokens the design needs that do not exist yet - extend the token set, do not inline the value.

For every candidate, decide one of:

| Decision | When | Action |
| --- | --- | --- |
| **Reuse as-is** | Existing artifact fully covers the need | Row in Reuse / Modify / Create with `Reuse` |
| **Extend** | 80%+ overlap; add a variant, prop, or method | Row with `Modify`; note the delta |
| **Create** | No overlap, or extending would break the existing contract | Row with `Create`; state why extension was rejected |

**Never** duplicate a component "because it will diverge later" - split when it actually diverges, not before. Two 90%-identical components in different folders are the top source of drift-driven bugs.

If reuse is unclear (candidate looks close but you are not sure), ask the user before deciding to create. `fe-review` re-checks this on the finished code and will flag duplicates - resolve them at plan time to save the round-trip.

**When you pick Modify, do consumer analysis before committing to it.** A shared component / hook / schema serves multiple callers; changing it can break pages you never opened. For every `Modify` row:

1. **Grep every import** of the artifact:
   ```bash
   grep -rn "from ['\"].*/Button['\"]" src/
   grep -rn "useProfile" src/
   grep -rn "profileSchema" src/
   ```
2. **List every consumer** in the plan under **Impact analysis** (see [Plan file format](#plan-file-format)) - route path, file, and the specific behavior that could shift (new required prop, changed default, tightened schema, renamed field).
3. **Classify the change:**

   | Change kind | Example | Safe? |
   | --- | --- | --- |
   | Additive, backward-compatible | new optional prop, new enum value, new optional field | Safe. Modify. |
   | Additive-with-default | new required prop with a sensible default | Safe if default is right for every consumer. Verify. |
   | Breaking | rename prop / field, change type, tighten schema, remove default | **Not safe.** Every consumer needs a matching change in the same plan, or split into a versioned artifact (`ButtonV2`, `useProfileV2`). |

4. **Add each impacted consumer as a Modify row in the Reuse / Modify / Create table** with the specific delta. `fe-implement` will not update files that are not in the table.
5. **Cover the impacted paths in the acceptance criteria and tests.** A silent regression in `/admin/users` because you added a required prop to `<Button>` is worse than the feature not shipping.

If impact analysis surfaces more than ~5 consumers with meaningful deltas, stop and reconsider: the change may belong behind a new variant / prop rather than a modification.

### 4. Break down artifacts

For each category, list the concrete files. Use the project's naming conventions from `CLAUDE.md`:

| Category | Example entry |
| --- | --- |
| Route | `src/app/(admin)/settings/profile/page.tsx` → `/settings/profile` |
| Layout | reuse `AdminLayout` |
| Page component | `SettingsProfilePage` (thin - composes sections) |
| Section / feature component | `ProfileForm`, `AvatarUploader` |
| Reusable component | `Input`, `Button` (reuse) |
| Data hook | `useProfile` (GET), `useUpdateProfile` (mutation) |
| API endpoint wrapper | `profileApi.get()`, `profileApi.update(payload)` |
| Zod schema | `profileSchema`, `updateProfileSchema` |
| Type | `Profile`, `UpdateProfilePayload` (derived from schema) |
| Test | `SettingsProfilePage.test.tsx` (smoke), `ProfileForm.test.tsx` (unit) |

Rules:

- **Every server response gets a Zod schema.** Types are derived (`type Profile = z.infer<typeof profileSchema>`), never hand-written in parallel.
- **Every mutation gets its own hook.** No `useMutation` inline in components.
- **Every new component appears in the Reuse / Modify / Create table** so `fe-implement` knows whether to invoke `fe-component`.
- **Do not list files that already exist** unless they are being modified. Reuse belongs in the Reuse row; only new + modified files go in this breakdown.

### 5. Sequence and dependencies

Order the artifacts so `fe-implement` can walk the list top-to-bottom:

1. **Types + schemas first** - hooks and components depend on them.
2. **API client wrappers** - hooks depend on them.
3. **Data hooks** - pages / components depend on them.
4. **Leaf components** (`AvatarUploader`) before **composite components** (`ProfileForm`).
5. **Page** last - composes everything above.
6. **Tests** - unit tests co-located with their subject; page smoke test after the page.

Call out blockers explicitly. Examples:

- "Blocked on backend: `PATCH /api/profile` returns 500 for empty `displayName`; contract is unclear. Owner: @backend-team."
- "Blocked on design: no empty state for `AvatarUploader` in Figma. Fallback: reuse `EmptyState` with 'No avatar yet' copy."

Do not proceed past step 7 with unresolved blockers - either resolve them with the user or file them as open questions.

### 6. Risks and open questions

One bullet per risk. Each bullet has a **what** and a **mitigation or ask**:

```md
- **Risk:** Profile update is optimistic; if the server rejects, the header greeting has already changed.
  **Mitigation:** roll back on error, surface a toast, re-fetch.

- **Open:** Does the avatar upload go through our own API or directly to S3 with a signed URL?
  **Ask:** @backend-team, before implementation.
```

If open questions exist, the plan is **provisional** - mark the frontmatter status accordingly (see [Plan file format](#plan-file-format)).

### 7. Write the plan file

Path: `docs/plans/<slug>.md`.

**Default slug: `YYMMDD-HHmm-<feature>`** - compact datetime prefix + kebab-case feature name.

- `260928-1430-settings-profile.md`
- `260929-0915-checkout-v2.md`
- `261002-1105-admin-invites.md`

Use the local time at the moment the plan is written (from `date +%y%m%d-%H%M`). The prefix sorts chronologically, prevents same-day collisions, and doubles as the plan's created-at.

The user may override with a bare feature slug (`checkout-v2.md`) - accept it, but keep the datetime prefix as the default when the user has no preference. Frontmatter `created:` still records the same timestamp regardless.

Create the `docs/plans/` directory if it does not exist.

Do not stash the plan in scratch, in comments, or in the chat. Downstream skills read the file - no file, no consumers.

## Plan file format

The plan file follows this exact layout. Downstream skills grep for these section headings.

```md
---
feature: settings-profile
status: ready            # ready | provisional | shipped
created: 260928-1430                # matches the filename prefix
owner: @hieu
---

# Plan: settings profile

Scope: user can view and update their display name, email, and avatar on `/settings/profile`. One page, one form, three fields, optimistic update on name only.

## Acceptance criteria

- Given the user is signed in on `/settings/profile`, when the page mounts, then the current profile renders inside 500ms of the query resolving.
- Given the display name is empty, when the user clicks **Save**, then the field shows an inline error and no request fires.
- ...

## Reuse / Modify / Create

| Action | Path | Note |
| --- | --- | --- |
| Reuse | `src/components/Input/Input.tsx` | as-is |
| Reuse | `src/layouts/AdminLayout.tsx` | route wraps in it |
| Modify | `src/api/profile.ts` | add `update()` |
| Create | `src/hooks/use-profile.ts` | query + mutation |
| Create | `src/pages/SettingsProfile/ProfileForm.tsx` | form section |
| Create | `src/pages/SettingsProfile/SettingsProfilePage.tsx` | route body |
| Create | `src/pages/SettingsProfile/SettingsProfilePage.test.tsx` | smoke |

## Impact analysis

Consumers touched by every `Modify` row above. Downstream skills use this to know which pages/tests to re-verify.

| Modified artifact | Consumer | File | Delta | Risk |
| --- | --- | --- | --- | --- |
| `profileApi.get()` | `/settings/account` | `src/pages/SettingsAccount/SettingsAccountPage.tsx` | schema tightens `email` to required | low - already required in UI |
| `<Input>` | `/login`, `/signup` | `src/pages/Login/LoginPage.tsx`, `src/pages/Signup/SignupPage.tsx` | new optional `hint` prop; no default change | none |

If a Modify row has **zero consumers** listed, either the grep was skipped or the row should be a `Create` under a different name.

## Artifact breakdown

### Routes
- `src/app/(admin)/settings/profile/page.tsx` → `/settings/profile` (guarded, AdminLayout)

### Data
- Schema: `profileSchema`, `updateProfileSchema` in `src/schemas/profile.ts`
- Types: `Profile`, `UpdateProfilePayload` derived from schemas
- API: `profileApi.get()`, `profileApi.update(payload)` in `src/api/profile.ts`
- Hooks: `useProfile()`, `useUpdateProfile()` in `src/hooks/use-profile.ts`

### Components
- Page (thin): `SettingsProfilePage`
- Sections: `ProfileForm`, `AvatarUploader`
- Reused: `Input`, `Button`, `EmptyState`

### Tests
- `SettingsProfilePage.test.tsx` - smoke: renders + happy save
- `ProfileForm.test.tsx` - unit: validation, submit disabled while pending
- E2E: skipped (covered by smoke + unit)

## Sequence

1. Schemas + types
2. `profileApi.update()`
3. `useProfile`, `useUpdateProfile`
4. `AvatarUploader`
5. `ProfileForm`
6. `SettingsProfilePage` + route
7. Tests

## Risks and open questions

- **Risk:** optimistic name update rolls back on error - confirm toast copy with design.
- **Open:** avatar upload via own API or signed S3 URL? Ask @backend-team.

## Out of scope

- Password change (separate plan).
- 2FA (separate plan).
```

Required sections: **Acceptance criteria, Reuse / Modify / Create, Impact analysis, Artifact breakdown, Sequence, Risks and open questions, Out of scope**. Omit none - "N/A" with a one-line reason is acceptable, missing sections are not. **Impact analysis is "N/A" only if the plan has zero Modify rows.**

## Input

- `CLAUDE.md` - framework / router / state / auth-storage / Style tokens / project structure.
- Existing tree under `src/` - reused via the survey pass.
- User answers to the interview.
- Optional: linked design (Figma URL), API contract (OpenAPI, `.proto`, or written spec).

## Output

- `docs/plans/<slug>.md` - one file per feature, following [Plan file format](#plan-file-format).
- For a website slice: one parent plan (`docs/plans/<slice>.md`) that lists child feature plans as a bulleted TOC.

## Verification

The plan is done when:

- [ ] Every acceptance criterion is Given / When / Then and observable (no implementation words).
- [ ] All four data states appear in criteria for every page touched.
- [ ] Reuse / Modify / Create table covers every file the feature will change or add.
- [ ] Reuse-first survey ran: every `Create` row has no 80%+ overlap with an existing artifact, or a Modify row exists instead.
- [ ] Impact analysis ran for every `Modify` row: consumers grepped, listed with delta and risk. Breaking changes either propagate to every consumer as their own Modify row, or the change is split into a versioned artifact.
- [ ] Sequence has no forward references (step N never depends on step N+1).
- [ ] Every risk has a mitigation; every open question has an owner.
- [ ] `status: provisional` iff open questions exist; `status: ready` iff none remain.
- [ ] The plan file passes `.claude/rules/markdown-style.md` (H1, scope line, tables over lists, no filler).

## Recommendations

- **Interview one question at a time.** Batched questions produce shallow answers and merged criteria.
- **Write criteria before artifacts.** Naming files before the behavior is decided leads to files that do not match the behavior.
- **Survey before you list Create rows.** Duplicate components are the top waste from skipping this step.
- **Sequence is a contract with `fe-implement`.** If step 3 depends on step 5, `fe-implement` will block - fix the sequence, do not paper over it in prose.
- **Mark provisional plans loudly.** A `status: ready` plan with unresolved questions poisons every downstream skill.
- **Keep the plan editable.** As `fe-implement` uncovers reality, update the plan and re-run `fe-summary` against the new version - do not let the plan drift out of date.

## Anti-patterns - reject on sight

- Plan lives in chat, comments, or a scratch file instead of `docs/plans/<slug>.md` - downstream skills cannot read it.
- Acceptance criteria written as implementation steps ("call `updateProfile`, then invalidate") - not observable.
- Empty state missing from criteria for a page that loads data.
- Artifact breakdown lists reused files under Create - inflates scope and confuses `fe-implement`.
- New component / hook / util that overlaps an existing one by 80%+ without a Modify row explaining why extension was rejected - `fe-review` will flag it as duplicate; resolve at plan time.
- "Will diverge later" as justification for creating a near-duplicate - split when it diverges, not on speculation.
- `Modify` row on a shared artifact with an empty Impact analysis - blast radius unassessed; downstream pages will regress silently.
- Breaking change to a shared artifact without matching Modify rows for every consumer - either update all callers in the same plan or version the artifact (`ButtonV2`, `useProfileV2`).
- Sequence lists tests before the code under test - tests belong last per artifact.
- Risks section says "None" without evidence - either you missed the risks or the feature is trivial (in which case, skip `fe-plan`).
- Plan marked `ready` with open questions still listed - hides blockers from downstream skills.
