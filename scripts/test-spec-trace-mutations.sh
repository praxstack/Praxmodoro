#!/usr/bin/env bash
set -euo pipefail

source_repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
audit_root="$(/usr/bin/mktemp -d /tmp/praxodoro-trace-mutations.XXXXXX)"
candidate_repo="$audit_root/candidate"

cleanup() {
  case "$audit_root" in
    /tmp/praxodoro-trace-mutations.*) /bin/rm -rf -- "$audit_root" ;;
    *) echo "ERROR: refusing unexpected mutation-test cleanup path: $audit_root" >&2 ;;
  esac
}
trap cleanup EXIT

git clone --shared --no-hardlinks --quiet "$source_repo" "$candidate_repo"
git -C "$candidate_repo" config user.name "Praxodoro Trace Mutation Test"
git -C "$candidate_repo" config user.email "trace-mutation@example.invalid"
git -C "$candidate_repo" config commit.gpgsign false

if [[ -n "$(git -C "$source_repo" diff --cached --name-only)" ]]; then
  if ! git -C "$source_repo" diff --quiet || \
    [[ -n "$(git -C "$source_repo" ls-files --others --exclude-standard)" ]]; then
    echo "FAIL: staged mutation candidate has unstaged or untracked paths" >&2
    exit 1
  fi
  git -C "$source_repo" diff --cached --binary HEAD >"$audit_root/current-candidate.patch"
else
  git -C "$source_repo" diff --binary HEAD >"$audit_root/current-candidate.patch"
fi

node --input-type=module - "$source_repo" >"$audit_root/semantic-candidates" <<'NODE'
import { execFileSync } from "node:child_process";

const sourceRepo = process.argv[2];
const reservedSubject = "docs: accept session domain contract";
const fields = execFileSync(
  "git",
  ["-C", sourceRepo, "log", "--reverse", "--format=%H%x00%s", "-z", "HEAD"],
).toString("utf8").split("\0");
for (let index = 0; index + 1 < fields.length; index += 2) {
  if (fields[index + 1] === reservedSubject) console.log(fields[index]);
}
NODE

semantic_base=""
accepted_base_output=""
if [[ -s "$audit_root/semantic-candidates" ]]; then
  while IFS= read -r candidate; do
    git -C "$candidate_repo" -c advice.detachedHead=false \
      checkout --quiet --detach "$candidate"
    if accepted_base_output="$(
      cd "$candidate_repo" && node "$source_repo/scripts/verify-spec-trace.mjs"
    )" && [[ "$accepted_base_output" == *"Semantic gate=done."* ]]; then
      semantic_base="$candidate"
      break
    fi
  done <"$audit_root/semantic-candidates"
  if [[ -z "$semantic_base" ]]; then
    echo "FAIL: no exact-subject acceptance is valid under the current verifier" >&2
    exit 1
  fi
elif [[ -s "$audit_root/current-candidate.patch" ]]; then
  git -C "$candidate_repo" apply "$audit_root/current-candidate.patch"
  /bin/cp "$source_repo/scripts/test-spec-trace-mutations.sh" \
    "$candidate_repo/scripts/test-spec-trace-mutations.sh"
  /bin/cp "$source_repo/scripts/verify-spec-trace.mjs" \
    "$candidate_repo/scripts/verify-spec-trace.mjs"
fi
/bin/cp "$source_repo/scripts/test-spec-trace-mutations.sh" \
  "$candidate_repo/scripts/test-spec-trace-mutations.sh"
/bin/cp "$source_repo/scripts/verify-spec-trace.mjs" \
  "$candidate_repo/scripts/verify-spec-trace.mjs"
(
  cd "$candidate_repo"
  node --input-type=module <<'NODE'
import { readFileSync, writeFileSync } from "node:fs";

const prd = JSON.parse(readFileSync("prd.json", "utf8"));
prd.semanticContractGate.status = "in_review";
prd.semanticContractGate.evidence = [
  "docs/specification/session-domain-contract.md",
  "docs/specification/acceptance-trace.md",
  "scripts/verify-spec-trace.mjs",
];
const atom = prd.atoms.find((candidate) => candidate.id === "3.1");
if (atom.status !== "done" && atom.status !== "todo") {
  prd.counts[atom.status] -= 1;
  prd.counts.todo += 1;
  atom.status = "todo";
  atom.evidence = null;
}
writeFileSync("prd.json", `${JSON.stringify(prd, null, 2)}\n`);
NODE
)
git -C "$candidate_repo" add -A
git -C "$candidate_repo" commit --quiet --allow-empty -m "test: seed semantic gate in review"

