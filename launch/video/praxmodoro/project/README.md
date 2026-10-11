# Praxmodoro demo video: HyperFrames source

The source for `../praxmodoro-demo.mp4`: a 55.7 s silent product demo (1920×1080, 30 fps,
H.264). It has seven rooms: an opening breathing light, the five moments of a session (Begin,
Focus, Check in, Break, Review), each shown in real footage of the beta app, and an end card.
It was built with HyperFrames 0.8.141 and its `product-launch-video` workflow.

This folder holds no footage and no renders.

## Where the footage lives

The app recordings stay in one read-only place:

    /mnt/project-files/launch/video/praxmodoro/footage/
      01-begin.mov  02-focus.mov  02-focus-dark.mov  03-checkin.mov  04-break.mov  05-review.mov
      clips.md      (how they were recorded)

The compositions load them as `assets/footage/<name>.mov`. Before rendering, link that path to
the footage folder (a symlink, not a copy):

    cd /path/to/this/project
    ln -s /mnt/project-files/launch/video/praxmodoro/footage assets/footage

## Re-render

You need Node 22 or later (for `npx`), ffmpeg, and a Chrome or Chromium that HyperFrames can
drive. `npx --yes hyperframes@0.8.141 doctor` reports what is missing. If it can't find a
browser, point it at one you already have instead of downloading another:

    export HYPERFRAMES_BROWSER_PATH=/path/to/chrome-or-headless_shell

Then, from this folder:

    npx --yes hyperframes@0.8.141 check     # lint, runtime, layout, motion and contrast
    npx --yes hyperframes@0.8.141 render --quality high --fps 30 --video-frame-format png \
      --output renders/praxmodoro-demo.mp4

`npm run check` and `npm run render` run the same commands. A render takes several minutes:
1,671 frames, with two workers on a 4-core machine. `--video-frame-format png` keeps the
screen recordings sharp.

Poster (1280×720, taken from the Focus room) and contact sheet (one frame every 2 s):

    ffmpeg -ss 19.5 -i renders/praxmodoro-demo.mp4 -frames:v 1 -vf scale=1280:720 poster.png
    ffmpeg -i renders/praxmodoro-demo.mp4 -vf "fps=1/2,scale=480:-1,tile=4x7:padding=8:margin=8:color=0x1b2035" -frames:v 1 contact.png

Do not run `hyperframes publish`. This project is not meant to be published.

## Change the end card

All of the end-card text is in one place: the `data-composition-variables` defaults at the top
of `compositions/frames/07-join.html`.

| id | default |
|---|---|
| `cta` | Join the Mac beta |
| `url` | praxmodoro.com (the planned domain, not bought yet) |
| `factsOne` | Free while testing · macOS 26 or later |
| `factsTwo` | Your data stays on your Mac |

Edit a default and re-render. To change it for one render only, override it without editing:

    npx --yes hyperframes@0.8.141 render ... --variables '{"url":"praxmodoro.app"}'

## What is where

- `index.html` is the root timeline. It has seven scene slots, plus the crossfades that the
  workflow's `transitions.mjs inject` stamped in at the bottom.
- `compositions/frames/01-open.html … 07-join.html` hold one room each. The app footage plays
  inside a masked window plate in frames 02–06: 6 source px are cropped from every edge and the
  corners are masked at a 22 px radius, so no wallpaper and no pointer show.
- The `data-duration` values in frames 01–06 include each room's dissolve tail: 1.2 s, or 1.4 s
  into the end card. The base lengths are in `STORYBOARD.md`.
- `tools/gen-moments.mjs` writes frames 02–06 from one config: timings, copy, skies and
  footage in-points. Re-running it writes the base lengths without the tails. Run
  `tools/rebuild.sh` instead. It regenerates the frames, restores `tools/index.base.html` and
  stamps the crossfades again. It needs the product-launch-video skill's `transitions.mjs`:
  set `TRANSITIONS=/path/to/transitions.mjs` if that is not in `~/.claude/skills`.
- `BRIEF.md`, `STORYBOARD.md` and `frame.md` are the brief, the shot-by-shot plan and the
  visual system (the site's tokens, adapted for video).
- `assets/fonts/` holds Zen Maru Gothic and Atkinson Hyperlegible Next, copied from the
  Praxmodoro site (SIL OFL, see `OFL.txt`).
- `assets/vendor/gsap-3.14.2.min.js` is GSAP 3.14.2 from npm (standard "no charge" GSAP
  license). It is vendored because the CDN was unreachable here, which also makes renders work
  offline.
- The ⌘ and ↩ keycaps are inline SVG paths from Lucide (ISC license). The site's font subsets
  have no glyphs for those symbols.
