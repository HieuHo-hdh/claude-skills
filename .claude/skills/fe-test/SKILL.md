---
name: fe-test
description: Use after fe-implement to translate a plan's acceptance criteria into unit and/or e2e tests. Every Given/When/Then bullet maps to at least one test; four data states (loading / error / empty / success) are non-negotiable per page. Produces a coverage matrix. Unit and e2e are each optional per feature - state which and why.
---

# fe-test

Turns the acceptance criteria in `docs/plans/<slug>.md` into executable tests. One criterion → at least one test. Emits a coverage matrix so `fe-summary` can verify nothing was missed.

## Contents

**Setup** - what has to be in place.
- [Prerequisites](#prerequisites) - plan, test runner, MSW or equivalent.
- [Working directory](#working-directory) - inside the target project.
- [Shared conventions](#shared-conventions) - naming, colocation.

**Workflow** - the ordered pass that produces tests.
- [1. Load plan and extract criteria](#1-load-plan-and-extract-criteria) - one row per bullet.
- [2. Classify each criterion](#2-classify-each-criterion) - unit, integration, or e2e.
- [3. Coverage matrix](#3-coverage-matrix) - criteria → test files.
- [4. Write unit tests](#4-write-unit-tests) - co-located, one behavior per test.
- [5. Write e2e tests](#5-write-e2e-tests) - Playwright preferred; happy path + one failure.
- [6. Run and iterate](#6-run-and-iterate) - fix, do not skip.
- [7. Annotate the plan](#7-annotate-the-plan) - matrix appended, status updated.

**Contract** - what this skill consumes and produces.
- [Input](#input)
- [Output](#output)
- [Verification](#verification)

## Prerequisites

- **`fe-implement` ran** - plan `status: shipped`; source under `src/` exists.
- **Test runner installed by `fe-setup`** - Vitest / Jest + Testing Library.
- **HTTP mocking layer** - MSW (`@mswjs/msw`) or the project's equivalent. Do not stub `fetch` directly.
- **E2E only:** Playwright installed. Skip e2e entirely if the project has no e2e runner and the user does not want one; note the skip in the coverage matrix.

## Working directory

Runs inside `source-code/<project-name>/`. Tests colocate with source; e2e goes under `e2e/` at the project root.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B.

## Shared conventions

- **Coding conventions:** `.claude/rules/fe-coding-conventions.md` - test names use `describe / it` in behavior form (`it('shows the empty state when there is no data')`), not `should`-prefixed.
- **A11y assertions:** query by role (`getByRole('button', { name: /save/i })`), not by test-id. Test-ids are a last resort.
- **No snapshot tests for JSX** - they rot silently. Use explicit assertions.

## Workflow

### 1. Load plan and extract criteria

Read `docs/plans/<slug>.md`. Extract every Given / When / Then bullet from the **Acceptance criteria** section into a table:

| # | Criterion (one line) | Page / component under test |
| --- | --- | --- |
| 1 | user sees profile once query resolves | `SettingsProfilePage` |
| 2 | empty display name blocks submit | `ProfileForm` |
| 3 | 500 on save surfaces a toast + rollback | `SettingsProfilePage` |

If the plan has zero acceptance criteria, refuse - re-run `fe-plan` step 2. Tests without criteria are cargo-culted coverage.

### 2. Classify each criterion

For each row above, decide the level:

| Level | When | Location |
| --- | --- | --- |
| **Unit** | Behavior of one component / hook / util in isolation | Co-located `*.test.ts(x)` next to the source |
| **Integration** | Multiple components + mocked network, no real routing | Co-located with the page (`<Page>.test.tsx`) |
| **E2E** | Full user flow, real router, real network (or MSW at the browser layer) | `e2e/<feature>.spec.ts` (Playwright) |

Defaults:

- **Data-state criteria** (loading / error / empty / success) → integration test at the page level.
- **Form validation criteria** → unit test on the form component.
- **Cross-page user flows** (sign in → dashboard → open modal) → e2e.
- **Auth guard behavior** (401 mid-session, redirect to `/login`, plus `next=` when the project enables it) → e2e.

If unit + integration would test the same behavior twice, keep the smaller one and drop the duplicate.

### 3. Coverage matrix

Emit this table and paste it into the plan later (see [Annotate the plan](#7-annotate-the-plan)):

| # | Criterion | Level | Test file | Test name |
| --- | --- | --- | --- | --- |
| 1 | profile renders once data resolves | integration | `SettingsProfilePage.test.tsx` | `renders the profile once the query resolves` |
| 2 | empty display name blocks submit | unit | `ProfileForm.test.tsx` | `disables Save when displayName is empty` |
| 3 | 500 on save surfaces toast + rollback | integration | `SettingsProfilePage.test.tsx` | `rolls back the header greeting on save failure` |
| 4 | 401 mid-session → redirect to `/login` | e2e | `e2e/settings-profile.spec.ts` | `redirects to login when the session expires mid-edit` |

**Every criterion must appear.** If a criterion cannot be tested (e.g. "renders in <500ms" is a performance criterion, out of scope for RTL), record it as `Level: manual` and note who verifies it.

### 4. Write unit tests

One `*.test.ts(x)` per component / hook / util, co-located. Structure:

```tsx
// src/pages/SettingsProfile/ProfileForm.test.tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { ProfileForm } from './ProfileForm'

describe('ProfileForm', () => {
  it('disables Save when displayName is empty', async () => {
    render(<ProfileForm initial={{ displayName: '', email: 'a@b.co' }} onSave={vi.fn()} />)
    await userEvent.clear(screen.getByLabelText(/display name/i))
    expect(screen.getByRole('button', { name: /save/i })).toBeDisabled()
  })
})
```

Rules:

- **Query by role, then label, then text.** `getByTestId` is a last resort.
- **One behavior per `it`.** If a test has two "and"s in its name, split it.
- **Never test implementation details** - do not assert on internal state, props of children, or `useEffect` firing.
- **Mock at the network boundary** (MSW), not at the module (`vi.mock('axios')`) - module mocks rot.
- **Reset MSW handlers between tests** via `beforeEach(() => server.resetHandlers())`.

### 5. Write e2e tests

One `.spec.ts` per user flow under `e2e/`. Playwright preferred. Structure:

```ts
// e2e/settings-profile.spec.ts
import { test, expect } from '@playwright/test'

test.describe('settings profile', () => {
  test('user updates display name and sees it in the header', async ({ page }) => {
    await page.goto('/login')
    await page.getByLabel(/email/i).fill('user@example.com')
    await page.getByLabel(/password/i).fill('correcthorse')
    await page.getByRole('button', { name: /sign in/i }).click()

    await page.goto('/settings/profile')
    await page.getByLabel(/display name/i).fill('Ada Lovelace')
    await page.getByRole('button', { name: /save/i }).click()

    await expect(page.getByRole('status')).toHaveText(/saved/i)
    await expect(page.getByRole('banner').getByText('Ada Lovelace')).toBeVisible()
  })
})
```

Rules:

- **One happy path + one failure path per flow.** More is diminishing returns.
- **Do not seed data via UI** if the API supports it - hit `POST /api/test/seed` (or equivalent) in `beforeEach`.
- **Do not assert timing** (`waitForTimeout(500)`) - use `expect(...).toBeVisible()` / `toHaveText(...)` which auto-retry.
- **Run in parallel by default**; only serialize when the test mutates shared state.

### 6. Run and iterate

```bash
pnpm test               # unit + integration
pnpm test:e2e           # if e2e exists
```

If a test fails:

1. Read the failure. Is it a **bug in the code** or **wrong test expectation**?
2. If bug: file it against the shipped feature - the plan's acceptance criterion was not met. Kick back to `fe-implement`.
3. If wrong expectation: fix the test. Do not `.skip` failing tests to make CI green.

### 7. Annotate the plan

Append this section to `docs/plans/<slug>.md` (before **Out of scope**):

```md
## Test coverage matrix

| # | Criterion | Level | Test file | Status |
| --- | --- | --- | --- | --- |
| 1 | profile renders once data resolves | integration | `SettingsProfilePage.test.tsx` | ✅ |
| 2 | empty display name blocks submit | unit | `ProfileForm.test.tsx` | ✅ |
| 3 | 500 on save surfaces toast + rollback | integration | `SettingsProfilePage.test.tsx` | ✅ |
| 4 | 401 mid-session → redirect to `/login` | e2e | `e2e/settings-profile.spec.ts` | ✅ |
| 5 | renders in <500ms | manual | — | 👀 QA |

E2E: **enabled** (Playwright, 1 flow).
Unit: **enabled**.
```

`fe-summary` reads this to check nothing slipped.

## Input

- `docs/plans/<slug>.md` - `status: shipped`, acceptance criteria populated.
- Source files under `src/` produced by `fe-implement`.

## Output

- `*.test.ts(x)` files colocated with source.
- `e2e/*.spec.ts` files if e2e is enabled.
- Test coverage matrix appended to the plan.

## Verification

```bash
pnpm test              # every unit + integration test green
pnpm test:e2e          # every e2e green (if enabled)
```

Coverage matrix reviewed:

- [ ] Every acceptance criterion has at least one row.
- [ ] Every page-level criterion covers all four data states.
- [ ] Every failure-path criterion has a dedicated test.
- [ ] No test is `.skip`ped without a linked issue.

## Anti-patterns - reject on sight

- Snapshot tests on JSX - they rot silently and reviewers stop reading them.
- `getByTestId` used where `getByRole` would work - couples tests to markup, not behavior.
- `waitForTimeout` in Playwright - always use auto-retrying assertions.
- Mocking modules (`vi.mock('axios')`) instead of the network (MSW) - module mocks bypass real serialization / typing.
- Two tests with the same assertion at different layers - keep the smaller one.
- E2E test that logs in via the UI on every run - seed the session or use storage state.
- `.skip` without a linked issue - dead test, delete it.
- Coverage matrix missing a criterion - a criterion without a test is a shipped bug waiting.
