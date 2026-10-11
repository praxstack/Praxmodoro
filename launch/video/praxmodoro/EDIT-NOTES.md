# Praxmodoro demo: edit notes

- **Output:** `praxmodoro-demo.mp4`: 55.7 s, 1920×1080, 30 fps constant (1,671 frames), H.264 High,
  yuv420p, 17.6 MB (17,647,166 bytes), no audio track
- **Poster:** `praxmodoro-demo-poster.png` (1280×720, the Focus room at 19.5 s)
- **Contact sheet:** `praxmodoro-demo-contact.png` (one frame every 2 s from 0 to 54 s: 28 tiles,
  each a quarter of full size, labeled with its time)
- **Source:** `project/` (HyperFrames 0.8.141; see `project/README.md` to re-render)
- **Footage:** `footage/` is read only. It is linked into the project, never copied.

The film is silent. It has no voice, music or sound effects, so the on-screen text carries the
story.

## Timeline

Times are in seconds on the final film. Rooms change by slow crossfades: 1.2 s, or 1.4 s into
the end card. During a crossfade the outgoing room keeps playing its own footage, never a frozen
frame. Each cue stays up until the next one swaps in at the same place, with a 0.45 s fade-out
followed by a 0.9 s fade-in and a lift of a few pixels.

| Time | Room | Footage (source in → out) | On screen |
|---|---|---|---|
| 0.0 – 6.0 | **Open** (dawn sky, breathing light) | none | 0.6 "Start with one tiny step." (inside the light) · 2.0 wordmark "Praxmodoro" · 2.5 "A calm focus timer for your Mac." · the words fade out 5.3–6.0, then the light dissolves into Begin |
| 6.0 – 16.2 | **Begin** (sand → sage) | `01-begin.mov` 1.30 → 11.50 s (12.70 s with the dissolve) | 7.05 "Begin" · 7.25 "One task, one tiny step." · 7.9 "Name the task and the smallest visible move." · 11.4 "Say how you're arriving, then pick a rhythm." · 14.1 keycaps ⌘ ↩ "begins" |
| 16.2 – 26.8 | **Focus** (sage → clear, then night) | `02-focus.mov` 0 → 7.2 s, then `02-focus-dark.mov` 5.6 → 11.8 s (it dissolves in at the same media time, 22.0–23.2) | 17.25 "Focus" · 17.45 "A light that breathes slower than you." · 18.1 "One long breath, about every twelve seconds." · 20.8 "It never speeds up." · 23.6 "The same light, in dark mode." |
| 26.8 – 34.6 | **Check in** (clear → lilac) | `03-checkin.mov` 0.90 → 8.70 s (9.90 s) | 27.85 "Check in" · 28.05 "A question, not a report card." · 28.4 keycaps ⌘ K + "asks how the step fits." · 30.8 "Four answers. / None of them is a failure." |
| 34.6 – 42.6 | **Break** (lilac → rose) | `04-break.mov` 6.40 → 14.40 s (15.60 s) | 35.65 "Break" · 35.85 "Rest that keeps your place." · 36.5 "Your next step waits on a re-entry card." · 40.2 keycap R + "returns you to that step." |
| 42.6 – 49.2 | **Review** (rose → mauve) | `05-review.mov` 1.85 → 8.45 s (9.85 s) | 43.65 "Review" · 43.85 "Today, written down gently." · 44.5 "A plain timeline. / No streaks, no scores." · 46.9 "One session is not a pattern." |
| 49.2 – 55.7 | **Join** (twilight → blue hour, small breathing light) | none | 50.4 "Join the Mac beta" · 51.5 URL pill "praxmodoro.com" · 52.3 "Free while testing · macOS 26 or later" · 52.6 "Your data stays on your Mac" · holds still to the last frame |

