# Praxmodoro footage clips

Built from `praxstack/Praxmodoro` `main` @ `3531d6a` (docs: record branch recovery evidence), in a detached worktree at `~/Developer/praxmodoro-footage/src`, Debug build, Xcode 27.0, macOS (Darwin 27).

**One local change was needed to run the app (not committed):** on this macOS/Xcode the unmodified build hangs at launch. Its main thread spins in `MenuBarExtraController.updateButton` and never opens a window. Removing the once-per-second `TimelineView` `.background` on the `MenuBarExtra` label in `app/Sources/PraxmodoroApp.swift` fixes it. That background is invisible, so the footage looks the same either way. The diff is in `../footage-only-launch-workaround.patch`.

Capture: `screencapture -V <secs> -R <window frame>`, Retina 1800×1104 (2× the 900×552-pt window), H.264 .mov, no audio. Each run used a fresh in-memory store (`-praxmodoro-ephemeral-store`), so no personal data appears. Light mode was forced per app with `-NSRequiresAquaSystemAppearance YES`; no system setting was changed. The flows were driven by keyboard through System Events (`../scripts/drive.sh`).

Sample data: task "Draft the grant budget", first step "Open last year's budget and copy the table.", capacity Foggy, policy Classic 25+5.

| File | Length | Mode | What it shows |
|---|---|---|---|
| `01-begin.mov` | 17.0 s | light | Empty start screen → task typed → first step typed → Foggy picked → Classic 25+5 picked → Begin (⌘↩) → focus screen appears at 24:59 |
| `02-focus.mov` | 12.0 s | light | Focus surface: the breathing companion field around the countdown (~24:55 → 24:43), thought-parking panel, hold/±1 min controls |
| `03-checkin.mov` | 10.0 s | light | Focus → ⌘K opens "How does the step fit right now?" with four answers → "1 Still fits — keep going" → back to focus with "Kept as is" note |
| `04-break.mov` | 16.0 s | light | ⌘K → "4 I could use a break" → break surface "Rest that keeps your place." with re-entry card → Water chosen → R ends break → "Welcome back." return overlay → ↩ back to focus |
| `05-review.mov` | 10.0 s | light | ⌘⇧W closes the session → review "Today, written down gently." timeline (capacity, check-ins, break: water, closed) and the insight card |
| `02-focus-dark.mov` | 12.0 s | dark | Same focus moment in dark mode; the companion glows brighter on dark |

Notes for the edit:
- The region is the window's rectangle, so a few pixels of desktop wallpaper show at the rounded corners (a small sparkle appears at the bottom corners). Crop 2–3 pt or mask the corners if that matters.
- The mouse pointer appears briefly near the top of `01-begin.mov`.
- Clips 02–05 come from one continuous session, so their clock values and timeline entries line up.
