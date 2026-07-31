# Development and Runtime Dependencies

## XcodeGen 2.46.0

- Purpose: generate `Praxodoro.xcodeproj` from reviewable `project.yml`.
- Canonical source: https://github.com/yonaskolb/XcodeGen
- Release: 2.46.0, 2026-07-16.
- Tag commit: `8445e778451c7e44237b90281bde622d764b0084`.
- Artifact: `https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip`.
- Archive SHA-256: `4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806`.
- Extracted universal executable SHA-256:
  `8774da746668bc18fe74e54cbaf10f2631a1fb05947cd374179aa912f14f99db`; the
  cached executable is revalidated before each invocation.
- License: MIT; the archive carries `xcodegen/LICENSE`.
- Scope: ignored repo-local development/CI tooling only; not linked or bundled in Praxodoro.
- Upgrade: separate dependency-review atom with new source, checksum, regeneration, build, and tests.
- Removal: committed `.xcodeproj` remains buildable while a replacement generator is evaluated.

## Swift Format 6.3.0

- Purpose: deterministic Swift formatting and style diagnostics.
- Source: Xcode 26.6 default Swift toolchain via `xcrun swift-format`.
- Scope: development and CI only; not an app dependency.
- Removal: source still compiles; replace only through a documented formatting decision.

## Runtime

The foundation app has no non-Apple runtime dependency. It links only Apple frameworks and the
local `PraxodoroCore` package. The tool bootstrap uses Apple-provided shell utilities and curl.
