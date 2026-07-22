(() => {
  "use strict";

  const questions = window.DECKDOC_QUESTIONNAIRE || [];
  const knowledge = window.DECKDOC_KNOWLEDGE || [];
  const categories = window.DECKDOC_CATEGORIES || [];
  const related = window.DECKDOC_RELATED_CHECKS || {};
  const conflictPairs = window.DECKDOC_CONFLICTS || [];
  const selected = new Set();
  const optionById = new Map();
  const groupByOption = new Map();
  const groupById = new Map(questions.map((group) => [group.id, group]));
  const symptomIds = new Set((groupById.get("symptom")?.options || []).map(([id]) => id));
  const flowOrder = ["timing", "alive", "scope", "environment", "details", "evidence"];
  let activeCategory = null;
  let activeSymptom = null;
  let flowIndex = 0;

  questions.forEach((group) => group.options.forEach(([id, label]) => {
    optionById.set(id, label);
    groupByOption.set(id, group.id);
  }));

  const exclusiveSets = [
    ["lcd", "oled", "model-unknown"],
    ["steamos", "windows", "other-os"],
    ["docked", "handheld"],
    ["one-title", "all-titles"],
    ["official-dock", "third-party-dock"],
    ["repro-always", "repro-rare"],
    [...symptomIds]
  ];

  const conflictMap = new Map();
  conflictPairs.forEach(([left, right, reason]) => {
    if (!conflictMap.has(left)) conflictMap.set(left, new Map());
    if (!conflictMap.has(right)) conflictMap.set(right, new Map());
    conflictMap.get(left).set(right, reason);
    conflictMap.get(right).set(left, reason);
  });

  const suggestionReasons = {
    "sound-works": "Tells us whether only one output path failed",
    "input-works": "Checks whether the session still accepts controls",
    "ssh-works": "Confirms the OS is still alive remotely",
    "stream-works": "Checks whether frames exist away from the panel",
    "screen-backlight": "Separates LCD backlight from scanout",
    "screen-no-light": "Moves an LCD case toward power or panel evidence",
    "external-works": "Separates the internal panel from the GPU/session",
    "during-game": "Separates boot/transition trouble from load",
    "after-wake": "Points toward suspend/resume reinitialization",
    "first-after-days": "Matches the long-off first-start pattern",
    "second-boot-works": "A major cold-start discriminator",
    "one-title": "Moves toward a title, Proton, or configuration path",
    "all-titles": "Moves toward a shared OS, GPU, memory, or storage path",
    "hard-lock": "Separates a process crash from a whole-session failure",
    "connected-icon": "Moves beyond Wi-Fi firmware to route or DNS",
    "device-missing": "Stronger than a disconnected device",
    "fan-zero": "Needs live temperature context",
    "hot-now": "A stopped fan while hot is a stop-load condition",
    "io-errors": "Separates a library problem from media risk",
    "read-only": "A forced read-only transition is a data-risk signal",
    "multi-dock-failure": "Several failed dock functions reveal a shared path",
    "known-good-accessory": "Moves the boundary away from the accessory",
    "firmware-also-fails": "Raises hardware suspicion across environments",
    "previous-image-fixes": "Strong evidence of a software regression",
    "plugins-off-fixes": "Can isolate third-party state",
    "windows": "Prevents SteamOS-only checks from being misapplied",
    "lcd": "Enables LCD backlight and Vangogh-specific branches",
    "oled": "Removes LCD-only backlight questions"
  };

  const evidenceBoosts = {
    "sig-display-gap": ["live-internal-display-gap", 34],
    "sig-gpu-timeout": ["cross-title-gpu-session", 16],
    "sig-gpu-reset-ok": ["cross-title-gpu-session", 12],
    "sig-gpu-reset-fail": ["cross-title-gpu-session", 30],
    "sig-page-fault": ["cross-title-gpu-session", 16],
    "sig-gamescope-core": ["cross-title-gpu-session", 18],
    "sig-session-restarts": ["cross-title-gpu-session", 14],
    "sig-oom": ["cross-title-gpu-session", 24],
    "sig-sof": ["sof-resume-audio", 34],
    "sig-wifi-fw": ["wifi-device-resume", 30],
    "sig-hot-fan": ["hot-zero-fan", 35],
    "sig-dock": ["dock-shared-path", 34],
    "sig-ext4": ["storage-data-risk", 28],
    "sig-smart": ["storage-data-risk", 34]
  };

  const genericRoutes = {
    display: ["Display symptom needs its timing and survivor checks", "path", "Tell us what stays alive, when the picture fails, the model, and external-display behavior.", "wiki/Display-and-Gamescope-Problems"],
    boot: ["Boot or power symptom needs a preboot boundary", "os", "Record LEDs, chime, BIOS reachability, update history, and whether recovery boots.", "wiki/Recovery-and-Escalation"],
    crash: ["Crash scope needs one-title versus system-wide evidence", "app", "Separate one game from the whole session, then align current logs with the failure.", "wiki/Crashes-GPU-and-Memory"],
    audio: ["Audio symptom needs device-versus-route evidence", "os", "Separate a missing device from a wrong route and check wake timing.", "wiki/Audio-Problems"],
    network: ["Network symptom needs staged localization", "path", "Separate device presence, link, local network, DNS, and resume behavior.", "wiki/Network-and-Resume-Problems"],
    thermal: ["Thermal symptom needs a live trend and fan context", "hardware", "Correlate load, temperature, RPM, suspend, and charging context.", "wiki/Power-Thermal-and-Battery-Problems"],
    "charge-problem": ["Charging symptom needs direct-versus-dock evidence", "path", "Compare a known-good direct supply with the dock and cable path.", "wiki/Power-Thermal-and-Battery-Problems"],
    storage: ["Storage symptom needs a data-risk gate", "hardware", "Stop writes when needed, then separate the device, filesystem, and library path.", "wiki/Storage-and-MicroSD-Problems"],
    dock: ["Dock symptom needs topology and A/B evidence", "path", "Identify which dock functions fail together and compare direct paths.", "wiki/Dock-USB-C-and-External-Displays"],
    input: ["Input symptom needs test-UI and cross-environment evidence", "app", "Separate one layout or control from device loss across environments.", "wiki/Controls-Bluetooth-and-Input"],
    performance: ["Performance symptom needs load-correlated evidence", "os", "Compare scope, load, clocks, memory, storage, and temperature.", "wiki/Crashes-GPU-and-Memory"],
    update: ["Update symptom needs slot and build comparison", "os", "Record exact builds and whether previous image or Rescue changes the result.", "wiki/DeckDoc-Rescue"]
  };

  const stage = document.querySelector("#guided-stage");
  const stack = document.querySelector("#question-stack");
  const rankedResults = document.querySelector("#ranked-results");

  function escapeHtml(value) {
    return String(value).replace(/[&<>"]/g, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[character]));
  }

  function guideHref(route) {
    if (/^https:\/\//.test(route)) return route;
    return `https://github.com/deucebucket/deckdoc/${String(route).replace(/^wiki\//, "wiki/")}`;
  }

  function unsafeSelections() {
    return ["smoke", "swelling", "liquid", "sparking", "port-damage", "hot-off"].filter((id) => selected.has(id));
  }

  function blockedReason(id) {
    if (selected.has(id)) return "";
    for (const [other, reason] of conflictMap.get(id) || []) {
      if (selected.has(other)) return `${reason} Clear “${optionById.get(other)}” to change this answer.`;
    }
    return "";
  }

  function clearForNewSymptom(nextSymptom) {
    const safety = [...selected].filter((id) => groupByOption.get(id) === "safety");
    selected.clear();
    safety.forEach((id) => selected.add(id));
    if (nextSymptom) selected.add(nextSymptom);
  }

  function setCategory(categoryId) {
    if (activeCategory?.id !== categoryId) clearForNewSymptom(null);
    activeCategory = categories.find((category) => category.id === categoryId) || null;
    activeSymptom = null;
    flowIndex = 0;
    update();
  }

  function setSymptom(symptomId) {
    clearForNewSymptom(symptomId);
    activeSymptom = symptomId;
    activeCategory = categories.find((category) => category.symptoms.includes(symptomId)) || activeCategory;
    flowIndex = 0;
    update();
  }

  function toggleOption(id, force = null) {
    if (!optionById.has(id)) return;
    if (symptomIds.has(id)) {
      if (selected.has(id) && force !== true) {
        clearForNewSymptom(null);
        activeSymptom = null;
      } else {
        setSymptom(id);
      }
      return;
    }

    const willSelect = force === null ? !selected.has(id) : force;
    if (willSelect) {
      if (blockedReason(id)) return;
      if (id === "none-unsafe") ["smoke", "swelling", "liquid", "sparking", "port-damage", "hot-off"].forEach((unsafe) => selected.delete(unsafe));
      if (["smoke", "swelling", "liquid", "sparking", "port-damage", "hot-off"].includes(id)) selected.delete("none-unsafe");
      const exclusive = exclusiveSets.find((set) => set.includes(id));
      if (exclusive) exclusive.forEach((other) => selected.delete(other));
      selected.add(id);
    } else {
      selected.delete(id);
    }
    update();
  }

  function flowGroups() {
    if (!activeSymptom) return [];
    const relevant = new Set(related[activeSymptom] || []);
    return flowOrder.map((groupId) => {
      const group = groupById.get(groupId);
      return { ...group, options: (group?.options || []).filter(([id]) => relevant.has(id)) };
    }).filter((group) => group.options.length);
  }

  function optionButton(id, label, context = "guided") {
    const reason = blockedReason(id);
    const selectedState = selected.has(id);
    const helper = context === "guided" ? suggestionReasons[id] : "";
    return `<button type="button" class="option-card ${context === "guided" ? "guided-option" : "advanced-option"}"
      data-option="${id}" data-label="${escapeHtml(label.toLowerCase())}" aria-pressed="${selectedState}"
      ${reason ? `disabled aria-disabled="true" title="${escapeHtml(reason)}"` : ""}>
      <span>${escapeHtml(label)}</span>
      ${helper ? `<small>${escapeHtml(helper)}</small>` : ""}
      ${reason ? `<small class="blocked-copy">Unavailable with your current answer</small>` : ""}
    </button>`;
  }

  function renderCategoryStage() {
    stage.innerHTML = `
      <div class="stage-heading">
        <span class="step-number">01</span>
        <div><p class="overline">Start broad</p><h3>Choose the main problem</h3><p>Pick the closest category. You will see only the issues nested under it.</p></div>
      </div>
      <div class="category-grid">
        ${categories.map((category) => `<button class="category-card" type="button" data-category="${category.id}">
          <span class="category-code">${escapeHtml(category.code)}</span>
          <strong>${escapeHtml(category.title)}</strong>
          <small>${escapeHtml(category.description)}</small>
          <span class="category-arrow" aria-hidden="true">→</span>
        </button>`).join("")}
      </div>
      <button class="safety-shortcut" type="button" data-open-safety><strong>Smoke, swelling, liquid, port damage, or electrical heat?</strong><span>Stop here and open the safety checks.</span></button>`;
  }

  function renderSymptomStage() {
    const symptoms = groupById.get("symptom").options.filter(([id]) => activeCategory.symptoms.includes(id));
    stage.innerHTML = `
      <div class="stage-heading">
        <span class="step-number">02</span>
        <div><p class="overline">${escapeHtml(activeCategory.title)}</p><h3>Which description is closest?</h3><p>Choose one main symptom. Connected symptoms appear as follow-up questions.</p></div>
      </div>
      <div class="symptom-grid">${symptoms.map(([id, label]) => `<button class="symptom-card" type="button" data-symptom="${id}"><strong>${escapeHtml(label)}</strong><span>Continue →</span></button>`).join("")}</div>
      <div class="stage-actions"><button class="button ghost" type="button" data-back-category>Back to categories</button></div>`;
  }

  function renderFollowupStage(groups) {
    if (flowIndex >= groups.length) {
      stage.innerHTML = `
        <div class="stage-complete">
          <span class="complete-mark" aria-hidden="true">✓</span>
          <p class="overline">Guided check complete</p>
          <h3>Review the likely branches below</h3>
          <p>You can still change any answer, browse every check, or copy the case summary.</p>
          <div class="stage-actions"><button class="button ghost" type="button" data-flow-back>Review last question</button><a class="button primary" href="#results">See results</a></div>
        </div>`;
      return;
    }
    const group = groups[flowIndex];
    const count = group.options.filter(([id]) => selected.has(id)).length;
    stage.innerHTML = `
      <div class="stage-heading">
        <span class="step-number">${String(flowIndex + 3).padStart(2, "0")}</span>
        <div><p class="overline">Connected check</p><h3>${escapeHtml(group.title)}</h3><p>${escapeHtml(group.hint)} Choose any that match, or skip if you do not know.</p></div>
      </div>
      <div class="guided-options">${group.options.map(([id, label]) => optionButton(id, label)).join("")}</div>
      <div class="stage-actions split">
        <button class="button ghost" type="button" data-flow-back>Back</button>
        <span>${count ? `${count} selected` : "No answer required"}</span>
        <button class="button primary" type="button" data-flow-next>${flowIndex === groups.length - 1 ? "Finish" : "Continue"}</button>
      </div>`;
  }

  function renderGuidedStage() {
    if (unsafeSelections().length) {
      stage.innerHTML = `<div class="stage-complete danger-stage"><span class="complete-mark">!</span><p class="overline">Safety stop</p><h3>Do not continue software troubleshooting</h3><p>Disconnect power if safe and contact Steam Support. Clear the physical-danger answer only if it was selected by mistake.</p><button class="button ghost" type="button" data-open-safety>Review safety answers</button></div>`;
      return;
    }
    if (!activeCategory) renderCategoryStage();
    else if (!activeSymptom) renderSymptomStage();
    else renderFollowupStage(flowGroups());
  }

  function advancedGroup(category, ids, extraClass = "") {
    const unique = [...new Set(ids)].filter((id) => optionById.has(id));
    const count = unique.filter((id) => selected.has(id)).length;
    return `<details class="advanced-group ${extraClass}" data-advanced-group="${category.id}">
      <summary><span><b>${escapeHtml(category.title)}</b><small>${escapeHtml(category.description || "")}</small></span><em>${count ? `${count} selected` : `${unique.length} checks`}</em></summary>
      <div class="advanced-grid">${unique.map((id) => optionButton(id, optionById.get(id), "advanced")).join("")}</div>
    </details>`;
  }

  function renderAdvanced() {
    const assigned = new Set();
    const safety = groupById.get("safety").options.map(([id]) => id);
    safety.forEach((id) => assigned.add(id));
    const blocks = [advancedGroup({ id: "safety", title: "Physical safety", description: "Stop conditions before software troubleshooting" }, safety, "danger-group")];
    categories.forEach((category) => {
      const ids = [...category.symptoms];
      category.symptoms.forEach((symptom) => ids.push(...(related[symptom] || [])));
      ids.forEach((id) => assigned.add(id));
      blocks.push(advancedGroup(category, ids));
    });
    const remaining = [...optionById.keys()].filter((id) => !assigned.has(id));
    if (remaining.length) blocks.push(advancedGroup({ id: "context", title: "Additional context & logs", description: "Less common environment and evidence facts" }, remaining));
    stack.innerHTML = blocks.join("");
  }

  function ruleScore(rule) {
    const symptomHits = rule.symptoms.filter((id) => selected.has(id));
    if (!symptomHits.length) return null;
    if ((rule.requiresAll || []).some((id) => !selected.has(id))) return null;
    const contextHits = (rule.contextsAny || []).filter((id) => selected.has(id));
    let score = 18 + symptomHits.length * 10 + (rule.requiresAll || []).length * 12 + contextHits.length * 5;
    Object.entries(evidenceBoosts).forEach(([evidence, [ruleId, boost]]) => {
      if (rule.id === ruleId && selected.has(evidence)) score += boost;
    });
    if (selected.has("firmware-also-fails") && rule.layer === "hardware") score += 14;
    if (selected.has("previous-image-fixes") && rule.layer === "os") score += 14;
    if (selected.has("one-title") && rule.layer === "app") score += 12;
    if (selected.has("multi-dock-failure") && rule.id === "dock-shared-path") score += 12;
    return { ...rule, score, matched: [...symptomHits, ...(rule.requiresAll || []), ...contextHits].filter((id) => selected.has(id)) };
  }

  function getResults() {
    const results = knowledge.map(ruleScore).filter(Boolean).sort((left, right) => right.score - left.score);
    if (activeSymptom && !results.some((result) => result.symptoms.includes(activeSymptom))) {
      const generic = genericRoutes[activeSymptom];
      if (generic) results.push({
        id: `generic-${activeSymptom}`, title: generic[0], layer: generic[1], why: generic[2], link: generic[3],
        kicker: "More answers will narrow this", confidence: "Starting branch", score: 12,
        evidence: ["Continue the short guided path or open Browse all checks for an uncommon detail."],
        steps: ["Run a full DeckDoc report while the symptom is present when safe."],
        avoid: "Do not apply a fix until its model, time scope, and preconditions match.", matched: [activeSymptom]
      });
    }
    return results.sort((left, right) => right.score - left.score).slice(0, 3);
  }

  function layerWeights(results) {
    const weights = { app: 2, os: 2, path: 2, hardware: 2 };
    results.forEach((result, index) => { weights[result.layer] += Math.max(8, result.score / (index + 1)); });
    if (selected.has("one-title")) weights.app += 18;
    if (selected.has("after-update") || selected.has("previous-image-fixes")) weights.os += 18;
    if (selected.has("sound-works") && selected.has("display")) weights.path += 18;
    if (selected.has("multi-dock-failure")) weights.path += 18;
    if (selected.has("firmware-also-fails") || selected.has("physical-event")) weights.hardware += 24;
    if (selected.has("sig-gpu-reset-fail") || selected.has("sig-smart")) weights.hardware += 16;
    const max = Math.max(...Object.values(weights), 1);
    Object.keys(weights).forEach((key) => { weights[key] = Math.round(weights[key] / max * 100); });
    return weights;
  }

  function renderConstellation(weights) {
    const labels = { app: "Application/config", os: "Driver/OS", path: "Device/path", hardware: "Hardware suspicion" };
    Object.entries(weights).forEach(([key, value]) => document.querySelector(`#node-${key}`).style.setProperty("--power", String(value / 100)));
    document.querySelector("#layer-legend").innerHTML = Object.entries(weights).map(([key, value]) => `<div class="layer-row"><span>${labels[key]}</span><span class="layer-meter"><i style="width:${value}%"></i></span><b>${value}</b></div>`).join("");
  }

  function renderResults(results) {
    if (!activeSymptom) {
      rankedResults.innerHTML = `<div class="empty-result"><div><strong>Start with one broad problem.</strong><p>DeckMD will ask a short chain of connected questions instead of showing the whole checklist.</p></div></div>`;
      return;
    }
    if (!results.length) {
      rankedResults.innerHTML = `<div class="empty-result"><div><strong>No safe pattern match yet.</strong><p>Unknown is better than a false diagnosis. Finish the guided questions or browse all checks.</p></div></div>`;
      return;
    }
    rankedResults.innerHTML = results.map((result, index) => `<article class="result-card">
      <div class="result-card-head"><span class="rank">${String(index + 1).padStart(2, "0")}</span><div><span class="result-kicker">${escapeHtml(result.kicker)}</span><h3>${escapeHtml(result.title)}</h3></div><span class="confidence">${escapeHtml(result.confidence)}</span></div>
      <p class="result-why">${escapeHtml(result.why)}</p>
      <details><summary>Evidence and safe next steps · ${result.matched.length} answers matched</summary>
        <div class="result-detail"><div><h4>Collect</h4><ul>${result.evidence.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul></div><div><h4>Safe next steps</h4><ul>${result.steps.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul></div><div><h4>Matched answers</h4><ul>${result.matched.map((id) => `<li>${escapeHtml(optionById.get(id) || id)}</li>`).join("")}</ul></div></div>
        <p class="avoid-box"><strong>Avoid:</strong> ${escapeHtml(result.avoid)}</p><a class="result-link" href="${escapeHtml(guideHref(result.link))}">Open the full diagnostic guide →</a>
      </details></article>`).join("");
  }

  function renderSafety() {
    const unsafe = unsafeSelections();
    const banner = document.querySelector("#safety-banner");
    banner.hidden = !unsafe.length;
    if (unsafe.length) document.querySelector("#safety-copy").textContent = `${unsafe.map((id) => optionById.get(id)).join(", ")}. Disconnect power if safe, do not charge, open, or stress-test it, and contact Steam Support.`;
  }

  function renderFacts() {
    const facts = [...selected].filter((id) => optionById.has(id));
    document.querySelector("#selection-count").textContent = `${facts.length} selected`;
    document.querySelector("#selected-facts").innerHTML = facts.length ? facts.map((id) => `<button class="fact-chip" type="button" data-remove-fact="${id}" title="Remove this answer">${escapeHtml(optionById.get(id))}<span>×</span></button>`).join("") : `<span class="suggestion-empty">No incident facts selected yet.</span>`;
  }

  function renderPath(groups) {
    const pieces = [`<button type="button" data-path-start>Start</button>`];
    if (activeCategory) pieces.push(`<button type="button" data-path-category>${escapeHtml(activeCategory.title)}</button>`);
    if (activeSymptom) pieces.push(`<button type="button" data-path-symptom>${escapeHtml(optionById.get(activeSymptom))}</button>`);
    if (activeSymptom && flowIndex < groups.length) pieces.push(`<span>${escapeHtml(groups[flowIndex].title)}</span>`);
    document.querySelector("#path-trail").innerHTML = pieces.join(`<i aria-hidden="true">›</i>`);
  }

  function updateProgress(groups) {
    let current = 0;
    let total = 2;
    if (activeCategory) current = 1;
    if (activeSymptom) {
      total += groups.length;
      current = Math.min(total, 3 + flowIndex);
      if (flowIndex >= groups.length) current = total;
    }
    document.querySelector("#progress-label").textContent = activeSymptom ? `Step ${Math.max(1, current)} of ${total}` : activeCategory ? "Choose a specific symptom" : "Choose a category to begin";
    document.querySelector("#progress-bar").style.width = `${activeSymptom ? current / total * 100 : activeCategory ? 20 : 0}%`;
  }

  function syncButtons() {
    document.querySelectorAll("[data-option]").forEach((button) => {
      const id = button.dataset.option;
      const reason = blockedReason(id);
      button.setAttribute("aria-pressed", selected.has(id) ? "true" : "false");
      button.disabled = Boolean(reason);
      button.setAttribute("aria-disabled", reason ? "true" : "false");
      if (reason) button.title = reason; else button.removeAttribute("title");
    });
    document.querySelectorAll(".advanced-group").forEach((group) => {
      const count = [...group.querySelectorAll("[data-option]")].filter((button) => selected.has(button.dataset.option)).length;
      const label = group.querySelector("summary em");
      if (count) label.textContent = `${count} selected`;
    });
  }

  function updateUrl() {
    const url = new URL(window.location.href);
    const facts = [...selected].filter((id) => optionById.has(id));
    if (facts.length) url.searchParams.set("s", facts.join(",")); else url.searchParams.delete("s");
    history.replaceState(null, "", url);
  }

  function update() {
    const groups = flowGroups();
    if (flowIndex > groups.length) flowIndex = groups.length;
    renderGuidedStage();
    renderAdvanced();
    syncButtons();
    renderSafety();
    renderFacts();
    renderPath(groups);
    updateProgress(groups);
    const results = getResults();
    renderResults(results);
    renderConstellation(layerWeights(results));
    document.querySelector(".constellation").hidden = !activeSymptom;
    document.querySelector(".result-grid").classList.toggle("single-column", !activeSymptom);
    document.querySelector(".all-checks-count").textContent = `${optionById.size} checks`;
    document.querySelector("#os-warning").hidden = !selected.has("windows");
    updateUrl();
  }

  function caseSummary() {
    const lines = ["DeckMD guided symptom check", "==========================="];
    if (activeCategory) lines.push(`\nCategory\n- ${activeCategory.title}`);
    questions.forEach((group) => {
      const facts = group.options.filter(([id]) => selected.has(id)).map(([, label]) => `- ${label}`);
      if (facts.length) lines.push(`\n${group.title}`, ...facts);
    });
    const results = getResults();
    if (results.length) lines.push("\nRanked diagnostic branches", ...results.map((result, index) => `${index + 1}. ${result.title} — ${result.confidence}`));
    lines.push("\nGenerated locally by DeckMD. Rankings are triage priorities, not diagnoses.");
    return lines.join("\n");
  }

  async function copyText(value, button) {
    try {
      await navigator.clipboard.writeText(value);
      const old = button.textContent;
      button.textContent = "Copied";
      setTimeout(() => { button.textContent = old; }, 1600);
    } catch (_) {
      const area = document.createElement("textarea");
      area.value = value;
      document.body.append(area);
      area.select();
      document.execCommand("copy");
      area.remove();
    }
  }

  renderAdvanced();

  const initial = new URLSearchParams(location.search).get("s");
  if (initial) {
    initial.split(",").forEach((id) => { if (optionById.has(id)) selected.add(id); });
    activeSymptom = [...selected].find((id) => symptomIds.has(id)) || null;
    if (activeSymptom) {
      [...selected].filter((id) => symptomIds.has(id) && id !== activeSymptom).forEach((id) => selected.delete(id));
      activeCategory = categories.find((category) => category.symptoms.includes(activeSymptom)) || null;
    }
  }

  stage.addEventListener("click", (event) => {
    const category = event.target.closest("[data-category]");
    const symptom = event.target.closest("[data-symptom]");
    const option = event.target.closest("[data-option]");
    if (category) setCategory(category.dataset.category);
    else if (symptom) setSymptom(symptom.dataset.symptom);
    else if (option) toggleOption(option.dataset.option);
    else if (event.target.closest("[data-back-category]")) { activeCategory = null; activeSymptom = null; clearForNewSymptom(null); update(); }
    else if (event.target.closest("[data-flow-back]")) { if (flowIndex > 0) flowIndex -= 1; else { selected.delete(activeSymptom); activeSymptom = null; } update(); }
    else if (event.target.closest("[data-flow-next]")) { flowIndex += 1; update(); }
    else if (event.target.closest("[data-open-safety]")) {
      const all = document.querySelector("#all-checks"); all.open = true;
      const safety = document.querySelector('[data-advanced-group="safety"]'); safety.open = true;
      safety.scrollIntoView({ behavior: "smooth", block: "start" });
    }
  });

  stack.addEventListener("click", (event) => {
    const button = event.target.closest("[data-option]");
    if (button) toggleOption(button.dataset.option);
  });

  document.querySelector("#path-trail").addEventListener("click", (event) => {
    if (event.target.closest("[data-path-start]")) { activeCategory = null; activeSymptom = null; clearForNewSymptom(null); update(); }
    else if (event.target.closest("[data-path-category]")) { activeSymptom = null; clearForNewSymptom(null); update(); }
    else if (event.target.closest("[data-path-symptom]")) { flowIndex = 0; update(); }
  });

  document.querySelector("#selected-facts").addEventListener("click", (event) => {
    const button = event.target.closest("[data-remove-fact]");
    if (button) toggleOption(button.dataset.removeFact, false);
  });

  document.querySelector("#option-search").addEventListener("input", (event) => {
    const query = event.target.value.trim().toLowerCase();
    document.querySelectorAll(".advanced-group").forEach((group) => {
      let matches = 0;
      group.querySelectorAll(".advanced-option").forEach((button) => {
        const visible = !query || button.dataset.label.includes(query);
        button.hidden = !visible;
        if (visible) matches += 1;
      });
      group.hidden = Boolean(query && !matches);
      if (query && matches) group.open = true;
    });
  });

  document.querySelector("#expand-all").addEventListener("click", (event) => {
    const groups = [...document.querySelectorAll(".advanced-group:not([hidden])")];
    const expand = groups.some((group) => !group.open);
    groups.forEach((group) => { group.open = expand; });
    event.currentTarget.textContent = expand ? "Collapse all groups" : "Expand all groups";
  });

  document.querySelector("#reset-all").addEventListener("click", () => {
    selected.clear(); activeCategory = null; activeSymptom = null; flowIndex = 0; update();
  });
  document.querySelector("#copy-summary").addEventListener("click", (event) => copyText(caseSummary(), event.currentTarget));
  document.querySelector("#copy-link").addEventListener("click", (event) => copyText(location.href, event.currentTarget));

  update();
})();
