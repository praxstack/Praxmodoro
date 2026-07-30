const shell = document.querySelector("#consoleShell");
const screenButtons = [...document.querySelectorAll("[data-screen-target]")];
const screens = [...document.querySelectorAll("[data-screen]")];
const barTimer = document.querySelector("#barTimer");
const barNote = document.querySelector("#barNote");
const timerTime = document.querySelector("#timerTime");
const timerState = document.querySelector("#timerState");
const timerToggle = document.querySelector("#timerToggle");
const meterFill = document.querySelector("#meterFill");
const initiateMessage = document.querySelector("#initiateMessage");
const checkinMessage = document.querySelector("#checkinMessage");

const screenMeta = {
  initiate: "Standby · context receded until start",
  focus: "Block 04 live · classic 25 + 5",
  checkin: "Check-in open · timer held",
  break: "Break · 03:00 · re-entry preserved",
  review: "Afternoon ledger · on this Mac"
};

const BLOCK_TOTAL = 25 * 60;
let remaining = 17 * 60 + 42;
let running = true;
let timerInterval;

function formatTime(totalSeconds) {
  const minutes = Math.floor(Math.max(0, totalSeconds) / 60);
  const seconds = Math.max(0, totalSeconds) % 60;
  return `${String(minutes).padStart(2, "0")}:${String(seconds).padStart(2, "0")}`;
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
  barNote.textContent = screenMeta[name] ?? screenMeta.initiate;
  if (name !== "initiate" && shell.dataset.dock === "receded") shell.dataset.dock = "live";
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
      holding: "Holding the plan. The reading closes and the timer resumes at 17:42.",
      smaller: "Next action reduced: write one plain sentence, not the whole bullet list.",
      detour: "Detour logged as data. Choose return, re-plan, or close the block — no penalty.",
      break: "Your place is held at 17:42. The break console is the next step."
    };
    checkinMessage.textContent = responses[button.dataset.checkin];
  });
});

document.querySelectorAll("[data-break]").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll("[data-break]").forEach((item) => item.dataset.selected = String(item === button));
  });
});

function updateTimer() {
  if (timerTime) timerTime.textContent = formatTime(remaining);
  if (barTimer) barTimer.textContent = `T−${formatTime(remaining)}${running ? "" : " · held"}`;
  if (meterFill) {
    const elapsed = Math.min(Math.max(BLOCK_TOTAL - remaining, 0), BLOCK_TOTAL);
    meterFill.style.width = `${((elapsed / BLOCK_TOTAL) * 100).toFixed(1)}%`;
  }
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
  timerState.textContent = running ? "Holding the block · next check-in ~15:16" : "Paused · your place is preserved";
  updateTimer();
});

document.querySelector("#rewindButton")?.addEventListener("click", () => { remaining = Math.max(0, remaining - 60); updateTimer(); });
document.querySelector("#forwardButton")?.addEventListener("click", () => { remaining = Math.min(BLOCK_TOTAL, remaining + 60); updateTimer(); });

document.querySelector("#beginSession")?.addEventListener("click", () => {
  shell.dataset.dock = "live";
  const dockNote = document.querySelector(".dock-note");
  if (dockNote) dockNote.textContent = "Awake · block 04 is live. Context is reference, not homework.";
  initiateMessage.textContent = "Block armed locally. The dock wakes and the stage moves to focus.";
  window.setTimeout(() => showScreen("focus"), 280);
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
  if (shell.dataset.dock === "receded") shell.dataset.dock = "live";
  document.querySelector("#scratchInput")?.focus();
});

document.querySelector("#effectsToggle")?.addEventListener("click", (event) => {
  const reduced = shell.dataset.effects !== "reduced";
  shell.dataset.effects = reduced ? "reduced" : "full";
  event.currentTarget.setAttribute("aria-pressed", String(reduced));
  event.currentTarget.textContent = reduced ? "Effects: reduced" : "Effects: full";
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
  const focusCurrent = document.querySelector("#screen-focus")?.classList.contains("is-current");
  if (event.code === "Space" && focusCurrent) {
    event.preventDefault();
    timerToggle?.click();
  }
  if (focusCurrent && (event.key === "-" || event.key === "_")) document.querySelector("#rewindButton")?.click();
  if (focusCurrent && (event.key === "+" || event.key === "=")) document.querySelector("#forwardButton")?.click();
});

const initialScreen = new URLSearchParams(location.search).get("screen") || location.hash.slice(1);
showScreen(screenMeta[initialScreen] ? initialScreen : "initiate", false);
updateTimer();
startTimer();
