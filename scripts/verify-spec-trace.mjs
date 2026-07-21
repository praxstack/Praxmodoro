#!/usr/bin/env node

import { existsSync, lstatSync, readFileSync, readdirSync } from "node:fs";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { join, relative } from "node:path";
import process from "node:process";

const root = process.cwd();
const failures = [];
const profileRegistry = [
  "governance",
  "core-unit",
  "repository-contract",
  "app-integration",
  "signed-ui",
  "accessibility-manual",
  "privacy-static",
  "privacy-runtime",
  "visual-regression",
  "performance-energy",
  "fresh-validator",
];
const allowedProfiles = new Set(profileRegistry);
const capabilityPrefixes = new Map([
  ["adhd-aware-coach", ["AHC", 21]],
  ["edition-capabilities", ["EDC", 19]],
  ["focus-session-engine", ["FSE", 25]],
  ["liquid-instrument-experience", ["LIE", 20]],
  ["local-data-control", ["LDC", 22]],
  ["macos-app-delivery", ["MAD", 15]],
]);
function read(path) {
  return readFileSync(join(root, path), "utf8");
}

function fail(message) {
  failures.push(message);
}

function range(prefix, count) {
  return Array.from({ length: count }, (_, index) => prefix + String(index + 1).padStart(3, "0"));
}

function sorted(values) {
  return [...values].sort((left, right) => left.localeCompare(right));
}

function sameMembers(left, right) {
  return JSON.stringify(sorted(left)) === JSON.stringify(sorted(right));
}

function sameOrder(left, right) {
  return JSON.stringify([...left]) === JSON.stringify([...right]);
}

function digestEntries(entries) {
  const hash = createHash("sha256");
  for (const [key, value] of entries) {
    hash.update(key);
    hash.update("\0");
    hash.update(value);
    hash.update("\0");
  }
  return hash.digest("hex");
}

function digestFileEntries(entries) {
  const hash = createHash("sha256");
  for (const [path, mode, value] of entries) {
    hash.update(path);
    hash.update("\0");
    hash.update(mode);
    hash.update("\0");
    hash.update(value);
    hash.update("\0");
  }
  return hash.digest("hex");
}

function workingTreeMode(path) {
  const mode = lstatSync(join(root, path)).mode;
  return mode & 0o111 ? "100755" : "100644";
}

function workingTreeDigest(paths) {
  return digestFileEntries(
    paths.map((path) => [path, workingTreeMode(path), readFileSync(join(root, path))]),
  );
}

function readIndex(path) {
  return execFileSync("git", ["show", ":" + path], { cwd: root });
}

function readIndexMode(path) {
  const row = execFileSync("git", ["ls-files", "--stage", "--", path], { cwd: root })
    .toString("utf8")
    .trim();
  const mode = row.match(/^(\d{6})\s/)?.[1];
  if (!mode) throw new Error("Git index mode unavailable for " + path);
  return mode;
}

function indexDigest(paths) {
  return digestFileEntries(paths.map((path) => [path, readIndexMode(path), readIndex(path)]));
}

function readCommit(commit, path) {
  return execFileSync("git", ["show", commit + ":" + path], { cwd: root });
}

function readCommitMode(commit, path) {
  const row = execFileSync("git", ["ls-tree", commit, "--", path], { cwd: root })
    .toString("utf8")
    .trim();
  const mode = row.match(/^(\d{6})\s/)?.[1];
  if (!mode) throw new Error("Git commit mode unavailable for " + path);
  return mode;
}

function commitDigest(commit, paths) {
  return digestFileEntries(
    paths.map((path) => [path, readCommitMode(commit, path), readCommit(commit, path)]),
  );
}

function commitsWithExactSubject(subject) {
  const rows = execFileSync("git", ["log", "--format=%H%x09%s", "HEAD"], { cwd: root })
    .toString("utf8")
    .split(/\r?\n/)
    .filter(Boolean);
  return rows
    .map((row) => row.split("\t"))
    .filter(([, candidate]) => candidate === subject)
    .map(([commit]) => commit);
}

function hasExactField(body, label, expectedValue) {
  const prefix = label + ":";
  const fields = body
    .split(/\r?\n/)
    .filter((line) => line.startsWith(prefix));
  return fields.length === 1 && fields[0] === prefix + " " + expectedValue;
}

const expectedCriteria = [
  ...range("S-", 3),
  ...range("E-", 10),
  ...range("C-", 10),
  ...range("G-", 7),
  ...range("U-", 10),
  ...range("P-", 10),
  ...range("D-", 7),
];
const expectedAssumptions = range("A-", 12);
const expectedScenarioIDs = [];
for (const [, [prefix, count]] of capabilityPrefixes) {
  expectedScenarioIDs.push(...range(prefix + "-S", count));
}

const expectedAtoms = new Map();
function atom(id, dependsOn, criteria) {
  expectedAtoms.set(id, { dependsOn: dependsOn.split(" ").filter(Boolean), criteria: criteria.split(" ").filter(Boolean) });
}
atom("1.1", "", "D-001 D-004");
atom("1.2", "1.1", "D-001 D-002");
atom("2.1", "1.1", "G-001 G-002 G-006");
atom("2.2", "2.1", "G-002 G-003 G-004 G-005 G-006");
atom("3.1", "2.1", "E-001 E-003 E-004 G-001");
atom("3.2", "3.1 3.3", "E-001 E-003 E-004 E-005 E-006 E-007 E-008 E-009 C-001 C-002 C-003 C-004 C-005 C-006 C-009 C-010 G-001");
atom("3.3", "3.1", "E-004 E-005 E-006 E-007 E-008 G-001");
atom("4.1", "2.2 3.2 3.3", "E-001 E-002 E-003 E-005 E-006 E-007 E-008 E-010 G-001");
atom("4.2", "1.1 4.1", "E-001 E-007 E-010 C-007 G-001 P-001 P-003 P-009 P-010");
atom("5.1", "1.1", "G-001 U-001 U-002 U-003 U-004 U-005 U-008 U-010");
atom("5.2", "2.2 4.1 4.2 5.1", "E-002 C-009 G-001 G-004 G-005 G-007 U-006 U-009 D-002");
atom("5.3", "3.2 3.3 5.2", "E-001 E-004 E-009 C-001 C-002 C-007 C-010 G-001 U-001 U-006 U-008");
atom("5.4", "5.3", "C-003 C-004 C-005 C-006 C-008 C-009 C-010 G-001 U-006 U-007");
atom("5.5", "5.1 5.2 5.3", "G-001 U-006 U-009");
atom("6.1", "3.2 4.2", "C-008 G-001 P-001 P-003 P-009 P-010");
atom("6.2", "4.1 5.2", "E-010 G-001 P-004 P-007");
atom("6.3", "4.2 6.1", "G-001 G-004 P-005 P-006 P-010");
atom("7.1", "5.1 5.4 5.5", "C-007 G-001 U-001 U-002 U-003 U-004 U-005 U-006 U-007 U-008 U-009");
atom("7.2", "6.1 6.2 6.3 7.1", "E-004 G-001 U-005 U-010 P-002 P-007 P-008 D-005");
atom("8.1", "1.2 7.2", "S-001 S-002 D-001 D-002 D-003 D-004 D-005");
atom("8.2", "8.1", "S-003 D-003 D-004 D-005 D-006 D-007");
const expectedExecutionOrder = [
  "1.1", "1.2", "2.1", "2.2", "3.1", "3.3", "3.2", "4.1", "4.2", "5.1", "5.2",
  "5.3", "5.4", "5.5", "6.1", "6.2", "6.3", "7.1", "7.2", "8.1", "8.2",
];

