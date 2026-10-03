---
name: fe-implement
description: Use after fe-plan to execute a plan file - walks Sequence, delegates artifact emission to fe-page / fe-component / fe-auth, keeps schema / hook / API / util code inline, updates plan progress after each step. Refuses provisional plans. Not for ad-hoc work without a plan (use fe-component / fe-page directly).
---

# fe-implement

Executes one `docs/plans/<slug>.md` plan file step-by-step. Reads once, walks Sequence, delegates per artifact type, verifies between steps, annotates the plan as work ships. Never deviates from the plan - if reality contradicts it, stop and re-run `fe-plan`.

## Contents

**Setup** - what must be in place before executing.
- [Prerequisites](#prerequisites) - the plan, plus every dependency it names.
- [Working directory](#working-directory) - inside the target project only.
- [Shared conventions](#shared-conventions) - rules the generated code must respect.

**Workflow** - the ordered pass that ships the plan.
- [1. Load and validate the plan](#1-load-and-validate-the-plan) - resolve path, refuse if provisional.
- [2. Delegation map](#2-delegation-map) - which artifact type → which skill.
- [3. Walk the Sequence](#3-walk-the-sequence) - one step; verify; annotate; next.
- [4. Modify rows - consumer sweep](#4-modify-rows---consumer-sweep) - update every consumer inline.
- [5. Progress annotation](#5-progress-annotation) - mark done in the plan.
- [6. Deviation protocol](#6-deviation-protocol) - what to do when reality bites.

**Contract** - what this skill consumes and produces.
- [Input](#input) - the plan file + the project state.
- [Output](#output) - source files + updated plan.
- [Verification](#verification) - the feature is done when.

## Prerequisites

- **`fe-plan` produced a plan file** at `docs/plans/<slug>.md` with `status: ready` (not `provisional`).
- **`fe-setup` prerequisites met** - framework / router / state / test runner recorded in `CLAUDE.md`.
- **If the plan involves auth** - `fe-auth` has run; client, store, guard exist.
- **If the plan involves layout shells** - `fe-boilerplate` has run; `PublicShell` / `AdminLayout` exist.

## Working directory

Runs inside `source-code/<project-name>/`. Plan lives at `docs/plans/`. Source emits under `src/`.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B.

## Shared conventions

- **Coding conventions:** `.claude/rules/fe-coding-conventions.md` - naming, imports, TypeScript, error handling.
- **A11y:** `.claude/rules/fe-a11y.md`.
- **Responsive:** `.claude/rules/fe-responsive.md`.
- **Markdown style:** `.claude/rules/markdown-style.md` - for edits to the plan file itself.

## Workflow

### 1. Load and validate the plan

If the user did not name a plan path, `ls docs/plans/*.md` and pick the most recent by name (datetime prefix sorts chronologically) - confirm with the user before proceeding. If multiple plans have the same timestamp, ask.

Refuse to run when:

| Condition | Reason |
| --- | --- |
| `status: provisional` | Open questions unresolved - re-run `fe-plan`. |
| `status: shipped` | Already done; ask user to open a new plan slug. |
| Missing Impact analysis for any `Modify` row | Blast radius unassessed - re-run `fe-plan` step 3. |
| Sequence forward reference (step N depends on N+M) | Would deadlock - re-run `fe-plan` step 5. |

Never work around a broken plan. Fix it, re-enter.

### 2. Delegation map

| Artifact | Handled by | Notes |
| --- | --- | --- |
| Zod schema / TS type | inline | module-scope; types via `z.infer<>` |
| API endpoint wrapper (`src/api/*.ts`) | inline | one function per endpoint, typed I/O |
| Data hook (`use*` in `src/hooks/`) | inline | one hook per query or mutation |
| Utility (`src/lib/*.ts`, `src/utils/*.ts`) | inline | pure functions |
| Reusable UI component (`src/components/<Name>/`) | **`fe-component`** | never hand-roll here |
| Page / route | **`fe-page`** | never hand-roll route + layout wiring here |
| Auth wiring | **`fe-auth`** | must exist before this skill runs |
| Style tokens (extend Style section) | inline; update `CLAUDE.md` | never inline hex |

**Rule:** components and pages always go through their sub-skills. This skill orchestrates; it does not emit component or page files directly.

### 3. Walk the Sequence

For each step, in order:

1. **Announce** in one line: `Step 3/7: data hooks (useProfile, useUpdateProfile).`
2. **Emit** the artifact per the delegation map.
3. **Verify immediately** - `pnpm typecheck` and `pnpm lint` on the touched files. Stop and fix on first failure; do not accumulate errors across steps.
4. **Annotate** the plan (see [Progress annotation](#5-progress-annotation)).
5. **Advance** - never batch. `useProfile` before `ProfileForm` is not optional; that is what Sequence is for.

Sub-skill invocations (`fe-component`, `fe-page`) run as nested calls and must complete before the next step begins.

### 4. Modify rows - consumer sweep

When a step touches an artifact listed in the plan's **Impact analysis**:

1. Apply the modification.
2. Immediately update every consumer per its **Delta** column - do not defer.
3. Re-run `pnpm typecheck`. A broken consumer here means the plan under-scoped impact - stop and update the plan.
4. If the change is breaking and Impact analysis prescribes a versioned artifact (`ButtonV2`, `useProfileV2`), create the new artifact instead of modifying in place.

The consumer sweep is the difference between "the feature works" and "the feature works and nothing else broke."

### 5. Progress annotation

After every step, edit `docs/plans/<slug>.md`:

- Prefix the completed Sequence line with `- [x]`.
- Append `(shipped)` to each artifact's row in the Artifact breakdown.

When every Sequence line is `- [x]`:

- Frontmatter `status: shipped`.
- Frontmatter `shipped: YYMMDD-HHmm` (from `date +%y%m%d-%H%M`).

`fe-review` and `fe-summary` grep these markers. Skipping annotation strands them.

### 6. Deviation protocol

If reality contradicts the plan mid-execution, stop and route back:

| Discovery | Action |
| --- | --- |
| API contract differs from plan | Re-run `fe-plan` step 2 - criteria may shift. Do not paper over silently. |
| Existing artifact covers the case after all | Update Reuse / Modify / Create (was `Create`, now `Reuse`), then continue. |
| Hidden consumer surfaces (grep missed it) | Add to Impact analysis, do the consumer sweep, continue. |
| Sub-skill (`fe-page` / `fe-component`) asks for a spec the plan does not give | Kick back to `fe-plan` - the plan is under-specified. |

Never edit files not in the plan. If new files become necessary, add them to the plan first.

## Input

- `docs/plans/<slug>.md` - `status: ready`.
- `CLAUDE.md` - project decisions.
- Existing tree under `src/`.

## Output

- Source files under `src/` matching the plan's Reuse / Modify / Create table.
- Updated plan: `- [x]` on every Sequence step, `(shipped)` on every artifact, frontmatter `status: shipped` + `shipped: <YYMMDD-HHmm>`.

## Verification

Run from `source-code/<project-name>/`. Stop and fix on first failure.

```bash
pnpm typecheck
pnpm lint
pnpm test
pnpm build
```

Then invoke **`fe-review`** (code quality) and **`fe-summary`** (plan coverage). The feature is not done until both pass.

## Anti-patterns - reject on sight

- Emitting a component or page file directly instead of invoking `fe-component` / `fe-page`.
- Running Sequence steps out of order to "unblock" work - fix the Sequence, do not skip.
- Editing files not listed in the plan without amending the plan first.
- Batching typecheck / lint to the end - single-step failures are easier to diagnose than a wall.
- Marking `status: shipped` while `- [ ]` unchecked steps remain in Sequence.
- Silently absorbing an API-contract delta - always kick back to `fe-plan`.
- Skipping the consumer sweep on a Modify row - a green build is not proof consumers still work.
