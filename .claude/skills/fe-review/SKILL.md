---
name: fe-review
description: Use after fe-implement to review the diff for correctness, convention adherence, duplication, dead code, and Impact-analysis coverage. Runs rule-by-rule against .claude/rules/fe-*.md. Emits a report grouped by severity and fixes low-risk findings in place. Not a substitute for security-review (invoke that separately for auth / user input).
---

# fe-review

Reads the git diff since the plan started, checks every changed file against the project's rule set, and grades findings by severity. Fixes trivial issues in place (dead code, import order, missing types). Flags the rest for user decision.

## Contents

**Setup** - the state to review against.
- [Prerequisites](#prerequisites) - plan shipped, git has the diff.
- [Working directory](#working-directory) - inside the target project.
- [Shared conventions](#shared-conventions) - the rule set this skill enforces.

**Workflow** - the ordered review pass.
- [1. Enumerate the diff](#1-enumerate-the-diff) - what to review.
- [2. Rule sweep](#2-rule-sweep) - one pass per rules file.
- [3. Duplication scan](#3-duplication-scan) - reject on 80%+ overlap.
- [4. Impact-analysis verification](#4-impact-analysis-verification) - every Modify consumer touched.
- [5. Dead-code sweep](#5-dead-code-sweep) - unused exports, `console.log`, TODOs without owner.
- [6. Report and auto-fix](#6-report-and-auto-fix) - severity buckets, in-place fixes for trivial.

**Contract** - what this skill consumes and produces.
- [Input](#input)
- [Output](#output)
- [Verification](#verification)

## Prerequisites

- **`fe-implement` ran** - plan `status: shipped`; diff exists on the working branch.
- **Rule files present** at `.claude/rules/fe-*.md` and `.claude/rules/markdown-style.md`.
- **Lint + typecheck pass locally** - `fe-review` grades quality, not brokenness. Fix red builds first.

## Working directory

Runs inside `source-code/<project-name>/`. Reads the diff scoped to that project. Never crosses into a sibling.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B.

## Shared conventions

- **Coding conventions:** `.claude/rules/fe-coding-conventions.md` - primary rule set.
- **A11y:** `.claude/rules/fe-a11y.md`.
- **Responsive:** `.claude/rules/fe-responsive.md`.
- **Markdown style:** `.claude/rules/markdown-style.md` - covers any docs / plan edits in the diff.

## Workflow

### 1. Enumerate the diff

```bash
git fetch origin
git diff --name-only origin/main...HEAD
```

For each changed file, note:

- Path and kind (component / hook / util / page / test / doc).
- Whether it appears in the plan's Reuse / Modify / Create table.
- Whether it appears in the plan's Impact analysis as a consumer.

If a changed file appears **nowhere** in the plan, flag as **Deviation** at Sev 1 - either the plan is stale or the code is out of scope.

### 2. Rule sweep

For each rules file, walk the diff and grade each violation. Do not batch; one rules file at a time so no rule is skipped.

| Rules file | Focus on the diff |
| --- | --- |
| `fe-coding-conventions.md` | Naming, imports, `any`, `React.FC`, palette leaks, `cn` usage, dead comments |
| `fe-a11y.md` | Semantic HTML, labels, focus, `aria-*`, contrast, keyboard bindings |
| `fe-responsive.md` | Mobile-first, `rem` not arbitrary `px`, breakpoint tokens, `100dvh` |
| `markdown-style.md` | Plan edits, `SKILL.md` edits, any `docs/**` changes |

Severity:

| Sev | Meaning | Action |
| --- | --- | --- |
| **1** | Correctness / a11y / security-adjacent | Report; block the ship |
| **2** | Convention violation with real impact (palette leak, `any`, `React.FC`) | Report; auto-fix if trivial and mechanical |
| **3** | Style nit (import order, comment noise) | Auto-fix in place; no report entry |

### 3. Duplication scan

For every **Create** row in the plan, verify against the tree:

```bash
grep -rn "export const <Name>" src/
grep -rn "function <name>" src/
grep -rn "const <resource>Schema" src/schemas/
```

Flag:

- **Same-name export** in two places → Sev 1.
- **Structural overlap ≥ 80%** with an existing artifact (compare props / signature / body) → Sev 1. Recommend either reuse the existing artifact or split via variant.
- **Parallel schemas for the same resource** (e.g. `profileSchema` and `userProfileSchema` both describe `/api/profile`) → Sev 1. One canonical schema per resource.

**Cheap heuristic:** if two components share ≥ 3 identical props and body length within 20% → open both, diff by eye, decide.

### 4. Impact-analysis verification

For every row in the plan's **Impact analysis**:

- Confirm the listed consumer file appears in the diff.
- Confirm the change matches the **Delta** column.
- If a consumer is listed but **not** in the diff → Sev 1 regression risk.
- If the diff modifies a shared artifact whose consumers are **not** listed in Impact analysis → Sev 1; the plan under-scoped impact.

Run one last cross-check:

```bash
grep -rn "from ['\"].*/<modified-artifact>['\"]" src/
```

Any import not in the Impact analysis is a hidden consumer - Sev 1.

### 5. Dead-code sweep

Scan the diff for:

- **Unused exports** - `ts-unused-exports` or `knip` if configured; otherwise a manual pass on new files.
- **Commented-out blocks** - delete on sight; git remembers.
- **`console.log` / `console.debug`** - Sev 2 (Sev 1 if it logs user data).
- **`// TODO` without a linked issue or owner** - Sev 2. Delete or file the issue.
- **`_unused` variables from removed features** - delete.
- **Barrel `index.ts` at a directory root** - Sev 2 per coding conventions.

### 6. Report and auto-fix

**Auto-fix in place** (no user gate) - deterministic and reversible:

- Import order per lint config.
- Missing trailing newline.
- Palette class → token when the token exists in `CLAUDE.md` Style section.
- `React.FC` → typed props.
- Dead comment / commented-out block removal.
- `console.log` removal (only in shipped code, not tests).

**Report** - group by severity, one bullet per finding, file:line:

```md
## Review findings

### Sev 1 (block ship)
- `src/pages/SettingsProfile/ProfileForm.tsx:42` - `<div onClick>` used for a submit action; use `<button type="submit">`.
- `src/hooks/use-profile.ts:18` - hidden consumer `src/components/Header/UserBadge.tsx:11` imports `useProfile` but is missing from the plan's Impact analysis.

### Sev 2 (fix before merge)
- `src/api/profile.ts:5` - `any` used for the response type; derive from `profileSchema`.
- `src/pages/SettingsProfile/ProfileForm.tsx:78` - `w-[180px]` arbitrary px; use `w-44` from the theme scale.

### Sev 3 (auto-fixed)
- (12 findings auto-fixed; see the follow-up commit.)
```

Do not silently apply Sev 1 or Sev 2 fixes - they may change behavior. Report and wait for user direction.

## Input

- `docs/plans/<slug>.md` - `status: shipped`.
- Git diff since the plan started (branch base).
- `.claude/rules/fe-*.md` and `.claude/rules/markdown-style.md`.
- Tree under `src/`.

## Output

- **Report** printed inline: Sev 1 / Sev 2 / Sev 3 buckets with file:line references.
- **In-place fixes** for Sev 3 items, committed as a follow-up.
- **Plan annotation** - append `## Review findings` section (Sev 1 + Sev 2 only) to `docs/plans/<slug>.md`.

## Verification

```bash
pnpm typecheck
pnpm lint
pnpm test
```

- [ ] All Sev 1 findings resolved.
- [ ] All Sev 2 findings resolved or explicitly deferred (with a linked issue in the report).
- [ ] Duplication scan clean.
- [ ] Impact-analysis verification clean (no hidden consumers, no missing sweeps).
- [ ] Rule sweep clean per `.claude/rules/fe-*.md`.

If any box is unchecked, ship is blocked. Fix and re-run.

## Anti-patterns - reject on sight

- Silently auto-fixing Sev 1 or Sev 2 findings - always report first.
- Skipping the duplication scan because "lint would have caught it" - lint does not detect structural overlap.
- Marking a Sev 1 finding as "won't fix" without a linked issue - unowned tech debt.
- Reviewing without reading the plan - Impact-analysis verification requires the plan's row-by-row list.
- Auto-fixing outside the diff scope - never touch files unrelated to the shipped feature.
- Running `fe-review` on a red build - fix compile / lint failures first; grading quality of broken code is theater.