const expectedScenarioAssignments = new Map();
function scenarios(ids, criteria, relationship) {
  for (const id of ids.split(" ").filter(Boolean)) {
    expectedScenarioAssignments.set(id, {
      criteria: criteria.split(" ").filter(Boolean),
      relationship,
    });
  }
}
scenarios("AHC-S001", "C-010", "direct");
scenarios("AHC-S002 AHC-S003", "C-001", "direct");
scenarios("AHC-S004 AHC-S005", "C-002", "direct");
scenarios("AHC-S006", "C-002", "supporting");
scenarios("AHC-S007", "C-010", "direct");
scenarios("AHC-S008", "C-003", "direct");
scenarios("AHC-S009", "C-004", "direct");
scenarios("AHC-S010", "C-003", "supporting");
scenarios("AHC-S011", "C-006", "direct");
scenarios("AHC-S012", "C-002 C-006", "supporting");
scenarios("AHC-S013 AHC-S014", "C-005", "direct");
scenarios("AHC-S015", "C-006", "direct");
scenarios("AHC-S016 AHC-S017", "C-007", "direct");
scenarios("AHC-S018 AHC-S019", "C-008", "direct");
scenarios("AHC-S020", "C-010", "direct");
scenarios("AHC-S021", "C-009", "direct");

scenarios("EDC-S001", "G-006", "supporting");
scenarios("EDC-S002", "G-002", "direct");
scenarios("EDC-S003 EDC-S004", "G-001", "direct");
scenarios("EDC-S005 EDC-S006", "G-002", "direct");
scenarios("EDC-S007 EDC-S008", "G-003", "direct");
scenarios("EDC-S009", "G-002", "direct");
scenarios("EDC-S010", "G-003", "supporting");
scenarios("EDC-S011", "G-004", "direct");
scenarios("EDC-S012 EDC-S013", "G-004", "supporting");
scenarios("EDC-S014", "G-005", "direct");
scenarios("EDC-S015", "G-004", "direct");
scenarios("EDC-S016", "G-003", "supporting");
scenarios("EDC-S017", "G-003", "supporting");
scenarios("EDC-S018", "G-006", "direct");
scenarios("EDC-S019", "G-007", "direct");

scenarios("FSE-S001", "E-001", "direct");
scenarios("FSE-S002", "E-002", "direct");
scenarios("FSE-S003", "E-001", "direct");
scenarios("FSE-S004", "E-003", "direct");
scenarios("FSE-S005", "C-010", "supporting");
scenarios("FSE-S006", "C-006", "direct");
scenarios("FSE-S007", "E-003", "direct");
scenarios("FSE-S008", "G-001", "direct");
scenarios("FSE-S009", "E-003 E-007 E-010", "supporting");
scenarios("FSE-S010 FSE-S011", "G-001", "direct");
scenarios("FSE-S012 FSE-S013", "E-004", "direct");
scenarios("FSE-S014", "E-008", "direct");
scenarios("FSE-S015 FSE-S016", "E-006", "direct");
scenarios("FSE-S017 FSE-S018", "E-007", "direct");
scenarios("FSE-S019", "E-005", "direct");
scenarios("FSE-S020 FSE-S021", "E-009", "direct");
scenarios("FSE-S022", "C-006", "supporting");
scenarios("FSE-S023 FSE-S024", "E-010", "direct");
scenarios("FSE-S025", "U-009", "direct");

scenarios("LIE-S001 LIE-S002 LIE-S003", "U-001", "direct");
scenarios("LIE-S004", "U-010", "direct");
scenarios("LIE-S005", "U-010", "supporting");
scenarios("LIE-S006", "U-002", "direct");
scenarios("LIE-S007", "U-003", "direct");
scenarios("LIE-S008 LIE-S009", "U-004", "direct");
scenarios("LIE-S010 LIE-S011", "U-005", "direct");
scenarios("LIE-S012 LIE-S013 LIE-S014", "U-006", "direct");
scenarios("LIE-S015", "U-007", "direct");
scenarios("LIE-S016 LIE-S017", "U-008", "direct");
scenarios("LIE-S018 LIE-S019", "U-009", "direct");
scenarios("LIE-S020", "D-003 D-005", "supporting");

scenarios("LDC-S001", "P-001", "direct");
scenarios("LDC-S002", "P-002", "supporting");
scenarios("LDC-S003", "P-002", "direct");
scenarios("LDC-S004 LDC-S005", "P-009", "direct");
scenarios("LDC-S006", "P-003", "direct");
scenarios("LDC-S007", "P-003", "supporting");
scenarios("LDC-S008", "P-001", "supporting");
scenarios("LDC-S009", "G-002", "direct");
scenarios("LDC-S010 LDC-S011 LDC-S012", "P-004", "direct");
scenarios("LDC-S013", "P-004", "supporting");
scenarios("LDC-S014", "P-005", "direct");
scenarios("LDC-S015", "P-005 G-004", "direct");
scenarios("LDC-S016 LDC-S017 LDC-S018", "P-006", "direct");
scenarios("LDC-S019", "P-007", "direct");
scenarios("LDC-S020", "P-008", "direct");
scenarios("LDC-S021 LDC-S022", "P-010", "direct");

scenarios("MAD-S001", "D-001", "direct");
scenarios("MAD-S002", "D-002", "direct");
scenarios("MAD-S003", "D-002", "supporting");
scenarios("MAD-S004", "D-002", "direct");
scenarios("MAD-S005", "E-010 D-003", "supporting");
scenarios("MAD-S006", "U-009", "direct");
scenarios("MAD-S007", "D-003", "supporting");
scenarios("MAD-S008", "D-003 D-005", "direct");
scenarios("MAD-S009", "S-002 D-003 D-005", "direct");
scenarios("MAD-S010", "D-001", "supporting");
scenarios("MAD-S011", "S-001", "direct");
scenarios("MAD-S012", "D-005", "supporting");
scenarios("MAD-S013", "D-004", "direct");
scenarios("MAD-S014", "S-003 D-006", "direct");
scenarios("MAD-S015", "D-007", "direct");

