# Native Scaffold and Quality Gates Plan

> **Required mode:** subagent-driven development with TDD/configuration-red evidence and an
> independent reviewer after each task.

**Goal:** Produce a reproducible macOS 26 app, internal Swift package, real app/UI test execution,
and deterministic generation/format/toolchain gates.

**Architecture:** XcodeGen 2.46.0 is checksum-bootstrapped from the official release into ignored
repo-local `.build/tools`; both the archive and installed executable are pinned, and every cached
executable is authenticated before invocation. One generated app target links one local `PraxodoroCore` package.
Unsigned compilation and the normal local test-signing path are proved separately.

**Toolchain:** Xcode 26.6, Swift 6.3.3, SwiftUI, Swift Testing, XCTest UI testing, XcodeGen 2.46.0,
Xcode-bundled `swift-format` 6.3.0.

---

## Task 1: OpenSpec 1.1 — Reproducible Native Project Scaffold

**Create:**

- `.xcodegen-version`
- `scripts/bootstrap-xcodegen.sh`
- `scripts/verify-scaffold.sh`
- `scripts/run-app-tests.sh`
- `scripts/smoke-scaffold.sh`
- `project.yml`
- `Packages/PraxodoroCore/Package.swift`
- `Packages/PraxodoroCore/Sources/PraxodoroCore/PraxodoroCore.swift`
- `Packages/PraxodoroCore/Tests/PraxodoroCoreTests/ScaffoldTests.swift`
- `PraxodoroApp/PraxodoroApp.swift`
- `PraxodoroApp/Platform/AppPaths.swift`
- `PraxodoroApp/Features/FocusLoop/InitiateView.swift`
- `PraxodoroTests/ScaffoldIntegrationTests.swift`
- `PraxodoroUITests/PraxodoroLaunchUITests.swift`
- generated `Praxodoro.xcodeproj/`

### Step 1: Write the exact tool bootstrap and scaffold verifier

Create `.xcodegen-version`:

```text
2.46.0
```

Create `scripts/bootstrap-xcodegen.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

bootstrap_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$bootstrap_root"

expected_version="$(tr -d '[:space:]' < .xcodegen-version)"
expected_sha256="4d9e34b62172d645eed6457cac13fc222569974098ef4ee9c3368bedf0196806"
expected_binary_sha256="8774da746668bc18fe74e54cbaf10f2631a1fb05947cd374179aa912f14f99db"
archive_url="https://github.com/yonaskolb/XcodeGen/releases/download/2.46.0/xcodegen.zip"
tool_parent="$bootstrap_root/.build/tools/xcodegen"
tool_root="$tool_parent/$expected_version"
binary="$tool_root/xcodegen/bin/xcodegen"

verify_binary() {
  local actual_binary_sha256
  actual_binary_sha256="$(/usr/bin/shasum -a 256 "$binary" | /usr/bin/awk '{print $1}')"
  if [[ "$actual_binary_sha256" != "$expected_binary_sha256" ]]; then
    echo "ERROR: XcodeGen executable checksum mismatch" >&2
    exit 1
  fi

  local version_output
  version_output="$("$binary" --version)"
  if [[ "$version_output" != "Version: $expected_version" ]]; then
    echo "ERROR: expected XcodeGen $expected_version, got: $version_output" >&2
    exit 1
  fi
}

if [[ -x "$binary" ]]; then
  verify_binary
  printf '%s\n' "$binary"
  exit 0
fi

if [[ -e "$tool_root" ]]; then
  echo "ERROR: partial XcodeGen tool directory exists: $tool_root" >&2
  exit 1
fi

/bin/mkdir -p "$tool_parent"
download_root="$(/usr/bin/mktemp -d "$tool_parent/.download.XXXXXX")"
archive="$download_root/xcodegen.zip"
unpacked="$download_root/unpacked"

cleanup_download() {
  case "$download_root" in
    "$tool_parent"/.download.*) /bin/rm -rf -- "$download_root" ;;
    *) echo "ERROR: refusing unexpected XcodeGen cleanup path: $download_root" >&2 ;;
  esac
}
trap cleanup_download EXIT

/usr/bin/curl --fail --location --silent --show-error "$archive_url" --output "$archive"
actual_sha256="$(/usr/bin/shasum -a 256 "$archive" | /usr/bin/awk '{print $1}')"
if [[ "$actual_sha256" != "$expected_sha256" ]]; then
  echo "ERROR: XcodeGen archive checksum mismatch" >&2
  exit 1
fi

/usr/bin/ditto -x -k "$archive" "$unpacked"
if [[ ! -x "$unpacked/xcodegen/bin/xcodegen" ]]; then
  echo "ERROR: official XcodeGen archive has the wrong layout" >&2
  exit 1
fi

/bin/mv "$unpacked" "$tool_root"
verify_binary
printf '%s\n' "$binary"
```

