#!/usr/bin/env node
// Build the documentation site: every Markdown document in the repo becomes a
// styled HTML page under docs/site/, and docs/index.html catalogues all of them
// alongside the design mockups.
//
// Hand-authored HTML wins. Where a document already has a bespoke page beside
// it (the design-parity audit, the direction gate), the catalogue links that
// page instead of a generic render — a generated page would be a downgrade.
//
// Run: npm run docs:build
import { readFileSync, writeFileSync, mkdirSync, existsSync, rmSync } from "node:fs";
import { dirname, join, relative, basename } from "node:path";
import { execFileSync } from "node:child_process";
import { marked } from "marked";

const ROOT = join(dirname(new URL(import.meta.url).pathname), "..");
const SITE = join(ROOT, "docs", "site");

/* ── Which documents, and how they are grouped ─────────────────────────── */

const SECTIONS = [
  {
    id: "contract",
    title: "The contract",
    blurb: "What done means, who may change what, and the current state of play. Read these first.",
    match: (p) => ["SPEC.md", "AGENTS.md", "README.md", "CONTEXT.md", "prd.json"].includes(p),
  },
  {
    id: "analysis",
    title: "Analysis & decisions",
    blurb: "Audits, direction records, and the reasoning behind the choices that stuck.",
    match: (p) => p.startsWith("docs/analysis/") || p === "praxmodoro-direction-gate.md",
  },
  {
    id: "specs",
    title: "Capability specs",
    blurb: "The canonical EARS requirements. These are authoritative — the app is measured against them.",
    match: (p) => p.startsWith("openspec/specs/"),
  },
  {
    id: "active",
    title: "Active change · add-companion-surfaces",
    blurb: "Milestone M2: proposal, design with argued alternatives, TDD tasks, and its four capability deltas.",
    match: (p) => p.startsWith("openspec/changes/add-companion-surfaces/"),
  },
  {
    id: "archive",
    title: "Archived change · M1 core loop",
    blurb: "Milestone M1 as it was shipped and archived on 2026-07-31.",
    match: (p) => p.startsWith("openspec/changes/archive/"),
  },
  {
    id: "handoff",
    title: "Handoffs",
    blurb: "Cross-agent handoff records. Both are superseded — kept as the state M2 started from.",
    match: (p) => p.startsWith("docs/handoff/"),
  },
  {
    id: "agents",
    title: "Agent conventions",
    blurb: "How issues, labels, and domain decisions are tracked.",
    match: (p) => p.startsWith("docs/agents/") || p.startsWith(".agent/"),
  },
  {
    id: "research",
    title: "Product research",
    blurb: "The 2026-07-20 landscape study. Product claims trace here; the outputs are the readable summaries.",
    match: (p) => p.startsWith("research/"),
  },
  {
    id: "tooling",
    title: "Generated tooling prompts",
    blurb: "OpenSpec's own workflow skills. Generated, not hand-written — listed for completeness.",
    match: (p) => p.startsWith(".codex/"),
  },
];

/** Documents with a hand-authored page instead of a generic render.
 *  `partial` pages are composed through the shared shell so they cannot drift;
 *  `standalone` pages own their markup entirely (the direction gate is a live
 *  decision tool with its own CSP and export behaviour — leave it alone). */
const BESPOKE = {
  "docs/analysis/2026-08-04-design-parity.md": {
    out: "docs/analysis/2026-08-04-design-parity.html",
    partial: "docs/partials/design-parity.body.html",
    eyebrow: "Design parity audit · local deep research",
    heading: "The engine was specified. The feeling was not.",
    standfirst:
      "Praxmodoro's behaviour is faithful, tested, and in places exact to one part in a billion. The approved visual language is between zero and a quarter delivered — because nothing ever made it testable.",
    meta: "<span>2026-08-04</span><span>branch feat/m2-companion-surfaces</span><span>4 evidence shards</span><span>sources: local only</span>",
  },
  "praxmodoro-direction-gate.md": { out: "praxmodoro-direction-gate.html", standalone: true },
};

/** The mockup sets. These are living prototypes, not documents. */
const MOCKUPS = [
  {
    href: "design-mocks/living-companion/app-mocks.html",
    name: "Living Companion",
    status: "approved",
    note: "Direction B, approved 2026-07-30. Warm dusk paper, a breathing companion field driven by real spring physics. The binding visual reference — and the one the shipped app diverges from.",
  },
  {
    href: "design-mocks/hallmark/app-mocks.html",
    name: "Hallmark · Liquid Instrument",
    status: "record",
    note: "Direction A. Precision-instrument language, denser and cooler. Kept as a comparative record.",
  },
  {
    href: "design-mocks/focus-observatory/app-mocks.html",
    name: "Focus Observatory",
    status: "record",
    note: "Direction C. Ambient, observational framing. Kept as a comparative record.",
  },
  {
    href: "design-mocks/direction-gate/compare.html",
    name: "Direction gate — side by side",
    status: "record",
    note: "All three directions in one view; the comparison the 2026-07-30 decision was made from.",
  },
];

