// Generates the five moment frames (02–06) for the Praxmodoro demo from one config,
// so the window plate, text column and motion grammar stay identical across rooms.
// Output files are plain, self-contained HyperFrames sub-compositions.
import { writeFileSync } from "node:fs";
import { join } from "node:path";

const PROJECT = process.argv[2];
if (!PROJECT) throw new Error("usage: node gen-moments.mjs <project-dir>");

// ---- shared geometry (see frame.md) ----
const PLATE = { x: 680, y: 136, w: 1160, h: 708.5 };
const SRC = { w: 1800, h: 1104, crop: 6, radius: 33 };
const S = PLATE.w / (SRC.w - 2 * SRC.crop); // display px per source px
const VID = {
  w: +(SRC.w * S).toFixed(2),
  h: +(SRC.h * S).toFixed(2),
  off: +(-SRC.crop * S).toFixed(2),
};
const RADIUS = Math.ceil(SRC.radius * S); // 22px

const C = {
  ink: "#242B3D",
  ink2: "#434A5B",
  nightInk: "#E0E4F1",
  nightInk2: "#B3BACF",
  accent: "#454A80",
  arcSun: "#F5C984",
  arcHalo: "rgba(249, 218, 161, 0.6)",
};

const ICON = {
  cmd: `<svg class="kbd-icon" viewBox="0 0 24 24" aria-hidden="true"><path d="M15 6v12a3 3 0 1 0 3-3H6a3 3 0 1 0 3 3V6a3 3 0 1 0-3 3h12a3 3 0 1 0-3-3"/></svg>`,
  ret: `<svg class="kbd-icon" viewBox="0 0 24 24" aria-hidden="true"><polyline points="9 10 4 15 9 20"/><path d="M20 4v7a4 4 0 0 1-4 4H4"/></svg>`,
};
const key = (inner, label) => `<span class="kbd" aria-label="${label}">${inner}</span>`;

const frames = [
  {
    id: "02-begin",
    p: "begin",
    n: 1,
    duration: 10.2,
    sky: ["#FAEFDC", "#DEF3E4"],
    title: "Begin",
    lede: "One task, one tiny step.",
    videos: [{ id: "begin-video", src: "assets/footage/01-begin.mov", start: 0, dur: 10.2, media: 1.3 }],
    cues: [
      { at: 1.9, html: "Name the task and the smallest visible move." },
      { at: 5.4, html: "Say how you’re arriving, then pick a rhythm." },
    ],
    keys: { at: 8.1, html: `${key(ICON.cmd, "Command")}${key(ICON.ret, "Return")}<span class="kbd-word">begins</span>` },
  },
  {
    id: "03-focus",
    p: "focus",
    n: 2,
    duration: 10.6,
    sky: ["#DEF3E4", "#DEF0F8"],
    night: { sky: ["#1B2035", "#101526"], at: 5.8, dur: 1.2 },
    title: "Focus",
    lede: "A light that breathes slower than you.",
    videos: [
      { id: "focus-video-light", src: "assets/footage/02-focus.mov", start: 0, dur: 7.2, media: 0 },
      { id: "focus-video-dark", src: "assets/footage/02-focus-dark.mov", start: 5.6, dur: 5.0, media: 5.6, layer: "dark" },
    ],
    cues: [
      { at: 1.9, html: "One long breath, about every twelve seconds." },
      { at: 4.6, html: "It never speeds up." },
      { at: 7.4, html: "The same light, in dark mode." },
    ],
  },
  {
    id: "04-checkin",
    p: "checkin",
    n: 3,
    duration: 7.8,
    sky: ["#DEF0F8", "#ECE5FB"],
    title: "Check in",
    lede: "A question, not a report card.",
    videos: [{ id: "checkin-video", src: "assets/footage/03-checkin.mov", start: 0, dur: 7.8, media: 0.9 }],
    cues: [
      { at: 1.6, html: `<span class="kbd-row">${key(ICON.cmd, "Command")}${key("K", "K")}</span> asks how the step fits.` },
      { at: 4.0, html: "Four answers.<br />None of them is a failure." },
    ],
  },
  {
    id: "05-break",
    p: "break",
    n: 4,
    duration: 8.0,
    sky: ["#ECE5FB", "#F9E0E9"],
    title: "Break",
    lede: "Rest that keeps your place.",
    videos: [{ id: "break-video", src: "assets/footage/04-break.mov", start: 0, dur: 8.0, media: 6.4 }],
    cues: [
      { at: 1.9, html: "Your next step waits on a re-entry card." },
      { at: 5.6, html: `<span class="kbd-row">${key("R", "R")}</span> returns you to that step.` },
    ],
  },
  {
    id: "06-review",
    p: "review",
    n: 5,
    duration: 6.6,
    sky: ["#F9E0E9", "#EBDDEF"],
    title: "Review",
    lede: "Today, written down gently.",
    videos: [{ id: "review-video", src: "assets/footage/05-review.mov", start: 0, dur: 6.6, media: 1.85 }],
    cues: [
      { at: 1.9, html: "A plain timeline.<br />No streaks, no scores." },
      { at: 4.3, html: "One session is not a pattern." },
    ],
  },
];

