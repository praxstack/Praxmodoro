# Praxmodoro website: design direction

**Working name: "A day, in quiet rooms."** This is the locked direction for the landing page, the legal pages and the 404. Read it before you change anything in `public/assets/css/site.css`, `src/pages/` or the share image.

## Personality

Praxmodoro's site should feel like a calm friend for a busy mind. The moment it loads, your breathing should slow down.

The visitor might have ADHD, or might just be tired of tools that shout. The page lowers the stimulation:

- one idea per room;
- a lot of air;
- soft light instead of hard edges;
- motion that breathes instead of motion that performs.

The tone is warm and kind. It is never clinical, never "productivity", and nothing on it ever keeps score.

In three lines:

1. **A breathing light, not a pitch.** The first thing you meet is a slow light you can breathe along with: four seconds in, six out.
2. **One day, one room at a time.** The page reads as a single day, from first light to night. Each moment of a session gets its own quiet room, lit by its hour.
3. **Soft, honest, unhurried.** Rounded type, mist and sage and lavender, short sentences, and no claims the app can't keep.

## What it must never look like

- **The old page.** That page had a big headline on the left, a card on the right, then stacked sections, in cream and terracotta. It read as a template. None of that structure survives here.
- **The chess site.** AskTheMove is being redesigned as a hand-drawn chess teacher's notebook, with paper, ink lines and hand lettering. This site has no paper texture, no drawn lines, no handwriting and no ink-on-paper feel. It is light and air, not paper.
- **The AI defaults:**
  - cream with a serif and terracotta;
  - near-black with one acid accent;
  - a broadsheet grid;
  - a purple-to-blue gradient hero;
  - aurora blobs.

## References (what each one taught)

| Reference | What we took | What we left |
|---|---|---|
| **James Turrell's Skyspaces and Ganzfeld rooms** | A room *is* its light. Colour changes slowly and has no hard edge. Each of our rooms is one colour of sky, and the rooms melt into each other. | The darkness and spectacle. |
| **Agnes Martin's late paintings** (pale bands of pink, blue and yellow) | Quiet, low-chroma colour carries feeling without decoration. Our skies stay at chroma 0.02 to 0.035. | The grid lines, which would read as ruled paper. |
| **Headspace breathing exercise** (as documented in design teardowns) | An exhale longer than the inhale. Slow sine easing. Rounded forms only. Tinted shadows, never grey. No pure black or white. | Characters and illustration. |
| **Tiimo** (tiimoapp.com, ADHD visual planner) | Copy for executive-function struggles can be warm and plain without being clinical ("No clutter, no pressure"). | The App Store marketing structure: awards strip, reviews, feature grid. |
| **Endel** (endel.io) | Each mode gets a single word (Relax, Focus, Sleep). Our five moments are single words too, and each one is its own heading. | Statistics as proof, and the dark-only look. |
| **Daylight Computer** (daylightcomputer.com) | Calm technology can be sold through what it refuses to do. Our "Nothing here scores you" room works the same way. | The warm cream base (an AI default) and the manifesto volume. |
| **Frequency Breathwork** (frequencybreathwork.com) | Concentric circles make a good breath mark, and muted greens read as calm. | It is also the cautionary example: "clinically-proven" and symptom claims. We make none. |
| **Session** (stayinsession.com), the benchmark Mac focus timer | Name the platform and requirements plainly and early. | The productivity framing ("Start your momentum"), app blocking and a Pro tier. Praxmodoro is about starting, not output. |
| **BOIA guidance on ADHD-friendly pages** | Short paragraphs with one idea each; no autoplaying motion without a pause control; no sticky elements covering content; real headings and lists. | — |

The five product references come from the shared research note (`/mnt/project-files/launch/design-research.md`, 8 October 2026). Gallery pages (Lapa Ninja, SiteInspire) did not render to the fetch tool, so the rest came from art and design teardowns.

**Skills that shaped this:**

