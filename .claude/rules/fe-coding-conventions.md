# Coding conventions

Shared rule referenced by every UI-emitting `fe-*` skill (`fe-component`, `fe-page`, `fe-boilerplate`, `fe-restyle`).

Scope: TypeScript / JavaScript source under `source-code/<project-name>/src/`. Deviations: state a reason inline.

## Contents

**Code shape** - how source is named, imported, typed, and commented.
- [Naming](#naming) - case per kind, no Hungarian prefixes.
- [Imports](#imports) - order, alias vs relative, named exports.
- [TypeScript](#typescript) - `interface` vs `type`, no `any`, discriminated unions.
- [Comments](#comments) - default is none; explain *why*, not *what*.

**Runtime behavior** - how the app handles errors and side effects.
- [Error handling](#error-handling) - validate at boundaries, do not swallow.
- [Async & side effects](#async--side-effects) - `async / await`, effects are for external sync.

**UI & styling** - how components consume design tokens and compose classes.
- [Theme tokens over palette](#theme-tokens-over-palette) - reference semantic tokens, not raw colors.
- [Class composition](#class-composition) - `cn` / `clsx` + `tailwind-merge`, never string concat.
- [Variants](#variants) - CVA / `tailwind-variants`, not nested ternaries.
- [One styling system per project](#one-styling-system-per-project) - Tailwind *or* CSS Modules, not both.
- [Global CSS scope](#global-css-scope) - tokens, resets, typography only.
- [Inline style](#inline-style) - only for runtime-computed values.
- [Dark mode](#dark-mode) - `dark:` on tokens, not palette swaps.

**Hygiene** - keeping the codebase clean.
- [Dead code](#dead-code) - delete on sight, git remembers.
- [Formatting](#formatting) - Prettier owns it, never argue.
- [Linting](#linting) - project lint config is source of truth.

**Anti-patterns** - the reject-on-sight list.
- [Anti-patterns - reject on sight](#anti-patterns---reject-on-sight)

## Naming

| Kind                          | Case                | Example                              |
| ----------------------------- | ------------------- | ------------------------------------ |
| React component               | PascalCase          | `UserCard`, `LoginForm`              |
| Component file                | PascalCase          | `UserCard.tsx`                       |
| Hook                          | camelCase + `use*`  | `useAuth`, `useDebounced`            |
| Utility function              | camelCase           | `formatDate`, `parseQuery`           |
| Utility file                  | kebab-case          | `format-date.ts`, `parse-query.ts`   |
| Constant (module-level)       | SCREAMING_SNAKE     | `MAX_RETRIES`, `API_BASE_URL`        |
| Type / interface              | PascalCase          | `UserProfile`, `ButtonProps`         |
| Enum / string-union values    | kebab-case strings  | `'sign-in'`, `'sign-out'`            |
| Boolean prop / variable       | positive `isX/hasX` | `isLoading`, `hasAccess`             |
| Event handler prop            | `onX` (verb)        | `onClick`, `onSubmit`, `onSelect`    |
| Event handler internal        | `handleX`           | `handleClick`, `handleSubmit`        |

**Do not** use Hungarian prefixes (`strName`, `bIsOpen`), abbreviations that are not universal (`usr`, `btn`), or file names that disagree with their default export (`Card.tsx` must default-export `Card`).

## Imports

Order - separated by blank lines, enforced by lint config:

1. Node built-ins (`node:*`).
2. External packages (`react`, `axios`, `zod`, UI library).
3. Internal via alias (`@/components/*`, `@/lib/*`, `@/hooks/*`).
4. Relative siblings (`./Foo`, `../parent-thing`).
5. Styles / assets (`./Foo.css`, `@/assets/logo.svg`).

**Use `@/*` for cross-directory imports; use `./` only for direct siblings** (same folder). Import order across the codebase must stay consistent - if the linter is not enforcing it, wire it up.

Prefer **named exports** everywhere. Default exports are allowed only for framework-required cases (Next.js `page.tsx` / `layout.tsx` / `error.tsx`). Never mix a default and named export in the same file.

## TypeScript

- **`interface` for object shapes and component props** (extensible, better error messages). **`type` for unions, intersections, tuples, mapped, or utility-derived aliases.**
- **Never use `any`.** Use `unknown` at boundaries and narrow with a type guard or Zod. If you truly need `any` (third-party gap), leave a one-line comment explaining why.
- **Discriminated unions over optional-prop soup.** A component that has two visual modes with different required inputs is a union type, not one interface with everything optional.
- **`readonly` on props you do not mutate.** Especially arrays and objects.
- **No non-null assertions (`x!`) in application code.** Narrow with a check or throw explicitly.
- **Enum → prefer string-literal unions.** `type Status = 'idle' | 'loading' | 'ready'` beats `enum Status { ... }` for tree-shakability and JSON compatibility.
- **`satisfies` for token / config objects.** Keeps literal narrowing while checking the shape.

## Comments

Default is **no comment**. Add one only when the *why* is non-obvious:

- Hidden constraint (e.g. "API returns `null` when the account is soft-deleted").
- Subtle invariant a future reader would violate.
- Workaround for a specific upstream bug - link the issue.
- `// TODO` / `// FIXME` for tracked deferred work - include an issue link or owner, state the next action, and remove when done. Example: `// TODO(#123): swap to react-hook-form once auth ships`. A TODO with no link or no next action is dead code - delete it.

**Do not** write comments that explain *what* the code does when a well-named identifier already does that. Do not reference the current task, PR, or callers ("used by X", "added for Y flow") - those rot as the codebase evolves and belong in the PR description.

Never write multi-paragraph docstrings on internal components. If a public helper needs docs, one line above the signature is the ceiling.

## Error handling

- **Validate at system boundaries only** - user input, external APIs, `localStorage` reads. Trust internal code and framework guarantees.
- **Do not catch what you cannot handle.** `try { ... } catch (e) { console.error(e) }` is not error handling; it hides bugs.
- **Errors flow up to the nearest error boundary or the top-level query hook**, which owns user-visible messaging.
- **Never swallow rejected promises.** Every `.then` needs a `.catch`, every `await` needs a surrounding `try` or a caller-side error state.
- **Do not add fallback values for scenarios that can't happen.** A required prop is not "possibly undefined". A required env var is not "maybe missing" - assert at boot.

## Async & side effects

- Prefer `async / await` over `.then` chains for readability. Reserve promise chaining for compositional cases (`Promise.all`, chained `.map`).
- Effects (`useEffect`) are for **synchronizing with external systems** (subscriptions, browser APIs, third-party libraries), not for deriving state - compute during render.
- Never fire a fetch in `useEffect` when the state library owns data (`useQuery`, `useSWR`, or the app's equivalent).

## Theme tokens over palette

Reference **semantic tokens** (`text-foreground`, `bg-surface`, `border-accent`, `text-muted-foreground`) - never raw palette classes (`text-slate-900`, `bg-neutral-50`) in component code. Tokens flip cleanly for dark mode and for `fe-restyle` re-skins; palette classes are dead weight the next time the visual language changes.

Define tokens once in `tailwind.config.ts` (or the `@theme` block in v4) as CSS variables. Components consume the token name, not the color value.

```tsx
// ✅ token
<button className="bg-primary text-primary-foreground" />

// ❌ palette leak
<button className="bg-indigo-600 text-white" />
```

## Class composition

Merge classes with **`cn`** (a `clsx` + `tailwind-merge` wrapper, typically `@/lib/cn.ts`). Never build class strings with `+` or template literals - conflict-resolving merge is required so a `className` override at the call site wins over a base class.

```tsx
// ✅
<div className={cn('rounded-md p-2', isActive && 'bg-primary', className)} />

// ❌ template string, later class does not win
<div className={`rounded-md p-2 ${isActive ? 'bg-primary' : ''} ${className}`} />
```

## Variants

Multi-variant components use **CVA** (`class-variance-authority`) or **`tailwind-variants`**. Encode variants as one typed `variants` object with `defaultVariants` - never as nested ternaries in JSX.

```tsx
// ✅ CVA
const button = cva('inline-flex items-center rounded-md', {
  variants: {
    intent: { primary: 'bg-primary text-primary-foreground', ghost: 'bg-transparent' },
    size: { sm: 'h-8 px-3 text-sm', md: 'h-10 px-4 text-base' },
  },
  defaultVariants: { intent: 'primary', size: 'md' },
})

// ❌ nested ternary soup
<button className={`rounded-md ${intent === 'primary' ? 'bg-primary text-primary-foreground' : 'bg-transparent'} ${size === 'sm' ? 'h-8 px-3' : 'h-10 px-4'}`} />
```

## One styling system per project

Pick **one** styling system at `fe-setup` time - Tailwind utilities, CSS Modules, or a CSS-in-JS library - and stick to it. Never mix systems on the same element. Cross-system codebases fragment tokens, defeat conflict-resolving merges, and make restyles miserable.

If a third-party component ships its own styles (Antd, MUI), consume its theming API rather than overriding with the project's system.

## Global CSS scope

Global CSS (`src/styles/globals.css` or `src/index.css`) is reserved for:

- Theme tokens (`@theme` block, CSS variables on `:root` / `.dark`).
- Resets and normalize.
- Typography base (font-family on `<html>`, heading rhythm if the design calls for it).

**Component-specific rules never go in global CSS.** If a component needs a style the utility system cannot express, colocate it in a CSS Module or a component-scoped `<style>` - not `globals.css`.

## Inline style

`style={{ ... }}` is reserved for values that **must** come from JavaScript at runtime - animated transforms, computed pixel positions, dynamic CSS variables driven by props (`style={{ '--progress': `${pct}%` }}`).

Anything the class system can express belongs in `className`. Inline `style` sidesteps the theme, is not tree-shakable, and breaks class merging.

## Dark mode

Dark mode is expressed by **swapping the token values**, not by adding conditional palette classes. Tokens are declared under `:root` and re-declared under `.dark`. Components reference token names and require no `dark:` branching for standard cases.

```tsx
// ✅ tokens flip automatically
<div className="bg-surface text-foreground" />

// ❌ palette branching everywhere
<div className="bg-white text-slate-900 dark:bg-slate-900 dark:text-white" />
```

Reach for the `dark:` variant only when a specific element needs a different treatment beyond the token flip (e.g. a dark-mode-only illustration, a shadow that must intensify).

## Dead code

Delete on sight - do not leave `// removed` comments, commented-out blocks, or unused exports "for later". Git remembers.

## Formatting

Prettier owns formatting. Never argue with it. Never add manual line-breaks that Prettier will undo. If a Prettier default is wrong for the project, change the config once - do not fight it per-file.

Install **`prettier-plugin-tailwindcss`** so utility-class order stays consistent - class order is not a review conversation.

## Linting

Every project's lint config is the source of truth. Run `pnpm lint` before declaring a task done. Do not add `// eslint-disable-*` to silence a real error - fix the code or, if the rule is wrong for the codebase, adjust the rule globally.

## Anti-patterns - reject on sight

- Function longer than the screen with no intermediate names - extract.
- Nested ternaries beyond one level - use `if` / early return.
- Duplicate literals (`'admin' | 'user' | 'guest'` in three places) - factor into a type alias.
- Fetch calls inside a component body - move to a hook.
- `console.log` left in a commit - use the project's logger or delete.
- Types imported from generated barrels that hide their origin - import from the source module.
- Arbitrary Tailwind values with hardcoded `px` (`w-[180px]`, `p-[7px]`, `text-[13px]`) - use the theme scale (`w-44`, `p-2`, `text-sm`). Arbitrary `rem` values (`w-[11.25rem]`) are tolerated once; on the second occurrence, extend `tailwind.config` / `@theme` rather than duplicating the literal. See `fe-responsive.md` → *Units - `rem` first, `px` for hairlines* for the a11y rationale.
- `React.FC` on component signatures - hides prop types and implicitly adds `children`; type the props directly.
- Barrel `index.ts` at a directory root (`src/components/index.ts`) - defeats tree-shaking and hides import origin.
- Zod schemas re-derived inside a component - hoist to the module scope so they are compiled once.