assert_in_review_blocked() {
  local output="$1"
  local label="$2"
  if [[ "$output" != *"Semantic gate=in_review;"* ]] || \
    { [[ "$output" != *"initial Atom 3.1 entry BLOCKED."* ]] && \
      [[ "$output" != *"reopened gate remains unaccepted."* ]]; }; then
    echo "FAIL: $label did not report an explicit in-review semantic block" >&2
    exit 1
  fi
}

assert_failure_contains() {
  local output_path="$1"
  local label="$2"
  local expected="$3"
  local expected_bullets="${4:-}"
  if ! /usr/bin/grep -Fq -- "$expected" "$output_path"; then
    echo "FAIL: $label did not emit the expected diagnostic: $expected" >&2
    /bin/cat "$output_path" >&2
    exit 1
  fi
  if [[ -n "$expected_bullets" ]]; then
    local actual_bullets
    actual_bullets="$(/usr/bin/grep -c '^- ' "$output_path" || true)"
    if [[ "$actual_bullets" != "$expected_bullets" ]]; then
      echo "FAIL: $label emitted $actual_bullets failure bullets; expected $expected_bullets" >&2
      /bin/cat "$output_path" >&2
      exit 1
    fi
  fi
}

baseline_output="$(cd "$candidate_repo" && node scripts/verify-spec-trace.mjs)"
assert_in_review_blocked "$baseline_output" "deterministic baseline"

contract_repo="$audit_root/contract-mutation"
git clone --shared --no-hardlinks --quiet "$candidate_repo" "$contract_repo"
(
  cd "$contract_repo"
  node --input-type=module <<'NODE'
import { readFileSync, writeFileSync } from "node:fs";

const path = "docs/specification/session-domain-contract.md";
const before = "public static let askBeforeAnotherBlock = true";
const after = "public static let askBeforeAnotherBlock = false";
const body = readFileSync(path, "utf8");
const occurrenceCount = body.split(before).length - 1;
if (occurrenceCount !== 1 || body.includes(after)) {
  throw new Error(
    `Expected exactly one unmutated contract target; found ${occurrenceCount}`,
  );
}
const mutated = body.replace(before, after);
if (mutated.includes(before) || mutated.split(after).length - 1 !== 1) {
  throw new Error("Contract mutation did not replace exactly one target");
}
writeFileSync(path, mutated);
NODE
)
contract_output="$(cd "$contract_repo" && node scripts/verify-spec-trace.mjs)"
assert_in_review_blocked "$contract_output" "mutable contract"

subject_repo="$audit_root/reserved-subject"
git clone --shared --no-hardlinks --quiet "$candidate_repo" "$subject_repo"
git -C "$subject_repo" config user.name "Praxodoro Trace Mutation Test"
git -C "$subject_repo" config user.email "trace-mutation@example.invalid"
git -C "$subject_repo" config commit.gpgsign false
git -C "$subject_repo" commit --quiet --allow-empty -m "docs: accept session domain contract"
(
  cd "$subject_repo"
  if node scripts/verify-spec-trace.mjs >"$audit_root/reserved-subject.out" 2>&1; then
    echo "FAIL: invalid reserved-subject commit bypassed the semantic acceptance guard" >&2
    exit 1
  fi
  assert_failure_contains \
    "$audit_root/reserved-subject.out" \
    "invalid reserved-subject commit" \
    "latest reserved semantic-gate commit is invalid:" \
    1
)

