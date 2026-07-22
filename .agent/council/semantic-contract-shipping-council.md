# Pre-Atom-3.1 semantic shipping council

Chairman verdict: PENDING
Subject SHA-256: 190583da7fc33584db8f4ea3bec523f1156d98ae3815d205763989f73fb21748

## Decision boundary

The only question was whether the exact repaired semantic-contract and trace-governance candidate
could enter independent staged-index receiving. `SHIP` does not authorize Atom 3.1 production
work. Production remains blocked until receiving accepts the exact transition, the reserved commit
is created, and postcommit validation passes.

## Selected panel and protocol

- Panel: Linus Torvalds, Miyamoto Musashi, Richard Feynman.
- Chair: Ada Lovelace, independent non-panel Codex subagent; provider identity was not exposed.
- Mode: full, with restatement gate, blind Round 1, anonymized anti-conformity Round 2, final Round
  3 positions, and separate chair synthesis.
- Round 2 mapping after submissions: Member A = Torvalds; Member B = Musashi; Member C = Feynman.

All three panelists passed the restatement gate: the candidate could ship only into receiving, Atom
3.1 remained blocked, and any post-acceptance mutation required a new receipt.

## Round 1 — blind independent positions

- Torvalds: `SHIP into receiving only`; the candidate was implementable, contained no production
  leakage, and passed the stated gates.
- Musashi: `SHIP into receiving only`; the remaining work was the exact staged transaction, not
  semantic expansion.
- Feynman: `SHIP into receiving only`; the contract stated the new-session and reset behavior and
  the verifier still blocked Atom 3.1.

No panelist reported a Critical, Major, or Important finding.

## Round 2 — anonymized anti-conformity review

All three independently retained `SHIP into receiving only` after comparing the anonymized
positions. The council preserved three dissenting cautions:

1. Five mutation regressions cover the known attacks; they are not universal proof.
2. The transition allowlist is a ceiling, not a checklist that justifies unrelated changes.
3. The current session audit is part of the exact reviewed candidate and must be staged unchanged
   and payload-bound.

## Round 3 — final positions

- Torvalds: `SHIP into receiving only`. Mandatory condition: stage the reviewed session audit
  unchanged; payload-bind it; treat the allowlist as a ceiling; invalidate after any byte, mode,
  path, gate-state, receipt, or digest change. Confidence: High, with targeted-coverage caveat.
- Musashi: `SHIP into receiving only`. Mandatory condition: bind the full payload and audit; any
  mutation requires a new receiving pass. Confidence: High, with targeted-coverage caveat.
- Feynman: `SHIP into receiving only`. Mandatory condition: bind the whole actual payload/path set,
  require independent receiving `ACCEPT`, and rerun receiving after mutation. Confidence: High,
  tempered because five tests cover known attacks rather than all attacks.

## Chairman synthesis — corrected final record

### 1. Selected Panel

Linus Torvalds, Miyamoto Musashi, Richard Feynman. All passed restatement gates and voted SHIP
through three rounds.

### 2. Chairman

Ada Lovelace — Codex subagent; underlying provider identity not independently exposed. This is
authorization to form an exact acceptance transaction for independent receiving, not production
approval.

### 3. Acceptable Compromises

Five mutations cover known attacks, not every possible mutation. The 13-path allowlist is a
ceiling, not a checklist. The receiving placeholder may become the final payload-bound receipt
within the reviewed transaction.

### 4. Kill Criteria

- If any of the 13 staged paths has unexpected bytes, mode, or identity by 2026-07-22,
  invalidated → HOLD receiving.
- If the session audit is not staged unchanged and payload-bound by 2026-07-22,
  invalidated → rebuild the receiving transaction.
- If staged `prd.json` lacks gate status `done`, the exact accepted evidence manifest, or Atom 3.1
  `todo` with no evidence by 2026-07-22, invalidated → reject the proposed transition.
- If receiving `ACCEPT` is not bound to the exact subject, allowlist, payload, and receipts by
  2026-07-22, invalidated → keep the gate unaccepted.
- If production begins before the exact reserved acceptance commit and successful postcommit
  validation by 2026-07-22, invalidated → reopen semantic review.

### 5. Concrete Next Step

Stage the exact 13-path semantic transition for independent receiving.

### 6. Unresolved Questions

Only whether independent receiving will accept the exact staged transaction. No unresolved
semantic issue presently blocks submission to receiving.

### 7. Agreements

All reviewers agree the repairs close the identified semantic and trace bypasses. The panel
unanimously authorizes receiving-only shipment while Atom 3.1 remains `todo` without evidence.

