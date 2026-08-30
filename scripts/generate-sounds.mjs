#!/usr/bin/env node
// Generate Praxmodoro's bundled sound cues as plain 16-bit mono WAV files.
// Original synthesized audio — no third-party samples, no licence burden
// (spec: session-settings "Sound cues, all optional": bundled, no network).
// Run: node scripts/generate-sounds.mjs  → writes app/Resources/Sounds/.
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const RATE = 44100;
const OUT = join(dirname(fileURLToPath(import.meta.url)), "..", "app", "Resources", "Sounds");

function wav(samples) {
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((s, i) => data.writeInt16LE(Math.max(-1, Math.min(1, s)) * 0x7fff, i * 2));
  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write("WAVEfmt ", 8);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(RATE, 24);
  header.writeUInt32LE(RATE * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write("data", 36);
  header.writeUInt32LE(data.length, 40);
  return Buffer.concat([header, data]);
}

/** A soft tick: a short sine burst with a fast exponential decay. */
function tick(freq, amp) {
  const n = Math.floor(RATE * 0.03);
  return Array.from({ length: n }, (_, i) => {
    const t = i / RATE;
    return amp * Math.sin(2 * Math.PI * freq * t) * Math.exp(-t * 220);
  });
}

/** A gentle two-note chime with slow decay and a soft attack. */
function chime(freqs, amp) {
  const note = Math.floor(RATE * 0.45);
  const out = [];
  freqs.forEach((freq, index) => {
    const start = Math.floor(index * note * 0.6);
    for (let i = 0; i < note; i++) {
      const t = i / RATE;
      const env = Math.min(1, t * 90) * Math.exp(-t * 6);
      const s = amp * env * (Math.sin(2 * Math.PI * freq * t) + 0.3 * Math.sin(4 * Math.PI * freq * t));
      out[start + i] = (out[start + i] ?? 0) + s;
    }
  });
  return out.map((s) => s ?? 0);
}

mkdirSync(OUT, { recursive: true });
const files = {
  "chime-block-start.wav": chime([392, 523.25], 0.26), // G4 → C5, a soft arrival into focus
  "tick-focus.wav": tick(1050, 0.22),
  "tick-break.wav": tick(700, 0.18),
  "chime-focus-end.wav": chime([523.25, 659.25], 0.3), // C5 → E5, rising: the block completed
  "chime-break-end.wav": chime([659.25, 523.25], 0.3), // E5 → C5, settling: come back gently
};
for (const [name, samples] of Object.entries(files)) {
  writeFileSync(join(OUT, name), wav(samples));
  console.log(`wrote ${name} (${samples.length} samples)`);
}
