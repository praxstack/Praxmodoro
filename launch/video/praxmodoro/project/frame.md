---
version: alpha
name: Praxmodoro — Breathing Light (frame layer)
description: >
  Video-first companion to the Praxmodoro landing page (site/DESIGN.md, "A day, in quiet rooms").
  Seeded with `build-frame.mjs --preset blue-professional` (its restraint: one accent, soft tinted
  surfaces, pill chrome, no hard edges), then hand-adapted to the site's own tokens because the
  preset's cream/cobalt/no-shadow prose contradicts the breathing-light identity. The frontmatter is
  normative; the hex values are the site's OKLCH tokens converted to sRGB.
unit: the frame, 1920×1080 at 30 fps
principle: one idea per room · a lot of air · soft light instead of hard edges · motion that breathes

colors:
  # semantic roles kept from the preset so tooling can read them
  bg: "#E4EEF9"            # sky-dawn, the base ground
  primary: "#454A80"       # dusk indigo, the one accent (site --color-accent)
  text: "#242B3D"          # ink, 10:1+ on every sky
  text-muted: "#434A5B"    # ink-2, secondary text, 6.2:1+
  text-light: "#545B6A"    # muted, small print (never under 40px in video)
  accent-ink: "#F4F7FE"    # text on the accent fill
  rule: "rgba(36, 43, 61, 0.14)"
  surface: "rgba(247, 250, 255, 0.66)"   # milk glass
  surface-rim: "rgba(250, 251, 255, 0.85)"
  # the sky, room by room (each moment has its hour)
  sky-dawn: "#E4EEF9"
  sky-haze: "#ECE8FA"
  sky-sand: "#FAEFDC"      # Begin
  sky-sage: "#DEF3E4"      # Focus
  sky-clear: "#DEF0F8"     # Check in
  sky-lilac: "#ECE5FB"     # Break
  sky-rose: "#F9E0E9"      # Review
  sky-mauve: "#EBDDEF"
  sky-twilight: "#DDDDF2"
  sky-bluehour: "#D5DCF2"  # Join
  sky-night: "#1B2035"     # Focus, dark mode beat
  sky-deep-night: "#101526"
  night-ink: "#E0E4F1"
  night-ink-2: "#B3BACF"
  # the breathing light (matched to the app's companion field)
  glow-core: "#FFFAEA"
  glow-sun: "#FFE0AC"
  glow-rose: "#FCD4D6"
  glow-lilac: "#DBD8F6"
  glow-ring: "rgba(55, 58, 87, 0.20)"
  arc-sun: "#F5C984"
  arc-halo: "rgba(249, 218, 161, 0.6)"
  shadow-tint: "rgba(51, 56, 85, 0.12)"
  shadow-deep: "rgba(37, 43, 76, 0.20)"

radii:
  pill: "999px"
  card-lg: "32px"
  card-md: "20px"
  card-sm: "12px"
  window: "33px at 2x source (≈22px on the 1160px window plate)"
  circle: "50%"

typography:
  # Zen Maru Gothic 500 for display, 700 for the wordmark; Atkinson Hyperlegible Next for body.
  # Video floor: nothing load-bearing under 44px (legible at 1/4 size on a phone).
  hero:         { fontFamily: "Zen Maru Gothic", px: 96, weight: 500, lineHeight: 1.08, tracking: "-0.015em", color: "text" }
  moment-title: { fontFamily: "Zen Maru Gothic", px: 104, weight: 500, lineHeight: 1.0, tracking: "-0.015em", color: "text" }
  lede:         { fontFamily: "Zen Maru Gothic", px: 56, weight: 500, lineHeight: 1.18, color: "text-muted" }
  cue:          { fontFamily: "Atkinson Hyperlegible Next", px: 44, weight: 500, lineHeight: 1.3, color: "text-muted" }
  wordmark:     { fontFamily: "Zen Maru Gothic", px: 56, weight: 700, tracking: "0.005em", color: "text" }
  kbd:          { fontFamily: "Atkinson Hyperlegible Next", px: 40, weight: 650, color: "text" }
  url:          { fontFamily: "Atkinson Hyperlegible Next", px: 60, weight: 650, color: "accent-ink" }

spacing:
  pad-x: "100px"
  column: "540px text column at x 100–640"
  window-plate: "1160×708 at x 680, y 136 (centre y ≈ 490)"
  keep-out: "nothing below y 900"

