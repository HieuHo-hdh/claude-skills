---
name: fe-summary
description: Use as the final gate after fe-implement, fe-test, and fe-review. Diffs the plan against what shipped - every acceptance criterion covered by a test, every Reuse/Modify/Create row backed by a file change, every Impact-analysis consumer touched. Produces a gap list and flips the plan to shipped only when the gap list is empty.
---

# fe-summary

Verifies that what shipped matches what the plan promised. Grades three dimensions: **criteria coverage**, **artifact coverage**, **impact coverage**. Emits a gap list. Blocks close-out until the gap list is empty or every gap has an owner + deferral reason.

## Contents

**Setup** - the state required to grade.
- [Prerequisites](#prerequisites) - plan, code, tests, review already done.
- [Working directory](#working-directory) - inside the target project.
- [Shared conventions](#shared-conventions) - the artifacts this skill reads.

**Workflow** - the ordered comparison pass.
- [1. Load the plan and its annotations](#1-load-the-plan-and-its-annotations) - one source of truth.
- [2. Criteria coverage](#2-criteria-coverage) - every acceptance criterion → a test.
- [3. Artifact coverage](#3-artifact-coverage) - every plan row → a file change.
- [4. Impact coverage](#4-impact-coverage) - every listed consumer touched, no hidden ones.
- [5. Gap list](#5-gap-list) - what shipped, what did not.
- [6. Close out or block](#6-close-out-or-block) - flip status or hold the door.

**Contract** - what this skill consumes and produces.
- [Input](#input)
- [Output](#output)
- [Verification](#verification)

## Prerequisites

- **`fe-implement` ran** - plan has `- [x]` on every Sequence step; `status: shipped`.
- **`fe-test` ran** - plan has a **Test coverage matrix** section.
- **`fe-review` ran** - plan has a **Review findings** section (or the report was clean).
- **Green build** locally: `pnpm typecheck`, `pnpm lint`, `pnpm test` all pass.

## Working directory

Runs inside `source-code/<project-name>/`. Reads `docs/plans/<slug>.md`, git diff, and test output. Emits into the plan file - never elsewhere.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B.

## Shared conventions

- **Markdown style:** `.claude/rules/markdown-style.md` - edits to the plan file.
- **Plan format:** `fe-plan`'s canonical layout - this skill relies on section names verbatim (`Acceptance criteria`, `Reuse / Modify / Create`, `Impact analysis`, `Sequence`, `Test coverage matrix`).

## Workflow

### 1. Load the plan and its annotations

Read `docs/plans/<slug>.md`. Extract:

- **Acceptance criteria** as an ordered list.
- **Reuse / Modify / Create** table rows.
- **Impact analysis** rows (empty if the feature had no Modify rows).
- **Sequence** with `- [x]` markers.
- **Test coverage matrix** rows.
- Frontmatter: `status`, `created`, `shipped`, `owner`.

Refuse when:

| Condition | Reason |
| --- | --- |
| `status: provisional` | The plan was never ready to implement. Re-run `fe-plan`. |
| No Test coverage matrix | `fe-test` did not run. Run it first. |
| Sequence has unchecked `- [ ]` steps | `fe-implement` did not finish. Complete or defer. |

### 2. Criteria coverage

For each acceptance criterion, verify it appears in the Test coverage matrix with a passing test file. Build:

| Criterion | Test file | Status |
| --- | --- | --- |
| profile renders once data resolves | `SettingsProfilePage.test.tsx` | ✅ covered |
| empty display name blocks submit | `ProfileForm.test.tsx` | ✅ covered |
| 500 on save surfaces toast + rollback | (missing) | ❌ gap |
| renders in <500ms | `Level: manual` in matrix | ⚠ deferred to QA |

**Gap rules:**

- **Missing row** in the matrix → gap.
- **Row present, test file does not exist on disk** → gap.
- **Row present, test exists, test is `.skip`ped** → gap (unless linked to an issue).
- **`Level: manual`** → not a gap, but log as deferred and name the owner.

### 3. Artifact coverage

For each Reuse / Modify / Create row, verify the file state matches:

| Row action | Expected on disk | Check |
| --- | --- | --- |
| `Reuse` | File exists, **not in diff** | `git diff --name-only` should NOT list it |
| `Modify` | File exists, **in diff** | must appear in `git diff` |
| `Create` | File exists (new), **in diff as add** | `git diff --diff-filter=A` includes it |

Also verify **annotation**: every artifact should have `(shipped)` in the Artifact breakdown section (added by `fe-implement`).

Any mismatch → gap. Report file, expected state, actual state.

### 4. Impact coverage

For every row in **Impact analysis**:

1. The listed consumer file must appear in the diff.
2. The change must be consistent with the **Delta** column (best-effort read; deep semantic checks are for `fe-review`).

Then do the hidden-consumer sweep:

```bash
grep -rn "from ['\"].*/<modified-artifact>['\"]" src/
```

Any importer not in Impact analysis → gap (Sev 1 in `fe-review` terms; here, block close-out).

### 5. Gap list

Emit the gap list, grouped:

```md
## Summary of shipped work

Plan: `260928-1430-settings-profile.md`
Shipped: 260928-1730
Owner: @hieu

### Coverage
- Criteria: 3 / 4 covered, 1 deferred to manual QA.
- Artifacts: 7 / 7 present (2 reuse, 1 modify, 4 create).
- Impact: 2 / 2 consumers touched; 0 hidden importers.

### Gaps
- **Criterion 3** ("500 on save surfaces toast + rollback") - no test in matrix.
  Owner: @hieu, follow-up before merge.
- **Manual criterion** ("renders in <500ms") - deferred to QA on staging.

### Deviations from plan
- (none)

### Follow-ups
- Add integration test for save-failure toast + rollback.
- QA to sign off on <500ms render on staging.
```

If **no gaps**, the Gaps and Deviations sections both say `(none)`.

### 6. Close out or block

**No gaps** → flip the plan:

- Frontmatter `status: shipped` stays.
- Add frontmatter `verified: YYMMDD-HHmm` (matches summary time).
- Summary section appended to the plan.
- Announce to the user: feature is done; recommend committing / opening a PR.

**Any gap** → block close-out:

- Do NOT flip `status`.
- Summary section still appended, gaps listed with owners.
- Announce to the user: feature is not done. List the next actions.

Never mark verified while gaps exist without linked owners - a green summary with hidden gaps is worse than no summary.

## Input

- `docs/plans/<slug>.md` - with `- [x]` Sequence, Test coverage matrix, and (usually) Review findings sections.
- Git diff since the plan started.
- Test suite results (`pnpm test`).

## Output

- **Summary section** appended to `docs/plans/<slug>.md` under a new `## Summary of shipped work` heading.
- Frontmatter `verified: <YYMMDD-HHmm>` added only when there are zero unowned gaps.
- Inline announcement to the user: pass / block, with the gap list.

## Verification

```bash
pnpm typecheck
pnpm lint
pnpm test
```

- [ ] Every acceptance criterion has a passing test row **or** a `manual` row with an owner.
- [ ] Every Reuse / Modify / Create row matches the diff (present, absent, added, modified).
- [ ] Every Impact-analysis consumer appears in the diff.
- [ ] No hidden importer of a modified artifact.
- [ ] Gap list is empty **or** every gap has an owner + follow-up.

## Anti-patterns - reject on sight

- Flipping `verified` while gaps remain unowned - hides regressions in the plan record.
- Running `fe-summary` without `fe-test` - no coverage matrix means no criteria coverage grade.
- Silently rewriting acceptance criteria to match the code that shipped - the plan is a contract; if the criteria were wrong, kick back to `fe-plan` and record the deviation.
- Skipping the hidden-consumer sweep because Impact analysis "looked complete" - grep is cheap; hidden imports are expensive.
- Marking a `manual` criterion `✅` when no human has actually verified - `manual` means owned but pending, not "assumed fine".
- Appending the summary anywhere other than the plan file - downstream tooling looks in the plan.
