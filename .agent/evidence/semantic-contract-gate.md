# Semantic contract gate evidence

Gate status: PENDING
Subject SHA-256: 190583da7fc33584db8f4ea3bec523f1156d98ae3815d205763989f73fb21748

## Scope

This evidence accepts the semantic specification and its machine-enforced governance transaction.
It does not claim that Atom 3.1 or any session engine implementation exists.

## Closed semantic decisions

- exact canonical revision-0 idle snapshot;
- exact idle/completed-to-prepared reset and prepared-update preservation;
- command-aware relational validation with named idle/reset failures;
- scheduled occurrence rules for every break decision and detour resolution;
- exact terminal stop and pending-replacement reason mapping; and
- an implementation plan that assigns these proofs to Atom 3.1 without leaking reducer/time-kernel
  behavior into the model atom.

## Closed governance attacks

- newest reserved acceptance is trusted only after complete historical replay;
- HEAD/index/worktree gate fingerprints and control-path dirt are detected;
- exact path, regular-file mode, byte, subject, payload, receipt, and allowlist closure is required;
- incomplete working reacceptance cannot fall back to stale history;
- a committed gate reopen invalidates the older acceptance; and
- Atom 3.1 cannot start while the gate is `in_review`.

## Validation before receiving

- Strict OpenSpec and trace: PASS — 57 criteria, 12 assumptions, 122 stable scenarios, 21 atoms.
- Mutation regression suite: PASS — six isolated, diagnostic-bound known-bypass cases.
- PraxodoroCore: PASS — 20 tests in two suites.
- Project generation/format: PASS — deterministic regeneration with no diff.
- Independent semantic review: READY.
- Independent acceptance-trace review: READY after five repair/re-review cycles.
- Full shipping council: PENDING after unanimous reconvened-panel HOLD.

## Transaction condition

The exact 13-path staged transition must receive an independent payload-bound `ACCEPT` and commit
with subject `docs: accept session domain contract`. Any later byte, path, mode, gate, receipt, or
digest mutation invalidates this evidence until receiving is repeated.

The first receiving pass returned HOLD on source-state-dependent mutation setup. The harness repair
passes from both the proposed staged-done state and an isolated clean postaccept state, but this gate
remains PENDING until fresh trace review, reconvened council, regenerated digests, and a new exact
receiving pass all succeed.

The reconvened council then found a compounded negative test that could pass through the wrong
guard. The six-case repair isolates the two guards, binds every negative to its expected diagnostic,
proves a single contract replacement, and verifier-validates the exact-subject acceptance base.
The next reviewer then found body-match and ancestry-policy mismatches in that base search. The
current harness parses the exact subject, searches the verifier's all-reachable history, and chooses
the oldest verifier-valid done acceptance. Local gates are green; independent review and council
approval are not yet granted.

The following review found that copying tooling before validation could dirty an invalid candidate
and block the next checkout. Validation now executes the current verifier externally against each
clean historical checkout and copies nothing until a valid base is selected. Local gates remain
green; approval remains pending.

The final clean-checkout re-review returned READY with no Critical, Major, or Important finding.
Council and receiving approval remain pending.