Create `scripts/verify-scaffold.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

scaffold_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$scaffold_root"

required_files=(
  .xcodegen-version
  project.yml
  Packages/PraxodoroCore/Package.swift
  PraxodoroApp/PraxodoroApp.swift
  PraxodoroApp/Platform/AppPaths.swift
  PraxodoroApp/Features/FocusLoop/InitiateView.swift
  PraxodoroTests/ScaffoldIntegrationTests.swift
  PraxodoroUITests/PraxodoroLaunchUITests.swift
  Praxodoro.xcodeproj/project.pbxproj
)

for required_file in "${required_files[@]}"; do
  if [[ ! -f "$required_file" ]]; then
    echo "ERROR: missing scaffold file: $required_file" >&2
    exit 1
  fi
done

xcode_version="$(xcodebuild -version | /usr/bin/sed -n '1s/^Xcode //p')"
[[ "$xcode_version" == "26.6" ]] || {
  echo "ERROR: expected Xcode 26.6, got: $xcode_version" >&2
  exit 1
}

swift_version="$(swift --version | /usr/bin/sed -n 's/.*Swift version \([^ ]*\).*/\1/p' | /usr/bin/head -1)"
[[ "$swift_version" == "6.3.3" ]] || {
  echo "ERROR: expected Swift 6.3.3, got: $swift_version" >&2
  exit 1
}

xcodegen_binary="$(bash scripts/bootstrap-xcodegen.sh)"
[[ "$("$xcodegen_binary" --version)" == "Version: 2.46.0" ]] || {
  echo "ERROR: XcodeGen exact-version proof failed" >&2
  exit 1
}

swift package describe --package-path Packages/PraxodoroCore >/dev/null

target_json="$(xcodebuild -list -json -project Praxodoro.xcodeproj)"
target_xml="$(printf '%s' "$target_json" | /usr/bin/plutil -extract project.targets xml1 -o - -)"
for target_name in Praxodoro PraxodoroTests PraxodoroUITests; do
  if ! /usr/bin/grep -Fq "<string>$target_name</string>" <<<"$target_xml"; then
    echo "ERROR: missing Xcode target: $target_name" >&2
    exit 1
  fi
done

echo "SCAFFOLD_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 targets=3"
```

Make the scripts executable, then run the verifier before creating the scaffold:

```bash
chmod +x scripts/bootstrap-xcodegen.sh scripts/verify-scaffold.sh
bash scripts/verify-scaffold.sh
```

Expected RED: `ERROR: missing scaffold file: project.yml`. A syntax error or a tool-install
failure is not the accepted configuration red.

### Step 2: Bootstrap and prove exact XcodeGen

```bash
xcodegen_binary="$(bash scripts/bootstrap-xcodegen.sh)"
"$xcodegen_binary" --version
```

Expected: exactly `Version: 2.46.0`. The archive checksum is checked before extraction, and the
installed executable checksum is checked before every invocation, including cached use. No
Homebrew/global install is used.

### Step 3: Create the strict core package

Create `Packages/PraxodoroCore/Package.swift`:

```swift
// swift-tools-version: 6.2

import PackageDescription

let strictSwiftSettings: [SwiftSetting] = [
  .swiftLanguageMode(.v6),
  .treatAllWarnings(as: .error),
]

let package = Package(
  name: "PraxodoroCore",
  platforms: [.macOS("26.0")],
  products: [
    .library(name: "PraxodoroCore", targets: ["PraxodoroCore"])
  ],
  targets: [
    .target(name: "PraxodoroCore", swiftSettings: strictSwiftSettings),
    .testTarget(
      name: "PraxodoroCoreTests",
      dependencies: ["PraxodoroCore"],
      swiftSettings: strictSwiftSettings
    ),
  ]
)
```

