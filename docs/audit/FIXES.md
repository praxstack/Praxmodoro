# Praxmodoro fixes (branch fix/audit-2026-10)

Scope: kept findings with severity P0/P1. The audit has no P0 and exactly one P1 (PXM-001). P2/P3 findings were out of scope.

## PXM-001 (P1) - Main CI red; fix stranded on draft PR #60 - status: partial
- Commits (cherry-picked with -x from the PR #60 commits, unpushed): 760d7b3 (ci(scripts): print failing test names in focused.sh, from dd57d72) and 34edcda (test(sound): pin the reviewed wake-handler body, from 19d20d3).
- Root cause (from the commit message and re-checked): SoundDirectorTests' exact-body source pin for handleSystemWake() was never updated when `skipPastBlockStartOnNextSync = true` was added, so the app unit suite stays red.
- Evidence: whitespace-stripped AppModel.swift now contains the exact string the updated test pins (checked with a script); `bash -n scripts/focused.sh` passes; worktree is clean.
- Not verified by running: `xcodebuild test -only-testing:PraxmodoroTests/SoundDirectorTests` fails with "test runner hung before establishing connection". This is the known SETUP.md limitation (no GUI session), not a result about the fix. Run `./scripts/focused.sh` from a desktop Terminal.
- The commits keep the original Cursor Agent authorship and messages, and lack the Co-Authored-By trailer. I did not amend them.
- Remains (owner decision): merging PR #60 / pushing this branch and confirming a green CI run on main. I did not push, and did not touch GitHub or billing. The audit notes some early failures were billing-blocked, so check Actions billing too.
