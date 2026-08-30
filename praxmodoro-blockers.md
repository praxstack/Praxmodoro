# Praxmodoro — every open blocker, one shot
> Twin of [[praxmodoro-blockers.html]] · DecisionCanvas 0.1.0 · canvas `01KZTPD57J8QPVKZ7D5BJF4JPC`
> generated 2026-08-12T10:40:00Z

Six decisions stand between here and uninterrupted execution. Everything else is already approved (Living Companion re-affirmed, settings plan approach D, both lanes authorized). Answer these once and nothing else waits on you: lane 1 (sounds, autostart, durations) and lane 2 (tokens + dark theme) run to completion, M2 closes after one Xcode run, and every ticket on the board becomes agent-executable.

<!-- dcanvas:begin sections -->
## 00 / CARRIED FORWARD — Unresolved from previous docs
These were deferred or left open in earlier canvases. Resolving them here writes back to the original decision — you do not need to reopen the old doc.

- **Which direction is the base for Praxodoro?**
  - [ ] A · Liquid Instrument ★ — Nocturnal machined instrument: glass controls, tactile panels, amber signal. Quietest identity, cleanest SwiftUI/Metal mapping, dossier-recommended. Known risk: visual density (its own Restraint score was 3/5).
  - [ ] B · Living Companion — Warm dusk-light; an abstract breathing field is the visual centre. Most emotionally supportive, makes the ADHD-aware positioning unmistakable. Known risk: continuous organic motion can distract; heaviest Reduce-Motion burden; must never read juvenile.
  - [ ] C · Focus Observatory — Cyan/steel control room with day ledger, calendar, and automations at the rim; the dock sleeps until a block starts. Strongest power-user legibility. Known risk: density raises activation energy on the start path.
  - [ ] None — rework needed — No direction is right as a base. Say what's off in a comment (e.g. blend A's timer with B's warmth) and I'll iterate the mocks before any spec is written.
- **GO: write the formal spec + first OpenSpec change from the chosen direction?**
  - [ ] GO
  - [ ] HOLD

## Timer rhythm
Two questions that shape the Rhythm settings pane before its spec is written. Plain terms: rewind/forward is the ±1-minute nudge from your original mock; autostart is what happens the moment a focus block's time runs out.