Create `Packages/PraxodoroCore/Sources/PraxodoroCore/PraxodoroCore.swift`:

```swift
public enum PraxodoroCore {
  public static let productName = "Praxodoro"
}
```

Create `Packages/PraxodoroCore/Tests/PraxodoroCoreTests/ScaffoldTests.swift`:

```swift
import Testing

@testable import PraxodoroCore

@Test
func exposesStableProductIdentity() {
  #expect(PraxodoroCore.productName == "Praxodoro")
}
```

### Step 4: Create the app, isolated-state contract, and semantic seed surface

Create `PraxodoroApp/Platform/AppPaths.swift`:

```swift
import Foundation

enum AppPaths {
  static func stateRoot(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) -> URL {
    if let override = environment["PRAXODORO_STATE_ROOT"], !override.isEmpty {
      return URL(filePath: override, directoryHint: .isDirectory)
    }

    return URL.applicationSupportDirectory
      .appending(component: "Praxodoro", directoryHint: .isDirectory)
  }
}
```

Create `PraxodoroApp/Features/FocusLoop/InitiateView.swift`:

```swift
import SwiftUI

struct InitiateView: View {
  var body: some View {
    VStack(spacing: 12) {
      Text("Praxodoro")
        .font(.system(size: 36, weight: .semibold, design: .rounded))
        .accessibilityIdentifier("initiate.heading")
        .accessibilityAddTraits(.isHeader)

      Text("One clear next move.")
        .font(.title3)
        .foregroundStyle(.secondary)
    }
    .frame(minWidth: 480, minHeight: 360)
    .padding(32)
  }
}
```

Create `PraxodoroApp/PraxodoroApp.swift`:

```swift
import PraxodoroCore
import SwiftUI

@main
struct PraxodoroApplication: App {
  static let productName = PraxodoroCore.productName
  private let stateRoot = AppPaths.stateRoot()

  var body: some Scene {
    WindowGroup(PraxodoroApplication.productName) {
      InitiateView()
        .environment(\.praxodoroStateRoot, stateRoot)
    }
    .defaultSize(width: 960, height: 720)
    .windowResizability(.contentMinSize)

    MenuBarExtra(PraxodoroApplication.productName, systemImage: "timer") {
      Text("No active session")
        .padding()
    }
  }
}

private struct PraxodoroStateRootKey: EnvironmentKey {
  static let defaultValue = AppPaths.stateRoot()
}

extension EnvironmentValues {
  var praxodoroStateRoot: URL {
    get { self[PraxodoroStateRootKey.self] }
    set { self[PraxodoroStateRootKey.self] = newValue }
  }
}
```

### Step 5: Create tests that compile the app and assert the real launch element

Create `PraxodoroTests/ScaffoldIntegrationTests.swift`:

```swift
import Foundation
import Testing

@testable import Praxodoro

@Test @MainActor
func applicationUsesCoreProductIdentity() {
  #expect(PraxodoroApplication.productName == "Praxodoro")
}

@Test
func testStateRootOverrideIsConsumed() {
  let root = AppPaths.stateRoot(environment: ["PRAXODORO_STATE_ROOT": "/tmp/praxodoro-test"])
  #expect(root.path == "/tmp/praxodoro-test")
}
```

Create `PraxodoroUITests/PraxodoroLaunchUITests.swift`:

```swift
import XCTest

final class PraxodoroLaunchUITests: XCTestCase {
  @MainActor
  func testLaunchesInitiateSurface() throws {
    let app = XCUIApplication()
    let stateRoot = FileManager.default.temporaryDirectory
      .appending(path: "PraxodoroUITests-\(UUID().uuidString)", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: stateRoot, withIntermediateDirectories: true)
    addTeardownBlock { try? FileManager.default.removeItem(at: stateRoot) }

    app.launchEnvironment["PRAXODORO_STATE_ROOT"] = stateRoot.path
    app.launchArguments = ["-PraxodoroSmokeMode", "YES"]
    app.launch()

    XCTAssertTrue(
      app.staticTexts["initiate.heading"].waitForExistence(timeout: 5),
      "The native initiation heading must be visible after an isolated launch."
    )
  }
}
```

