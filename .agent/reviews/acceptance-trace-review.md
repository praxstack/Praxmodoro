# Acceptance trace and mutation review

Verdict: READY
Subject SHA-256: 190583da7fc33584db8f4ea3bec523f1156d98ae3815d205763989f73fb21748

## Current frozen review identity

- Final reviewer: `/root/trace_repair_final_review`
- Review mode: independent exact-index review after five post-receiving/council repair cycles
- Verifier SHA-256: `181e0bc97bdfb93d8857fff1405a131f07f74b89e3be1ca0f28966d89515d33d`
- Mutation-suite SHA-256: `86df53cbe11349d1d6f66c0f21a90ae2d24c3460ff647f8d5db612f1d4058ef7`
- Mutation-suite Git blob: `cb22d00c97b0e66de7952f5a5a6a158232ada055`
- Current case count: six diagnostic-bound cases

## Historical initial-audit provenance

- Initial reviewer: `/root/trace_mutation_audit`
- Initial reviewed mutation-suite SHA-256: `52b6ac79c21be7b5bfdae5c20607ae6634814922a7a28b405278a0ddb9f96d1b`
- Initial review mode: isolated-clone audit with two repair/re-review rounds

## Initial findings and repaired attacks — historical checkpoint

No Critical, Major, or Important finding remained. The reviewer first reproduced reserved-subject,
stale-receipt, committed partial-reacceptance, and reopened-gate bypasses. The exact candidate now:

- replays the newest reserved acceptance and its status, evidence, paths, modes, receipts, subject,
  payload, and allowlist digests;
- fingerprints the gate across HEAD, index, and worktree;
- detects staged, unstaged, and nonignored untracked control-path mutation;
- requires complete exact working reacceptance and rejects fallback to stale historical receipts;
- blocks any unfinished Atom 3.1 under `in_review`; and
- permits normal later-atom changes after a trusted acceptance.

At that historical checkpoint, five isolated regression cases passed. This was targeted evidence
against the then-known attacks, not the current suite identity or a claim of exhaustive proof. The
later all-reachable exact-subject policy closed the first-parent limitation raised at this stage.

## Receiving-induced re-review

The first exact-index receiving review returned HOLD because the original mutation harness seeded
its temporary baseline from the source gate state. It therefore failed against a staged `done`
candidate and could have had nothing to commit after acceptance. The working repair now creates an
explicit isolated `in_review` seed, normalizes unfinished Atom 3.1 state only inside that seed, uses
an allow-empty synthetic commit, accepts both honest initial/reopened block messages, and disables
host commit signing only inside disposable clones.

Working repair SHA-256: `af55002af974745812b27c93b14edbc6e9ed753fdda33589f999ea447fd4d880`.
`bash -n`, ShellCheck, the five-case suite from the proposed `done` candidate, and an isolated clean
postaccept replay all pass. READY remains withheld until the repaired blob and regenerated receipts
are staged together and independently re-reviewed as one exact index.

The first exact staged re-review confirmed the repaired blob but returned HOLD on two future-state
issues: a mixed partially staged tree could still cause a composite working snapshot, and a later
completed Atom 3.1 could make mutations fail through unrelated counts/evidence. The second repair
fails closed whenever a staged candidate also has unstaged or untracked paths. Once a valid semantic
acceptance exists, it seeds all five mutations from the earliest reserved acceptance commit—the
last canonical state before Atom 3.1 could start—then overlays only the current verifier and harness.
Synthetic status changes also update the prior status count and clear evidence.

Second repair SHA-256: `f9fed2be94610b4df1df7c2e10f8167a41fc76700d2ab156e9934b5aecf22181`.
The exact staged-done candidate again passed bash syntax, ShellCheck, and all five mutations. READY
was withheld until the fresh independent review below bound this second repaired index.

## Second-repair exact-index re-review — historical, later invalidated

The independent reviewer returned READY with no Critical, Major, Important, or Minor finding. It
reproduced exactly 13 staged paths, zero unstaged/untracked paths, working/index blob
`54b68ff15c6ce61eaa83599d96aae8b9cfa55324`, file SHA-256
`f9fed2be94610b4df1df7c2e10f8167a41fc76700d2ab156e9934b5aecf22181`, and semantic subject
`f9a644aadd3f700330f174874de6a00466ab824cc02a02b53622158cc5411663`. Bash syntax,
ShellCheck, cached diff checks, and all five mutation cases passed. The reviewer specifically
confirmed both previously held axes: mixed staged/working input fails closed, and postaccept sources
seed from the canonical reserved pre-Atom-3.1 snapshot while overlaying the current verifier/harness.

## Council-induced third repair

The reconvened panel found that the invalid-reserved-subject case also moved Atom 3.1 to `doing`,
so the case could remain green through the Atom guard even if the reserved-commit guard regressed.
The panel unanimously returned HOLD after anti-conformity review. The current repair separates those
two attacks, requires the intended diagnostic for every negative case, proves that the contract
mutation changes exactly one occurrence, and selects an exact-subject first-parent acceptance base
that must itself pass the current verifier as `Semantic gate=done`.

The six-case suite passed with bash syntax and ShellCheck. At that checkpoint, the receipt remained
PENDING until a fresh independent exact-index reviewer reproduced the repaired staged candidate.

The next independent review confirmed every false-positive repair, including a counterfactual
deletion of the reserved-commit guard, but returned HOLD on history selection. Git `--grep` could
match the reserved text in a commit body, and the harness searched first-parent history while the
verifier searches every commit reachable from `HEAD`. The fourth repair parses `%H` and `%s`
separately, compares the subject exactly, searches the same all-reachable ancestry as the verifier,
and walks candidates oldest-first until it finds one that the current verifier explicitly accepts
as `Semantic gate=done`. Six cases, bash syntax, ShellCheck, and cached diff checks pass again.

The re-review confirmed those two findings closed but returned HOLD on candidate-loop isolation:
copying current tooling into an invalid older checkout could leave modified or untracked paths that
block checkout of the next candidate. The fifth repair now validates every historical checkout by
executing the current verifier from its source path with the candidate repository as the working
directory. It copies no bytes into the candidate until after a valid base is selected. The six-case
suite and shell gates passed again; a fresh verdict was still required at that checkpoint.

## Final clean-checkout re-review

Independent outcome: READY. The reviewer confirmed every prior finding closed. Candidate discovery
uses NUL-delimited commit hash/subject fields, exact subject equality, all reachable history,
oldest-first iteration, and explicit current-verifier acceptance. Failed attempts are read-only and
cannot dirty later checkouts; current tooling is copied only after selection. The exact index has 13
regular `100644` paths with zero unstaged or untracked residue. Bash syntax, ShellCheck, cached diff
checks, and all six mutation cases pass. No Critical, Major, or Important finding remains.

Residual caveat: the current pre-acceptance history has no reserved acceptance candidate, so the
multi-candidate loop is structurally reviewed rather than dynamically reached by this run. The
postcommit harness will exercise the real accepted-candidate path before Atom 3.1 can begin.