- **Hallmark** (redesign, custom bespoke route, slop gates).
- **Anthropic frontend-design** (one signature, restraint).
- **UI/UX Pro Max.** Its palette and font output was used as input only: its lavender and green steered the hues, and its Lora with Raleway and its neumorphism were rejected. Its UX rules on reduced motion, excessive motion and focus also applied.
- **Taste Skill** ("soft" and "redesign" variants). Kept: macro whitespace, tinted shadows, balanced headings. Rejected: scroll reveals and spring physics.
- **Impeccable** (craft floor and "quieter"). Followed: no eyebrows above headings, no grey text on colour, and the browser surfaces themed.
- **Emil Kowalski's animate, review-animations and apple-design.** Applied: UI state changes under 300 ms, a strong ease-out curve, hover gated to fine pointers, reduced transparency and increased contrast honoured.

## The structure

The page is one column of rooms. A room is a band of sky, at least as tall as its content plus a generous breath of space. Every room says one thing. The text column is left-aligned inside a centred measure. Only the hero is centred.

```
 ┌──────────────────────────────────────────┐  first light (mist)
 │ Praxmodoro                Motion  Join    │  header, not sticky
 │                                          │
 │              .  ·  ◯  ·  .               │
 │           (  Start with one   )          │  the breathing light,
 │           (    tiny step.     )          │  with the headline at its centre
 │              breathe in                  │  cue swaps in and out with the breath
 │                                          │
 │      A calm focus timer for your Mac…    │
 │      [ you@example.com      Join ]       │
 │      ☐ Email me about the beta…          │
 ├──────────────────────────────────────────┤  haze → sand
 │  Starting is the hard part.              │  room: why
 │  09:00  Finish the grant budget          │  the reminder echoes, fading
 │  11:30  Finish the grant budget          │
 │  14:00  Finish the grant budget          │
 │  ( 1  Open last year's budget… )         │  the tiny step, a smooth stone
 ├──────────────────────────────────────────┤
 │  One calm loop.                          │
 │  ◜•◝                                     │  sun on its arc = where you are ("Moment 1 of 5")
 │  Begin                                   │  one word, nothing above it
 │  One task, one tiny step.                │
 │  [ try it here ]                         │
 │  [ app screen ]                          │  swap-ready image slot
 ├──────────────────────────────────────────┤  sand → sage
 │  ◜ •◝  Focus   …                         │
 ├────  Check in (clear sky) ───────────────┤
 ├────  Break (lilac afternoon) ────────────┤
 ├────  Review (dusk rose) ─────────────────┤
 ├────  Nothing here scores you. (evening) ─┤
 ├────  It stays on your Mac. (twilight) ───┤
 ├────  Questions (blue hour) ──────────────┤
 ├────  Begin when you're ready. + form ────┤
 └────  night: footer statement ────────────┘
```

**Signature:** the breathing light. It is the app's companion field, simplified. Like the app's Focus screen, the most important words sit in its centre: there, the time; here, "Start with one tiny step." The light breathes. The words never move.

**Secondary motifs.** They stay quiet and are used only where they encode something true:

- **The sun on an arc.** Each moment room has a small arc with the light at its position: 1 of 5 at the left horizon, 5 of 5 at the right. It shows where you are in the sequence. It is the only numbering on the page, because the five moments really are an order.
- **The smooth stone.** A tiny step is drawn as a pebble: an uneven rounded shape with a number in it. It appears only where a step is shown: the "hard part" example and the try-it result.

## Tokens

All colours are OKLCH and are defined once in `:root` in `site.css`. Dark mode redefines the same names, so components never branch on theme. There is no pure black or white anywhere.

### Light: a day

| Token | Value | Role |
|---|---|---|
| `--sky-dawn` | `oklch(94.5% 0.018 250)` | mist, hero top |
| `--sky-haze` | `oklch(94% 0.024 295)` | lilac haze, hero to "why" |
| `--sky-sand` | `oklch(95.5% 0.028 82)` | first sun: Begin |
| `--sky-sage` | `oklch(94.5% 0.03 155)` | morning: Focus |
| `--sky-clear` | `oklch(94.5% 0.022 225)` | midday: Check in |
| `--sky-lilac` | `oklch(93.5% 0.03 300)` | afternoon: Break |
| `--sky-rose` | `oklch(93% 0.03 355)` | dusk: Review |
| `--sky-mauve` | `oklch(91.5% 0.028 318)` | evening: calm |
| `--sky-twilight` | `oklch(90.5% 0.028 285)` | twilight: private |
| `--sky-bluehour` | `oklch(89.5% 0.032 272)` | blue hour: questions and join |
| `--sky-night` | `oklch(25% 0.04 272)` | night: footer (both themes) |
| `--color-ink` | `oklch(29% 0.035 268)` | text, 10:1 or more on every sky |
| `--color-ink-2` | `oklch(41% 0.03 268)` | secondary text, 6.2:1 or more |
| `--color-muted` | `oklch(47% 0.026 268)` | small print, 4.6:1 or more |
| `--color-accent` | `oklch(43% 0.09 278)` | dusk indigo: the one button fill, links, focus |
| `--color-accent-ink` | `oklch(97.5% 0.01 270)` | text on accent, 7.7:1 |
| `--glow-sun` / `--glow-rose` / `--glow-lilac` / `--glow-core` | sand-gold, pink, lilac, near-white | the breathing light, matched to the app's field |