const fontFaces = `
      @font-face {
        font-family: "Zen Maru Gothic";
        font-style: normal;
        font-weight: 500;
        src: url("assets/fonts/zen-maru-gothic-latin-500.woff2") format("woff2");
      }
      @font-face {
        font-family: "Atkinson Hyperlegible Next";
        font-style: normal;
        font-weight: 200 800;
        src: url("assets/fonts/atkinson-hyperlegible-next-latin-wght.woff2") format("woff2");
      }`;

function arcSvg(p) {
  // The site's arc: horizon, dotted half-circle, five ticks; the sun rides a <g> rotated about (60,62).
  return `<svg id="${p}-arc" class="arc" viewBox="0 0 120 74" role="img" aria-label="Moment">
            <path class="arc-horizon" d="M0 62h120" />
            <path class="arc-path" d="M10 62a50 50 0 0 1 100 0" />
            <g class="arc-ticks">
              <circle cx="10" cy="62" r="1.6" /><circle cx="24.64" cy="26.64" r="1.6" /><circle cx="60" cy="12" r="1.6" /><circle cx="95.36" cy="26.64" r="1.6" /><circle cx="110" cy="62" r="1.6" />
            </g>
            <g id="${p}-sun">
              <circle class="arc-glow" cx="10" cy="62" r="10" />
              <circle class="arc-sun" cx="10" cy="62" r="5.5" />
            </g>
          </svg>`;
}

