# Praxmodoro fix review: fix/audit-2026-10

Reviewer: independent Opus review, 2026-10-08
Worktree: separate fix worktree (HEAD 34edcda, merge-base with origin/main 3531d6a)
Scope: 2 commits, both cherry-picked with `-x` from draft PR #60.

## Verdict: request-changes

The SoundDirectorTests pin update (34edcda) is a real fix for a stale test. It is not covering up a regression. The focused.sh change (760d7b3) makes CI diagnostics worse in the exact case it was written for. PR #60 ran CI with these same two patches (patch-ids match) and was still red. In that run focused.sh printed nothing after "Diagnostics:" and exited 1, not 65. So PXM-001 is not fixed by this branch, and we still don't know the remaining cause of the red suite.

## Per-commit verdicts

| Commit | Source (PR #60) | Subject | Verdict |
|---|---|---|---|
| 760d7b3 | dd57d72 (same patch-id f6fad55) | ci(scripts): print failing test names in focused.sh diagnostics | request-changes (M1, m3) |
| 34edcda | 19d20d3 (same patch-id 6c57f0f) | test(sound): pin the reviewed wake-handler body | approve-with-nits (m1, m2, n2) |

## Extra focus: is the SoundDirectorTests pin change a real fix, or does it hide a regression in handleSystemWake()?

It is a real fix for a stale test. It does not hide a regression. Evidence:

- `handleSystemWake()` (app/Sources/AppModel.swift:141-144) got `skipPastBlockStartOnNextSync = true` on purpose in 0223062 ("fix: address Codex review findings", 2026-08-30, "Skip past block-start cues after wake"). The pin was written earlier in ecc814e (2026-08-24) and never updated. `git log -S` confirms those are the only commits that touch either string.
- The test's contract, from its name and spec task 10.9, is that wake cancels expired chimes and does not resync. Resync is left to the next root date edge. The new line only sets a private flag. It does not call `syncSound`, `materialize`, or the scheduler, so the contract still holds.
- The new behaviour matches the design doc (openspec/changes/archive/2026-08-26-add-session-settings/design.md:21: "a sound after the fact is noise, not information"). The spec also says block-start fires on derived auto-return, and the flag only suppresses a block-start whose instant is already past on the first sync after wake.
- I ran the pin's whitespace-stripped `contains` checks against both trees with a script, because the hosted suite can't run headless. On base 3531d6a the old pin is false, so the test really was red on main, and the new pin is true. On HEAD the new pin is true. The branch changes nothing under app/Sources.

Caveats, which are the reason for the nits rather than a clean approve:
- **m1 (pre-existing, latent bug that the pin now locks in).** `begin()` (AppModel.swift:381-382) and `endBreak()` (AppModel.swift:682-683) set `pendingBlockStartAt = now` and call `syncSound(at: now)` with the same instant. In syncSound, `past = instant <= now` (AppModel.swift:253) is therefore true. If the wake flag is still armed, meaning no syncSound has run since wake, the user's own block-start chime is silently dropped. In practice the window is short, because the menu-bar label's 1s TimelineView (PraxmodoroApp.swift:186-196) calls observeDerivedPhase, which clears the flag. There is also an ordering risk: if the first post-wake TimelineView tick fires before `didWakeNotification`, the retro block-start plays anyway and the flag stays armed for one more tick. Suggested fix: use `instant < now` for "past", or clear the flag in begin()/endBreak(), or set the skip only for records produced by materialize(). This is outside the branch's scope, so it should be a follow-up.
- **m2.** The suppression flag has no behavioural test. The only coverage is the source-text pin. Add model tests with the existing CueRecorder: (a) handleSystemWake, then advance the clock across a derived auto-return, then observeDerivedPhase: no `.blockStart` scheduled at a past instant. (b) handleSystemWake, then begin(): `.blockStart` scheduled at t0. Test (b) would fail today and expose m1.

## Findings

| ID | Sev | Location | Finding | Evidence | Suggested fix |
|---|---|---|---|---|---|
| M1 | major | scripts/focused.sh:39 (grep line) with `set -euo pipefail` (line 15) | 760d7b3 replaced `Testing failed` in the grep alternation with `[Tt]est [Cc]ase .* failed`. When nothing matches, as when the test runner hangs or there is only a summary, grep exits 1. pipefail plus errexit then aborts the script, so the new `sed` summary, the "full log" echo and `exit "$status"` never run. The commit makes diagnostics worse in exactly the case it targets. It also hides xcodebuild's exit code (1 instead of 65). | PR #60 run 36238560153 (same patches) printed `FAIL: ... (xcodebuild exit 65). Diagnostics:` and then nothing, with step exit code 1. Main run 34876884042 (old script) printed `Testing failed:` and the footer, exit 65. Local repro with a synthetic "runner hung" log: head version exits 1 with no output, base version prints the summary and exits 65. | Add `\|\| true` to both diagnostic pipelines (or `set +e` inside the else branch) so `exit "$status"` always runs. Consider keeping `Testing failed` out of the grep, since sed now covers it. |
| M2 | major | PXM-001 / FIXES.md "Root cause" | The stale pin was at most one cause of the red suite. CI on PR #60 with these exact patches still failed: `checks` job, xcodebuild exit 65, 2026-09-26. Because of M1 that run gives no clue what is still failing. It could be another failing test or a runner hang on the CI host. FIXES.md marks the item "partial", which is honest, but "Root cause (re-checked)" overstates it. | `gh pr view 60` statusCheckRollup: checks=FAILURE. `git patch-id --stable` shows 19d20d3 = 34edcda and dd57d72 = 760d7b3. | Fix M1, re-run CI (or `./scripts/focused.sh` in a desktop Terminal), and identify the remaining failure before claiming PXM-001 is resolved. |
| m1 | minor (pre-existing, 0223062) | app/Sources/AppModel.swift:253-258, 381-382, 682-683 | The wake flag can drop a user-initiated block-start chime, because `instant <= now` counts the current instant as past. | Code reading. Deterministic, since begin()/endBreak() pass the same `now`. | See the extra-focus section. Follow-up task. |
| m2 | minor | app/Tests/PraxmodoroTests/SoundDirectorTests.swift:448-461 | The suppression behaviour is covered only by a brittle source-text equality pin. No behavioural test exists. | `grep skipPastBlockStartOnNextSync app/Tests` finds only the pin string. | Add behavioural tests (a) and (b) above. |
| m3 | minor (pre-existing, still present) | scripts/focused.sh:39-43 | `... \| sort -u \| head -40` and `sed ... \| head -40` under pipefail: with more than 40 lines, the upstream process gets SIGPIPE, the pipeline returns 141, errexit aborts, and the real exit status is lost. | Local repro with 5000 failure lines: exit 141. | Same fix as M1 (`\|\| true`), or write to a temp file and `head` it. |
| n1 | nit | both commits | No `Co-Authored-By: Claude` trailer. The commits carry `Co-authored-by: Prax Lannister` and `(cherry picked from ...)`. Author is Cursor Agent, committer is Prax Lannister. Claude didn't write these patches, so adding a Claude trailer would arguably misattribute them. Leaving them as-is is defensible; it's the owner's call. Commit order is reversed relative to PR #60, which does no harm (the commits touch separate files). | `git log --format=%B` | None required. |
| n2 | nit | 34edcda message | Says the suite has been "red on main since Aug 30". CI on main has been red since 2026-08-22 (last success 2026-08-21). The earlier failures were billing or other, so the date only fits the pin-related failure. | `gh run list --branch main` | Optional wording tweak. |

There are no security, secrets, PII, dependency or lockfile concerns. The diff is test- and script-only: 2 files, +16/-5.

## Check results (branch head 34edcda; base numbers from SETUP.md at 3531d6a)

| Check | Head result | Base |
|---|---|---|
| `./scripts/generate.sh` | OK (writes only gitignored files; worktree still clean) | OK |
| `swift test` PraxmodoroCore | 49 tests / 13 suites pass | 49/13 pass |
| `swift test` PraxmodoroStore | 8 tests / 6 suites pass | 8/6 pass |
| `swift format lint --strict` (Sources dirs per SETUP) | clean, exit 0; changed test file also lint-clean | clean |
| `bash -n` + `shellcheck scripts/focused.sh` | clean (shellcheck can't see the pipefail/errexit logic bug, M1) | n/a |
| `xcodebuild ... build-for-testing` | TEST BUILD SUCCEEDED | BUILD SUCCEEDED |
| `xcodebuild test-without-building -only-testing:PraxmodoroTests/SoundDirectorTests` (timeout 480s) | exit 65: "The test runner hung before establishing connection" (headless limit from SETUP.md, not a result about the fix) | same failure mode (audit test.log) |
| Pin assertions emulated outside XCTest | old pin false / new pin true on base sources; new pin true on head | test red on base |
| `./scripts/verify-project.sh`, UI tests | not run (need a GUI session and Accessibility permission) | not run |

No Praxmodoro processes were left running. I made no changes to the branch. Side effects: one read-only `git fetch origin prax/critical-bug-management-b272`, which updated only FETCH_HEAD, and build output in the session scratchpad.

## FIXES.md claims

- Confirmed: both commits cherry-picked with `-x`, patch-identical to PR #60, unpushed, worktree clean. `bash -n` passes. Whitespace-stripped AppModel.swift contains the new pin string. Hosted xcodebuild test hangs headless. Commits lack the Co-Authored-By trailer and were not amended.
- Not confirmed or contradicted: that the stale pin is *the* root cause keeping the app unit suite red. PR #60's CI with the same patches is still red (M2). I couldn't confirm that the focused.sh change gives actionable diagnostics, because in the hung/summary-only case it prints less than before (M1).
