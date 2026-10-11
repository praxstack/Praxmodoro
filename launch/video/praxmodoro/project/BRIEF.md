---
workflow: product-launch-video
flow: automation
storyboard: no
message: "Praxmodoro helps you start with one tiny step, and keeps you company without ever rushing you."
destination: website
aspect: 1920x1080
language: en
audience: Mac users with ADHD, or anyone tired of tools that shout, landing on the beta waitlist page
length: 45-60s
angle: product-demo, one calm session in five moments (Begin, Focus, Check in, Break, Review), shown in real footage
narration: no
---

## Intent

The actual product demo video for Praxmodoro, a calm macOS focus timer for people
with ADHD, edited from real screen recordings of the beta app on Prax's Mac. It
is a show-it-as-is demo, not a pitch: the real app screens are the video's
assets. The feel is the landing page's "breathing light" identity: soft dawn
gradients, a slow breathing orb, gentle type, motion that never rushes.

The video is silent. On-screen text carries the story and must stay readable at
phone size (1/4 scale).

## Assets

- /mnt/project-files/launch/video/praxmodoro/footage/01-begin.mov — start screen: task, first step, Foggy, Classic 25+5, Begin. Belongs to "Begin". Mouse pointer near the top in the first second.
- /mnt/project-files/launch/video/praxmodoro/footage/02-focus.mov — focus surface with the breathing companion (light). Belongs to "Focus".
- /mnt/project-files/launch/video/praxmodoro/footage/02-focus-dark.mov — the same focus moment in dark mode. Belongs to "Focus", after the light clip.
- /mnt/project-files/launch/video/praxmodoro/footage/03-checkin.mov — ⌘K check-in, four answers, "Still fits". Belongs to "Check in".
- /mnt/project-files/launch/video/praxmodoro/footage/04-break.mov — "I could use a break", break surface with re-entry card, Welcome back. Belongs to "Break".
- /mnt/project-files/launch/video/praxmodoro/footage/05-review.mov — "Today, written down gently." review. Belongs to "Review".
- /home/claude/praxmodoro/site (branch claude/beta-waitlist-site, de52a93) — brand source: site/DESIGN.md, public/assets/css/site.css tokens, self-hosted fonts (Zen Maru Gothic, Atkinson Hyperlegible Next).

Footage is read-only and is never copied into the delivered project.

## Customizations

- Present each clip inside the brand's frame: the app window on a soft sky gradient, gentle scale/pan only.
- Crop about 6 px off every edge of the footage and mask the window corners (radius about 33 px at 2x) so no desktop wallpaper shows.
- Trim dead time; never speed the footage up (the companion's breathing must stay at its real pace).
- Slow, calm transitions.
- End card: "Join the Mac beta" with the waitlist URL written as praxmodoro.com (planned domain, not bought yet). Keep the end-card text in one easily editable place.
- Output 1920x1080, 30 fps, H.264 MP4, plus a 1280x720 poster PNG and a contact sheet.

## Notes

- Copy must stay true to the app and the site: one task, one tiny step; a companion that breathes about every twelve seconds and never speeds up; ⌘K check-ins; breaks that keep your place; a gentle review. Mac beta, free while testing, data stays on your Mac.
- No pricing, no AI claims (the app has none), no invented features or statistics, no medical claims.
- No voice-over, music or sound effects: HeyGen is not used and no local TTS/music engines are installed for this run.
- Autonomous run: nobody answers questions mid-run; decisions are recorded in STORYBOARD.md and EDIT-NOTES.md.