components:
  sky:
    background: "linear-gradient(180deg, {from}, {to}) per moment, exactly as the site's rooms"
    description: "Full-bleed ground on its own clip. Rooms melt into each other through slow crossfades."
  window-plate:
    content: "the real app footage, cropped 6 source px per edge, corners masked (radius 33 source px)"
    rim: "1px {colors.surface-rim} hairline"
    shadow: "0 1px 2px {shadow-tint}, 0 24px 48px -28px {shadow-deep}, 0 60px 100px -70px {shadow-deep} (site --shadow-screen)"
    description: "No fake chrome is added; the real macOS title bar stays because it is real. Motion: gentle settle and a very slow scale only."
  arc:
    shape: "120×74 viewBox: horizon line, dotted half-circle path, five tick dots, sun with halo at the moment's position"
    description: "Moment n of 5. The only numbering in the film, because the five moments are an order."
  moment-heading:
    composes: "arc → moment-title → lede"
    description: "One word per moment (Begin, Focus, Check in, Break, Review), nothing above it."
  cue:
    description: "One short plain sentence under the lede, swapped in place as the footage reaches it. Never more than two lines."
  kbd:
    backgroundColor: "{colors.surface}"
    border: "1.5px solid rgba(36, 43, 61, 0.24)"
    rounded: "{radii.card-sm}"
    description: "Keycaps exactly as the site shows them: ⌘ ↩, ⌘ K, R."
  breathing-light:
    layers: "halo radial (core → sun → rose → lilac → fade), core, three hairline rings that lag the halo"
    motion: "4 s in, 6 s out on sine in-out (cubic-bezier 0.37, 0, 0.63, 1); halo grows about 14%; no spring, no overshoot"
    description: "The signature. Used on the opening and the end card only; the app's own companion carries the breath in the footage."
  url-pill:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.accent-ink}"
    rounded: "{radii.pill}"
    description: "The one solid element, on the end card."
---

# Praxmodoro — Breathing Light (frame layer)

## Where this came from

`build-frame.mjs --preset blue-professional` produced the first version of this file. The preset
was the closest shipped look (one accent, soft tinted surfaces, pill chrome), but its prose asks for
cream, cobalt and zero shadows, which the brand forbids ("cream with a serif and terracotta" and
hard flat cards are both on the site's never list). The frontmatter above was therefore rewritten
from the site's real tokens (`site/public/assets/css/site.css`, `:root`) and `site/DESIGN.md`.

## Personality

A calm friend for a busy mind. The moment the video starts, your breathing should slow down.

1. **A breathing light, not a pitch.** The film opens and closes on the slow light: four seconds in,
   six out.
2. **One moment, one room.** Each of the five moments is its own room, lit by its hour of the day:
   Begin (sand), Focus (sage, then night for dark mode), Check in (clear sky), Break (lilac),
   Review (rose), Join (blue hour).
3. **Soft, honest, unhurried.** Rounded type, mist and sage and lavender, short sentences, and no
   claim the app can't keep.

## The frame

- 1920×1080. Text column on the left (x 100–640), the real app window on the right
  (1160×708, centred near y 490). Everything sits above y 900.
- Type never goes under 44px for anything a viewer must read. At a quarter of the size (a phone in a
  feed) that is still 11px.
- No pure black or white. Shadows are tinted toward the ink hue and very soft.
- Every corner is rounded. The window keeps the real macOS title bar; nothing fake is added.

## Motion

Motion breathes. It never performs.

- Rooms crossfade slowly (1.2 s) so the skies melt into each other, like the site's rooms.
- Text arrives with opacity and a small lift (8–12px) on a long, soft ease-out; a cue swaps in place
  with a short crossfade. Nothing slams, bounces, flips or overshoots.
- The window settles from 98.5% to 100% as its room arrives and then drifts no more than about 1.5%
  across the whole room. That is the only camera move.
- The footage always plays at its real speed. The app's companion breathes at its own pace, so the
  film never speeds the breathing up.
- The breathing light (open and end card) follows the site: 4 s in, 6 s out, sine in-out.

## Never

- Paper textures, drawn lines, handwriting (that is the chess site).
- Cream with terracotta, near-black with one acid accent, purple-to-blue hero gradients, aurora blobs.
- Countdowns, flashing, scores, streaks, red badges, percentages.
- Medical claims, AI claims, pricing, invented features or numbers.
- Italic or gradient headings.