atom_start_repo="$audit_root/in-review-atom-start"
git clone --shared --no-hardlinks --quiet "$candidate_repo" "$atom_start_repo"
(
  cd "$atom_start_repo"
  node --input-type=module <<'NODE'
import { readFileSync, writeFileSync } from "node:fs";

const prd = JSON.parse(readFileSync("prd.json", "utf8"));
const atom = prd.atoms.find((candidate) => candidate.id === "3.1");
const priorStatus = atom.status;
atom.status = "doing";
atom.evidence = null;
prd.counts[priorStatus] -= 1;
prd.counts.doing += 1;
writeFileSync("prd.json", `${JSON.stringify(prd, null, 2)}\n`);
NODE
  if node scripts/verify-spec-trace.mjs >"$audit_root/in-review-atom-start.out" 2>&1; then
    echo "FAIL: in-review semantic gate allowed incomplete Atom 3.1 to start" >&2
    exit 1
  fi
  assert_failure_contains \
    "$audit_root/in-review-atom-start.out" \
    "in-review Atom 3.1 start" \
    "Atom 3.1 must remain incomplete with no evidence while semanticContractGate is in_review" \
    1
)

mode_repo="$audit_root/mode-reacceptance"
git clone --shared --no-hardlinks --quiet "$candidate_repo" "$mode_repo"
git -C "$mode_repo" config user.name "Praxodoro Trace Mutation Test"
git -C "$mode_repo" config user.email "trace-mutation@example.invalid"
git -C "$mode_repo" config commit.gpgsign false
(
  cd "$mode_repo"
  node --input-type=module <<'NODE'
import { appendFileSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";

const receivingPath = ".agent/reviews/semantic-contract-receiving-review.md";
const candidateEvidence = [
  "docs/specification/session-domain-contract.md",
  "docs/specification/acceptance-trace.md",
  "scripts/verify-spec-trace.mjs",
];
const acceptedEvidence = [
  ...candidateEvidence,
  ".agent/reviews/semantic-contract-review.md",
  ".agent/reviews/acceptance-trace-review.md",
  ".agent/council/semantic-contract-shipping-council.md",
  receivingPath,
  ".agent/evidence/semantic-contract-gate.md",
];
const transitionPaths = [
  ".agent/council/semantic-contract-shipping-council.md",
  ".agent/evidence/semantic-contract-gate.md",
  ".agent/reviews/acceptance-trace-review.md",
  receivingPath,
  ".agent/reviews/semantic-contract-review.md",
  "docs/specification/session-domain-contract.md",
  "prd.json",
  "progress.txt",
];
const capabilityNames = [
  "adhd-aware-coach",
  "edition-capabilities",
  "focus-session-engine",
  "liquid-instrument-experience",
  "local-data-control",
  "macos-app-delivery",
];
const subjectPaths = [
  "SPEC.md",
  "BLUEPRINT.md",
  "README.md",
  "prd.json",
  "progress.txt",
  "package.json",
  "package-lock.json",
  "docs/engineering/dependencies.md",
  "docs/specification/session-domain-contract.md",
  "docs/specification/acceptance-trace.md",
  "docs/superpowers/plans/2026-07-21-session-domain.md",
  "scripts/verify-spec-trace.mjs",
  "scripts/test-spec-trace-mutations.sh",
  ".agent/evidence/atom-1.1-native-scaffold.md",
  ".agent/evidence/atom-1.2-native-quality.md",
  ".agent/evidence/atom-2.1-edition-catalog.md",
  ".agent/evidence/atom-2.2-validated-product-access.md",
  "openspec/changes/build-native-praxodoro/proposal.md",
  "openspec/changes/build-native-praxodoro/design.md",
  "openspec/changes/build-native-praxodoro/tasks.md",
  ...capabilityNames.map(
    (name) => `openspec/changes/build-native-praxodoro/specs/${name}/spec.md`,
  ),
];

function git(args) {
  return execFileSync("git", args);
}
function sorted(values) {
  return [...values].sort((left, right) => left.localeCompare(right));
}
function indexMode(path) {
  const row = git(["ls-files", "--stage", "--", path]).toString("utf8").trim();
  const mode = row.match(/^(\d{6})\s/)?.[1];
  if (!mode) throw new Error(`No index mode for ${path}`);
  return mode;
}
function indexContent(path) {
  return git(["show", `:${path}`]);
}
function fileDigest(paths) {
  const hash = createHash("sha256");
  for (const path of paths) {
    hash.update(path);
    hash.update("\0");
    hash.update(indexMode(path));
    hash.update("\0");
    hash.update(indexContent(path));
    hash.update("\0");
  }
  return hash.digest("hex");
}
function allowlistDigest(paths) {
  const hash = createHash("sha256");
  for (const path of paths) {
    hash.update(path);
    hash.update("\0");
    hash.update("");
    hash.update("\0");
  }
  return hash.digest("hex");
}

const prd = JSON.parse(readFileSync("prd.json", "utf8"));
prd.semanticContractGate.status = "done";
prd.semanticContractGate.evidence = acceptedEvidence;
writeFileSync("prd.json", `${JSON.stringify(prd, null, 2)}\n`);
appendFileSync(
  "docs/specification/session-domain-contract.md",
  "\n<!-- isolated synthetic acceptance revision -->\n",
);
appendFileSync(
  "progress.txt",
  "\n2099-01-01T00:00:00Z | actor=trace-mutation | atom=semantic-gate | TEST_ONLY | isolated acceptance\n",
);
mkdirSync(".agent/reviews", { recursive: true });
mkdirSync(".agent/council", { recursive: true });
mkdirSync(".agent/evidence", { recursive: true });

const placeholder = "PLACEHOLDER";
writeFileSync(
  ".agent/reviews/semantic-contract-review.md",
  `Verdict: READY\nSubject SHA-256: ${placeholder}\n`,
);
writeFileSync(
  ".agent/reviews/acceptance-trace-review.md",
  `Verdict: READY\nSubject SHA-256: ${placeholder}\n`,
);
writeFileSync(
  ".agent/council/semantic-contract-shipping-council.md",
  `Chairman verdict: SHIP\nSubject SHA-256: ${placeholder}\n`,
);
writeFileSync(
  ".agent/evidence/semantic-contract-gate.md",
  `Gate status: ACCEPTED\nSubject SHA-256: ${placeholder}\n`,
);
writeFileSync(
  receivingPath,
  [
    "Verdict: ACCEPT",
    `Subject SHA-256: ${placeholder}`,
    `Staged subject SHA-256: ${placeholder}`,
    `Staged allowlist SHA-256: ${placeholder}`,
    `Staged payload SHA-256: ${placeholder}`,
    "",
  ].join("\n"),
);
git(["add", ...transitionPaths]);

const subjectDigest = fileDigest(subjectPaths);
writeFileSync(
  ".agent/reviews/semantic-contract-review.md",
  `Verdict: READY\nSubject SHA-256: ${subjectDigest}\n`,
);
writeFileSync(
  ".agent/reviews/acceptance-trace-review.md",
  `Verdict: READY\nSubject SHA-256: ${subjectDigest}\n`,
);
writeFileSync(
  ".agent/council/semantic-contract-shipping-council.md",
  `Chairman verdict: SHIP\nSubject SHA-256: ${subjectDigest}\n`,
);
writeFileSync(
  ".agent/evidence/semantic-contract-gate.md",
  `Gate status: ACCEPTED\nSubject SHA-256: ${subjectDigest}\n`,
);
writeFileSync(
  receivingPath,
  [
    "Verdict: ACCEPT",
    `Subject SHA-256: ${subjectDigest}`,
    `Staged subject SHA-256: ${subjectDigest}`,
    `Staged allowlist SHA-256: ${placeholder}`,
    `Staged payload SHA-256: ${placeholder}`,
    "",
  ].join("\n"),
);
git([
  "add",
  ".agent/reviews/semantic-contract-review.md",
  ".agent/reviews/acceptance-trace-review.md",
  ".agent/council/semantic-contract-shipping-council.md",
  ".agent/evidence/semantic-contract-gate.md",
  receivingPath,
]);
const stagedPaths = sorted(
  git(["diff", "--cached", "--no-renames", "--name-only", "-z"])
    .toString("utf8")
    .split("\0")
    .filter(Boolean),
);
const payloadPaths = stagedPaths.filter((path) => path !== receivingPath);
const payloadDigest = fileDigest(payloadPaths);
const stagedAllowlistDigest = allowlistDigest(stagedPaths);
writeFileSync(
  receivingPath,
  [
    "Verdict: ACCEPT",
    `Subject SHA-256: ${subjectDigest}`,
    `Staged subject SHA-256: ${subjectDigest}`,
    `Staged allowlist SHA-256: ${stagedAllowlistDigest}`,
    `Staged payload SHA-256: ${payloadDigest}`,
    "",
  ].join("\n"),
);
git(["add", receivingPath]);
NODE

  git diff --cached --check
  node scripts/verify-spec-trace.mjs >/dev/null
  git commit --quiet -m "docs: accept session domain contract"
  node scripts/verify-spec-trace.mjs >/dev/null

  node --input-type=module <<'NODE'
import { readFileSync, writeFileSync } from "node:fs";

const prd = JSON.parse(readFileSync("prd.json", "utf8"));
prd.semanticContractGate.status = "in_review";
prd.semanticContractGate.evidence = [
  "docs/specification/session-domain-contract.md",
  "docs/specification/acceptance-trace.md",
  "scripts/verify-spec-trace.mjs",
];
writeFileSync("prd.json", `${JSON.stringify(prd, null, 2)}\n`);
NODE
  node scripts/verify-spec-trace.mjs >/dev/null
  git add prd.json
  git commit --quiet -m "chore: reopen semantic gate"
  node scripts/verify-spec-trace.mjs >/dev/null

  reopened_atom_repo="$audit_root/reopened-atom"
  git clone --shared --no-hardlinks --quiet "$mode_repo" "$reopened_atom_repo"
  (
    cd "$reopened_atom_repo"
    node --input-type=module <<'NODE'
import { readFileSync, writeFileSync } from "node:fs";

const prd = JSON.parse(readFileSync("prd.json", "utf8"));
const atom = prd.atoms.find((candidate) => candidate.id === "3.1");
const priorStatus = atom.status;
atom.status = "doing";
atom.evidence = null;
prd.counts[priorStatus] -= 1;
prd.counts.doing += 1;
writeFileSync("prd.json", `${JSON.stringify(prd, null, 2)}\n`);
NODE
    if node scripts/verify-spec-trace.mjs >"$audit_root/reopened-atom.out" 2>&1; then
      echo "FAIL: reopened semantic gate allowed incomplete Atom 3.1 to start" >&2
      exit 1
    fi
    assert_failure_contains \
      "$audit_root/reopened-atom.out" \
      "reopened-gate Atom 3.1 start" \
      "Atom 3.1 must remain incomplete with no evidence while semanticContractGate is in_review" \
      1
  )

  node --input-type=module <<'NODE'
import { readFileSync, writeFileSync } from "node:fs";

const prd = JSON.parse(readFileSync("prd.json", "utf8"));
prd.semanticContractGate.status = "done";
prd.semanticContractGate.evidence = [
  "docs/specification/session-domain-contract.md",
  "docs/specification/acceptance-trace.md",
  "scripts/verify-spec-trace.mjs",
  ".agent/reviews/semantic-contract-review.md",
  ".agent/reviews/acceptance-trace-review.md",
  ".agent/council/semantic-contract-shipping-council.md",
  ".agent/reviews/semantic-contract-receiving-review.md",
  ".agent/evidence/semantic-contract-gate.md",
];
writeFileSync("prd.json", `${JSON.stringify(prd, null, 2)}\n`);
NODE
  git add prd.json
  if node scripts/verify-spec-trace.mjs >"$audit_root/mode-reacceptance.out" 2>&1; then
    echo "FAIL: stale historical receipts accepted a prd.json-only reacceptance" >&2
    exit 1
  fi
  assert_failure_contains \
    "$audit_root/mode-reacceptance.out" \
    "incomplete working-tree reacceptance" \
    "accepted semantic gate staged paths violate the required/allowed transition manifest"
  git commit --quiet -m "chore: unauthorized mode-only semantic reacceptance"
  if node scripts/verify-spec-trace.mjs >"$audit_root/postcommit-mode-reacceptance.out" 2>&1; then
    echo "FAIL: committed mode-only reacceptance reused stale historical receipts" >&2
    exit 1
  fi
  assert_failure_contains \
    "$audit_root/postcommit-mode-reacceptance.out" \
    "committed unauthorized reacceptance" \
    "current done state requires a newer fully validated reserved acceptance commit" \
    1
)

echo "SPEC_TRACE_MUTATIONS_OK cases=6 semantic-in-review=blocked invalid-reserved-subject=rejected atom-start=blocked reopened-atom=rejected incomplete-reacceptance=rejected postcommit-reacceptance=rejected"