### Step 6: Generate the project

Create `project.yml`:

```yaml
name: Praxodoro
options:
  minimumXcodeGenVersion: 2.46.0
  xcodeVersion: "26.6"
  bundleIdPrefix: com.praxodoro
  deploymentTarget:
    macOS: "26.0"
  createIntermediateGroups: true
packages:
  PraxodoroCore:
    path: Packages/PraxodoroCore
settings:
  base:
    MACOSX_DEPLOYMENT_TARGET: "26.0"
    SWIFT_VERSION: "6.0"
targets:
  Praxodoro:
    type: application
    platform: macOS
    sources:
      - path: PraxodoroApp
    dependencies:
      - package: PraxodoroCore
        product: PraxodoroCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.praxodoro.app
        PRODUCT_NAME: Praxodoro
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: Praxodoro
        INFOPLIST_KEY_LSApplicationCategoryType: public.app-category.productivity
  PraxodoroTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: PraxodoroTests
    dependencies:
      - target: Praxodoro
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
  PraxodoroUITests:
    type: bundle.ui-testing
    platform: macOS
    sources:
      - path: PraxodoroUITests
    dependencies:
      - target: Praxodoro
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
schemes:
  Praxodoro:
    build:
      targets:
        Praxodoro: all
        PraxodoroTests: [test]
        PraxodoroUITests: [test]
    test:
      targets:
        - PraxodoroTests
        - PraxodoroUITests
```

Generate:

```bash
xcodegen_binary="$(bash scripts/bootstrap-xcodegen.sh)"
"$xcodegen_binary" generate --spec project.yml
```

Expected: the three declared targets and shared `Praxodoro` scheme are generated.

### Step 7: Create real app-test and isolated-smoke drivers

Create `scripts/run-app-tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

test_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$test_root"

/bin/mkdir -p .build/TestResults
run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
derived_data="$test_root/.build/DerivedDataTests"
result_bundle="$test_root/.build/TestResults/Praxodoro-$run_id.xcresult"
tests_json="$test_root/.build/TestResults/Praxodoro-$run_id-tests.json"
summary_json="$test_root/.build/TestResults/Praxodoro-$run_id-summary.json"

xcodebuild \
  -project Praxodoro.xcodeproj \
  -scheme Praxodoro \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data" \
  build-for-testing

xcodebuild \
  -project Praxodoro.xcodeproj \
  -scheme Praxodoro \
  -destination 'platform=macOS' \
  -derivedDataPath "$derived_data" \
  -resultBundlePath "$result_bundle" \
  test-without-building

xcrun xcresulttool get test-results tests --compact --path "$result_bundle" > "$tests_json"
xcrun xcresulttool get test-results summary --compact --path "$result_bundle" > "$summary_json"
for evidence_name in PraxodoroTests PraxodoroUITests applicationUsesCoreProductIdentity \
  testLaunchesInitiateSurface
do
  if ! /usr/bin/grep -Fq "$evidence_name" "$tests_json"; then
    echo "ERROR: app test evidence missing: $evidence_name" >&2
    exit 1
  fi
done

test_result="$(/usr/bin/plutil -extract result raw -o - "$summary_json")"
total_tests="$(/usr/bin/plutil -extract totalTestCount raw -o - "$summary_json")"
passed_tests="$(/usr/bin/plutil -extract passedTests raw -o - "$summary_json")"
failed_tests="$(/usr/bin/plutil -extract failedTests raw -o - "$summary_json")"
if [[ "$test_result" != "Passed" || "$failed_tests" -ne 0 || "$total_tests" -lt 3 \
  || "$passed_tests" -ne "$total_tests" ]]
then
  echo "ERROR: app tests did not all execute and pass: result=$test_result total=$total_tests passed=$passed_tests failed=$failed_tests" >&2
  exit 1
fi

echo "APP_TESTS_OK total=$total_tests passed=$passed_tests result_bundle=$result_bundle"
```

