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