In each moment room, a small arc sits above the moment word. Its sun moves one step along the
arc per room (the site's "moment n of 5" arc). The app window settles from 98.5% to 100% and
then drifts to 101.2% over the room. Apart from the crossfades, that is the only motion. All
footage plays at its real speed (1.0×). Nothing is sped up or slowed down.

## Every line of on-screen text I wrote

1. Start with one tiny step.
2. Praxmodoro
3. A calm focus timer for your Mac.
4. Begin
5. One task, one tiny step.
6. Name the task and the smallest visible move.
7. Say how you're arriving, then pick a rhythm.
8. [⌘] [↩] begins
9. Focus
10. A light that breathes slower than you.
11. One long breath, about every twelve seconds.
12. It never speeds up.
13. The same light, in dark mode.
14. Check in
15. A question, not a report card.
16. [⌘] [K] asks how the step fits.
17. Four answers. None of them is a failure.
18. Break
19. Rest that keeps your place.
20. Your next step waits on a re-entry card.
21. [R] returns you to that step.
22. Review
23. Today, written down gently.
24. A plain timeline. No streaks, no scores.
25. One session is not a pattern.
26. Join the Mac beta
27. praxmodoro.com
28. Free while testing · macOS 26 or later
29. Your data stays on your Mac

Sources: lines 1, 5, 10, 15, 19 and 23 and the end-card facts are the site's own copy
(`site/public/index.html`). Lines 19 and 23 are also the app's own headings, which show in the
window next to them, just as they do on the site. Lines 11 and 12 come from the brief. Lines 8,
16 and 21 match the shortcuts in `clips.md` (⌘↩ Begin, ⌘K check-in, R ends the break). Line 25
paraphrases the app's own review note ("One session is not a pattern"). There is no pricing, no
AI claim, no medical claim and no number other than "about every twelve seconds" and "macOS 26".

The app's own interface text also shows inside the footage. Examples are "One small step, held
with you.", the task "Draft the grant budget", the step "Open last year's budget and copy the
table.", the four check-in answers, "Welcome back." and the review timeline. That text is
untouched.

## End card

All end-card text is in one place: the `data-composition-variables` defaults at the top of
`project/compositions/frames/07-join.html` (`cta`, `url`, `factsOne`, `factsTwo`). The URL is
written as `praxmodoro.com`, the planned domain, which has not been bought yet. Change it there,
or pass `--variables '{"url":"…"}'` at render time.

## Decisions

- **Brand frame.** Each moment is a "room" with the site's sky gradient for that hour. The real
  app window sits on the right (1160 px wide) with the site's soft tinted screen shadow. The
  text column is on the left. The open and the end card use the site's breathing light: 4 s
  in, 6 s out, sine in-out.
- **Footage treatment.** 6 source px are cropped from every edge, and the corners are masked
  at 22 px on screen (33 source px), so no wallpaper corner or sparkle shows. The macOS title
  bar stays because it is real. Begin starts at source 1.30 s, after the pointer has left
  (last seen at about 1.20 s).
- **Trims.** Begin ends on the new focus screen at 25:00, since pressing Begin starts the timer.
  Check in starts just before ⌘K. Break starts on the break surface, with the re-entry card
  already up. Review starts as the review appears.
- **Dark mode.** The dark clip dissolves over the light clip at the same media time, so the
  countdown stays continuous (about 24:44 at the switch). The room's sky and type turn to night
  at the same moment.
- **Opening.** The opening words fade out just before the first crossfade, so they never sit on
  top of the incoming app window.
- **Assembly.** The workflow's `assemble-index.mjs` refuses media inside frames, and the hoisted
  videos it produces can't be cropped, masked or scaled. So `index.html` was written by hand in
  the same shape. The workflow's `transitions.mjs inject` then stamped the crossfades, and
  `verify` passed.

## Checks run

- `hyperframes lint`: 0 errors and 1 warning. The warning is `nested_media_start_basis_ambiguous`
  on the dark Focus clip. Its `data-start="5.6"` is local to its room, which is intended.
- `hyperframes check`: passed, with 0 runtime errors, 0 layout issues and 0 motion issues. All
  static text passes WCAG AA contrast. Three contrast warnings appear only at 27.85 s, in the
  last frames of the Focus → Check in crossfade. There the fading night-mode type (about 3%
  opacity) is measured against the incoming light sky. This is transient and not readable text.
- `transitions.mjs verify`: 6 crossfades verified.
- `hyperframes render --quality high --fps 30 --video-frame-format png` finished in 2 min 16 s,
  and HyperFrames validated the file. `ffprobe` gave the numbers at the top of this file.
- I looked at the contact sheet and at full-size stills of every cue. No wallpaper corners, no
  pointer, no clipped or overlapping text. Line breaks are balanced, with no orphan words.
  Everything I wrote is 44 px or larger, so about 11 px at quarter size.

## Not verified

- **"About every twelve seconds."** I did not measure the companion's breathing period from the
  footage. Each clip is 10–12 s long, too short to time a full cycle reliably. The line comes from
  the brief and the site. The footage plays at 1.0×, so the film shows whatever the app does.
- **Clock values in `clips.md`.** It says `02-focus.mov` runs "~24:55 → 24:43". In the footage,
  the clock reads about 24:51 at the start and 24:40 at the end. This is cosmetic.
- **Review timestamps.** Every row in the review timeline reads "3:00 PM". That is the real state
  of the short recorded session, not an edit.
- **Real-time playback.** No person watched the film in real time, and HyperFrames Studio preview
  was not opened (autonomous run, no viewer). I checked stills, the contact sheet and the
  ffprobe numbers. I did not check how smooth the footage looks in motion. The source clips are
  variable-frame-rate screen captures, and the renderer resamples them to 30 fps.
- **Colors.** The site's OKLCH tokens were converted to sRGB hex by hand. They are close to the
  site but not checked side by side in a browser.
- **Brand capture.** The automated site capture ran out of its time budget and lost its fonts.
  The fonts were copied straight from the site's `public/assets/fonts` instead. The capture
  folder is not part of the delivered project.
- **HeyGen auth.** `npx hyperframes auth status` reports "Not signed in to HeyGen" (exit 1), as
  expected. Nothing was signed in, installed or published.