Create `scripts/smoke-scaffold.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

smoke_project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$smoke_project_root"

smoke_binary="$smoke_project_root/.build/DerivedData/Build/Products/Debug/Praxodoro.app/Contents/MacOS/Praxodoro"
[[ -x "$smoke_binary" ]] || {
  echo "ERROR: missing built app binary: $smoke_binary" >&2
  exit 1
}

/bin/mkdir -p .build/Smoke
smoke_state="$(/usr/bin/mktemp -d "$smoke_project_root/.build/Smoke/state.XXXXXX")"
smoke_log="$smoke_project_root/.build/Smoke/scaffold-$(date -u +%Y%m%dT%H%M%SZ)-$$.log"
smoke_pid=""

cleanup_smoke() {
  if [[ -n "$smoke_pid" ]] && /bin/kill -0 "$smoke_pid" 2>/dev/null; then
    /bin/kill -TERM "$smoke_pid" 2>/dev/null || true
  fi
  case "$smoke_state" in
    "$smoke_project_root"/.build/Smoke/state.*) /bin/rm -rf -- "$smoke_state" ;;
    *) echo "ERROR: refusing unexpected smoke cleanup path" >&2 ;;
  esac
}
trap cleanup_smoke EXIT

/bin/mkdir -p "$smoke_state/home" "$smoke_state/tmp" "$smoke_state/data"
CFFIXED_USER_HOME="$smoke_state/home" \
TMPDIR="$smoke_state/tmp" \
PRAXODORO_STATE_ROOT="$smoke_state/data" \
  "$smoke_binary" -PraxodoroSmokeMode YES >"$smoke_log" 2>&1 &
smoke_pid=$!

/bin/sleep 5
if ! /bin/kill -0 "$smoke_pid" 2>/dev/null; then
  echo "ERROR: Praxodoro exited before the smoke probe completed" >&2
  exit 1
fi

/bin/kill -TERM "$smoke_pid"
set +e
wait "$smoke_pid"
smoke_status=$?
set -e
smoke_pid=""

if [[ "$smoke_status" -ne 0 && "$smoke_status" -ne 143 ]]; then
  echo "ERROR: unexpected Praxodoro termination status: $smoke_status" >&2
  exit 1
fi

if /usr/bin/grep -Eiq 'fatal error|uncaught exception|crash' "$smoke_log"; then
  echo "ERROR: fatal marker found in smoke log: $smoke_log" >&2
  exit 1
fi

echo "SCAFFOLD_SMOKE_OK log=$smoke_log termination=$smoke_status"
```

Make both executable.

### Step 8: Run fresh GREEN evidence

```bash
chmod +x scripts/run-app-tests.sh scripts/smoke-scaffold.sh
bash scripts/verify-scaffold.sh
swift test --package-path Packages/PraxodoroCore
xcodebuild \
  -project Praxodoro.xcodeproj \
  -scheme Praxodoro \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  build CODE_SIGNING_ALLOWED=NO
bash scripts/run-app-tests.sh
bash scripts/smoke-scaffold.sh
```

Required GREEN: scaffold toolchain/target proof, named SwiftPM test, unsigned build, executed app
unit/UI evidence including `applicationUsesCoreProductIdentity` and
`testLaunchesInitiateSurface`, a Passed summary with zero failures and at least three executed
tests, and an isolated smoke log with explicit termination status. If local test signing fails,
stop and record the empirical blocker; never skip UI tests or add `CODE_SIGNING_ALLOWED=NO` to the
test driver without evidence.

### Step 9: Commit and post-commit verify

