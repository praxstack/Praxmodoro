---
format: 1920x1080
fps: 30
duration: 55.7s
message: "Praxmodoro helps you start with one tiny step, and keeps you company without ever rushing you."
arc: Breath (open) → Begin → Focus (light, then dark) → Check in → Break → Review → Join the Mac beta
audience: Mac users with ADHD, or anyone tired of tools that shout
mode: autonomous
music: none
captions: none
---

# Praxmodoro demo — storyboard

Silent film. On-screen text carries the story; no SCRIPT.md, no music, no sound effects
(`music: none`, no `sfx:` cues: the project is marked silent). Every frame below is a real
sub-composition in `compositions/frames/`, and every app screen is real footage from
`/mnt/project-files/launch/video/praxmodoro/footage/` (linked, never copied, as `assets/footage/`).

## Video direction

- **Palette system** (from `frame.md`): each moment is a room lit by its hour, painted as a vertical
  sky gradient exactly like the site's rooms. Open: dawn → haze. Begin: sand → sage. Focus: sage →
  clear, then night (`sky-night` → `sky-deep-night`) for the dark-mode beat. Check in: clear → lilac.
  Break: lilac → rose. Review: rose → mauve. Join: twilight → blue hour. Ink for titles, ink-2 for
  ledes and cues, dusk indigo only for the arc stroke details, keycap text and the URL pill.
- **Type**: Zen Maru Gothic 500 for the moment word, lede and hero line; 700 for the wordmark.
  Atkinson Hyperlegible Next for cues, keycaps, facts and the URL. Floor 44px for anything a viewer
  must read.
- **Layout grammar**: asymmetric 35/65 on every moment frame: text column left (arc → moment word →
  lede → cue), the real app window right on its soft sky with the site's tinted screen shadow.
  Centered compositions only for the open and the end card (the breathing light).
- **Motion grammar + reveal model**: long, soft ease-out settles (sine / power2-out family, never
  bouncy); text arrives with opacity and a small lift; cues swap in place, each on the moment the
  footage reaches it (the footage plays the role a voice-over would). The window settles 98.5% →
  100% and then drifts at most ~1.5% across the room: the "gentle scale" the brief allows and
  nothing more. The footage runs at its real speed.
- **Breath**: the breathing light on the open and the end card follows the site exactly: 4 s in,
  6 s out, sine in-out, halo grows ~14%, three hairline rings lag 0.2–0.7 s. It is the brand's
  signature (DESIGN.md exception), not decorative "lazy breathing" on cards or text.
- **Rhythm / held frames**: Open and Join are held breathers (one restrained reveal, then stillness).
  Focus is the slow centre of the film: its only event is the light-to-night dissolve.
- **Transitions**: every room arrives by a slow 1.2 s crossfade (Join 1.4 s); incoming text waits
  until the dissolve has mostly finished, so two rooms' words never overlap.
- **Negative list**: no cursor, no fake chrome, no click ripples, no zoom-throughs, no counters,
  no bouncy or spring entrances, no flashing, no AI, pricing or medical claims, no invented
  features. Neither slideshow (all text dumped at once, then frozen) nor screensaver (everything
  floating).

## Frame 1 — Open: the breathing light