function build(f) {
  const { id, p, n, duration: D } = f;
  const night = f.night;
  const videoLayers = f.videos
    .map(
      (v) => `          <div id="${v.id}-layer" class="${p}-layer">
            <video
              id="${v.id}"
              src="${v.src}"
              muted
              playsinline
              data-start="${v.start}"
              data-duration="${v.dur}"
              data-media-start="${v.media}"
              data-track-index="${v.layer === "dark" ? 2 : 1}"
            ></video>
          </div>`,
    )
    .join("\n");

  const cues = f.cues
    .map((c, i) => `            <p id="${p}-cue-${i + 1}" class="${p}-cue">${c.html}</p>`)
    .join("\n");
  const keys = f.keys ? `\n          <div id="${p}-keys" class="${p}-keys">${f.keys.html}</div>` : "";

  // ---- timeline ----
  const prevAngle = Math.max(0, (n - 2) * 45);
  const angle = (n - 1) * 45;
  const tl = [];
  tl.push(`      // Window plate: a gentle settle, then the slowest possible drift. Footage runs at real speed.`);
  tl.push(`      tl.fromTo("#${p}-plate", { scale: 0.985 }, { scale: 1, duration: 2.0, ease: "power2.out" }, 0);`);
  tl.push(`      tl.to("#${p}-plate", { scale: 1.012, duration: ${(D - 2.0).toFixed(2)}, ease: "none" }, 2.0);`);
  tl.push(`      // Text column waits until the room's crossfade has mostly finished.`);
  tl.push(`      tl.fromTo("#${p}-arc", { opacity: 0, y: 10 }, { opacity: 1, y: 0, duration: 1.0, ease: "power3.out" }, 0.9);`);
  if (n === 1) {
    tl.push(`      tl.fromTo("#${p}-sun", { opacity: 0 }, { opacity: 1, duration: 1.2, ease: "sine.inOut" }, 1.1);`);
  } else {
    tl.push(
      `      tl.fromTo("#${p}-sun", { rotation: ${prevAngle}, svgOrigin: "60 62" }, { rotation: ${angle}, svgOrigin: "60 62", duration: 1.6, ease: "sine.inOut" }, 1.0);`,
    );
  }
  tl.push(`      tl.fromTo("#${p}-title", { opacity: 0, y: 12 }, { opacity: 1, y: 0, duration: 1.0, ease: "power3.out" }, 1.05);`);
  tl.push(`      tl.fromTo("#${p}-lede", { opacity: 0, y: 12 }, { opacity: 1, y: 0, duration: 1.0, ease: "power3.out" }, 1.25);`);
  f.cues.forEach((c, i) => {
    const sel = `#${p}-cue-${i + 1}`;
    if (i > 0) {
      const prev = `#${p}-cue-${i}`;
      tl.push(`      tl.to("${prev}", { opacity: 0, y: -6, duration: 0.45, ease: "sine.inOut" }, ${(c.at - 0.3).toFixed(2)});`);
    }
    tl.push(`      tl.fromTo("${sel}", { opacity: 0, y: 10 }, { opacity: 1, y: 0, duration: 0.9, ease: "power3.out" }, ${c.at.toFixed(2)});`);
  });
  if (f.keys) {
    tl.push(`      tl.fromTo("#${p}-keys", { opacity: 0, y: 10 }, { opacity: 1, y: 0, duration: 0.9, ease: "power3.out" }, ${f.keys.at.toFixed(2)});`);
  }
  if (night) {
    tl.push(`      // Same moment, at night: the dark clip dissolves in at the same media time; the room turns to night.`);
    tl.push(`      tl.fromTo("#focus-video-dark-layer", { opacity: 0 }, { opacity: 1, duration: ${night.dur}, ease: "sine.inOut" }, ${night.at});`);
    tl.push(`      tl.fromTo("#${p}-night", { opacity: 0 }, { opacity: 1, duration: ${night.dur}, ease: "sine.inOut" }, ${night.at});`);
    tl.push(
      `      tl.fromTo("#${p}-column", { "--ink": "${C.ink}", "--ink-2": "${C.ink2}" }, { "--ink": "${C.nightInk}", "--ink-2": "${C.nightInk2}", duration: ${night.dur}, ease: "sine.inOut" }, ${night.at});`,
    );
  }

  const nightLayer = night
    ? `\n        <div id="${p}-night" class="${p}-sky-layer" style="background: linear-gradient(180deg, ${night.sky[0]}, ${night.sky[1]});"></div>`
    : "";

  return `<template id="${id}-template">
  <style>${fontFaces}
    #root {
      position: absolute;
      inset: 0;
      width: 100%;
      height: 100%;
      overflow: hidden;
    }
    #${p}-sky {
      position: absolute;
      inset: 0;
    }
    .${p}-sky-layer {
      position: absolute;
      inset: 0;
    }
    #${p}-plate {
      position: absolute;
      left: ${PLATE.x}px;
      top: ${PLATE.y}px;
      width: ${PLATE.w}px;
      height: ${PLATE.h}px;
      transform-origin: 50% 50%;
    }
    #${p}-shadow {
      position: absolute;
      inset: 0;
      border-radius: ${RADIUS}px;
      background: #f5f5f7;
      box-shadow:
        0 1px 2px rgba(51, 56, 85, 0.12),
        0 24px 48px -28px rgba(37, 43, 76, 0.2),
        0 60px 100px -70px rgba(37, 43, 76, 0.2),
        0 30px 80px -40px rgba(51, 56, 85, 0.14);
    }
    #${p}-mask {
      position: absolute;
      inset: 0;
      overflow: hidden;
      border-radius: ${RADIUS}px;
      clip-path: inset(0 round ${RADIUS}px);
    }
    .${p}-layer {
      position: absolute;
      inset: 0;
    }
    .${p}-layer video {
      position: absolute;
      left: ${VID.off}px;
      top: ${VID.off}px;
      width: ${VID.w}px;
      height: ${VID.h}px;
      object-fit: fill;
    }
    #${p}-rim {
      position: absolute;
      inset: 0;
      border-radius: ${RADIUS}px;
      box-shadow: inset 0 0 0 1px rgba(36, 43, 61, 0.1);
      pointer-events: none;
    }
    #${p}-column {
      --ink: ${C.ink};
      --ink-2: ${C.ink2};
      position: absolute;
      left: 100px;
      top: ${PLATE.y}px;
      width: 540px;
      height: ${PLATE.h}px;
      display: flex;
      flex-direction: column;
      justify-content: center;
      color: var(--ink);
    }
    #${p}-arc {
      display: block;
      width: 150px;
      height: 92.5px;
      overflow: visible;
      color: var(--ink-2);
    }
    #${p}-arc .arc-horizon,
    #${p}-arc .arc-path {
      fill: none;
      stroke: currentColor;
      stroke-width: 1.2;
      stroke-linecap: round;
    }
    #${p}-arc .arc-horizon {
      opacity: 0.36;
    }
    #${p}-arc .arc-path {
      opacity: 0.65;
      stroke-dasharray: 1 4;
    }
    #${p}-arc .arc-ticks {
      fill: currentColor;
      opacity: 0.55;
    }
    #${p}-arc .arc-glow {
      fill: ${C.arcHalo};
    }
    #${p}-arc .arc-sun {
      fill: ${C.arcSun};
      stroke: currentColor;
      stroke-width: 1;
    }
    #${p}-title {
      margin: 22px 0 0;
      font-family: "Zen Maru Gothic", sans-serif;
      font-weight: 500;
      font-size: 104px;
      line-height: 1;
      letter-spacing: -0.015em;
      color: var(--ink);
      text-wrap: balance;
    }
    #${p}-lede {
      margin: 20px 0 0;
      font-family: "Zen Maru Gothic", sans-serif;
      font-weight: 500;
      font-size: 56px;
      line-height: 1.18;
      color: var(--ink-2);
      text-wrap: balance;
    }
    #${p}-cues {
      position: relative;
      margin-top: 40px;
      width: 540px;
      height: 130px;
    }
    .${p}-cue {
      position: absolute;
      left: 0;
      top: 0;
      width: 540px;
      margin: 0;
      font-family: "Atkinson Hyperlegible Next", sans-serif;
      font-weight: 500;
      font-size: 44px;
      line-height: 1.3;
      color: var(--ink-2);
      text-wrap: balance;
    }
    #${p}-keys {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-top: 22px;
      height: 64px;
    }
    /* Keycaps sit on their own row above the sentence they belong to. */
    #${p}-column .kbd-row {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 14px;
    }
    #${p}-column .kbd {
      display: inline-flex;
      align-items: center;
      justify-content: center;
      min-width: 58px;
      height: 58px;
      padding: 0 14px;
      box-sizing: border-box;
      border-radius: 14px;
      background: rgba(247, 250, 255, 0.72);
      border: 1.5px solid rgba(36, 43, 61, 0.24);
      box-shadow: 0 2px 0 rgba(36, 43, 61, 0.14);
      font-family: "Atkinson Hyperlegible Next", sans-serif;
      font-weight: 650;
      font-size: 34px;
      line-height: 1;
      color: ${C.ink};
    }
    #${p}-column .kbd-icon {
      display: block;
      width: 30px;
      height: 30px;
      fill: none;
      stroke: ${C.ink};
      stroke-width: 2.2;
      stroke-linecap: round;
      stroke-linejoin: round;
    }
    #${p}-column .kbd-word {
      margin-left: 6px;
      font-family: "Atkinson Hyperlegible Next", sans-serif;
      font-weight: 500;
      font-size: 44px;
      color: var(--ink-2);
    }
  </style>

  <div id="root" data-composition-id="${id}" data-width="1920" data-height="1080" data-duration="${D}">
    <div id="${p}-sky" class="clip" data-start="0" data-duration="${D}" data-track-index="0">
      <div class="${p}-sky-layer" style="background: linear-gradient(180deg, ${f.sky[0]}, ${f.sky[1]});"></div>${nightLayer}
    </div>

    <div id="${p}-plate">
      <div id="${p}-shadow"></div>
      <div id="${p}-mask">
${videoLayers}
      </div>
      <div id="${p}-rim"></div>
    </div>

    <div id="${p}-column">
      ${arcSvg(p)}
      <h2 id="${p}-title">${f.title}</h2>
      <p id="${p}-lede">${f.lede}</p>
      <div id="${p}-cues">
${cues}
      </div>${keys}
    </div>
  </div>

  <script src="assets/vendor/gsap-3.14.2.min.js"></script>
  <script>
    (function () {
      const tl = gsap.timeline({ paused: true });
${tl.join("\n")}
      window.__timelines["${id}"] = tl;
    })();
  </script>
</template>
`;
}

for (const f of frames) {
  const out = join(PROJECT, "compositions/frames", `${f.id}.html`);
  writeFileSync(out, build(f));
  console.log("wrote", out);
}
console.log({ S, VID, RADIUS });