const expectedCriterionProfiles = new Map();
function profiles(ids, profileNames) {
  for (const id of ids.split(" ").filter(Boolean)) {
    expectedCriterionProfiles.set(id, profileNames.split(" ").filter(Boolean));
  }
}
profiles("S-001 S-002 D-001 D-003", "governance");
profiles("S-003 D-006 D-007", "fresh-validator");
profiles("E-001 C-001 C-002 C-003 C-004 C-005 C-006 C-008 C-009 C-010", "core-unit signed-ui");
profiles("E-002", "core-unit app-integration");
profiles("E-003 E-005 E-006 E-008 E-009 G-002 G-006", "core-unit");
profiles("E-004", "core-unit performance-energy");
profiles("E-007", "core-unit repository-contract");
profiles("E-010", "repository-contract app-integration");
profiles("C-007 U-006 U-007", "signed-ui accessibility-manual");
profiles("G-001", "core-unit app-integration signed-ui accessibility-manual privacy-static privacy-runtime");
profiles("G-003", "core-unit privacy-static");
profiles("G-004", "core-unit app-integration privacy-runtime");
profiles("G-005", "core-unit app-integration");
profiles("G-007", "app-integration");
profiles("U-001 U-004 U-008", "visual-regression accessibility-manual");
profiles("U-002", "visual-regression signed-ui");
profiles("U-003", "visual-regression performance-energy");
profiles("U-005", "performance-energy");
profiles("U-009", "app-integration signed-ui");
profiles("U-010", "privacy-static governance");
profiles("P-001", "privacy-static");
profiles("P-002 P-005", "privacy-runtime");
profiles("P-003 P-006 P-009", "repository-contract privacy-runtime");
profiles("P-004", "app-integration privacy-runtime");
profiles("P-007", "privacy-static privacy-runtime");
profiles("P-008", "privacy-static fresh-validator");
profiles("P-010", "repository-contract privacy-static");
profiles("D-002", "governance app-integration");
profiles("D-004", "signed-ui governance");
profiles("D-005", "governance privacy-runtime performance-energy");

const spec = read("SPEC.md");
const trace = read("docs/specification/acceptance-trace.md");
const proposal = read("openspec/changes/build-native-praxodoro/proposal.md");
const taskBody = read("openspec/changes/build-native-praxodoro/tasks.md");
const prd = JSON.parse(read("prd.json"));
const packageJSON = JSON.parse(read("package.json"));
const packageLock = JSON.parse(read("package-lock.json"));
const expectedFullSpecDigest = "9f8903b7f81ccf27713c891b8e1796d2e68ed32d572827175e2a783f8349cb42";
const fullSpecDigest = digestEntries([["SPEC.md", spec]]);
if (fullSpecDigest !== expectedFullSpecDigest) fail("full SPEC.md digest drift: " + fullSpecDigest);
const expectedFullTraceDigest = "7189b5bb190747a6e82ca5cbf3c7b073fbe0eff9efb5f125e9e0f47da79708f7";
const fullTraceDigest = digestEntries([["acceptance-trace.md", trace]]);
if (fullTraceDigest !== expectedFullTraceDigest) fail("full acceptance trace digest drift: " + fullTraceDigest);
const expectedProposalDigest = "dcdc18478e659c52982e3f6400b8166ca49cbbc60f0cb21f4f65d0c676f2bbb9";
const proposalDigest = digestEntries([["proposal.md", proposal]]);
if (proposalDigest !== expectedProposalDigest) fail("OpenSpec proposal digest drift: " + proposalDigest);

const criterionMatches = [...spec.matchAll(/^- \*\*([SECGUPD]-\d{3}):\*\* (.+)$/gm)];
const assumptionMatches = [...spec.matchAll(/^- \*\*(A-\d{3}):\*\* (.+)$/gm)];
const criteria = criterionMatches.map((match) => match[1]);
const assumptions = assumptionMatches.map((match) => match[1]);
if (!sameOrder(criteria, expectedCriteria)) fail("SPEC criterion IDs/order differ from the frozen 57-ID contract");
if (!sameOrder(assumptions, expectedAssumptions)) fail("SPEC assumption IDs/order differ from the frozen 12-ID contract");
const specSemanticDigest = digestEntries([
  ...criterionMatches.map((match) => [match[1], match[2].trim()]),
  ...assumptionMatches.map((match) => [match[1], match[2].trim()]),
]);
const expectedSpecSemanticDigest = "d886186259dafb571235ba364bcba04eb49bfc23bd9dda6e27ca67fa5881bc30";
if (specSemanticDigest !== expectedSpecSemanticDigest) {
  fail("SPEC criterion/assumption semantic digest drift: " + specSemanticDigest);
}

if (prd.counts.earsAcceptanceCriteria !== 57) fail("prd frozen criterion count must equal 57");
if (prd.counts.documentedAssumptions !== 12) fail("prd frozen assumption count must equal 12");
if (prd.counts.openSpecScenarios !== 122) fail("prd frozen scenario count must equal 122");
if (prd.counts.atoms !== 21) fail("prd frozen atom count must equal 21");

if (!sameOrder(prd.executionOrder ?? [], expectedExecutionOrder)) {
  fail("prd executionOrder differs from the frozen dependency-safe order");
}

