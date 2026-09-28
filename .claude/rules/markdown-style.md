# Markdown style

Shared rule referenced by every `.md` file in this repo - `.claude/rules/*.md`, `.claude/skills/*/SKILL.md`, project READMEs, generated docs.

Scope: how Markdown documents are laid out and written. Target reader: a developer or AI agent skimming for actionable information. Deviations: state a reason inline.

## Contents

**Structure** - how a document is shaped so a reader can navigate it in seconds.
- [Title & scope line](#title--scope-line) - one H1, one-line scope, no preamble.
- [Contents block](#contents-block) - grouped TOC for docs past ~150 lines.
- [Skill file layout](#skill-file-layout) - fixed section order for `.claude/skills/*/SKILL.md`.
- [Headings](#headings) - H2/H3 depth cap, noun-phrase or imperative.
- [Tables](#tables) - preferred over prose lists for enumerated attributes.
- [Code fences](#code-fences) - language tag, minimal example, `✅ / ❌` pairs.
- [Anti-pattern lists](#anti-pattern-lists) - close every rule doc with "reject on sight".

**Voice & tone** - what the prose sounds like.
- [Imperative form](#imperative-form) - "Prefer X." not "You might want to consider X."
- [Word economy](#word-economy) - compress with `:`, `,`, `` ` ``, `"…"`, `→`.
- [Length](#length) - one idea per bullet, ~40 lines per section, 200-400 lines per doc.
- [No filler](#no-filler) - kill hedges, throat-clearing, marketing verbs.
- [Terminology](#terminology) - use the codebase's own names, define once if new.

**Anti-patterns** - the reject-on-sight list.
- [Anti-patterns - reject on sight](#anti-patterns---reject-on-sight)

## Title & scope line

Every `.md` file opens with exactly one H1 (title, ≤ 5 words) followed by a single scope line. No welcome paragraph, no "in this document we will discuss…".

```md
# Coding conventions

Shared rule referenced by every UI-emitting `fe-*` skill (...).

Scope: TypeScript / JavaScript source under `source-code/<project-name>/src/`. Deviations: state a reason inline.
```

The scope line **is** the introduction. If it cannot be one sentence, the doc is doing too much - split it.

Skill files (`SKILL.md`) precede the H1 with YAML frontmatter - see [Skill file layout](#skill-file-layout).

## Contents block

Docs longer than ~150 lines get a `## Contents` section immediately after the scope line. Group related sections under **bold group labels** with a one-line group summary; list each section as an anchor link with a one-line description.

```md
## Contents

**Structure & semantics** - how the DOM is shaped so assistive tech can parse it.
- [Semantic HTML first](#semantic-html-first) - pick the right HTML element before reaching for ARIA.
- [Heading order](#heading-order) - one `<h1>`, no level skips.
```

Groups appear **only in the Contents block**. The sections themselves stay flat at H2 - do not nest H3s under H2 groups just to mirror the TOC.

## Skill file layout

Skill files at `.claude/skills/<name>/SKILL.md` follow a fixed structure. Anything not on this list belongs in a sibling doc, not in the `SKILL.md`.

**Order** - top to bottom, no reshuffling:

1. **Frontmatter** - YAML block with `name` and `description`. First lines of the file, before the H1.
2. **H1 title** - matches the frontmatter `name` verbatim.
3. **Scope / opening line** - one sentence stating the default or the invariant the skill operates under. No welcome paragraph.
4. **Contents** - grouped TOC per [Contents block](#contents-block). Include when the skill has more than ~3 main sections.
5. **Prerequisites** - tools, MCPs, directory state, or upstream skills required before running. Skip if none.
6. **Main content** - one H2 per section listed in the Contents block, in the same order. Skill-specific names (`Workflow`, `Working directory`, `Style tokens`, etc.).
7. **Input / Output** - shape of what the skill consumes (arguments, upstream artifacts) and produces (files written, structured summary). Skip for purely interactive skills.
8. **Verification** - concrete commands or checks that confirm the skill's output is correct. Skip when the skill has no observable output.

```md
---
name: fe-setup
description: Use when scaffolding a new frontend project ...
---

# fe-setup

Default: pin every dependency to its latest stable version at install time.

## Contents

**Setup** - ...
- [Prerequisites](#prerequisites) - tools required before scaffolding.
- [Working directory](#working-directory) - where the project lives.
- [Workflow](#workflow) - step-by-step scaffold.

## Prerequisites

...

## Working directory

...

## Workflow

...

## Verification

...
```

**Rules**:

- **Section names for the fixed slots are canonical** - `Prerequisites`, `Input`, `Output`, `Verification` verbatim. Do not rename to `Requirements`, `Testing`, `Checks`. Main content sections take skill-specific names.
- **Frontmatter `description` is the skill's routing signal.** Write it so the harness picks the right skill from a one-line intent. Start with `Use when …`.
- **`name` matches the folder name** (`fe-setup` → `.claude/skills/fe-setup/SKILL.md`).
- **Optional slots that are absent leave no placeholder.** Do not write `## Prerequisites` followed by `_None._` - omit the section entirely.
- **Voice may vary per skill; layout may not.** A CLI-heavy skill (`fe-setup`) reads terser than a UI-composition one (`fe-boilerplate`). Adjust density and vocabulary to the audience the skill serves, but keep the section order and canonical names fixed. Word-economy rules ([Word economy](#word-economy)) apply everywhere.

## Headings

- **One H1**, at the top, matching the filename intent.
- **H2 for sections**, **H3 sparingly for subsections**. Do not go past H3 in rule docs.
- Heading text is a **noun phrase** (`Naming`, `Error handling`) or an **imperative** (`Delete on sight`). Not a full sentence, not a question.
- Never skip levels (H2 → H4).

## Tables

Prefer a table when the same attribute repeats across items (kind → case, framework → breakpoint scale, widget → keys). Prose lists that repeat the same phrase ("For X, use Y. For X, use Y…") should be tables.

Column headers are one or two words. Cell contents wrap - do not hand-align columns with spaces; Prettier will re-flow them.

## Code fences

- Always tag the language (e.g. `tsx`, `bash`, `md`) - untagged fences break syntax highlighting and copy-paste.
- Show the shortest example that makes the point. Trim imports, boilerplate, unused props.
- For "do this, not that" pairs, use `✅` and `❌` comments inside the fence:

```tsx
// ✅ mobile-first
<div className="flex flex-col gap-4 md:flex-row" />

// ❌ desktop-first
<div className="flex flex-row max-md:flex-col" />
```

- One example per point. If a second example says the same thing in different words, delete it.

## Anti-pattern lists

Every rule doc closes with `## Anti-patterns - reject on sight`. Each bullet is one sentence: **what's wrong** + **why** or **what to do instead**.

```md
- Placeholder-only labels - disappear on input and fail contrast.
- Modals that do not trap focus - keyboard user escapes into background content.
```

Do not restate a rule as its inverse if the rule section already covered it - the anti-pattern list catches things the rule sections did not name.

## Imperative form

Rules are commands, not suggestions.

```md
✅ Prefer named exports. Default exports are allowed only for framework-required cases.
❌ You might want to consider using named exports in most cases.
```

Kill "might", "could", "generally", "usually" unless the exception varies. Kill "In this section we will…" - the heading already said it.

## Word economy

Reduce word count wherever meaning survives. Punctuation and inline code carry the compression:

- **Colon for definitions / labels** - `Prerequisites: Node LTS, pnpm, network access.` beats "The prerequisites for this skill are Node LTS, pnpm, and network access."
- **Comma for parallel lists** - `Runs on macOS, Linux, Windows.` beats three sentences.
- **Backticks for names, paths, commands** - `` `fe-setup` `` beats "the fe-setup skill". `` `source-code/<name>/` `` beats "the folder called source-code with the project name inside it".
- **Quotes for verbatim strings** - `Start with "Use when …".` beats "Start with the phrase Use when followed by an ellipsis."
- **Arrows for mapping / causation** - `frontmatter name → folder name` beats "the frontmatter name attribute should match the folder name". `stale token → 401 → refresh` beats a three-sentence explanation.
- **Slashes for either-or** - `pnpm / npm / yarn` beats "pnpm, npm, or yarn".

Rule of thumb: if a sentence has more than two "and"s, or repeats the same noun phrase, restructure with punctuation before adding more words.

```md
✅ Prerequisites: `node` (LTS), `pnpm`, `source-code/` at repo root.
❌ The prerequisites for this skill are that you have Node.js installed (LTS version or newer), that pnpm is installed globally, and that the source-code directory exists at the root of the repository.
```

Compression stops where clarity breaks. If a reader has to re-read a compressed line to parse it, expand it - punctuation is a tool, not a scoring system.

## Length

- **One idea per bullet.** If a bullet has two "and"s, split it.
- **One screen per section.** If a section runs past ~40 lines (excluding fenced examples), promote a subsection to its own H2 or split the doc.
- **Total doc**: rule files target 200-400 lines. Past 400, split by concern.

## No filler

Cut on sight:

- "Basically", "essentially", "really", "very", "just".
- "It's worth noting that…", "Please note that…", "As mentioned above…".
- Marketing verbs: "empower", "leverage", "unlock", "seamless", "robust".
- Emoji as decoration. `✅ / ❌` and `→` inside code examples are fine; a 🎉 in a heading is not.

## Terminology

Use the codebase's own names for things (`fe-setup`, `source-code/<project-name>`, `CLAUDE.md`). Do not invent synonyms mid-doc. If a term is new, define it once in parentheses on first use, then never again.

## Anti-patterns - reject on sight

- Nested bullet trees more than two levels deep - restructure into subsections or a table.
- Vague filler headings (`Introduction`, `Overview`, `Notes`) - state the concept, not the category.
- Anchor links pointing to sections that do not exist - broken TOCs ship silently.
- Comments inside example code that explain the language itself (`// this is a variable`).
- `> Note:` blockquote callouts stacked between every paragraph - reserve them for genuine hidden constraints.
- "See below" / "See above" cross-references - link the anchor explicitly.
- Manually space-aligned table columns - Prettier will re-flow them into a diff.
- Two consecutive code fences with no prose between them - merge or annotate.