- **Rewind / forward (±1 min on the running block) — keep or drop? It was in your approved mock but never made it into any spec. The engine derives time purely from recorded events (that's what makes it survive sleep and relaunch), so nudging time must itself be a recorded event — doable, just delicate.**
  - [x] Keep it ★ — ±1 min lands as a real recorded adjustment in the engine, honest across sleep/relaunch, with +/- keys. Lives in the Rhythm pane. Moderate engine work, fully testable.
  - [ ] Drop it — Recorded as an explicit non-goal with the engine-integrity reasoning, so the next audit finds a decision instead of a gap. Ticket #6 closes as decided-no.
- **When a focus block ends (autostart ON): what exactly happens? Your spec forbids forced breaks, so RoundPie's hard autostart needs adapting. Note: the flow policy is exempt either way — flow never auto-ends, the settings pane will say so.**
  - [x] Break starts as the offered default ★ — The break simply begins; declining or ending it is one ordinary keystroke, no penalty, no modal wall. Closest to RoundPie while honoring the no-forced-breaks rule.
  - [ ] Prompt first — Block ends, a gentle prompt asks; the break starts only on confirmation. Softer, but adds one decision at exactly the moment attention is depleted.
  - [ ] Keep breaks fully manual — No autostart at all; the setting is not built. Smallest scope, furthest from your RoundPie ask.

## Sound & notifications
Notification defaults we ship are lint-checked so they can never carry urgency or judgment language. The open question is text YOU type into the custom-notification box.

- **Should text you write yourself in the notification box be exempt from the copy-tone rules?**
  - [x] My words are mine ★ — Product-shipped defaults stay linted; anything you type is yours verbatim, even if it's 'GET BACK TO WORK'.
  - [ ] Lint mine too — The same gentle-language rules apply to custom text; the box refuses urgency words. Protects the product voice, constrains you.

## Design execution (lane 2)
Living Companion specifies three typefaces (Gabarito, Hanken Grotesk, Sono). The app currently ships zero of them — pure system fonts. All three are SIL Open Font License, so bundling is legally clean.

- **Bundle the three Living Companion typefaces into the app, or formally amend the direction to system fonts?**
  - [x] Bundle all three ★ — The direction you just re-affirmed gets its real voice. OFL-licensed, ~1-2 MB binary cost, runtime test fails loudly if a face is missing instead of silently substituting.
  - [ ] System fonts, amended — San Francisco everywhere, recorded as a formal amendment so spec and app finally agree. Zero binary cost, loses most of the type personality.

## Operations
One physical action only you can perform, and one standing policy so I never have to ask again.

- **M2's final gate needs macOS automation consent granted interactively — one 'Product ▸ Test' (Cmd-U) run in Xcode, approving any dialog that appears. Command to open it: open app/Praxmodoro.xcodeproj — when will you do this?**
  - [x] Doing it now ★ — I watch for the result, then immediately run the full verification gate, close milestone M2, and archive its change.
  - [ ] Later today — Both lanes proceed regardless; M2 closes whenever the run happens. Nothing else waits on it.
- **Standing push policy going forward, so momentum never pauses to ask: push main to origin automatically after each green, committed milestone?**
  - [x] Auto-push when green ★ — Every committed unit with a passing suite goes straight to origin/main. Matches what you have had me doing today. Never a force-push, ever.
  - [ ] Ask each time — I hold pushes until you say the word, every time.

## The gate
GO means: both lanes run to completion without further questions — OpenSpec change, engine work, sounds, panes, tokens, dark theme — pausing only at spec-mandated independent validation, and M2 closes the moment the Xcode run lands.

- **Execute everything above to completion?**
  - [ ] GO
  - [ ] HOLD

<!-- dcanvas:end sections -->

<!-- dcanvas:begin decisions -->
### Decisions (applied 2026-08-12T13:41:39.963Z · export `01KZTPM2DDFA8Q5ZM76ES0JXEJ`)

| question | decision | confirmation | note |
|---|---|---|---|
| base_direction | living-companion | explicit |  |
| write_spec | go | explicit |  |
| rewind_forward | keep-as-engine-event | default |  |
| autostart_semantics | stay-manual | explicit |  |
| notification_text_lint | user-words-exempt | default |  |
| typography | bundle-three-faces | default |  |
| xcode_consent_run | now | default |  |
| push_policy | auto-push-green | default |  |
| execute_all | hold | explicit | ⚠ question-mark |

**Gate:** raw `go` → effective `hold` (words win — comments contain open questions)

**Comments:**
- **autostart_semantics:** Give All Options in settings to user but keep Prompt first as default [[Prompt first
Block ends, a gentle prompt asks; the break starts only on confirmation. Softer, but adds one decision at exactly the moment attention is depleted.]] && give these 3 optons in setting s

1[[Break starts as the offered default
The break simply begins; declining or ending it is one ordinary keystroke, no penalty, no modal wall. Closest to RoundPie while honoring the no-forced-breaks rule.]]
2[[Prompt first
Block ends, a gentle prompt asks; the break starts only on confirmation. Softer, but adds one decision at exactly the moment attention is depleted.]]
3[[Keep breaks fully manual
No autostart at all; the setting is not built. Smallest scope, furthest from your RoundPie ask.]]
- **execute_all:** create /goal /autononomou-irchestartion self /coding-leadrshop-pinciple- cmobined prompt for yourself
or do we need to run /wayfinder or /implemetn as per matt poccock ?
<!-- dcanvas:end decisions -->
