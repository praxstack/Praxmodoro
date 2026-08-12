#!/usr/bin/env node
// Design-token converter (issue #8): derives app/Sources/DesignTokens.swift
// from the Living Companion mock's tokens.css (light) and tokens-dark.css
// (dark). Colour math is the real pipeline — OKLCH → OKLab → LMS → linear
// sRGB → gamma — not an eyeballed approximation; out-of-gamut channels are
// clamped to [0, 1] and every clamp is reported on stderr and annotated on
// the emitted constant.
//
// Scope (per the approved settings-parity plan, lane 2): colour, spacing,
// radius and duration tokens. Type faces/sizes are ticket #9; gradients,
// shadows and z-index stay CSS-side.
//
// Zero dependencies. Run via `npm run tokens:build` or directly with node.

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const mockDir = join(root, "design-mocks", "living-companion");
const outputPath = join(root, "app", "Sources", "DesignTokens.swift");

// ---------------------------------------------------------------------------
// Colour math
// ---------------------------------------------------------------------------

/** OKLCH → gamma-encoded sRGB in [0,1], with gamut-clamp reporting. */
function oklchToSrgb({ lightness, chroma, hueDegrees }) {
  const hue = (hueDegrees * Math.PI) / 180;
  const labA = chroma * Math.cos(hue);
  const labB = chroma * Math.sin(hue);

  // OKLab → LMS (Björn Ottosson's matrices; cube undoes the cube roots).
  const l = (lightness + 0.3963377774 * labA + 0.2158037573 * labB) ** 3;
  const m = (lightness - 0.1055613458 * labA - 0.0638541728 * labB) ** 3;
  const s = (lightness - 0.0894841775 * labA - 1.291485548 * labB) ** 3;

  // LMS → linear sRGB.
  const linear = [
    4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s,
  ];

  // Gamma encode, then clamp to the sRGB gamut. The clamp is the documented
  // fallback for tokens the mock authored outside sRGB; every use is noted.
  const clampedChannels = [];
  const rgb = linear.map((value, index) => {
    const encoded =
      value <= 0.0031308 ? 12.92 * value : 1.055 * Math.pow(value, 1 / 2.4) - 0.055;
    if (encoded < -1e-9 || encoded > 1 + 1e-9) {
      clampedChannels.push("rgb"[index]);
    }
    return Math.min(1, Math.max(0, encoded));
  });
  return { rgb, clampedChannels };
}

// ---------------------------------------------------------------------------
// CSS parsing
// ---------------------------------------------------------------------------

/** All `--name: value;` custom properties in declaration order. */
function parseCustomProperties(css) {
  const declarations = new Map();
  for (const match of css.matchAll(/--([a-z0-9-]+)\s*:\s*([^;]+);/g)) {
    declarations.set(match[1], match[2].replace(/\s+/g, " ").trim());
  }
  return declarations;
}

/** `oklch(96.5% 0.014 78)` or `oklch(98% 0.01 80 / 0.6)` → components. */
function parseOklch(value, tokenName, fileName) {
  const match = value.match(
    /^oklch\(\s*([\d.]+)%\s+([\d.]+)\s+([\d.]+)\s*(?:\/\s*([\d.]+)\s*)?\)$/
  );
  if (!match) {
    throw new Error(`${fileName}: --${tokenName} is not plain oklch(): "${value}"`);
  }
  return {
    lightness: Number(match[1]) / 100,
    chroma: Number(match[2]),
    hueDegrees: Number(match[3]),
    alpha: match[4] === undefined ? 1 : Number(match[4]),
  };
}

/** kebab-case → lowerCamelCase; a leading step count expands its letter
 *  (`2xs` → `xxs`, `3xl` → `xxxl`) so every name is a Swift identifier. */
function swiftName(kebab) {
  return kebab
    .split("-")
    .map((part) => part.replace(/^([23])(x[sl])$/, (_, n, xs) => "x".repeat(Number(n) - 1) + xs))
    .map((part, index) => (index === 0 ? part : part[0].toUpperCase() + part.slice(1)))
    .join("");
}

const stripPrefix = (declarations, prefix) =>
  [...declarations].filter(([name]) => name.startsWith(prefix))
    .map(([name, value]) => [name.slice(prefix.length), value]);

// ---------------------------------------------------------------------------
// Load both variants
// ---------------------------------------------------------------------------

const lightCSS = readFileSync(join(mockDir, "tokens.css"), "utf8");
const darkCSS = readFileSync(join(mockDir, "tokens-dark.css"), "utf8");
const light = parseCustomProperties(lightCSS);
const dark = parseCustomProperties(darkCSS);

