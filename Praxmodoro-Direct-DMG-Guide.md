# Praxmodoro approved backlog and direct-DMG guide

## Launch the DecisionCanvas HTML

The generated HTML is standalone. It does not need installation.

```bash
cd /Users/prax/Developer/Praxomodoro
open docs/backlog/praxmodoro-approved-backlog.html
```

To regenerate it from the authoritative canvas and open a live DecisionCanvas room:

```bash
cd /Users/prax/Developer/Praxomodoro
dcanvas validate docs/backlog/praxmodoro-approved-backlog.dcanvas.json
dcanvas seal docs/backlog/praxmodoro-approved-backlog.dcanvas.json
dcanvas render docs/backlog/praxmodoro-approved-backlog.dcanvas.json
dcanvas room docs/backlog/praxmodoro-approved-backlog.dcanvas.json --via codex
```

Use the authenticated loopback URL printed by `dcanvas room`. Keep the process running while the room is open.

## Apply an offline decision export

1. Open `docs/backlog/praxmodoro-approved-backlog.html`.
2. Choose GO or HOLD in the Approval gate.
3. Select **Offline handoff**.
4. Download `praxmodoro-approved-backlog.decisions.json`.
5. Apply and verify it:

```bash
cd /Users/prax/Developer/Praxomodoro
dcanvas apply docs/backlog/praxmodoro-approved-backlog.decisions.json
dcanvas read docs/backlog/praxmodoro-approved-backlog.decisions.json --gate --json
```

Only an accepted export with `effective: "go"` authorizes gated work. Opening the HTML alone does not.

## Direct-DMG build and publication sequence

The release backlog is approved, but no DMG exists yet. Implement issue #50 before using this section as a release procedure.

1. Verify the Apple Developer team, Developer ID Application certificate, private-key access, bundle identifier, and `notarytool` credentials.
2. Configure the Release archive with hardened runtime and minimum entitlements.
3. Run the complete current project gate. Stop if any required test, review, or source check fails.
4. Archive and Developer ID sign `Praxmodoro.app`.
5. Verify the signed application with `codesign` and `spctl`.
6. Submit the signed application for notarization and wait for an accepted result.
7. Staple and validate the notarization ticket.
8. Create a drag-install DMG containing `Praxmodoro.app` and an Applications shortcut.
9. Sign, notarize, staple, and verify the final DMG.
10. Install from the final DMG on a clean account or clean Mac, then smoke-test first launch and the complete focus loop.
11. Publish the immutable DMG, SHA-256 checksum, release notes, compatibility, privacy statement, and rollback instructions.

## Install Praxmodoro from the final direct DMG

These steps apply only after the release lane produces a signed and notarized DMG.

1. Download the DMG and compare its SHA-256 checksum with the published checksum.
2. Double-click the DMG.
3. Drag `Praxmodoro.app` to the Applications shortcut.
4. Eject the mounted Praxmodoro volume.
5. Open Praxmodoro from `/Applications`.
6. Confirm macOS identifies the developer and opens the app without a Gatekeeper override.
7. Start one short focus block and verify Hold, Resume, break, and review behavior.

## Approved UI and UX improvements

- Add sticky section navigation with per-lane item counts.
- Add filters for issue number, lane, and approval state.
- Collapse the full issue inventory while keeping the direct-DMG lane visible.
- Pair every status color with explicit status text.
- Show source and freshness beside GitHub and Git facts.
- Offer compact and comfortable density controls.
- Preserve keyboard, screen-reader, reduced-motion, and non-drag operation.
- Provide clean print and offline handoff layouts.