### 8. Disagreements

None on disposition. The sole limitation concerns proof breadth: the mutation corpus demonstrates
resistance to known attacks, not all conceivable attacks.

### 9. Decision Options

1. SHIP the 13-path transition into independent receiving.
2. HOLD for broader mutation coverage.
3. REJECT the candidate.

### 10. Recommended Next Steps

Choose option 1. Receiving should inspect staged gate status `done`, the exact accepted evidence
manifest, Atom 3.1 `todo`/no evidence, and all path/mode/byte/digest bindings. Production remains
blocked until the exact reserved acceptance commit and postcommit validation succeed.

### 11. Confidence

High. Pinned HEAD and candidate hashes matched; strict validation passed across 57 criteria, 12
assumptions, 122 scenarios, and 21 atoms; five mutation cases and Swift 20/20 passed; no significant
review finding remains.

### 12. Execution Reliability

Three of three panelists remained live; one required a timeout reminder; none were degraded or
offline. The first chair attempt was interrupted after repeated silent bounded waits. The
replacement chair reproduced the central evidence, but its first synthesis misstated the path
count and staged gate state; root rejected it. The same chair corrected both statements before this
record was accepted. No silent or simulated vote affected the verdict.

## Frozen council conditions

- Exactly 13 changed paths may enter receiving; the allowlist remains a ceiling.
- Every staged path must be a regular non-executable file with identical worktree/index bytes.
- The session audit remains present unchanged from this council freeze and payload-bound.
- Any mutation after independent receiving `ACCEPT` invalidates the receipt.
- Atom 3.1 stays `todo` with null evidence until after the reserved semantic acceptance commit and
  postcommit gates pass.

## Receiving HOLD and reconvening requirement

The first exact-index receiving pass found that the mutation harness was not source-state
independent. Its `Verdict: HOLD` invalidated the proposed transaction before any acceptance commit.
The path ceiling remains 13, but the harness bytes, subject digest, payload digest, trace-review
receipt, council verdict, and receiving receipt must all be regenerated. A reconvened independent
panel and chair must bind the repaired exact candidate before this file may again say SHIP.

## Reconvened council HOLD

The reconvened panel reviewed the second repaired harness. Torvalds and Musashi initially returned
`SHIP into receiving only`; Feynman returned HOLD because the reserved-subject regression combined
two independent invalid states and accepted any nonzero verifier result. In blind anti-conformity
Round 2, all three panelists adopted HOLD. Their mandatory repair conditions were:

1. keep Atom 3.1 `todo`/null in the invalid-reserved-subject case;
2. test the in-review Atom 3.1 start guard as a separate case;
3. require the intended diagnostic instead of accepting arbitrary failure;
4. prove the contract mutation replaces exactly one target; and
5. select an exact-subject acceptance base and explicitly verify that it is valid.

The repaired six-case harness is locally green, but the chairman verdict remains PENDING. A fresh
exact-index trace review and a final reconvened panel round must bind these new bytes before any
chair synthesis or receiving pass.

## Independent history-selection HOLD

The fresh trace reviewer verified the council's compounded-test repair and proved that deleting
only the reserved-commit guard makes the harness fail. It nevertheless returned HOLD because the
acceptance-base search could match a body line and used a narrower ancestry policy than the
verifier. The current repair now compares the parsed `%s` subject exactly, searches all commits
reachable from `HEAD`, and selects the oldest candidate that the current verifier accepts as done.
These changed bytes require a fresh trace verdict before the panel can issue its final position.

The next re-review confirmed exact subject and all-reachable ancestry were closed, then returned
HOLD because failed candidate attempts could dirty the shared checkout and prevent selection of a
later valid base. The repaired loop performs read-only validation with the current verifier located
outside the candidate checkout and overlays current tooling only after a valid base is chosen.

## Final Round 3 receipt-identity HOLD

On the final frozen subject, Musashi and Feynman returned `SHIP into independent receiving only`.
Torvalds returned HOLD because the required trace receipt's top identity still presented the old
five-case suite hash as current, while the final suite has six cases and a different hash. The two
shipping votes also identified that stale block as historical provenance. Root accepted the HOLD:
the receipt now separates current frozen identity from historical audit provenance, records final
suite SHA-256 `86df53cbe11349d1d6f66c0f21a90ae2d24c3460ff647f8d5db612f1d4058ef7`,
blob `cb22d00c97b0e66de7952f5a5a6a158232ada055`, and six cases. The chairman verdict remains PENDING
until all panelists bind this repaired receipt and the newly frozen subject.