```bash
git add .xcodegen-version project.yml scripts/bootstrap-xcodegen.sh \
  scripts/verify-scaffold.sh scripts/run-app-tests.sh scripts/smoke-scaffold.sh \
  Packages PraxodoroApp PraxodoroTests PraxodoroUITests Praxodoro.xcodeproj \
  BLUEPRINT.md docs/superpowers/plans/2026-07-20-native-scaffold.md \
  openspec/changes/build-native-praxodoro/design.md \
  openspec/changes/build-native-praxodoro/tasks.md prd.json progress.txt \
  .agent/evidence/atom-1.1-native-scaffold.md \
  .agent/evidence/atom-1.1-app-test-receipt.json
git diff --cached --name-status
git commit -m "chore: scaffold native macOS app"
git status --short -- project.yml Praxodoro.xcodeproj Packages PraxodoroApp \
  PraxodoroTests PraxodoroUITests scripts BLUEPRINT.md \
  docs/superpowers/plans/2026-07-20-native-scaffold.md \
  openspec/changes/build-native-praxodoro/design.md \
  openspec/changes/build-native-praxodoro/tasks.md prd.json progress.txt \
  .agent/evidence
```

Expected pre-commit staged manifest: only the scaffold implementation/generated project, its
aligned canonical checksum/status changes, concise progress summary, and compact test receipt.
Progress entries for scratch atoms are approved audit history only;
they do not credit or integrate later implementation. Expected post-commit status: empty for every
listed atom/canonical/evidence path.

---

## Task 2: OpenSpec 1.2 — Strict Quality, Provenance, and Regeneration

**Create:** `.swift-format`, `docs/engineering/dependencies.md`,
`scripts/verify-project-generation.sh`. **Modify:** `project.yml`, `README.md`, generated project.

### Step 1: Write the verifier and observe the provenance RED

Create `scripts/verify-project-generation.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

generation_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$generation_root"

[[ -f docs/engineering/dependencies.md ]] || {
  echo "ERROR: missing dependency provenance" >&2
  exit 1
}

xcode_version="$(xcodebuild -version | /usr/bin/sed -n '1s/^Xcode //p')"
swift_version="$(swift --version | /usr/bin/sed -n 's/.*Swift version \([^ ]*\).*/\1/p' | /usr/bin/head -1)"
format_version="$(xcrun swift-format --version)"
xcodegen_binary="$(bash scripts/bootstrap-xcodegen.sh)"
xcodegen_output="$("$xcodegen_binary" --version)"

[[ "$xcode_version" == "26.6" ]] || { echo "ERROR: Xcode $xcode_version" >&2; exit 1; }
[[ "$swift_version" == "6.3.3" ]] || { echo "ERROR: Swift $swift_version" >&2; exit 1; }
[[ "$format_version" == "6.3.0" ]] || { echo "ERROR: swift-format $format_version" >&2; exit 1; }
[[ "$xcodegen_output" == "Version: 2.46.0" ]] || {
  echo "ERROR: $xcodegen_output" >&2
  exit 1
}

/bin/mkdir -p .build
snapshot_root="$(/usr/bin/mktemp -d "$generation_root/.build/xcodegen-snapshot.XXXXXX")"
snapshot_project="$snapshot_root/Praxodoro.xcodeproj"
/usr/bin/ditto Praxodoro.xcodeproj "$snapshot_project"

cleanup_snapshot() {
  case "$snapshot_root" in
    "$generation_root"/.build/xcodegen-snapshot.*) /bin/rm -rf -- "$snapshot_root" ;;
    *) echo "ERROR: refusing unexpected snapshot cleanup path" >&2 ;;
  esac
}
trap cleanup_snapshot EXIT

"$xcodegen_binary" generate --spec project.yml
if ! /usr/bin/diff -qr "$snapshot_project" Praxodoro.xcodeproj; then
  echo "ERROR: XcodeGen output changed during no-diff regeneration" >&2
  exit 1
fi

xcrun swift-format lint --configuration .swift-format --strict \
  Packages/PraxodoroCore/Package.swift
xcrun swift-format lint --configuration .swift-format --recursive --strict \
  Packages/PraxodoroCore/Sources Packages/PraxodoroCore/Tests \
  PraxodoroApp PraxodoroTests PraxodoroUITests

echo "PROJECT_GENERATION_OK xcode=26.6 swift=6.3.3 xcodegen=2.46.0 swift-format=6.3.0"
```

```bash
chmod +x scripts/verify-project-generation.sh
bash scripts/verify-project-generation.sh
```

Expected RED: `ERROR: missing dependency provenance`.

### Step 2: Add formatter policy and exact provenance

Create `.swift-format`:

