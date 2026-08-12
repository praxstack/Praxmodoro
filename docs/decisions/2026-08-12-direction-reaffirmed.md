# Decision: visual direction re-affirmed — Living Companion

Date: 2026-08-12 · Decider: Prax · Instrument: dcanvas export `01KZTMCW568JN5GKMA8TP9PHPA` (canvas `01KYSZMZQDXAVQXTQCCHH7ETYR`) · Gate: **go**

## The decision

`base_direction = living-companion`, confirmed **explicitly**, after reviewing three deliberately divergent alternatives (D Flight Instrument, E Quiet Terminal, F Broadsheet — `design-mocks/direction-gate-2/`). `write_spec = go`.

This closes GitHub issue #5 and unblocks the design-system chain (#8 tokens, #9 typography, #10 field fidelity, #11–#12 migrations, #13 motion, #14 contract).

## What this decision means, precisely

1. **Living Companion stays the binding reference** (`design-mocks/living-companion/`, physics contract `companion-physics.js`) — now by a second, informed confirmation rather than the original 2026-07-30 approval alone. The 2026-08-04 "hated it" reaction is superseded by this record.
2. **The mandate is execution, not re-selection.** The design-parity audit (`docs/analysis/2026-08-04-design-parity.md`) stands: the app implements roughly a fifth of this direction. The gap closes by building the direction properly — tokens derived not eyeballed, the three typefaces resolved, motion vocabulary, field fidelity.
3. **D, E and F become comparative records**, kept like the first gate's alternates. They are not dead weight: E's restraint and D's tabular time are referenced as seasoning for Living Companion's execution where the audit found it flat.
4. `direction_notes` was left at default — no constraints were attached beyond the choice itself.

## Raw export

```json
{"kind":"decisions","schemaVersion":"0.1.0","canvasId":"01KYSZMZQDXAVQXTQCCHH7ETYR","exportId":"01KZTMCW568JN5GKMA8TP9PHPA","exportedAt":"2026-08-12T09:21:02.118Z","baseline":"6ff9fa687a46b5dcc9b2d4a9cf1592976b25acb7120aaeaec2f741e345478b53","answers":[{"questionId":"01KYSZMZQDXAVQXTQCCHH7ETYT","confirmation":"explicit","key":"base_direction","resolution":"answered","value":"living-companion"},{"questionId":"01KYSZMZQDXAVQXTQCCHH7ETYV","confirmation":"default","key":"direction_notes","resolution":"answered"},{"questionId":"01KYSZMZQDXAVQXTQCCHH7ETYX","confirmation":"explicit","key":"write_spec","resolution":"answered","value":"go"}],"gate":{"raw":"go","effective":"go","wordsWinTriggered":false}}
```