const lightColours = stripPrefix(light, "color-");
const darkColours = new Map(stripPrefix(dark, "color-"));

// The dark variant must re-declare exactly the light colour set — a missing
// or extra name is a divergence between the variants, not a theme.
const lightNames = new Set(lightColours.map(([name]) => name));
for (const [name] of lightColours) {
  if (!darkColours.has(name)) throw new Error(`tokens-dark.css is missing --color-${name}`);
}
for (const name of darkColours.keys()) {
  if (!lightNames.has(name)) throw new Error(`tokens-dark.css declares --color-${name}, which tokens.css does not`);
}

// ---------------------------------------------------------------------------
// Emit Swift
// ---------------------------------------------------------------------------

const clampNotes = [];

function colourLines(variantLabel, colours) {
  const lines = [];
  for (const [name, value] of colours) {
    if (value === "transparent") continue; // --color-clear: SwiftUI's own Color.clear is canonical.
    const token = parseOklch(value, `color-${name}`, variantLabel);
    const { rgb, clampedChannels } = oklchToSrgb(token);
    const constant = swiftName(name);
    const channels = rgb.map((v) => v.toFixed(4));
    let note = "";
    if (clampedChannels.length > 0) {
      note = `  // gamut: clamped ${clampedChannels.join(",")}`;
      clampNotes.push(`${variantLabel} --color-${name}: clamped ${clampedChannels.join(",")}`);
    }
    lines.push(
      `        static let ${constant} = Color(red: ${channels[0]}, green: ${channels[1]}, blue: ${channels[2]}, opacity: ${token.alpha})${note}`
    );
    if (token.alpha < 1) {
      lines.push(`        static let ${constant}Alpha: Double = ${token.alpha}`);
    }
  }
  return lines;
}

/** rem → points at the platform text base (1rem = 16pt). */
function remToPoints(value, tokenName) {
  const match = value.match(/^([\d.]+)rem$/);
  if (!match) throw new Error(`--${tokenName} is not a rem length: "${value}"`);
  return Number(match[1]) * 16;
}

/** ms → seconds. */
function msToSeconds(value, tokenName) {
  const match = value.match(/^([\d.]+)ms$/);
  if (!match) throw new Error(`--${tokenName} is not a ms duration: "${value}"`);
  return Number(match[1]) / 1000;
}

const scaleLines = (entries, prefix, unit, convert) =>
  entries.map(([name, value]) => {
    const number = convert(value, `${prefix}${name}`);
    return `        static let ${swiftName(name)}: ${unit} = ${number}`;
  });

const spacingLines = scaleLines(stripPrefix(light, "space-"), "space-", "CGFloat", remToPoints);
const radiusLines = scaleLines(stripPrefix(light, "radius-"), "radius-", "CGFloat", remToPoints);
const durationLines = scaleLines(stripPrefix(light, "dur-"), "dur-", "TimeInterval", msToSeconds);

const swift = `// GENERATED by scripts/generate-design-tokens.mjs — edit tokens.css, not this file.
// Source of truth: design-mocks/living-companion/tokens.css (light) and
// tokens-dark.css (dark). Colours are the mock's oklch declarations pushed
// through OKLCH → OKLab → LMS → linear sRGB → gamma, clamped to gamut where
// noted; spacing and radii are rem × 16pt; durations are ms → seconds.
// Regenerate with \`npm run tokens:build\`.
import SwiftUI

enum DesignTokens {
    enum Light {
${colourLines("tokens.css", lightColours).join("\n")}
    }

    enum Dark {
${colourLines("tokens-dark.css", lightColours.map(([name]) => [name, darkColours.get(name)])).join("\n")}
    }

    enum Spacing {
${spacingLines.join("\n")}
    }

    enum Radius {
${radiusLines.join("\n")}
    }

    enum Duration {
${durationLines.join("\n")}
    }
}
`;

writeFileSync(outputPath, swift);

const colourCount = lightColours.filter(([, value]) => value !== "transparent").length;
console.log(
  `DesignTokens.swift: ${colourCount} colours × 2 variants, ` +
    `${spacingLines.length} spacing, ${radiusLines.length} radius, ${durationLines.length} duration tokens.`
);
if (clampNotes.length > 0) {
  console.error(`gamut clamps (${clampNotes.length}):`);
  for (const note of clampNotes) console.error(`  ${note}`);
} else {
  console.log("gamut clamps: none — every token converts inside sRGB.");
}
