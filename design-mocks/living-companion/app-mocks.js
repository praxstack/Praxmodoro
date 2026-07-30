const shell = document.querySelector("#prototypeShell");
const screenButtons = [...document.querySelectorAll("[data-screen-target]")];
const screens = [...document.querySelectorAll("[data-screen]")];
const hudCenter = document.querySelector("#hudCenter");
const timerTime = document.querySelector("#timerTime");
const timerState = document.querySelector("#timerState");
const timerToggle = document.querySelector("#timerToggle");
const focusField = document.querySelector("#focusField");
const initiateMessage = document.querySelector("#initiateMessage");
const checkinMessage = document.querySelector("#checkinMessage");
const breakMessage = document.querySelector("#breakMessage");

const screenMeta = {
  initiate: "Ready · nothing running",
  focus: "Focus · breathing with you",
  checkin: "Check-in · timer held",
  break: "03:00 · intentional break",
  review: "Today · local record"
};

let remaining = 17 * 60 + 26;
let running = true;
let timerInterval;

function formatTime(totalSeconds) {
  const minutes = Math.floor(Math.max(0, totalSeconds) / 60);
  const seconds = Math.max(0, totalSeconds) % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
}

function focusScreenIsCurrent() {
  return document.querySelector("#screen-focus")?.classList.contains("is-current");
}

function updateHud(name) {
  if (name === "focus") {
    hudCenter.textContent = `${formatTime(remaining)} · ${running ? "breathing with you" : "held"}`;
  } else {
    hudCenter.textContent = screenMeta[name] ?? screenMeta.initiate;
  }
}

function showScreen(name, updateHash = true) {
  screenButtons.forEach((button) => {
    button.setAttribute("aria-selected", String(button.dataset.screenTarget === name));
  });
  screens.forEach((screen) => {
    const active = screen.dataset.screen === name;
    screen.classList.toggle("is-current", active);
    screen.toggleAttribute("inert", !active);
  });
  updateHud(name);
  if (updateHash) history.replaceState(null, "", `#${name}`);
  document.querySelector(`[data-screen="${name}"]`)?.querySelector("h1, h2")?.focus?.({ preventScroll: true });
}

screenButtons.forEach((button) => button.addEventListener("click", () => showScreen(button.dataset.screenTarget)));
document.querySelectorAll("[data-screen-jump]").forEach((button) => button.addEventListener("click", () => showScreen(button.dataset.screenJump)));

document.querySelectorAll(".choice-row, .mode-row").forEach((group) => {
  group.addEventListener("click", (event) => {
    const button = event.target.closest("button");
    if (!button) return;
    group.querySelectorAll("button").forEach((item) => item.setAttribute("aria-pressed", String(item === button)));
  });
});

document.querySelectorAll("[data-checkin]").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll("[data-checkin]").forEach((item) => item.dataset.selected = String(item === button));
    const responses = {
      holding: "Kept as is. The check-in folds away and the block continues.",
      smaller: "New next step: add a check beside the one finished section.",
      detour: "Detour noted as information. Return, re-plan, or close — all fine.",
      break: "Your place is held. The intentional break is ready when you are."
    };
    checkinMessage.textContent = responses[button.dataset.checkin];
  });
});

document.querySelectorAll("[data-break]").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll("[data-break]").forEach((item) => item.dataset.selected = String(item === button));
    const responses = {
      water: "Water it is. Your place is held while you stand up.",
      stretch: "Stretch chosen. The re-entry card waits, unchanged.",
      away: "Step away — a doorway counts. Nothing advances without you.",
      quiet: "Quiet chosen. No prompts until you come back."
    };
    if (breakMessage) breakMessage.textContent = responses[button.dataset.break];
  });
});

function updateTimer() {
  if (!timerTime) return;
  timerTime.textContent = formatTime(remaining);
  if (focusScreenIsCurrent()) updateHud("focus");
}

function startTimer() {
  clearInterval(timerInterval);
  timerInterval = window.setInterval(() => {
    if (!running || remaining <= 0) return;
    remaining -= 1;
    updateTimer();
  }, 1000);
}

timerToggle?.addEventListener("click", () => {
  running = !running;
  timerToggle.textContent = running ? "Ⅱ" : "▶";
  timerToggle.setAttribute("aria-label", running ? "Pause timer" : "Resume timer");
  timerState.textContent = running ? "Breathing with you · check-in in 6 min" : "Held · your place is kept";
  if (focusField) focusField.dataset.state = running ? "breathing" : "held";
  updateTimer();
});

function adjustMinutes(delta) {
  remaining = Math.max(0, remaining + delta * 60);
  updateTimer();
}

document.querySelector("#rewindButton")?.addEventListener("click", () => adjustMinutes(-1));
document.querySelector("#forwardButton")?.addEventListener("click", () => adjustMinutes(1));

document.querySelector("#beginSession")?.addEventListener("click", () => {
  initiateMessage.textContent = "Session prepared locally. The companion settles into focus.";
  window.setTimeout(() => showScreen("focus"), 320);
});

function addScratchItem() {
  const input = document.querySelector("#scratchInput");
  const list = document.querySelector("#scratchList");
  const value = input.value.trim();
  if (!value) return;
  const row = document.createElement("div");
  row.className = "scratch-item";
  const time = new Intl.DateTimeFormat(undefined, { hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date());
  row.innerHTML = `<span class="scratch-time">${time}</span><span></span><span class="scratch-type">later</span>`;
  row.children[1].textContent = value;
  list.append(row);
  input.value = "";
  input.focus();
}

document.querySelector("#scratchAdd")?.addEventListener("click", addScratchItem);
document.querySelector("#scratchInput")?.addEventListener("keydown", (event) => {
  if (event.key === "Enter") addScratchItem();
});

document.querySelector("#quickCapture")?.addEventListener("click", () => {
  showScreen("focus");
  window.setTimeout(() => document.querySelector("#scratchInput")?.focus(), 120);
});

document.querySelector("#effectsToggle")?.addEventListener("click", (event) => {
  const reduced = shell.dataset.effects !== "reduced";
  shell.dataset.effects = reduced ? "reduced" : "full";
  const toggle = event.currentTarget;
  toggle.setAttribute("aria-pressed", String(reduced));
  toggle.querySelector(".motion-label").textContent = reduced ? "Motion: still" : "Motion: gentle";
});

window.recordChoice = function recordChoice(button) {
  document.querySelectorAll(".prototype-feedback button").forEach((item) => item.classList.toggle("is-selected", item === button));
  if (typeof window.toggleSelect === "function") window.toggleSelect(button);
};

document.addEventListener("keydown", (event) => {
  if (event.target.matches("input, textarea, select")) return;
  const order = ["initiate", "focus", "checkin", "break", "review"];
  const index = Number(event.key) - 1;
  if (index >= 0 && index < order.length) showScreen(order[index]);
  if (!focusScreenIsCurrent()) return;
  if (event.code === "Space") {
    event.preventDefault();
    timerToggle?.click();
  }
  if (event.key === "+" || event.key === "=") adjustMinutes(1);
  if (event.key === "-" || event.key === "_") adjustMinutes(-1);
});

const initialScreen = new URLSearchParams(location.search).get("screen") || location.hash.slice(1);
showScreen(screenMeta[initialScreen] ? initialScreen : "initiate", false);
updateTimer();
startTimer();