/* ── Collect ───────────────────────────────────────────────────────────── */

const tracked = execFileSync("git", ["ls-files", "*.md"], { cwd: ROOT, encoding: "utf8" })
  .split("\n")
  .filter((p) => p && !p.includes("node_modules"))
  .sort();

/** Several documents open with the bare product name, which makes the index
 *  unscannable. Name the well-known ones for what they actually are. */
const TITLES = {
  "README.md": "README — project overview",
  "CONTEXT.md": "CONTEXT — domain glossary",
  "SPEC.md": "SPEC — the completion contract",
  "AGENTS.md": "AGENTS — the agent contract",
  "praxmodoro-direction-gate.md": "Direction gate — the 2026-07-30 decision",
};

const titleOf = (path, source) => {
  if (TITLES[path]) return TITLES[path];
  const h1 = source.match(/^#\s+(.+)$/m);
  if (h1) return h1[1].replace(/[`*]/g, "").trim();
  return basename(path, ".md");
};

const summaryOf = (source) => {
  const body = source.replace(/^#\s+.+$/m, "").replace(/^>.*$/gm, "");
  const para = body.split(/\n\s*\n/).map((s) => s.trim()).find((s) => s && !s.startsWith("#") && !s.startsWith("|") && !s.startsWith("-"));
  if (!para) return "";
  const flat = para.replace(/\s+/g, " ").replace(/[`*_[\]]/g, "").replace(/\((?:https?|\.)[^)]*\)/g, "");
  return flat.length > 175 ? flat.slice(0, 172).trimEnd() + "…" : flat;
};

const slugOf = (path) => path.replace(/\.md$/, "").replace(/[/.]/g, "-").replace(/^-+/, "");

const docs = tracked.map((path) => {
  const source = readFileSync(join(ROOT, path), "utf8");
  const section = SECTIONS.find((s) => s.match(path)) ?? SECTIONS[SECTIONS.length - 1];
  return {
    path,
    source,
    section: section.id,
    title: titleOf(path, source),
    summary: summaryOf(source),
    slug: slugOf(path),
    words: source.split(/\s+/).filter(Boolean).length,
    bespoke: BESPOKE[path]?.out ?? null,
    bespokeSpec: BESPOKE[path] ?? null,
  };
});

// Any title shared by two documents gets a qualifier. The same capability
// spec appears canonically, as an M2 delta, and in the M1 archive — the reader
// needs to know which one they are opening.
const SECTION_QUALIFIER = {
  specs: "canonical",
  active: "M2 change",
  archive: "M1 archived",
};

const groups = new Map();
for (const d of docs) groups.set(d.title, [...(groups.get(d.title) ?? []), d]);
for (const [, group] of groups) {
  if (group.length < 2) continue;
  const sectionsDiffer = new Set(group.map((d) => d.section)).size === group.length;
  for (const d of group) {
    const base = basename(d.path, ".md");
    const basesDiffer = new Set(group.map((g) => basename(g.path, ".md"))).size === group.length;
    const qualifier = sectionsDiffer
      ? SECTION_QUALIFIER[d.section] ?? d.section
      : basesDiffer
        ? base
        : basename(dirname(d.path));
    d.title = `${d.title} · ${qualifier}`;
  }
}

/* ── The shared shell ──────────────────────────────────────────────────── */

const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");

/**
 * Palette and type quoted from design-mocks/living-companion/tokens.css.
 * The documentation speaks the language the product was designed in.
 */
const CSS = readFileSync(join(ROOT, "docs", "assets", "docs.css"), "utf8");

