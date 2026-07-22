# Devil’s-Advocate Review of the Praxodoro Plan

## Verdict

The outcome is reachable, but the plan is larger than one ordinary feature branch and will fail if “21 atoms” is treated as permission for a single long implementation context. The contract is strongest where it defines timer, edition, privacy, and accessibility invariants; it is weakest where QA depends on tooling not yet proven and where compact/Enterprise surfaces tempt premature breadth.

## Strong objections and resolutions

### 1. “Scaffold Lite/Pro/Enterprise” can become speculative architecture

**Objection:** Capability enums, StoreKit adapters, offline license formats, managed policy, MDM, tenant schemas, and admin UI could consume the build before the local loop exists.

**Resolution:** In the first slice, implement only `ProductCapability`, `EntitlementSnapshot`, `ProductRules`, static Lite development evidence, and tests. StoreKit, signed licenses, MDM, accounts, tenants, seats, and servers remain absent and require separate OpenSpec changes. Enterprise is a bounded capability/policy interface plus a prohibition on behavior fields, not a service scaffold.

### 2. The OpenSpec checklist is not yet an executable implementation plan

**Objection:** Each checkbox contains paths and commands but not the concrete code required by the writing-plans discipline. A fresh implementer could still invent incompatible signatures.

**Resolution:** Write dated subsystem plans before dispatch. The first plan covers tasks 1.1, 2.1, and 2.2 with exact interfaces/code/tests. Later plans cover session domain, runtime/persistence, UI, privacy, and verification after earlier interfaces are real. `BLUEPRINT.md` freezes cross-subsystem names.

### 3. Committing generated `.xcodeproj` conflicts with XcodeGen’s usual no-commit appeal

**Objection:** Generated files create review noise and can drift.

**Resolution:** For a greenfield autonomous build, the committed project is an executable fallback when the generator is unavailable, while `project.yml` remains the human source. Exact 2.46.0 no-diff regeneration is mandatory. If the project is noisy or non-deterministic, the maintainer can switch to generator-only tracking before app code depends on it.

### 4. “VoiceOver tests” can be overstated

**Objection:** XCUITest identifiers and accessibility labels do not prove real VoiceOver rotor/focus/announcement quality.

**Resolution:** Separate automated semantics/keyboard assertions from manual VoiceOver QA evidence. Final status must say which was automated and which was manually observed. No test name may imply full VoiceOver proof if it only checks labels.

### 5. Zero-network and energy proofs are environment-sensitive

**Objection:** A shell script can easily miss child/system traffic or silently skip unavailable capture tools. Low Power Mode and hidden GPU work are not fully represented by unit tests.

**Resolution:** Verification scripts fail closed when capture is unavailable. Use process-attributed socket/DNS observation, entitlement/assets audit, repository network-symbol scan, Instruments/signposts, and a manual evidence report. A local-first or energy claim remains partial until the environment-specific evidence exists.

### 6. 56 EARS criteria plus 12 assumptions may create traceability theater

**Objection:** Many criteria can be mechanically mapped to a few tests without proving behavior, or duplicated between root and OpenSpec specs.

**Resolution:** Root criteria define completion themes; OpenSpec scenarios remain the detailed test source. `prd.json` maps atoms to root IDs, and final validator maps both to named test/smoke evidence. Duplicate criteria require shared evidence plus independent scenario review, not duplicate shallow tests.

### 7. Compact surface is high risk and not needed to prove product value

**Objection:** `NSPanel` behavior across Spaces/fullscreen/accessibility can delay the complete main/menu-bar loop.

**Resolution:** Keep task 5.5 after 5.4 and make it independently revertible. Do not describe the overall 21-atom change complete if 5.5 remains red, but use earlier green checkpoints to preserve progress. If evidence shows a platform blocker, park it explicitly rather than degrading accessibility.

### 8. Session-only coaching data conflicts with useful history

**Objection:** Removing raw check-ins/capacity at completion limits personalization and review.

**Resolution:** Keep content-free factual timing/count aggregates. Raw values remain session-only by default. A later explicit private-history setting can retain them for 30 days and must explain/scope sync separately. This is a privacy-first default, not a prohibition on future opt-in history.

### 9. macOS 26-only narrows the market

**Objection:** Paid competitors support older systems, and requiring macOS 26 reduces adoption.

**Resolution:** The user prioritized an extremely advanced Liquid Glass app and the local toolchain is current. Supporting older systems would introduce compatibility rendering before product validation. Record macOS 26+ clearly; revisit through a separate compatibility change after the core loop is proven.

### 10. “Highest possible library for effects” could be read as a mandate for dependencies

**Objection:** The user asked for the highest possible library, while the design chooses no third-party runtime effects dependency.

**Resolution:** “Highest possible” is interpreted as highest-quality result, not maximum dependency count. Native macOS 26 glass, Canvas, MeshGradient, and a bounded removable Metal ambient effect offer deeper platform integration and accessibility/power control. A third-party effect library is admitted only if a measured visual/performance gap remains and it passes provenance/fallback review.

## Required plan changes before implementation

- Keep task count and criteria counts mechanically verified.
- Add a dated exact-code plan for tasks 1.1, 2.1, and 2.2.
- Make XcodeGen installation/version proof the first scaffold gate.
- Do not install a runtime effects package in the initial scaffold.
- Separate automated accessibility checks from manual VoiceOver evidence in reports.
- Make zero-network/performance scripts fail if they cannot observe the claimed property.
- Preserve explicit green checkpoints after scaffold, capability foundation, pure session core, runtime/persistence, main UI, and full QA.

## What to cut if the approach must simplify

Cut decorative ambient complexity before semantic hierarchy. Cut paid/service adapters before Lite behavior. Cut compact-panel implementation before main/menu-bar correctness only if it is explicitly left incomplete, not silently removed. Never cut timer correctness, editable initiation, check-in/break choice, low-cognitive-load mode, accessibility fallbacks, privacy controls, local data portability, or validation.
