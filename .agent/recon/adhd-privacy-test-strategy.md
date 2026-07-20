# ADHD-aware coach, privacy, and test-strategy recon

Source: fresh-context read-only specialist review of the research outputs and Hallmark mocks on 2026-07-20.

## Findings that bind the spec

- The evidence supports a nonjudgmental loop: one task, tiny first action, focus, optional check-in, steerable break, re-entry, descriptive review.
- Lite/Pro/Enterprise gates did not exist in the research or mocks and must be specified before implementation. Core initiation, check-ins, breaks, low-cognitive-load mode, accessibility, privacy, and deterministic help remain in Lite.
- Existing mock copy conflicts on session-only coaching data versus retained history and optional iCloud storage. The implementation needs an explicit data dictionary, retention manifest, sync-category contract, and honest deletion semantics.
- Capacity must default to `nil`/unspecified. A preselected “Steady” state would record an answer the user did not provide.
- The first action must be editable, and deterministic/manual initiation must work without AI.
- “Drift” may only mean an explicit user/session event; no passive application or browser observation.
- Analytics must remain descriptive, show sample counts, avoid causal/moral/comparative language, and never change defaults without confirmation.
- Notification permission timing, privacy-safe previews, deduplication, dismissal, and quiet behavior require explicit scenarios.
- Hallmark mocks are visual evidence, not semantic proof. Native implementation must expose selection, focus, charts, and state changes to VoiceOver and keyboard input.
- Remote Google Fonts in the mock must not become a shipped native dependency or undermine zero-network demonstrations.

## Safety and privacy floor

- No diagnosis, treatment, symptom severity, mental-health risk, productivity worth, employability, or treatment-response scoring.
- No screenshots, keystrokes, clipboard harvesting, microphone, camera, location, Health data, passive app history, or website-content inspection.
- Task text, scratchpad, check-ins, capacity, interruption notes, and behavioral timestamps are sensitive content and never enter diagnostics.
- Check-ins and breaks are always skippable, dismissible, and manually triggerable; missing one has no penalty.
- Sync, integrations, diagnostics, AI, and blocking are separately opt-in. Denial preserves the Lite core.
- Enterprise administration is limited to license, version, update, deployment, and allowed managed-policy data; it never exposes personal behavioral content.

## Initial deterministic gates

- Fresh Lite install starts offline with no account, paywall, permission, capacity, or network dependency.
- Unspecified capacity stays `nil` and causes no capacity-derived suggestion.
- AI unavailable/disabled/failing still exposes editable deterministic/manual first-action help.
- Every check-in choice has one documented transition; ignore/dismiss creates no score, streak loss, escalation, or repeat event.
- Breaks explain explicit inputs, offer alternatives/quiet mode/disable, and can end early without penalty.
- Low-cognitive-load mode removes analytics, animation, coach history, and upgrade UI from the focus surface.
- Fewer than five relevant observations across three days yields counts/denominators only, never a pattern recommendation.
- Notification previews omit sensitive content by default and never request Critical Alerts.
- With network features off, a 30-minute Lite session makes no app-originated outbound request.
- Downgrading Pro to Lite preserves readable/exportable local data and the entire Lite core.
- OS Reduce Motion, Reduce Transparency, and Increase Contrast automatically activate full fallback paths.
- VoiceOver and Full Keyboard Access reach every action, expose selection state, and announce meaningful timer state once rather than every second.

## Data-default recommendation

- Active state: local, session plus 24-hour recovery, sync off.
- Task/action history: local, 30-day default, separate sync category.
- Capacity/check-in answers: session-only unless private history is explicitly enabled; then bounded 30-day local retention and separate sync choice.
- Scratchpad/interruption notes: local until resolved or seven days after session.
- Content-free duration/count aggregates: local for 90 days with reset/delete.
- Notifications: ephemeral until delivery/dismissal/invalidation; never synced.
- AI prompts/results: memory-only until the user accepts an action; no transmission by Praxodoro in this change.
- Diagnostics: off or explicit opt-in, bounded, and content-free.

## Mock corrections carried forward

- No preselected capacity.
- Replace causal “helped” and surveillance-adjacent “drift” wording.
- Make the first action editable.
- Add semantic selection and focus behavior in native controls.
- Provide textual chart values and context.
- Connect reduced-effects behavior to OS settings and make reduced transparency fully opaque.
- Self-host preview fonts before any public web preview.