const shell = ({ title, eyebrow, heading, standfirst, meta, body, depth, nav, extraClass = "" }) => {
  const up = "../".repeat(depth);
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
<style>${CSS}</style>
</head>
<body class="${extraClass}">
<a class="skip" href="#main">Skip to content</a>
<nav class="topbar">
  <a class="brand" href="${up}index.html"><span class="brand-mark" aria-hidden="true"></span>Praxmodoro docs</a>
  <div class="topnav">${nav}</div>
  <button class="theme" type="button" data-theme-toggle aria-label="Switch colour theme">◑</button>
</nav>
<main id="main" class="wrap">
${eyebrow ? `<div class="eyebrow">${esc(eyebrow)}</div>` : ""}
${heading ? `<h1>${esc(heading)}</h1>` : ""}
${standfirst ? `<p class="standfirst">${standfirst}</p>` : ""}
${meta ? `<div class="meta">${meta}</div>` : ""}
${body}
</main>
<script>
(() => {
  const root = document.documentElement;
  const stored = localStorage.getItem("praxdocs-theme");
  if (stored) root.setAttribute("data-theme", stored);
  document.querySelector("[data-theme-toggle]")?.addEventListener("click", () => {
    const current = root.getAttribute("data-theme")
      ?? (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
    const next = current === "dark" ? "light" : "dark";
    root.setAttribute("data-theme", next);
    localStorage.setItem("praxdocs-theme", next);
  });
})();
</script>
</body>
</html>`;
};

const NAV = (depth) => {
  const up = "../".repeat(depth);
  return SECTIONS.filter((s) => s.id !== "tooling")
    .map((s) => `<a href="${up}index.html#${s.id}">${esc(s.title.split("·")[0].trim())}</a>`)
    .join("");
};

/* ── Render each document ──────────────────────────────────────────────── */

marked.setOptions({ gfm: true, headerIds: true, mangle: false });

if (existsSync(SITE)) rmSync(SITE, { recursive: true });
mkdirSync(SITE, { recursive: true });

let generated = 0;
for (const doc of docs) {
  if (doc.bespoke) continue;

  // Strip the H1 — the shell renders it as the page heading.
  const withoutH1 = doc.source.replace(/^#\s+.+$/m, "");
  let html = marked.parse(withoutH1);
  // Rewrite links between markdown documents to their generated pages.
  html = html.replace(/href="([^":]+?)\.md(#[^"]*)?"/g, (whole, target, hash) => {
    const resolved = join(dirname(doc.path), `${target}.md`).replace(/^\.\//, "");
    const hit = docs.find((d) => d.path === resolved);
    if (!hit) return whole;
    return `href="${hit.bespoke ? "../../" + hit.bespoke : hit.slug + ".html"}${hash ?? ""}"`;
  });
  // Relative links to non-Markdown neighbours (a sibling prototype, a stylesheet)
  // must still resolve from the flat site directory.
  html = html.replace(/href="(\.\/[^":]+|[^":#/][^":]*)"/g, (whole, target) => {
    if (/^(https?:|mailto:|#|\.\.\/\.\.\/)/.test(target) || target.endsWith(".html") && !target.includes("/")) {
      if (!target.startsWith("./")) return whole;
    }
    if (/^(https?:|mailto:|local:|#)/.test(target)) return whole;
    if (/\.md(#|$)/.test(target)) return whole;
    const resolved = join(dirname(doc.path), target).replace(/^\.\//, "");
    if (!existsSync(join(ROOT, resolved.split("#")[0]))) return whole;
    return `href="../../${resolved}"`;
  });

  // Wide tables get their own scroll container so the page never scrolls sideways.
  html = html.replace(/<table>/g, '<div class="scroller"><table>').replace(/<\/table>/g, "</table></div>");

  const section = SECTIONS.find((s) => s.id === doc.section);
  const page = shell({
    title: `${doc.title} · Praxmodoro docs`,
    eyebrow: section.title,
    heading: doc.title,
    standfirst: doc.summary ? esc(doc.summary) : "",
    meta: `<span>${doc.words.toLocaleString()} words</span><span><code>${esc(doc.path)}</code></span>`,
    body: `<article class="prose">${html}</article>
<footer class="docfoot">
  <a class="srcbtn" href="../../${doc.path}">Read the Markdown source<span aria-hidden="true"> ↗</span></a>
  <span class="srcpath"><code>${esc(doc.path)}</code></span>
</footer>`,
    depth: 1,
    nav: NAV(1),
  });
  writeFileSync(join(SITE, `${doc.slug}.html`), page);
  generated += 1;
}

/* ── Bespoke pages composed through the same shell ─────────────────────── */

for (const doc of docs) {
  const spec = doc.bespokeSpec;
  if (!spec?.partial) continue;
  // Depth is measured from docs/, where index.html lives.
  const depth = spec.out.replace(/^docs\//, "").split("/").length - 1;
  const up = "../".repeat(depth);
  const page = shell({
    title: `${doc.title} · Praxmodoro docs`,
    eyebrow: spec.eyebrow,
    heading: spec.heading,
    standfirst: spec.standfirst,
    meta: spec.meta,
    body: `${readFileSync(join(ROOT, spec.partial), "utf8")}
<footer class="docfoot">
  <a class="srcbtn" href="${relative(dirname(join(ROOT, spec.out)), join(ROOT, doc.path))}">Read the Markdown source<span aria-hidden="true"> ↗</span></a>
  <span class="srcpath"><code>${esc(doc.path)}</code></span>
</footer>`,
    depth,
    nav: NAV(depth),
  });
  writeFileSync(join(ROOT, spec.out), page);
}

/* ── The index ─────────────────────────────────────────────────────────── */

const statusChip = (s) =>
  s === "approved" ? '<span class="chip ok">approved direction</span>' : '<span class="chip muted">comparative record</span>';

/** docs/index.html sits one level below the repository root. */
const IDX_UP = "../";

const mockCards = MOCKUPS.map(
  (m) => `<a class="mock" href="${IDX_UP}${m.href}">
    <span class="mock-top">${esc(m.name)}${statusChip(m.status)}</span>
    <span class="mock-note">${esc(m.note)}</span>
    <span class="mock-go">Open the prototype <span aria-hidden="true">→</span></span>
  </a>`
).join("");

const sectionBlocks = SECTIONS.map((section) => {
  const items = docs.filter((d) => d.section === section.id);
  if (!items.length) return "";
  const rows = items
    .map((d) => {
      const htmlHref = d.bespoke ? `${IDX_UP}${d.bespoke}` : `site/${d.slug}.html`;
      return `<li class="doc" data-search="${esc((d.title + " " + d.path + " " + d.summary).toLowerCase())}">
        <a class="doc-main" href="${htmlHref}">
          <span class="doc-title">${esc(d.title)}${d.bespoke ? '<span class="chip accent">designed page</span>' : ""}</span>
          ${d.summary ? `<span class="doc-sum">${esc(d.summary)}</span>` : ""}
          <span class="doc-path"><code>${esc(d.path)}</code> · ${d.words.toLocaleString()} words</span>
        </a>
        <a class="doc-md" href="${IDX_UP}${d.path}" title="Markdown source">MD</a>
      </li>`;
    })
    .join("");
  return `<section class="block" id="${section.id}">
    <div class="block-head">
      <h2>${esc(section.title)}</h2>
      <p>${esc(section.blurb)}</p>
    </div>
    <ul class="docs">${rows}</ul>
  </section>`;
}).join("");

const counts = {
  docs: docs.length,
  pages: generated + Object.keys(BESPOKE).length,
  mocks: MOCKUPS.length,
  words: docs.reduce((n, d) => n + d.words, 0),
};

const index = shell({
  title: "Praxmodoro — documentation",
  eyebrow: "",
  heading: "",
  standfirst: "",
  meta: "",
  extraClass: "is-index",
  body: `
<header class="hero">
  <div class="eyebrow">Documentation index</div>
  <h1>Every document, and the mockups they argue about.</h1>
  <p class="standfirst">Praxmodoro is a native macOS focus timer built spec-first. This is the whole paper trail — the contract, the specs, the audits, the research it rests on, and the three design directions one of which was approved.</p>
  <div class="stats">
    <span><b>${counts.docs}</b> documents</span>
    <span><b>${counts.pages}</b> HTML pages</span>
    <span><b>${counts.mocks}</b> mockup sets</span>
    <span><b>${(counts.words / 1000).toFixed(0)}k</b> words</span>
  </div>
  <label class="search">
    <span class="sr">Filter documents</span>
    <input type="search" id="filter" placeholder="Filter documents — try “accessibility”, “spec”, “break”" autocomplete="off">
  </label>
</header>

<section class="block" id="mockups">
  <div class="block-head">
    <h2>Design mockups</h2>
    <p>Interactive prototypes. Living Companion is the approved direction and the reference the app is audited against; the other two are the alternatives it was chosen over.</p>
  </div>
  <div class="mocks">${mockCards}</div>
</section>

${sectionBlocks}

<p class="rebuild">Generated by <code>npm run docs:build</code> from the Markdown in this repository. Edit the Markdown, not these pages.</p>
`,
  depth: 0,
  nav: NAV(0),
}).replace(
  "</script>",
  `</script>
<script>
(() => {
  const input = document.getElementById("filter");
  if (!input) return;
  const docs = [...document.querySelectorAll(".doc")];
  const blocks = [...document.querySelectorAll(".block")];
  input.addEventListener("input", () => {
    const q = input.value.trim().toLowerCase();
    docs.forEach((d) => { d.hidden = q !== "" && !d.dataset.search.includes(q); });
    blocks.forEach((b) => {
      const items = [...b.querySelectorAll(".doc")];
      b.hidden = items.length > 0 && items.every((d) => d.hidden);
    });
  });
})();
</script>`
);

writeFileSync(join(ROOT, "docs", "index.html"), index);

console.log(`docs: ${generated} generated + ${Object.keys(BESPOKE).length} hand-authored = ${counts.pages} pages`);
console.log(`index: docs/index.html (${counts.docs} documents, ${counts.mocks} mockup sets)`);