### Dark: the same day, at night

The skies drop to L 19–22 % and keep a faint version of their hue. They stay in the cool half of the wheel, because warm hues at low lightness turn brown. Ink is `oklch(93% 0.014 265)`. The accent is a moonlit periwinkle, `oklch(80% 0.075 282)`, with dark text on it. The light becomes a moon: dimmer and cooler, with a pale gold core.

### Type

| Role | Face | Why |
|---|---|---|
| Display and headings | **Zen Maru Gothic** 500 (700 for the wordmark and small labels) | A Japanese rounded gothic. Its terminals are soft and slightly brushed, so it is gentle without being childish. It is rare on Western sites, so it doesn't read as a template. |
| Body, forms and small print | **Atkinson Hyperlegible Next** (variable 200–800) | Drawn by the Braille Institute so similar letters stay distinct. It is humane and readable at 18 px. |

Both are SIL OFL 1.1, self-hosted as Latin subsets in `public/assets/fonts/`. They total about 57 KB, and the credits are in `OFL.txt`. Headings are always roman: no italic headers and no gradient text.

**Scale.** It is fluid, with one size per job:

| Token | Size | Use |
|---|---|---|
| `--text-display` | clamp(2.35rem → 4.4rem) | the h1 inside the light |
| `--text-2xl` | clamp(2rem → 3.25rem) | room titles |
| `--text-xl` | clamp(1.5rem → 2rem) | moment headings |
| `--text-md` | 1.25rem | ledes |
| `--text-base` | 1.125rem (18 px) | body, line-height 1.65, measure 34em or less |
| `--text-sm` | 0.9375rem | notes and form help |

Small print never goes under 13 px.

### Space, shape, depth

- **Space.** The scale runs on a 4-point grid: `--space-2xs` (0.25rem) through `--space-4xl` (7rem). Each room pads with `--room-pad: clamp(5rem, 3rem + 7vw, 9.5rem)`.
- **Shape.**
  - Every corner is rounded: `--radius-sm` 0.75rem, `--radius-md` 1.25rem, `--radius-lg` 2rem, pills.
  - App screens use 1.25rem corners and a hairline rim. There is no fake window chrome: no traffic lights, no title bar.
- **Depth.** Shadows are tinted toward the ink hue and very soft. Nothing glows on dark.

## Motion language

Motion breathes. It never performs.

- **The breath.** Four seconds in, six seconds out: a 10-second loop, six breaths a minute. It runs on `--ease-breath: cubic-bezier(0.37, 0, 0.63, 1)` (sine in-out), with no spring and no overshoot.
  - The light's halo grows by about 14 %.
  - Three hairline rings follow it a beat later, like ripples on still water.
  - The words "Breathe in" and "Breathe out" cross-fade in time with it.
- **Where it moves.** Only two places: the hero light, and a smaller, slower light in the join room. Nothing else loops. Nothing fades in on scroll. Nothing counts down. Nothing flashes.
- **State changes.** These are quick and kind, because a sluggish control is its own kind of stress.
  - Colour changes take 200 ms on `--ease-out: cubic-bezier(0.23, 1, 0.32, 1)`.
  - A press settles 1 px over 120 ms.
  - The try-it result arrives with opacity and a 4 px lift over 300 ms.
  - Hover effects are gated to fine pointers.
  - Focus rings appear instantly and are never animated.

  The slowness lives in the breath, not in the controls.
