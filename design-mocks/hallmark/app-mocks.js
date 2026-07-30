const shell = document.querySelector("#prototypeShell");
const screenButtons = [...document.querySelectorAll("[data-screen-target]")];
const screens = [...document.querySelectorAll("[data-screen]")];
const hudCenter = document.querySelector("#hudCenter");
const timerTime = document.querySelector("#timerTime");
const timerState = document.querySelector("#timerState");
const timerToggle = document.querySelector("#timerToggle");
const initiateMessage = document.querySelector("#initiateMessage");
const checkinMessage = document.querySelector("#checkinMessage");

const screenMeta = {
  initiate: "Ready · no session running",
  focus: "23:42 · focus in progress",
  checkin: "Check-in · timer held",
  break: "02:00 · intentional break",
  review: "Today · local focus trail",
  settings: "Settings · local first",
  surfaces: "Mac surfaces · shared session state"
};

let remaining = 23 * 60 + 42;
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
  hudCenter.textContent = screenMeta[name] ?? screenMeta.initiate;
  if (updateHash) history.replaceState(null, "", `#${name}`);
  document.querySelector(`[data-screen="${name}"]`)?.querySelector("h1, h2")?.focus?.({ preventScroll: true });
}

screenButtons.forEach((button) => button.addEventListener("click", () => showScreen(button.dataset.screenTarget)));
document.querySelectorAll("[data-screen-jump]").forEach((button) => button.addEventListener("click", () => showScreen(button.dataset.screenJump)));

document.querySelectorAll(".choice-row, .mode-row, .surface-row").forEach((group) => {
  group.addEventListener("click", (event) => {
    const button = event.target.closest("button");
    if (!button) return;
    group.querySelectorAll("button").forEach((item) => item.setAttribute("aria-pressed", String(item === button)));
  });
});

document.querySelectorAll(".switch").forEach((control) => {
  control.addEventListener("click", () => {
    if (control.disabled) return;
    const enabled = control.getAttribute("aria-pressed") === "true";
    control.setAttribute("aria-pressed", String(!enabled));
  });
});

document.querySelectorAll("[data-settings-target]").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll("[data-settings-target]").forEach((item) => item.setAttribute("aria-selected", String(item === button)));
    document.querySelectorAll("[data-settings]").forEach((section) => section.classList.toggle("is-current", section.dataset.settings === button.dataset.settingsTarget));
  });
});

document.querySelectorAll("[data-checkin]").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll("[data-checkin]").forEach((item) => item.dataset.selected = String(item === button));
    const responses = {
      holding: "Holding the plan. The check-in closes and the timer resumes.",
      smaller: "Next action reduced: write one rough promise, not all three.",
      detour: "Detour captured. Choose return, re-plan, or finish without penalty.",
      break: "Your place is preserved. Opening an intentional break is the next step."
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
  if (!timerTime) return;
  timerTime.textContent = formatTime(remaining);
  document.querySelectorAll(".menu-head span, .menu-mini-dial").forEach((node) => node.textContent = formatTime(remaining));
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
  timerState.textContent = running ? "Holding your place · check-in in 8 min" : "Paused · your place is preserved";
});

document.querySelector("#rewindButton")?.addEventListener("click", () => { remaining = Math.max(0, remaining - 60); updateTimer(); });
document.querySelector("#forwardButton")?.addEventListener("click", () => { remaining += 60; updateTimer(); });

document.querySelector("#beginSession")?.addEventListener("click", () => {
  initiateMessage.textContent = "Session prepared locally. Opening the focus instrument.";
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
  showScreen("focus");
  window.setTimeout(() => document.querySelector("#scratchInput")?.focus(), 120);
});

document.querySelector("#effectsToggle")?.addEventListener("click", (event) => {
  const reduced = shell.dataset.effects !== "reduced";
  shell.dataset.effects = reduced ? "reduced" : "full";
  event.currentTarget.setAttribute("aria-pressed", String(reduced));
  event.currentTarget.textContent = reduced ? "Effects: reduced" : "Effects: full";
});

document.querySelectorAll("[data-surface]").forEach((button) => {
  button.addEventListener("click", () => {
    const title = document.querySelector("#surfacePreview .menu-head strong");
    const task = document.querySelector("#surfacePreview .menu-task strong");
    const descriptions = {
      menu: ["Praxmodoro", "Write the product brief"],
      capsule: ["Focus capsule", "Three core promises"],
      lock: ["Return overlay", "Your place is preserved"]
    };
    [title.textContent, task.textContent] = descriptions[button.dataset.surface];
  });
});

window.recordChoice = function recordChoice(button) {
  document.querySelectorAll(".prototype-feedback button").forEach((item) => item.classList.toggle("is-selected", item === button));
  if (typeof window.toggleSelect === "function") window.toggleSelect(button);
};

document.addEventListener("keydown", (event) => {
  if (event.target.matches("input, textarea, select")) return;
  const order = ["initiate", "focus", "checkin", "break", "review", "settings", "surfaces"];
  const index = Number(event.key) - 1;
  if (index >= 0 && index < order.length) showScreen(order[index]);
  if (event.code === "Space" && document.querySelector("#screen-focus")?.classList.contains("is-current")) {
    event.preventDefault();
    timerToggle?.click();
  }
});

const initialScreen = new URLSearchParams(location.search).get("screen") || location.hash.slice(1);
showScreen(screenMeta[initialScreen] ? initialScreen : "initiate", false);
updateTimer();
startTimer();