```json
{
  "indentation": { "spaces": 2 },
  "lineLength": 100,
  "maximumBlankLines": 1,
  "multiElementCollectionTrailingCommas": true,
  "orderedImports": { "includeConditionalImports": false },
  "rules": {
    "AlwaysUseLowerCamelCase": true,
    "DoNotUseSemicolons": true,
    "IdentifiersMustBeASCII": true,
    "NoBlockComments": true,
    "OrderedImports": true,
    "UseTripleSlashForDocumentationComments": true
  },
  "version": 1
}
```

Create `docs/engineering/dependencies.md`:

```markdown
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
```

### Step 3: Enable strict project compilation and accept the intended generated delta

Add under top-level `settings.base` in `project.yml`:

```yaml
    SWIFT_STRICT_CONCURRENCY: complete
    SWIFT_TREAT_WARNINGS_AS_ERRORS: YES
    GCC_TREAT_WARNINGS_AS_ERRORS: YES
```

Generate once to intentionally update the committed project candidate:

```bash
xcodegen_binary="$(bash scripts/bootstrap-xcodegen.sh)"
"$xcodegen_binary" generate --spec project.yml
git diff --check -- project.yml Praxodoro.xcodeproj
```

Append to `README.md` using a four-backtick outer fence so the inner shell block remains valid:

````markdown
## Native foundation commands

```bash
bash scripts/bootstrap-xcodegen.sh
bash scripts/verify-scaffold.sh
bash scripts/verify-project-generation.sh
swift test --package-path Packages/PraxodoroCore
xcodebuild -project Praxodoro.xcodeproj -scheme Praxodoro \
  -destination 'platform=macOS' -derivedDataPath .build/DerivedData \
  build CODE_SIGNING_ALLOWED=NO
bash scripts/run-app-tests.sh
bash scripts/smoke-scaffold.sh
```
````

### Step 4: Format and run the complete GREEN gate

```bash
xcrun swift-format format --configuration .swift-format --in-place \
  Packages/PraxodoroCore/Package.swift
xcrun swift-format format --configuration .swift-format --recursive --in-place \
  Packages/PraxodoroCore/Sources Packages/PraxodoroCore/Tests \
  PraxodoroApp PraxodoroTests PraxodoroUITests
bash scripts/verify-project-generation.sh
swift test --package-path Packages/PraxodoroCore
xcodebuild \
  -project Praxodoro.xcodeproj \
  -scheme Praxodoro \
  -destination 'platform=macOS' \
  -derivedDataPath .build/DerivedData \
  build CODE_SIGNING_ALLOWED=NO
bash scripts/run-app-tests.sh
bash scripts/smoke-scaffold.sh
```

Required GREEN: actual tool versions, byte-stable recursive project generation, lint over only
source paths, strict package/app compilation, executed unit/UI suites, and isolated smoke.

### Step 5: Commit and prove clean generation after the commit

```bash
git add .swift-format docs/engineering/dependencies.md \
  scripts/verify-project-generation.sh project.yml Praxodoro.xcodeproj README.md \
  Packages PraxodoroApp PraxodoroTests PraxodoroUITests
git commit -m "chore: enforce native project quality gates"
bash scripts/verify-project-generation.sh
git status --short -- project.yml Praxodoro.xcodeproj
```

Expected post-commit status: empty for both generator source and output.

## Plan Verification Checklist

- [ ] No Homebrew/global XcodeGen mutation.
- [ ] Exact tag commit, archive checksum, and extracted executable checksum match official release evidence.
- [ ] Cached executable tampering fails closed before the executable is invoked; interrupted-download cleanup is confined to the exact `.download.*` temporary directory.
- [ ] No `jq` dependency.
- [ ] Package warnings are errors from Task 1; app warnings become errors in Task 2.
- [ ] App unit and UI tests both execute, not only compile.
- [ ] Unsigned build proof remains separate from local test-signing proof.
- [ ] Smoke storage is unique and safely cleaned; fatal markers and termination are evaluated.
- [ ] `initiate.heading` has heading semantics and is found by XCUITest.
- [ ] Regeneration compares pre/post directories and post-commit Git state separately.
- [ ] Formatter never traverses SwiftPM `.build` output.