- **Stillness is complete.** Nothing is lost at rest.
  - The page's switch ("Pause the breathing" under the light, "Motion" in the header) pauses the light exactly where it is. It never snaps back to a rest size, so pausing is not itself a jolt. "Let it breathe" carries on from the same point.
  - With Reduce Motion on in the system, the animations are removed rather than paused: the light rests at mid-breath, the switch under the light goes away (it would have nothing to do), and the header switch reads "Motion: still" and explains why it can't change.
  - Either way the cue becomes a static line: "In for four, out for six."

  A loop longer than five seconds needs a pause control nearby (WCAG 2.2.2).

## Interaction and states

- **Waitlist forms.** These are unchanged in behaviour.
  - They post to `/api/waitlist` and work without JavaScript.
  - With JavaScript they send JSON, show inline status and keep focus management.
  - States: default, hover (colour only), focus-visible (2 px ring, 3 px offset), active, disabled, busy ("Joining…"), error (message in words, under the form), and success (the form is replaced by a note).
- **Try it here** (the Begin room). This is a small local demo. You write a task and one step, and the page holds the step on a stone. Nothing is sent. Without JavaScript it stays hidden. It has no timer.

## Image slots

App screens are design renders today. Real footage of the Mac app will replace them, so each slot is one `<figure class="screen" data-screen="…">` with:

- a light `<img>`;
- a dark `<source media="(prefers-color-scheme: dark)">`;
- explicit `width` and `height`.

**To swap in a still**, replace the files named `app-<moment>-<light|dark>-<880|1600>.webp` and update `width` and `height`.

**To swap in footage:**

- Replace the `<picture>` with `<video muted playsinline loop preload="none" poster="…" width height>`.
- Only autoplay it when motion is gentle. Add a pause control.
- `.screen video` is already styled the same as `.screen img`.

## Copy rules

- No medical or therapy claims. "ADHD-aware" and "designed with ADHD in mind" are fine; "treats", "helps your ADHD" and "clinically" are not.
- State the facts plainly: macOS 26 or later, beta, free while testing, data stays on the Mac.
- AI is only ever "planned, opt-in" and off by default.
- Short paragraphs, one idea each. Sentence case. Use plain verbs on buttons ("Join the beta", "Hold this step").

## Hallmark record

- **Route:** custom, at bespoke depth: palette, type and structure designed for this brief.
- **Structure:** a single-column day of rooms, with a centred breathing hero and a centred reading column (text left-aligned inside it).
- **Nav:** edge-aligned and minimal, not sticky.
- **Footer:** a statement at night.
- **Axes:** light paper, rounded sans display, cool accent (indigo 278°).
- **Previous Hallmark work in this repo:** the app mocks used "Control Room", "Workbench" and "Companion stage". This page shares none of their structure.
- **Pre-emit critique:** P5 H4 E4 S5 R4 V5. Hierarchy and restraint lose a point each because the page is long (ten rooms). Each room says one thing, but a visitor who only wants the form still scrolls past five moments. The header's Join button and the hero form are there for them.
- **Slop gates (58), two audit passes on the rendered page:**
  - *Pass 1 found and fixed:* spacing values off the scale (gate 24); inputs with a 1.5 px border, no outline reserved at rest, no hover or disabled state, and a status line that collapsed when empty (39); flex rows without `align-items` (36); no pressed state on the quiet controls (26); the hero's form below the fold at 1280×800 (44); the hero headline breaking onto three lines on 13-inch screens; low-contrast text on the disabled motion switch (40).
  - *Pass 2:* clean. No sideways scroll at 320–1920 px. No two-line buttons or links. Every heading roman, with `overflow-wrap: anywhere`. Text contrast was measured against the painted background (gradients and the light included) at 1440 and 390 px, in light and dark, on the home, privacy, terms and 404 pages: 0 failures.
  - *Exceptions the brief asks for:* the centred hero (gate 6) and the animated bloom (29). Both are the breathing companion itself, the one thing this page is about, in the atmospheric genre where the canvas is the design.
- **Review-animations (Emil Kowalski) on the breathing light:** justified (it is the content, not decoration); transform and opacity only; sine in-out with no spring; asymmetric 4 s in, 6 s out; rings lag 0.2–0.7 s like a real ripple; nothing on the page reacts to scroll. One finding, fixed: pausing used to snap the light to its rest size. It now holds where it is.