- src: compositions/frames/01-open.html
- duration: 6.0s
- transition_in: cut
- status: animated
- scene: The breathing light on a dawn sky; "Start with one tiny step." rests at its centre; the wordmark and "A calm focus timer for your Mac." settle beneath.
- type: Hook
- blueprint: titlecard-reveal (Adapt)
- focal: breathing light (built in HTML from the site's tokens)
- roles: breathing light = hero · headline = foreground · wordmark + tagline = supporting
- asset_candidates: assets/fonts/zen-maru-gothic-latin-500.woff2, assets/fonts/zen-maru-gothic-latin-700.woff2, assets/fonts/atkinson-hyperlegible-next-latin-wght.woff2
- poster: 3.5s

Adapt: keep the one restrained reveal and the still hold; the "card" is the site's breathing light.
Scene 1 (0.0–1.0s): dawn-to-haze sky; the light fades up from nothing at the centre of the upper
two-thirds and begins its inhale (`ambient-glow-bloom`). Centered, light ~60% of frame height.
Scene 2 (0.6–2.0s): "Start with one tiny step." arrives inside the light with a soft lift (one
restrained reveal, `gsap-effects` fade + lift); the words never move after that.
Scene 3 (2.0–3.6s): beneath the light, the wordmark (small light dot + "Praxmodoro") and then the
line "A calm focus timer for your Mac." rise in, one after the other.
Scene 4 (3.6–5.3s): held breather; the light finishes its 4 s inhale and begins the exhale.
Scene 5 (5.3–6.0s): the words step back (opacity only) so they never sit over the incoming window;
the light alone melts into the Begin room.

## Frame 2 — Begin

- src: compositions/frames/02-begin.html
- duration: 10.2s
- transition_in: crossfade 1.2s
- status: animated
- scene: Sand room. Moment 1 of 5: "Begin / One task, one tiny step." beside the real start screen as the task and first step are typed, Foggy and Classic 25+5 are picked and ⌘↩ begins.
- type: Product_Intro
- blueprint: device-surface-showcase (Adapt: static-tour)
- focal: assets/footage/01-begin.mov (media 1.3 s → 11.5 s, +1.2 s dissolve tail; pointer gone from 1.23 s)
- roles: 01-begin.mov = cutout (window plate) · moment heading = foreground copy · sky = background
- asset_candidates: assets/footage/01-begin.mov

Adapt (static-tour): keep the held surface whose real screens advance and the side headline that
swaps per beat; the screens are real footage, so there is no reconstructed UI, no cursor and no tap
compression.
Scene 1 (0.0–1.2s): the room crossfades in; the window settles 98.5% → 100% on the right (asymmetric
35/65); the footage is already typing the task.
Scene 2 (0.9–2.3s): left column: the arc with the sun at the left horizon, then "Begin", then the
lede "One task, one tiny step." rise in one after the other.
Scene 3 (1.9s): cue "Name the task and the smallest visible move." (while the step is typed).
Scene 4 (5.4s): cue swaps in place to "Say how you're arriving, then pick a rhythm." (Foggy at
~5.7 s, Classic 25+5 at ~7.5 s).
Scene 5 (8.1–10.2s): keycaps ⌘ ↩ + "begins" settle under the cue; the footage presses Begin
(~8.7 s) and the focus screen appears at 25:00; hold.

## Frame 3 — Focus

- src: compositions/frames/03-focus.html
- duration: 10.6s
- transition_in: crossfade 1.2s
- status: animated
- scene: Sage room. Moment 2 of 5: "Focus / A light that breathes slower than you." beside the real focus screen; midway the same moment dissolves into dark mode and the room turns to night.
- type: Key_Feature
- blueprint: device-surface-showcase (Adapt: static-tour)
- focal: assets/footage/02-focus.mov (media 0 → 7.2 s), then assets/footage/02-focus-dark.mov (media 5.6 → 11.8 s, including the dissolve tail)
- roles: 02-focus.mov = cutout · 02-focus-dark.mov = cutout (same plate, dissolved in) · sky = background
- asset_candidates: assets/footage/02-focus.mov, assets/footage/02-focus-dark.mov

Adapt: the surface advance is a theme change, not a screen change. Both clips show the same timer
values at the same media time, so the dissolve keeps the clock continuous.
Scene 1 (0.0–1.2s): crossfade in; window settle.
Scene 2 (0.9–2.3s): arc (sun at the second tick), "Focus", lede "A light that breathes slower than
you."
Scene 3 (1.9s): cue "One long breath, about every twelve seconds."
Scene 4 (4.6s): cue swaps to "It never speeds up."
Scene 5 (5.8–7.0s): the dark-mode clip dissolves over the light one at the same media time; the sky
crossfades to night and the type turns to night ink.
Scene 6 (7.4s): cue swaps to "The same light, in dark mode."; hold to the end.

## Frame 4 — Check in

- src: compositions/frames/04-checkin.html
- duration: 7.8s
- transition_in: crossfade 1.2s
- status: animated
- scene: Clear-sky room. Moment 3 of 5: "Check in / A question, not a report card." beside the real ⌘K check-in with its four answers.
- type: Key_Feature
- blueprint: device-surface-showcase (Adapt: static-tour)
- focal: assets/footage/03-checkin.mov (media 0.9 → 8.7 s, +1.2 s dissolve tail)
- roles: 03-checkin.mov = cutout · sky = background
- asset_candidates: assets/footage/03-checkin.mov

Scene 1 (0.0–1.2s): crossfade in from night to clear sky; window settle; footage shows focus.
Scene 2 (0.9–2.3s): arc (sun at the top), "Check in", lede "A question, not a report card."
Scene 3 (1.6s): keycaps ⌘ K on their own row, then "asks how the step fits." (the check-in opens at
~1.3 s).
Scene 4 (4.0s): cue swaps to "Four answers. / None of them is a failure."; "Still fits" is chosen
and the check-in folds away ("Kept as is") at ~6.0 s; hold.

## Frame 5 — Break

- src: compositions/frames/05-break.html
- duration: 8.0s
- transition_in: crossfade 1.2s
- status: animated
- scene: Lilac room. Moment 4 of 5: "Break / Rest that keeps your place." beside the real break surface and re-entry card, then "Welcome back." with the same step.
- type: Key_Feature
- blueprint: device-surface-showcase (Adapt: static-tour)
- focal: assets/footage/04-break.mov (media 6.4 → 14.4 s, +1.2 s dissolve tail)
- roles: 04-break.mov = cutout · sky = background
- asset_candidates: assets/footage/04-break.mov

Scene 1 (0.0–1.2s): crossfade in; window settle; break surface with the re-entry card.
Scene 2 (0.9–2.3s): arc (sun at the fourth tick), "Break", lede "Rest that keeps your place."
Scene 3 (1.9s): cue "Your next step waits on a re-entry card."
Scene 4 (5.6s): cue swaps to keycap R (own row) + "returns you to that step."; "Welcome back."
appears at ~6.3 s showing the same step; hold.

## Frame 6 — Review

- src: compositions/frames/06-review.html
- duration: 6.6s
- transition_in: crossfade 1.2s
- status: animated
- scene: Rose room. Moment 5 of 5: "Review / Today, written down gently." beside the real review timeline and its "Observed, not concluded" note.
- type: Benefits
- blueprint: device-surface-showcase (Adapt: static-tour)
- focal: assets/footage/05-review.mov (media 1.85 → 8.45 s, +1.4 s dissolve tail to 9.85 s)
- roles: 05-review.mov = cutout · sky = background
- asset_candidates: assets/footage/05-review.mov

Scene 1 (0.0–1.2s): crossfade in; window settle; the review appears at ~0.4 s.
Scene 2 (0.9–2.3s): arc (sun at the right horizon), "Review", lede "Today, written down gently."
Scene 3 (1.9s): cue "A plain timeline. / No streaks, no scores."
Scene 4 (4.3s): cue swaps to "One session is not a pattern."; hold.

## Frame 7 — Join the Mac beta

- src: compositions/frames/07-join.html
- duration: 6.5s
- transition_in: crossfade 1.4s
- status: animated
- scene: Blue-hour room. A smaller breathing light, "Join the Mac beta", the URL pill "praxmodoro.com" and the facts "Free while testing · macOS 26 or later" / "Your data stays on your Mac". End-card text lives in one place: the variables at the top of compositions/frames/07-join.html.
- type: CTA
- blueprint: titlecard-reveal (Adapt)
- focal: end-card copy
- roles: breathing light = supporting · CTA line = hero · URL pill = foreground · facts = supporting
- asset_candidates: assets/fonts/zen-maru-gothic-latin-500.woff2, assets/fonts/atkinson-hyperlegible-next-latin-wght.woff2

Scene 1 (0.0–1.4s): crossfade in; small breathing light above centre fades up and begins an inhale.
Scene 2 (1.2–2.4s): "Join the Mac beta" rises in, centered.
Scene 3 (2.3–3.4s): the URL pill settles beneath.
Scene 4 (3.1–4.4s): the two fact lines rise in; then the final frame holds still to the end (final
frame: no exit, the last image is the call to action).