const expectedAtomCommitSubjects = new Map();
for (const block of taskBody.split(/(?=^- \[[ x]\] \d+\.\d+ )/m)) {
  const id = block.match(/^- \[[ x]\] (\d+\.\d+) /m)?.[1];
  if (!id) continue;
  const subject = block.match(/^  - \*\*Commit:\*\* `([^`]+)`\.$/m)?.[1];
  if (!subject) fail("OpenSpec task lacks an exact milestone commit subject: " + id);
  else expectedAtomCommitSubjects.set(id, subject);
}
if (!sameOrder([...expectedAtomCommitSubjects.keys()], [...expectedAtoms.keys()])) {
  fail("OpenSpec milestone commit subjects differ from the frozen 21-atom registry");
}
const stagedPathsForAtomTransition = execFileSync(
  "git",
  ["diff", "--cached", "--no-renames", "--name-only", "-z"],
  { cwd: root },
)
  .toString("utf8")
  .split("\0")
  .filter(Boolean);
const doneAtomsWithoutCommit = [];
const atomMilestoneCommits = new Map();

for (const [id, subject] of expectedAtomCommitSubjects) {
  const matchingCommits = commitsWithExactSubject(subject);
  if (matchingCommits.length > 1) {
    fail("multiple commits use the reserved atom milestone subject: " + id);
    continue;
  }
  if (matchingCommits.length === 0) continue;
  const milestoneCommit = matchingCommits[0];
  atomMilestoneCommits.set(id, milestoneCommit);
  try {
    const historicalPRD = JSON.parse(readCommit(milestoneCommit, "prd.json").toString("utf8"));
    const historicalAtom = historicalPRD.atoms.find((candidate) => candidate.id === id);
    if (historicalAtom?.status !== "done" || typeof historicalAtom?.evidence !== "string") {
      fail("atom milestone commit does not record a done evidence transition: " + id);
      continue;
    }
    readCommit(milestoneCommit, historicalAtom.evidence);
    const historicalTasks = readCommit(
      milestoneCommit,
      "openspec/changes/build-native-praxodoro/tasks.md",
    ).toString("utf8");
    if (!new RegExp("^- \\[x\\] " + id.replace(".", "\\.") + " ", "m").test(historicalTasks)) {
      fail("atom milestone commit does not check its OpenSpec task: " + id);
    }
    const changedPaths = execFileSync(
      "git",
      ["diff-tree", "--no-commit-id", "--no-renames", "--name-only", "-r", "-z", milestoneCommit + "^", milestoneCommit],
      { cwd: root },
    )
      .toString("utf8")
      .split("\0")
      .filter(Boolean);
    for (const requiredPath of [
      "prd.json",
      "progress.txt",
      "openspec/changes/build-native-praxodoro/tasks.md",
      historicalAtom.evidence,
    ]) {
      if (!changedPaths.includes(requiredPath)) {
        fail("atom milestone commit lacks required transition path: " + id + " -> " + requiredPath);
      }
    }
    const currentAtom = prd.atoms.find((candidate) => candidate.id === id);
    if (currentAtom?.status !== "done" || currentAtom?.evidence !== historicalAtom.evidence) {
      fail("current PRD regresses a historically committed atom: " + id);
    }
  } catch (error) {
    fail("atom milestone commit cannot reproduce its status transition: " + id + " -> " + error.message);
  }
}

if (!sameOrder(prd.atoms.map((entry) => entry.id), [...expectedAtoms.keys()])) {
  fail("prd atom IDs/order differ from the frozen 21-atom graph");
}
for (const entry of prd.atoms) {
  const expected = expectedAtoms.get(entry.id);
  if (!expected) continue;
  if (!sameOrder(entry.dependsOn, expected.dependsOn)) fail("prd dependency drift for atom " + entry.id);
  if (!sameOrder(entry.criteria, expected.criteria)) fail("prd criterion ownership drift for atom " + entry.id);
  if (!["todo", "doing", "done", "parked"].includes(entry.status)) fail("invalid status for atom " + entry.id);
  if (entry.status === "done") {
    if (typeof entry.evidence !== "string" || !existsSync(join(root, entry.evidence))) {
      fail("done atom lacks existing evidence: " + entry.id);
    } else {
      const evidenceBody = read(entry.evidence);
      const expectedCommitSubject = expectedAtomCommitSubjects.get(entry.id);
      if (!expectedCommitSubject || !evidenceBody.includes("`" + expectedCommitSubject + "`")) {
        fail("done atom evidence lacks its exact milestone commit subject: " + entry.id);
      }
      if (!atomMilestoneCommits.has(entry.id)) {
        doneAtomsWithoutCommit.push(entry.id);
        for (const requiredPath of ["prd.json", "progress.txt", "openspec/changes/build-native-praxodoro/tasks.md", entry.evidence]) {
          if (!stagedPathsForAtomTransition.includes(requiredPath)) {
            fail("uncommitted done-atom transition lacks staged milestone path: " + entry.id + " -> " + requiredPath);
          }
        }
      }
      for (const criterion of entry.criteria) {
        if (!evidenceBody.includes("`" + criterion + "`")) {
          fail("done atom evidence lacks supported-criterion link: " + entry.id + " -> " + criterion);
        }
      }
    }
    for (const dependency of entry.dependsOn) {
      if (prd.atoms.find((candidate) => candidate.id === dependency)?.status !== "done") {
        fail("done atom has incomplete dependency: " + entry.id + " -> " + dependency);
      }
    }
  } else if (entry.status === "doing") {
    if (entry.evidence !== null) fail("doing atom must have null evidence: " + entry.id);
    for (const dependency of entry.dependsOn) {
      if (prd.atoms.find((candidate) => candidate.id === dependency)?.status !== "done") {
        fail("doing atom has incomplete dependency: " + entry.id + " -> " + dependency);
      }
    }
  } else if (entry.evidence !== null) {
    fail("incomplete atom must have null evidence: " + entry.id);
  }
}
if (doneAtomsWithoutCommit.length > 1) {
  fail("more than one done atom lacks its exact milestone commit");
}
for (const status of ["todo", "doing", "done", "parked"]) {
  const actual = prd.atoms.filter((entry) => entry.status === status).length;
  if (actual !== prd.counts[status]) fail("prd status count mismatch for " + status);
}
const firstRunnable = expectedExecutionOrder.find((id) => {
  const candidate = prd.atoms.find((entry) => entry.id === id);
  return candidate !== undefined &&
    ["todo", "doing"].includes(candidate.status) &&
    candidate.dependsOn.every(
      (dependency) => prd.atoms.find((entry) => entry.id === dependency)?.status === "done",
    );
}) ?? null;
if (prd.nextAtom !== firstRunnable) fail("prd nextAtom does not equal the first runnable atom");
const doingAtoms = prd.atoms.filter((entry) => entry.status === "doing");
if (doingAtoms.length > 1) fail("at most one atom may be doing");
if (doingAtoms.length === 1 && doingAtoms[0].id !== prd.nextAtom) {
  fail("the doing atom must equal prd.nextAtom");
}
const taskRows = [...taskBody.matchAll(/^- \[([ x])\] (\d+\.\d+) /gm)].map((match) => ({
  checked: match[1] === "x",
  id: match[2],
}));
if (!sameOrder(taskRows.map((row) => row.id), [...expectedAtoms.keys()])) {
  fail("OpenSpec task IDs/order differ from the frozen 21-atom graph");
}
for (const row of taskRows) {
  const status = prd.atoms.find((entry) => entry.id === row.id)?.status;
  if (row.checked !== (status === "done")) {
    fail("OpenSpec task checkbox disagrees with prd status for atom " + row.id);
  }
}

if (prd.planningGate?.status !== "done") fail("planningGate is not done");
for (const path of prd.planningGate?.evidence ?? []) {
  if (!existsSync(join(root, path))) fail("planningGate evidence is missing: " + path);
}
if (!["in_review", "done"].includes(prd.semanticContractGate?.status)) {
  fail("semanticContractGate must be in_review or done");
}
if (prd.semanticContractGate?.blocksAtom !== "3.1") fail("semanticContractGate must block Atom 3.1");
const expectedSemanticGateRequirements = [
  "closed-session-domain-contract",
  "stable-openspec-scenario-ids",
  "machine-verified-criterion-scenario-atom-trace",
  "strict-openspec-validation",
  "independent-semantic-review",
  "independent-trace-review",
  "shipping-council",
  "exact-staged-index-receiving-review",
];
if (!sameOrder(prd.semanticContractGate?.required ?? [], expectedSemanticGateRequirements)) {
  fail("semanticContractGate required checks differ from the frozen gate");
}
const semanticCandidateEvidence = [
  "docs/specification/session-domain-contract.md",
  "docs/specification/acceptance-trace.md",
  "scripts/verify-spec-trace.mjs",
];
const semanticAcceptedEvidence = [
  ...semanticCandidateEvidence,
  ".agent/reviews/semantic-contract-review.md",
  ".agent/reviews/acceptance-trace-review.md",
  ".agent/council/semantic-contract-shipping-council.md",
  ".agent/reviews/semantic-contract-receiving-review.md",
  ".agent/evidence/semantic-contract-gate.md",
];
const semanticSubjectPaths = [
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
  ".agent/evidence/atom-1.1-native-scaffold.md",
  ".agent/evidence/atom-1.2-native-quality.md",
  ".agent/evidence/atom-2.1-edition-catalog.md",
  ".agent/evidence/atom-2.2-validated-product-access.md",
  "openspec/changes/build-native-praxodoro/proposal.md",
  "openspec/changes/build-native-praxodoro/design.md",
  "openspec/changes/build-native-praxodoro/tasks.md",
  ...[...capabilityPrefixes.keys()].map(
    (name) => "openspec/changes/build-native-praxodoro/specs/" + name + "/spec.md",
  ),
];
const semanticStageAllowlist = sorted([
  ".agent/council/semantic-contract-shipping-council.md",
  ".agent/evidence/atom-1.1-native-scaffold.md",
  ".agent/evidence/atom-1.2-native-quality.md",
  ".agent/evidence/atom-2.1-edition-catalog.md",
  ".agent/evidence/atom-2.2-validated-product-access.md",
  ".agent/evidence/semantic-contract-gate.md",
  ".agent/reviews/acceptance-trace-review.md",
  ".agent/reviews/semantic-contract-receiving-review.md",
  ".agent/reviews/semantic-contract-review.md",
  "BLUEPRINT.md",
  "README.md",
  "SPEC.md",
  "docs/engineering/dependencies.md",
  "docs/specification/acceptance-trace.md",
  "docs/specification/session-domain-contract.md",
  "docs/superpowers/plans/2026-07-21-session-domain.md",
  "openspec/changes/build-native-praxodoro/design.md",
  "openspec/changes/build-native-praxodoro/specs/adhd-aware-coach/spec.md",
  "openspec/changes/build-native-praxodoro/specs/edition-capabilities/spec.md",
  "openspec/changes/build-native-praxodoro/specs/focus-session-engine/spec.md",
  "openspec/changes/build-native-praxodoro/specs/liquid-instrument-experience/spec.md",
  "openspec/changes/build-native-praxodoro/specs/local-data-control/spec.md",
  "openspec/changes/build-native-praxodoro/specs/macos-app-delivery/spec.md",
  "openspec/changes/build-native-praxodoro/tasks.md",
  "package.json",
  "prd.json",
  "progress.txt",
  "scripts/verify-spec-trace.mjs",
]);
const semanticReceivingPath = ".agent/reviews/semantic-contract-receiving-review.md";
const semanticRequiredTransitionPaths = sorted([
  ".agent/council/semantic-contract-shipping-council.md",
  ".agent/evidence/semantic-contract-gate.md",
  ".agent/reviews/acceptance-trace-review.md",
  ".agent/reviews/semantic-contract-receiving-review.md",
  ".agent/reviews/semantic-contract-review.md",
  "docs/specification/session-domain-contract.md",
  "prd.json",
  "progress.txt",
]);
const semanticGateCommitSubject = "docs: accept session domain contract";
const semanticGateCommits = commitsWithExactSubject(semanticGateCommitSubject);
const latestSemanticGateCommit = semanticGateCommits[0] ?? null;
const semanticStagedPaths = execFileSync(
  "git",
  ["diff", "--cached", "--no-renames", "--name-only", "-z"],
  { cwd: root },
)
  .toString("utf8")
  .split("\0")
  .filter(Boolean);
const semanticStagedPathSet = new Set(semanticStagedPaths);
const semanticStagedPathsAreAllowed = semanticStagedPaths.every((path) =>
  semanticStageAllowlist.includes(path)
);
const semanticStagedPathsAreComplete = semanticRequiredTransitionPaths.every((path) =>
  semanticStagedPathSet.has(path)
);
const hasPendingSemanticGateTransition =
  semanticStagedPaths.length > 0 &&
  semanticStagedPathsAreAllowed &&
  semanticStagedPathsAreComplete;
const expectedSemanticEvidence = prd.semanticContractGate?.status === "done"
  ? semanticAcceptedEvidence
  : semanticCandidateEvidence;
if (!sameOrder(prd.semanticContractGate?.evidence ?? [], expectedSemanticEvidence)) {
  fail("semanticContractGate evidence differs from its frozen status-specific manifest");
}
if (prd.semanticContractGate?.status === "in_review" && latestSemanticGateCommit === null) {
  const atom31 = prd.atoms.find((entry) => entry.id === "3.1");
  if (atom31?.status !== "todo" || atom31?.evidence !== null) {
    fail("Atom 3.1 must remain incomplete with no evidence while semanticContractGate is in_review");
  }
}
for (const path of prd.semanticContractGate?.evidence ?? []) {
  if (!existsSync(join(root, path))) fail("semanticContractGate evidence is missing: " + path);
}
if (prd.semanticContractGate?.status === "done") {
  const historicalGateCommit = latestSemanticGateCommit;
  const useWorkingSemanticGateCandidate =
    historicalGateCommit === null || hasPendingSemanticGateTransition;
  let subjectDigest = null;
  let stagedSubjectDigest = null;
  let stagedPayloadDigest = null;
  let stagedAllowlistDigest = null;
  const receiptRequirements = new Map([
    [".agent/reviews/semantic-contract-review.md", ["Verdict", "READY"]],
    [".agent/reviews/acceptance-trace-review.md", ["Verdict", "READY"]],
    [".agent/council/semantic-contract-shipping-council.md", ["Chairman verdict", "SHIP"]],
    [".agent/reviews/semantic-contract-receiving-review.md", ["Verdict", "ACCEPT"]],
    [".agent/evidence/semantic-contract-gate.md", ["Gate status", "ACCEPTED"]],
  ]);

  if (useWorkingSemanticGateCandidate) {
    const acceptedStagedPaths = sorted(semanticStagedPaths);
    const stagedPayloadPaths = acceptedStagedPaths.filter(
      (path) => path !== semanticReceivingPath,
    );
    subjectDigest = workingTreeDigest(semanticSubjectPaths);
    try {
      stagedSubjectDigest = indexDigest(semanticSubjectPaths);
      stagedPayloadDigest = indexDigest(stagedPayloadPaths);
      stagedAllowlistDigest = digestEntries(acceptedStagedPaths.map((path) => [path, ""]));
    } catch {
      fail("semanticContractGate subject/payload paths are not all present in the Git index");
    }
    if (stagedSubjectDigest !== null && stagedSubjectDigest !== subjectDigest) {
      fail("semanticContractGate working subject differs from its exact staged-index subject");
    }
    if (!semanticStagedPathsAreAllowed || !semanticStagedPathsAreComplete) {
      fail("accepted semantic gate staged paths violate the required/allowed transition manifest");
    }
    for (const path of acceptedStagedPaths) {
      try {
        if (workingTreeMode(path) !== "100644" || readIndexMode(path) !== "100644") {
          fail(path + " must remain a regular non-executable file in the semantic gate transition");
        }
      } catch {
        fail(path + " has no verifiable working-tree/index mode in the semantic gate transition");
      }
    }
    for (const path of ["prd.json", ...semanticAcceptedEvidence.slice(3)]) {
      if (!existsSync(join(root, path))) continue;
      try {
        const working = readFileSync(join(root, path));
        const indexed = readIndex(path);
        if (!working.equals(indexed)) fail(path + " differs from the exact Git-index gate transition");
      } catch {
        fail(path + " is not present in the Git index for the accepted gate transition");
      }
    }
  } else {
    try {
      subjectDigest = commitDigest(historicalGateCommit, semanticSubjectPaths);
      stagedSubjectDigest = subjectDigest;
      const historicalPRD = JSON.parse(readCommit(historicalGateCommit, "prd.json").toString("utf8"));
      if (historicalPRD.semanticContractGate?.status !== "done") {
        fail("historical semantic-gate commit does not record the gate as done");
      }
      const changedPaths = execFileSync(
        "git",
        ["diff-tree", "--no-commit-id", "--no-renames", "--name-only", "-r", "-z", historicalGateCommit + "^", historicalGateCommit],
        { cwd: root },
      )
        .toString("utf8")
        .split("\0")
        .filter(Boolean);
      const acceptedChangedPaths = sorted(changedPaths);
      const changedPathSet = new Set(acceptedChangedPaths);
      const changedPathsAreAllowed = acceptedChangedPaths.every((path) =>
        semanticStageAllowlist.includes(path)
      );
      const changedPathsAreComplete = semanticRequiredTransitionPaths.every((path) =>
        changedPathSet.has(path)
      );
      if (!changedPathsAreAllowed || !changedPathsAreComplete) {
        fail("historical semantic-gate commit paths violate the required/allowed transition manifest");
      }
      for (const path of acceptedChangedPaths) {
        if (readCommitMode(historicalGateCommit, path) !== "100644") {
          fail(path + " is not a regular non-executable file in the historical semantic gate commit");
        }
      }
      const historicalPayloadPaths = acceptedChangedPaths.filter(
        (path) => path !== semanticReceivingPath,
      );
      stagedPayloadDigest = commitDigest(historicalGateCommit, historicalPayloadPaths);
      stagedAllowlistDigest = digestEntries(acceptedChangedPaths.map((path) => [path, ""]));
      const currentContract = readFileSync(
        join(root, "docs/specification/session-domain-contract.md"),
      );
      const indexedContract = readIndex(
        "docs/specification/session-domain-contract.md",
      );
      const acceptedContract = readCommit(
        historicalGateCommit,
        "docs/specification/session-domain-contract.md",
      );
      const currentContractMode = workingTreeMode(
        "docs/specification/session-domain-contract.md",
      );
      const indexedContractMode = readIndexMode(
        "docs/specification/session-domain-contract.md",
      );
      const acceptedContractMode = readCommitMode(
        historicalGateCommit,
        "docs/specification/session-domain-contract.md",
      );
      if (!currentContract.equals(acceptedContract)) {
        fail(
          "current session-domain contract differs from the latest accepted semantic gate; " +
          "set semanticContractGate to in_review and complete a new exact gate transition",
        );
      }
      if (!indexedContract.equals(acceptedContract)) {
        fail(
          "indexed session-domain contract differs from the latest accepted semantic gate; " +
          "set semanticContractGate to in_review and complete a new exact gate transition",
        );
      }
      if (
        currentContractMode !== acceptedContractMode ||
        indexedContractMode !== acceptedContractMode
      ) {
        fail(
          "session-domain contract mode differs from the latest accepted semantic gate; " +
          "set semanticContractGate to in_review and complete a new exact gate transition",
        );
      }
    } catch (error) {
      fail("historical semantic-gate commit cannot reproduce its subject/payload: " + error.message);
    }
  }

  for (const [path, [label, value]] of receiptRequirements) {
    let body = null;
    try {
      body = useWorkingSemanticGateCandidate
        ? read(path)
        : readCommit(historicalGateCommit, path).toString("utf8");
    } catch {
      fail("semantic-gate receipt is unavailable: " + path);
      continue;
    }
    if (!hasExactField(body, label, value)) fail(path + " lacks one exact accepted " + label + " field");
    if (!hasExactField(body, "Subject SHA-256", subjectDigest)) {
      fail(path + " does not bind its verdict to the accepted semantic subject");
    }
  }
  let receiving = null;
  try {
    receiving = useWorkingSemanticGateCandidate
      ? read(semanticReceivingPath)
      : readCommit(historicalGateCommit, semanticReceivingPath).toString("utf8");
  } catch {
    fail("semantic receiving review is unavailable");
  }
  if (receiving !== null) {
    if (!hasExactField(receiving, "Staged subject SHA-256", stagedSubjectDigest)) {
      fail("semantic receiving review does not bind the exact accepted subject");
    }
    if (!hasExactField(receiving, "Staged allowlist SHA-256", stagedAllowlistDigest)) {
      fail("semantic receiving review does not bind the exact staged path allowlist");
    }
    if (!hasExactField(receiving, "Staged payload SHA-256", stagedPayloadDigest)) {
      fail("semantic receiving review does not bind every accepted payload except its own receipt");
    }
  }
}

const expectedCapabilityNames = sorted(capabilityPrefixes.keys());
const specsRoot = join(root, "openspec/changes/build-native-praxodoro/specs");
const actualCapabilityNames = sorted(
  readdirSync(specsRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name),
);
if (!sameOrder(actualCapabilityNames, expectedCapabilityNames)) {
  fail("OpenSpec capability directories differ from the frozen six-capability set");
}
const capabilitySpecDigest = digestEntries([...capabilityPrefixes.keys()].map((name) => [
  name,
  readFileSync(join(specsRoot, name, "spec.md")),
]));
const expectedCapabilitySpecDigest = "c7bd9e1f30d64047e5b763c4d7109c6971f924d4ec1264734ecfab6dc8e16966";
if (capabilitySpecDigest !== expectedCapabilitySpecDigest) {
  fail("full OpenSpec capability-spec digest drift: " + capabilitySpecDigest);
}
const scenarioTitles = new Map();
const scenarioBodies = new Map();
const observedScenarioIDs = [];
for (const [capabilityName, [prefix]] of capabilityPrefixes) {
  const path = join(specsRoot, capabilityName, "spec.md");
  const body = readFileSync(path, "utf8");
  const headings = [...body.matchAll(/^#### Scenario: \[([A-Z]{3}-S\d{3})\] (.+)$/gm)];
  if (headings.length !== [...body.matchAll(/^#### Scenario:/gm)].length) {
    fail(relative(root, path) + " contains a scenario without a stable ID");
  }
  for (const match of headings) {
    const id = match[1];
    if (!id.startsWith(prefix + "-S")) fail(relative(root, path) + " contains wrong-prefix ID " + id);
    if (scenarioTitles.has(id)) fail("duplicate OpenSpec scenario ID " + id);
    const contentStart = match.index + match[0].length;
    const remaining = body.slice(contentStart);
    const boundaryOffset = remaining.search(/\n(?=### Requirement:|#### Scenario:)/);
    const semanticBody = remaining
      .slice(0, boundaryOffset === -1 ? remaining.length : boundaryOffset)
      .trim()
      .replace(/\r\n/g, "\n")
      .replace(/[ \t]+$/gm, "");
    scenarioTitles.set(id, match[2]);
    scenarioBodies.set(id, semanticBody);
    observedScenarioIDs.push(id);
  }
}
if (!sameMembers(observedScenarioIDs, expectedScenarioIDs)) {
  fail("OpenSpec scenario IDs differ from the frozen 122-ID registry");
}
const scenarioSemanticDigest = digestEntries(expectedScenarioIDs.map((id) => [
  id,
  (scenarioTitles.get(id) ?? "") + "\n" + (scenarioBodies.get(id) ?? ""),
]));
const expectedScenarioSemanticDigest = "6b98504360d0103286dbf773336188577614320f3490dd7df6af66961f356c8c";
if (scenarioSemanticDigest !== expectedScenarioSemanticDigest) {
  fail("OpenSpec scenario semantic-body digest drift: " + scenarioSemanticDigest);
}

const scenarioRows = new Map();
for (const line of trace.split("\n")) {
  const match = line.match(/^\| ([A-Z]{3}-S\d{3}) \| ([^|]+) \| ([^|]+) \| (direct|supporting) \|$/);
  if (!match) continue;
  const id = match[1];
  const title = match[2].trim();
  const linkedCriteria = match[3].split(",").map((item) => item.trim()).filter(Boolean);
  if (scenarioRows.has(id)) fail("duplicate scenario trace row " + id);
  scenarioRows.set(id, { title, criteria: linkedCriteria, relationship: match[4] });
}

const profileSection = trace.split("## Validation profiles\n")[1]?.split("\n## ")[0] ?? "";
const profileRows = [];
const profileDefinitions = new Map();
for (const line of profileSection.split("\n")) {
  const match = line.match(/^\| ([a-z-]+) \| ([^|]+) \|$/);
  if (match) {
    profileRows.push(match[1]);
    profileDefinitions.set(match[1], match[2].trim());
  }
}
if (!sameOrder(profileRows, profileRegistry)) {
  fail("validation-profile table differs in names, order, count, or uniqueness from the frozen registry");
}
if (!sameMembers(scenarioRows.keys(), expectedScenarioIDs)) {
  fail("scenario trace rows differ from the frozen 122-ID registry");
}
for (const id of expectedScenarioIDs) {
  const row = scenarioRows.get(id);
  const expected = expectedScenarioAssignments.get(id);
  if (!row || !expected) {
    fail("missing frozen scenario assignment for " + id);
    continue;
  }
  if (row.title !== scenarioTitles.get(id)) fail("scenario title drift for " + id);
  if (!sameOrder(row.criteria, expected.criteria)) fail("scenario criterion mapping drift for " + id);
  if (row.relationship !== expected.relationship) fail("scenario relationship drift for " + id);
  for (const criterion of row.criteria) {
    if (!expectedCriteria.includes(criterion)) fail("scenario " + id + " references unknown criterion " + criterion);
  }
}
for (const criterion of expectedCriteria) {
  const hasDirectWitness = [...scenarioRows.values()].some(
    (row) => row.relationship === "direct" && row.criteria.includes(criterion),
  );
  if (!hasDirectWitness) fail("criterion lacks a direct OpenSpec scenario witness: " + criterion);
}

const traceRows = new Map();
for (const line of trace.split("\n")) {
  const match = line.match(/^\| ([SECGUPD]-\d{3}) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \| ([^|]+) \|$/);
  if (!match) continue;
  const id = match[1];
  const descriptor = match[2].trim();
  const owners = match[3].split(",").map((item) => item.trim()).filter(Boolean);
  const rowProfiles = match[4].split(",").map((item) => item.trim()).filter(Boolean);
  const evidenceContributors = match[5].split(",").map((item) => item.trim()).filter(Boolean);
  const proof = match[6].trim();
  if (traceRows.has(id)) fail("duplicate criterion trace row " + id);
  traceRows.set(id, { descriptor, owners, profiles: rowProfiles, evidenceContributors, proof });
  if (proof.length === 0) fail("criterion " + id + " has no proof oracle");
}
if (!sameOrder([...traceRows.keys()], expectedCriteria)) {
  fail("criterion trace IDs/order differ from the frozen 57-ID contract");
}
const criterionOracleDigest = digestEntries(expectedCriteria.map((id) => [
  id,
  traceRows.get(id)?.proof ?? "",
]));
const expectedCriterionOracleDigest = "ffc1afca2b70c38cb0d12486204e54d48703f8df660c7d338763993ca0573fde";
if (criterionOracleDigest !== expectedCriterionOracleDigest) {
  fail("criterion proof-oracle digest drift: " + criterionOracleDigest);
}
const traceSemanticDigest = digestEntries([
  ...profileRegistry.map((name) => ["profile:" + name, profileDefinitions.get(name) ?? ""]),
  ...expectedCriteria.map((id) => [
    "criterion:" + id,
    (traceRows.get(id)?.descriptor ?? "") + "\n" + (traceRows.get(id)?.proof ?? ""),
  ]),
]);
const expectedTraceSemanticDigest = "ac9a347ed8dcaf9b7dfceab16266d93ef44983eadbfc6ffd561a9bf025b78b61";
if (traceSemanticDigest !== expectedTraceSemanticDigest) {
  fail("trace profile/descriptor/oracle semantic digest drift: " + traceSemanticDigest);
}
const expectedOwners = new Map(expectedCriteria.map((id) => [id, []]));
for (const [atomID, value] of expectedAtoms) {
  for (const criterion of value.criteria) expectedOwners.get(criterion)?.push(atomID);
}
for (const criterion of expectedCriteria) {
  const row = traceRows.get(criterion);
  const owners = expectedOwners.get(criterion) ?? [];
  if (!sameOrder(row?.owners ?? [], owners)) {
    fail("criterion owner drift for " + criterion);
  }
  if (!sameOrder(row?.profiles ?? [], expectedCriterionProfiles.get(criterion) ?? [])) {
    fail("criterion validation-profile drift for " + criterion);
  }
  if (!sameOrder(row?.evidenceContributors ?? [], owners)) {
    fail("criterion planned evidence contributors must equal every owner for " + criterion);
  }
}

const expectedPackageRootKeys = [
  "name",
  "version",
  "private",
  "description",
  "scripts",
  "devDependencies",
  "engines",
  "packageManager",
];
if (!sameMembers(Object.keys(packageJSON), expectedPackageRootKeys)) {
  fail("package.json root keys differ from the frozen manifest");
}
if (
  packageJSON.name !== "praxodoro-spec-tooling" ||
  packageJSON.version !== "0.1.0" ||
  packageJSON.private !== true ||
  packageJSON.description !== "Pinned specification tooling for the native Praxodoro macOS app."
) {
  fail("package.json identity/version/privacy/description differs from the frozen manifest");
}
const expectedPackageScripts = new Map([
  [
    "spec:validate",
    "openspec validate --all --strict --no-interactive && node scripts/verify-spec-trace.mjs",
  ],
  ["spec:trace", "node scripts/verify-spec-trace.mjs"],
  ["spec:list", "openspec list"],
]);
if (!sameMembers(Object.keys(packageJSON.scripts ?? {}), expectedPackageScripts.keys())) {
  fail("package.json script keys differ from the frozen manifest");
}
for (const [name, value] of expectedPackageScripts) {
  if (packageJSON.scripts?.[name] !== value) {
    fail("package.json script value differs from the frozen manifest: " + name);
  }
}
if (
  !sameMembers(Object.keys(packageJSON.engines ?? {}), ["node"]) ||
  packageJSON.engines?.node !== ">=20.19.0"
) {
  fail("package.json engine declaration differs from the frozen manifest");
}
if (packageJSON.devDependencies?.["@fission-ai/openspec"] !== "1.6.0") {
  fail("package.json must pin @fission-ai/openspec exactly to 1.6.0");
}
if (!sameMembers(Object.keys(packageJSON.devDependencies ?? {}), ["@fission-ai/openspec"])) {
  fail("package.json development dependency set differs from the frozen single-tool manifest");
}
if (packageJSON.packageManager !== "npm@10.9.8") fail("packageManager must remain npm@10.9.8");
const packageLockDigest = digestEntries([
  ["package-lock.json", readFileSync(join(root, "package-lock.json"))],
]);
const expectedPackageLockDigest = "619ebae35ec06c6add3737ee2ea54fdf6d5d55d1bab3bbc987be7d9b869e40c8";
if (packageLockDigest !== expectedPackageLockDigest) {
  fail("complete package-lock.json digest drift: " + packageLockDigest);
}
const lockRoot = packageLock.packages?.[""];
if (
  !sameMembers(Object.keys(packageLock), ["name", "version", "lockfileVersion", "requires", "packages"]) ||
  packageLock.name !== "praxodoro-spec-tooling" ||
  packageLock.version !== "0.1.0" ||
  packageLock.lockfileVersion !== 3 ||
  packageLock.requires !== true ||
  lockRoot?.name !== "praxodoro-spec-tooling" ||
  lockRoot?.version !== "0.1.0" ||
  !sameMembers(Object.keys(lockRoot ?? {}), ["name", "version", "devDependencies", "engines"]) ||
  !sameMembers(Object.keys(lockRoot?.devDependencies ?? {}), ["@fission-ai/openspec"]) ||
  lockRoot?.devDependencies?.["@fission-ai/openspec"] !== "1.6.0" ||
  !sameMembers(Object.keys(lockRoot?.engines ?? {}), ["node"]) ||
  lockRoot?.engines?.node !== ">=20.19.0"
) {
  fail("package-lock root identity/version/engine/OpenSpec declaration differs from the frozen manifest");
}
const lockedOpenSpec = packageLock.packages?.["node_modules/@fission-ai/openspec"];
const expectedOpenSpecIntegrity =
  "sha512-7yFTQ3hrrk11mQ2ACClNv2gtAN0o116vCgwoiQKmreoB6ambSnrZh7wf2FNFoSDBXHBi9iiCQ7G16fG71ZNppA==";
const expectedOpenSpecTarball = "https://registry.npmjs.org/@fission-ai/openspec/-/openspec-1.6.0.tgz";
if (
  lockedOpenSpec?.version !== "1.6.0" ||
  lockedOpenSpec?.integrity !== expectedOpenSpecIntegrity ||
  lockedOpenSpec?.resolved !== expectedOpenSpecTarball ||
  lockedOpenSpec?.license !== "MIT" ||
  lockedOpenSpec?.dev !== true
) {
  fail("package-lock lacks the exact OpenSpec 1.6.0 version/source/integrity/license/dev record");
}
const dependencies = read("docs/engineering/dependencies.md");
for (const requiredText of [
  "## OpenSpec 1.6.0",
  "https://github.com/Fission-AI/OpenSpec",
  expectedOpenSpecTarball,
  expectedOpenSpecIntegrity,
  "License: MIT",
  "Scope: development and CI only",
  "Purpose: strict specification validation",
  "Upgrade:",
  "Removal:",
]) {
  if (!dependencies.includes(requiredText)) fail("OpenSpec dependency provenance is missing: " + requiredText);
}

for (const path of [
  "SPEC.md",
  "BLUEPRINT.md",
  "prd.json",
  "openspec/changes/build-native-praxodoro/tasks.md",
  "docs/specification/session-domain-contract.md",
  "docs/specification/acceptance-trace.md",
  "docs/engineering/dependencies.md",
]) {
  if (!existsSync(join(root, path))) fail("required specification artifact is missing: " + path);
}

if (failures.length > 0) {
  console.error("Specification trace verification failed:");
  failures.forEach((failure) => console.error("- " + failure));
  process.exit(1);
}

console.log(
  "Specification trace verified: 57 frozen criteria, 12 frozen assumptions, " +
    "122 immutable OpenSpec scenarios, 21 frozen atoms, exact owners/evidence state.",
);
