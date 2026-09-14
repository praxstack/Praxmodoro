# Praxmodoro approved backlog: direct DMG release
> Twin of [[praxmodoro-approved-backlog.html]] · DecisionCanvas 0.2.0 · canvas `01M1AMCH35XEHPRK3K3NC6VZJV`
> generated 2026-08-31T00:40:00Z

This room records the current merged baseline, all 38 open GitHub issues, the approved direct-DMG delivery sequence, and actionable interface improvements. Approval means these items may enter specification and implementation in dependency order. It does not claim that a DMG, notarization receipt, or release already exists.

<!-- dcanvas:begin sections -->
<!-- dcanvas:hash sections aac2b82ac45be14ef1ea50f4766cfd9146da25accb6df91d6fd5503460de4e27 -->
## 01 — Merged baseline
Verified on 2026-08-31: main and origin/main point to d352996. PR #58 is merged. The completed architecture-stabilization commits are ancestors of main. These rows are locked because they report repository facts rather than ask for a new choice.

- **Merged and completed items**
  - 4 items to triage (approved / hold)

## 02 — Distribution method
The approved route is a direct download from the project release page. It does not use the Mac App Store or an installer package.

- **Which distribution route does this backlog implement?**
  - [x] APPROVED: direct DMG ★ — Developer ID signed and notarized drag-install DMG, published with checksum and release notes.
  - [ ] Not selected: Mac App Store — Excluded from this release lane.
  - [ ] Not selected: PKG installer — Excluded because Praxmodoro only needs a drag-install application bundle.

## 03 — Approved direct-DMG release lane
Each row remains a backlog item until it has its own implementation, verification, and durable receipt. The sequence starts from issue #50 and ends with an installed-artifact smoke test.

- **Direct-DMG delivery steps**
  - 10 items to triage (approved / hold)

## 04 — Approved open product backlog
Live GitHub evidence on 2026-08-31 showed 38 open issues. Every row carried ready-for-agent. Approval here preserves the backlog and does not bypass per-change specifications, tests, or review.

- **Open GitHub issues**
  - 38 items to triage (approved / hold)

## 05 — Approved UI and UX improvements
These changes improve backlog navigation without changing the underlying decision semantics or approval receipts.

- **Interface improvements**
  - 8 items to triage (approved / hold)

## 06 — Approval gate
GO accepts the approved defaults above as one authoritative backlog decision. It does not publish a release or bypass specification, implementation, review, signing, notarization, or test gates.

- **Apply this approved backlog and direct-DMG plan?**
  - [ ] GO
  - [ ] HOLD

<!-- dcanvas:end sections -->

<!-- dcanvas:begin decisions -->
<!-- dcanvas:hash decisions 5686a4a55b9c563e19052642b71ad44164767a13f48ab761358a1bb0616bb25a -->
### Decisions (applied 2026-08-31T01:53:58.793Z · export `01M1AQV3FS2BFBZR1BCQ3E6FER`)

| question | decision | confirmation | note |
|---|---|---|---|
| merged_items | approved: 4 | default |  |
| distribution_method | direct-dmg | default |  |
| direct_dmg_steps | approved: 10 | default |  |
| open_product_backlog | approved: 38 | default |  |
| ui_ux_improvements | approved: 8 | default |  |
| final_go | go | explicit |  |

**Gate:** raw `go` → effective `go`
<!-- dcanvas:end decisions -->
