---
name: fe-component
description: Use when building a single reusable UI component from a brief - e.g., "make me a Button", "scaffold a DataTable". Drafts the props API first, enumerates variants and states, wires a11y and responsive rules, ships one unit test. Not for full pages (use fe-page) or theme changes (use fe-restyle).
---

# fe-component

Builds one component: props API, variants, states, a11y, responsive behavior, unit test. Reuses Style tokens from `CLAUDE.md` - never hardcodes hexes / sizes / breakpoints.

## Contents

**Setup** - preconditions and shared rules.
- [Prerequisites](#prerequisites) - upstream skills, deps.
- [Working directory](#working-directory) - target project under `source-code/`.
- [Shared conventions](#shared-conventions) - responsive, a11y, coding, structure, tokens.

**Workflow** - build order for one component.
- [1. Gather brief](#1-gather-brief) - name, purpose, props, variants, states.
- [2. Draft the props API](#2-draft-the-props-api---typescript-first) - TypeScript first, approve before implementing.
- [3. Enumerate states](#3-enumerate-states) - hover, focus-visible, active, disabled, loading, error.
- [4. Pick the primitive](#4-pick-the-primitive) - extend the UI library, do not hand-roll.
- [5. Implement](#5-implement---with-tokens-not-values) - tokens, spacing scale, motion rule.
- [6. A11y checklist](#6-a11y-checklist) - semantics, focus, keyboard, contrast, motion.
- [7. Location](#7-location) - folder shape, barrel `index.ts`.
- [8. Unit test](#8-unit-test---one-file-four-cases) - contract coverage, four cases.
- [9. Three-width sanity check](#9-three-width-sanity-check) - 375 / 768 / 1280 px.

**I/O & verification** - closing loop.
- [Input](#input) - `CLAUDE.md`, existing components.
- [Output](#output) - component, test, barrel.
- [Verification](#verification) - typecheck, lint, scoped test.
- [Recommendations](#recommendations) - guardrails.

## Prerequisites

- **`fe-setup` has run** - framework, UI library, and test runner recorded in `CLAUDE.md`.
- **Style section is populated** - this skill consumes tokens, does not derive them. If empty, run `fe-boilerplate`'s Style tokens step first.
- **Testing library installed** - Vitest or Jest + Testing Library from `fe-setup`. Missing → wire it before writing tests.

## Working directory

Runs inside `source-code/<project-name>/` - the project scaffolded by `fe-setup`. Read `CLAUDE.md` first for framework / UI library / Style tokens / responsive rule reference. All generated files go under that project only.

**Full rule:** `.claude/rules/fe-workspace-layout.md` - Path B.

## Shared conventions

- **Responsive:** `.claude/rules/fe-responsive.md` - mobile-first, breakpoint scale, touch targets, focus-visible. Read before writing any layout code.
- **A11y:** `.claude/rules/fe-a11y.md` - semantic elements, ARIA when semantics fall short, keyboard patterns, contrast floors.
- **Coding conventions:** `.claude/rules/fe-coding-conventions.md` - naming, imports, TypeScript rules, comment discipline.
- **Project structure:** `.claude/rules/fe-project-structure.md` - one folder per component, co-located tests, barrel index.
- **Style tokens:** the Style section of the project's `CLAUDE.md` - colors, type, spacing, motion. Consume by variable, not by hex.

## Workflow

### 1. Gather brief

Ask (or read from context) - one section at a time:

- **Name** - PascalCase, singular (`Button`, not `Buttons`).
- **Purpose** - one sentence: what does it do, who uses it.
- **Props** - required inputs. What is variable, what is fixed?
- **Variants** - visual/behavioral flavors (`primary` / `secondary` / `ghost`; `sm` / `md` / `lg`). Pick the smallest set that solves current needs - not future ones.
- **States** - which of these apply? `default`, `hover`, `focus-visible`, `active`, `disabled`, `loading`, `error`, `readonly`, `empty`. Not all apply to every component.
- **A11y hooks** - is it a button, link, input, dialog, tab? The `role` decides keyboard behavior.

If the answer to any of the above is "I don't know", stop and ask - do not guess. A wrong props API is expensive to unwind later.

### 2. Draft the props API - TypeScript first

Write the interface **before** the implementation. This is the contract; changing it later ripples across every call site.

```ts
type ButtonSize = 'sm' | 'md' | 'lg'
type ButtonTone = 'primary' | 'secondary' | 'ghost'

interface ButtonProps {
  /** Visible label. For icon-only, use `aria-label` instead. */
  children: React.ReactNode
  size?: ButtonSize   // default 'md'
  tone?: ButtonTone   // default 'primary'
  disabled?: boolean
  loading?: boolean
  onClick?: () => void
  type?: 'button' | 'submit' | 'reset'  // default 'button'
}
```

Rules:

- **Required props are unmarked; optional props end in `?`.** Do not use runtime defaults to fake optionality.
- **Defaults are declared once**, in the destructure: `({ size = 'md', tone = 'primary' })`. Do not scatter defaults through JSX.
- **Discriminated unions** for mutually-exclusive props: an `IconButton` variant is a *different component*, not a magic `icon?: string` prop.
- **`children` beats magic content props.** Prefer `<Button><Icon/> Save</Button>` over `<Button icon="save" label="Save" />`.

Present the interface to the user and get approval before implementing.

### 3. Enumerate states

For every state that applies (`hover`, `focus-visible`, `active`, `disabled`, `loading`, `error`), decide the visual change *now*:

| State           | Behavior                                                                 |
| --------------- | ------------------------------------------------------------------------ |
| `hover`         | Only on `@media (hover: hover)`. Never carry required info in hover.     |
| `focus-visible` | Always visible. 2px outline / ring in accent color, offset 2px.          |
| `active`        | Slight scale or brightness shift - snappy, not slow.                     |
| `disabled`      | Opacity 0.5, `cursor: not-allowed`, `pointer-events: none` on the click. |
| `loading`       | Spinner + disable interaction. Preserve width - do not reflow.           |
| `error`         | Red-ish border + inline message. Never rely on color alone (icon too).   |

Non-applicable states → do not implement them "just in case."

### 4. Pick the primitive

- **Antd / MUI** - extend the library primitive. Do **not** hand-roll a Button when `<Button>` exists.
- **shadcn/ui + Tailwind** - copy the shadcn primitive if it exists, then extend. `pnpm dlx shadcn@latest add button` on demand.
- **Tailwind-only** - hand-roll, but consume tokens (`bg-[var(--color-accent)]`, not `bg-blue-500`).
- **Vue / other** - the equivalent primitive from that ecosystem.

### 5. Implement - with tokens, not values

- **Every color** comes from a Style token (`var(--color-accent)` or `theme.token.colorPrimary`). Zero hex literals in the component file.
- **Every size** uses the spacing scale (`p-3`, `gap-2`). No `padding: 11px`.
- **Every breakpoint** uses the library's scale (`md:flex-row`). No `@media (min-width: 763px)`.
- **Every motion timing** uses the Style section's motion rule (or the theme's transition tokens).

### 6. A11y checklist

- Correct semantic element (`<button>` for buttons, `<a>` for links, not `<div onClick>`).
- Icon-only controls have `aria-label`.
- Focus is visible (see step 3).
- Keyboard operable: Enter/Space for buttons, arrow keys for tab/menu components.
- Disabled controls remove themselves from tab order (`disabled` attribute, not just visual).
- Contrast: accent-on-surface ≥ 4.5:1 (text) or 3:1 (large text / icons).
- `prefers-reduced-motion` respected for any animation > 200ms.

### 7. Location

```text
src/components/<Name>/
  ├── <Name>.tsx        ← the component
  ├── <Name>.test.tsx   ← the test
  └── index.ts          ← `export * from './<Name>'`
```

`index.ts` keeps the import site clean: `import { Button } from '@/components/Button'`.

### 8. Unit test - one file, four cases

Do not aim for exhaustive coverage. Cover the contract:

```tsx
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { Button } from './Button'

describe('Button', () => {
  it('renders its label', () => {
    render(<Button>Save</Button>)
    expect(screen.getByRole('button', { name: 'Save' })).toBeInTheDocument()
  })

  it('applies the tone variant', () => {
    render(<Button tone="secondary">Save</Button>)
    expect(screen.getByRole('button')).toHaveClass(/secondary/i)
  })

  it('is not clickable when disabled', async () => {
    const onClick = vi.fn()
    render(<Button disabled onClick={onClick}>Save</Button>)
    await userEvent.click(screen.getByRole('button'))
    expect(onClick).not.toHaveBeenCalled()
  })

  it('fires onClick on interaction', async () => {
    const onClick = vi.fn()
    render(<Button onClick={onClick}>Save</Button>)
    await userEvent.click(screen.getByRole('button'))
    expect(onClick).toHaveBeenCalledOnce()
  })
})
```

For Jest projects, swap `vi.fn()` → `jest.fn()` and `toHaveBeenCalledOnce()` → `toHaveBeenCalledTimes(1)`.

### 9. Three-width sanity check

If the component has any responsive behavior, eyeball it at **375 / 768 / 1280 px** (see `.claude/rules/fe-responsive.md`). Do not skip this step for anything with a layout - margins collapse differently at every breakpoint.

## Input

- `CLAUDE.md` - framework, UI library, Style section.
- Existing components under `src/components/` (may share sub-primitives).

## Output

- `src/components/<Name>/<Name>.tsx`
- `src/components/<Name>/<Name>.test.tsx`
- `src/components/<Name>/index.ts`

## Verification

Run from `source-code/<project-name>/`. Stop and fix on first failure.

```bash
pnpm typecheck
pnpm lint
pnpm test <Name>          # scoped to this component
```

Run `pnpm build` if the component is used in a Next.js layout - prerender catches things dev hides.

## Recommendations

- **Draft the props API first, in isolation.** A prop shape written after implementation always leaks internals.
- **Do not add props for hypothetical future needs.** Three duplicated call sites is better than a premature `variant` prop.
- **Reject color / size / breakpoint literals during self-review.** If you see `#fff` or `12px` or `min-width: 768px`, replace with a token.
- **Never hide interaction behind `:hover`.** Touch users don't have it.
- **One test file per component.** Do not co-locate multiple component tests to save keystrokes.
- **Prefer composition over configuration.** A `Card` with `<Card.Header>`, `<Card.Body>`, `<Card.Footer>` beats a `Card` with `title` / `body` / `footer` string props.
