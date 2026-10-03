# Motion

Shared rule referenced by `fe-motion`, `fe-boilerplate`, `fe-page`, `fe-component`.

Scope: when to animate, which properties, duration budget, reduced-motion handling. Deviations: state a reason inline.

## Contents

**Principles** - what animation earns.
- [What motion is for](#what-motion-is-for) - affordance + continuity, not decoration.
- [Where to use it](#where-to-use-it) - landing / marketing yes; data-dense admin no.

**Technique** - mechanics that stay safe.
- [Properties](#properties) - opacity / translate / scale only.
- [Duration budget](#duration-budget) - entrance ≤400ms, micro ≤150ms.
- [Easing](#easing) - one curve per project, hoisted to presets.
- [Viewport reveal](#viewport-reveal) - `once: true`, generous margin.
- [Reduced motion](#reduced-motion) - always short-circuit.

**Anti-patterns**
- [Anti-patterns - reject on sight](#anti-patterns---reject-on-sight)

## What motion is for

Motion earns its spot when it does one of two jobs:

- **Affordance** - signals a thing is interactive (hover lift, press scale, focus glow) or that a thing just happened (toast slide-in, snackbar).
- **Continuity** - softens a hard discontinuity (section reveal on scroll, modal open, newly inserted list item).

Everything else is decoration. Decoration is distraction - cut it.

## Where to use it

- **Public / marketing (landing page, hero, feature grid, pricing, CTA):** yes. Entrance + hover polish is expected.
- **Admin / data-dense (tables, lists, dashboards):** no entrance animation, no scroll reveal. Users return many times a day - re-animating familiar content is motion-sickness bait and slows every interaction by one frame.
- **Forms, settings:** micro-interactions only (focus ring, submit button press, inline error shake). No section-level motion.

## Properties

**Jank-safe set** - these do not trigger layout or paint:

- `opacity`
- `transform: translate(x, y)` - entrance offsets ≤ 16px.
- `transform: scale()` - press ≥ 0.96, hover ≤ 1.04.

Never animate `color`, `background-color`, `box-shadow`, `width`, `height`, `top` / `left`, `border-radius`. These paint or re-layout mid-frame and jank on mid-tier devices.

## Duration budget

| Interaction                    | Duration     |
| ------------------------------ | ------------ |
| Entrance / section reveal      | 300–400 ms   |
| Hover lift                     | 150 ms       |
| Press / tap                    | 100–150 ms   |
| Toast / snackbar slide-in      | 200–250 ms   |

Longer than 400 ms feels sluggish; shorter than 100 ms is invisible.

## Easing

Pick **one** easing curve per project and reuse it. Default: `cubic-bezier(0.22, 1, 0.36, 1)` ("easeOutQuint") - fast start, gentle land. Define once in `src/lib/motion-presets.ts`; new motion imports from there - no inline curves in page code.

## Viewport reveal

Scroll-triggered entrance (`whileInView`) must set `viewport={{ once: true, margin: '-10%' }}`:

- `once: true` - re-animating on every scroll past is motion-sickness bait and makes the page feel laggy.
- `margin: '-10%'` - starts the animation before the element is fully in view, so by the time the user looks at it, it's settled.

## Reduced motion

Every animation in the codebase must short-circuit under `prefers-reduced-motion: reduce`:

- Entrance transforms → render at final position with 0 duration.
- Hover / press → no-op (CSS `:focus-visible` still shows affordance).
- Stagger → 0 delay.

Centralize in `src/lib/motion-presets.ts` - a single `prefersReducedMotion` check derives all preset shapes. Do not re-check in page code.

## Anti-patterns - reject on sight

- Entrance animations on admin tables / lists - every pagination step should not fade in.
- Animating `color`, `background`, `box-shadow`, or layout properties - paint / layout jank.
- Scroll-triggered reveal without `once: true` - repeated motion as the user scrolls back and forth.
- Different easing curves on different sections - breaks visual coherence; hoist to presets.
- Hover-only motion that reveals required info - invisible on touch (see `fe-a11y.md` → *Touch and pointer*).
- Nested `motion.*` wrappers animating the same element - compositing overhead, no visible gain.
- Inline curves (`transition={{ duration: 0.35, ease: [0.1, 0.9, 0.2, 1] }}`) scattered across components - drift the brand feel; use the presets file.
- Autoplay video or looping ambient animation above the fold - WCAG 2.2.2 fail if there's no pause control.
