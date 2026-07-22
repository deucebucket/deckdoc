(() => {
  "use strict";

  const questions = window.DECKDOC_QUESTIONNAIRE || [];
  const knowledge = window.DECKDOC_KNOWLEDGE || [];
  const selected = new Set();
  const optionById = new Map();
  const groupByOption = new Map();
  const groupById = new Map(questions.map((q) => [q.id, q]));

  questions.forEach((group) => group.options.forEach(([id, label]) => {
    optionById.set(id, label);
    groupByOption.set(id, group.id);
  }));

  const exclusives = [
    ["none-unsafe", "smoke", "swelling", "liquid", "sparking", "port-damage", "hot-off"],
    ["lcd", "oled", "model-unknown"],
    ["steamos", "windows", "other-os"],
    ["docked", "handheld"],
    ["one-title", "all-titles"]
  ];

  const suggestionReasons = {
    "sound-works": "Separates a dead/frozen system from one failed output path",
    "input-works": "Shows whether the session is still accepting controls",
    "ssh-works": "Confirms the kernel and network path remain alive",
    "stream-works": "Tests whether rendered frames exist away from the panel",
    "screen-backlight": "Narrows LCD panel power versus scanout; not applicable to OLED",
    "screen-no-light": "Moves an LCD case toward backlight/panel power evidence",
    "external-works": "Separates the internal panel path from the GPU/session",
    "internal-works": "Separates external Alt Mode/dock from the internal display",
    "during-game": "Distinguishes boot/transition failures from load or title paths",
    "after-wake": "Moves device loss toward suspend/resume reinitialization",
    "first-after-days": "Identifies the long-off first-start research pattern",
    "second-boot-works": "Recovery on the second start is a major discriminator",
    "mode-switch": "Points to Gamescope/KWin session transition",
    "dock-transition": "Points to Type-C, Alt Mode, hub, or hotplug state",
    "one-title": "Moves the first branch toward title/Proton/configuration",
    "all-titles": "Moves the first branch toward shared OS/GPU/memory/storage",
    "hard-lock": "Separates a process exit from whole-system recovery failure",
    "returns-library": "Often leaves a title, Steam, or Gamescope boundary",
    "sig-gpu-reset-ok": "Recovery outcome changes the severity and downstream interpretation",
    "sig-gpu-reset-fail": "Repeated failed reset is an escalation boundary",
    "sig-oom": "Identifies a killed process instead of guessing from swap allocation",
    "connected-icon": "Separates firmware/device loss from route/DNS/service stages",
    "device-missing": "Stronger than a disconnected or administratively down device",
    "local-network": "Separates local link/gateway from DNS or Steam service",
    "fan-zero": "Needs temperature context before it means anything",
    "hot-now": "Zero RPM plus ≥70°C is a stop-load condition",
    "io-errors": "Separates a Steam library path problem from block/media risk",
    "read-only": "A forced read-only transition is a data-risk signal",
    "multi-dock-failure": "Several dock functions failing together reveal the common upstream path",
    "known-good-accessory": "Known-good A/B moves the boundary away from the accessory",
    "firmware-also-fails": "Persistence outside the installed OS raises hardware suspicion",
    "previous-image-fixes": "Same hardware working on the previous image is strong regression evidence",
    "plugins-off-fixes": "A reversible clean run can isolate third-party state",
    "windows": "Prevents SteamOS-only signatures and fixes from being misapplied",
    "lcd": "Backlight and Vangogh-specific paths may apply",
    "oled": "Avoids treating OLED as an LCD with a missing backlight"
  };

  const related = window.DECKDOC_RELATED_CHECKS || {};

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
    display: ["Display symptom needs its timing and survivor checks", "path", "Select what stays alive, when it goes black, LCD/OLED, and external-display behavior.", "wiki/Display-and-Gamescope-Problems"],
    boot: ["Boot/power symptom needs a preboot boundary", "os", "Record LEDs/chime/BIOS reachability, update history, and whether recovery or Rescue boots.", "wiki/Recovery-and-Escalation"],
    crash: ["Crash scope needs one-title versus system-wide evidence", "app", "Select when it crashes, what survives, how many titles reproduce, and current-incident log signatures.", "wiki/Crashes-GPU-and-Memory"],
    audio: ["Audio symptom needs device-versus-route evidence", "os", "Select wake timing, device missing versus wrong route, model, and SOF evidence.", "wiki/Audio-Problems"],
    network: ["Network symptom needs staged localization", "path", "Select device presence, link state, local gateway, wake timing, and firmware evidence.", "wiki/Network-and-Resume-Problems"],
    thermal: ["Thermal symptom needs a live trend and fan context", "hardware", "Select load, temperature, RPM, suspend, and charging context. Stop load if the fan is stopped while hot.", "wiki/Power-Thermal-and-Battery-Problems"],
    "charge-problem": ["Charging symptom needs direct-versus-dock evidence", "path", "Compare a known-good direct PD supply with the dock/cable path and record exported telemetry.", "wiki/Power-Thermal-and-Battery-Problems"],
    storage: ["Storage symptom needs a data-risk gate", "hardware", "Select device missing/read-only/I/O errors and stop writes when data may be at risk.", "wiki/Storage-and-MicroSD-Problems"],
    dock: ["Dock symptom needs topology and A/B evidence", "path", "Select which dock functions fail together and compare direct known-good paths.", "wiki/Dock-USB-C-and-External-Displays"],
    input: ["Input symptom needs test-UI and cross-environment evidence", "app", "Select one title/control, firmware behavior, wake timing, and Bluetooth/touch branch.", "wiki/Controls-Bluetooth-and-Input"],
    performance: ["Performance symptom needs load-correlated evidence", "os", "Select scope, load, clocks, warm/cold scene, memory pressure, storage activity, and temperature.", "wiki/Crashes-GPU-and-Memory"],
    update: ["Update symptom needs slot/build comparison", "os", "Record exact builds and whether previous image, stable channel, recovery, or Rescue changes the result.", "wiki/DeckDoc-Rescue"]
  };

  const stack = document.querySelector("#question-stack");
  const suggestionRail = document.querySelector("#suggestion-rail");
  const rankedResults = document.querySelector("#ranked-results");

  function escapeHtml(value) {
    return String(value).replace(/[&<>"]/g, (c) => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
  }

  function guideHref(route) {
    if (/^https:\/\//.test(route)) return route;
    return `https://github.com/deucebucket/deckdoc/${String(route).replace(/^wiki\//, "wiki/")}`;
  }

  function renderQuestions() {
    stack.innerHTML = questions.map((group, index) => `
      <details class="question-group" data-group="${group.id}" data-tone="${group.tone || "normal"}" ${index < 2 ? "open" : ""}>
        <summary>
          <span class="question-title"><span class="overline">${escapeHtml(group.eyebrow)}</span><h3>${escapeHtml(group.title)}</h3><p>${escapeHtml(group.hint)}</p></span>
          <span class="group-count" data-count-for="${group.id}">0 selected</span>
        </summary>
        <div class="question-body"><div class="option-grid">
          ${group.options.map(([id, label]) => `<button type="button" class="option-card" data-option="${id}" data-label="${escapeHtml(label.toLowerCase())}" aria-pressed="false">${escapeHtml(label)}</button>`).join("")}
        </div></div>
      </details>`).join("");

    stack.addEventListener("click", (event) => {
      const button = event.target.closest("[data-option]");
      if (!button) return;
      toggleOption(button.dataset.option);
    });
  }

  function toggleOption(id, force = null) {
    const willSelect = force === null ? !selected.has(id) : force;
    if (willSelect) {
      const exclusive = exclusives.find((set) => set.includes(id));
      if (exclusive) exclusive.forEach((other) => selected.delete(other));
      if (id === "none-unsafe") ["smoke","swelling","liquid","sparking","port-damage","hot-off"].forEach((x) => selected.delete(x));
      if (["smoke","swelling","liquid","sparking","port-damage","hot-off"].includes(id)) selected.delete("none-unsafe");
      selected.add(id);
    } else {
      selected.delete(id);
    }
    update();
  }

  function currentSuggestions() {
    const candidates = [];
    const seen = new Set();
    const primary = questions.find((q) => q.id === "symptom").options.map(([id]) => id).filter((id) => selected.has(id));
    primary.forEach((symptom) => (related[symptom] || []).forEach((id) => {
      if (!selected.has(id) && !seen.has(id)) { seen.add(id); candidates.push(id); }
    }));
    knowledge.forEach((rule) => {
      if (!rule.symptoms.some((id) => selected.has(id))) return;
      [...(rule.requiresAll || []), ...(rule.contextsAny || [])].forEach((id) => {
        if (optionById.has(id) && !selected.has(id) && !seen.has(id)) { seen.add(id); candidates.push(id); }
      });
    });
    return candidates.slice(0, 10);
  }

  function renderSuggestions(ids) {
    document.querySelectorAll(".option-card.suggested").forEach((el) => el.classList.remove("suggested"));
    ids.forEach((id) => document.querySelector(`[data-option="${CSS.escape(id)}"]`)?.classList.add("suggested"));
    if (!ids.length) {
      suggestionRail.innerHTML = `<span class="suggestion-empty">Select one or more primary symptoms to reveal the most useful follow-up checks.</span>`;
      return;
    }
    suggestionRail.innerHTML = ids.map((id) => `
      <button class="suggestion-chip" type="button" data-suggestion="${id}">
        ${escapeHtml(optionById.get(id))}<small>${escapeHtml(suggestionReasons[id] || "Adds a useful diagnostic contrast")}</small>
      </button>`).join("");
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
    const results = knowledge.map(ruleScore).filter(Boolean).sort((a, b) => b.score - a.score);
    const primary = questions.find((q) => q.id === "symptom").options.map(([id]) => id).filter((id) => selected.has(id));
    const matchedSymptoms = new Set(results.flatMap((r) => r.symptoms));
    primary.forEach((symptom) => {
      if (matchedSymptoms.has(symptom)) return;
      const generic = genericRoutes[symptom];
      if (!generic) return;
      results.push({
        id: `generic-${symptom}`, title: generic[0], layer: generic[1], why: generic[2], link: generic[3],
        kicker: "More discriminating answers needed", confidence: "Unranked branch", score: 12,
        evidence: ["Use the adaptive next-check rail to add timing, survivor, scope, and evidence facts."],
        steps: ["Run a full DeckDoc report while the symptom is present when safe."],
        avoid: "Do not apply a fix until its model, time scope, and preconditions match.", matched: [symptom]
      });
    });
    return results.sort((a, b) => b.score - a.score).slice(0, 6);
  }

  function layerWeights(results) {
    const weights = { app: 2, os: 2, path: 2, hardware: 2 };
    results.forEach((r, index) => { weights[r.layer] += Math.max(8, r.score / (index + 1)); });
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
    const labels = {app:"Application/config", os:"Driver/OS", path:"Device/path", hardware:"Hardware suspicion"};
    Object.entries(weights).forEach(([key, value]) => {
      document.querySelector(`#node-${key}`).style.setProperty("--power", String(value / 100));
    });
    document.querySelector("#layer-legend").innerHTML = Object.entries(weights).map(([key, value]) => `
      <div class="layer-row"><span>${labels[key]}</span><span class="layer-meter"><i style="width:${value}%"></i></span><b>${value}</b></div>`).join("");
  }

  function renderResults(results) {
    const primarySelected = questions.find((q) => q.id === "symptom").options.some(([id]) => selected.has(id));
    if (!primarySelected) {
      rankedResults.innerHTML = `<div class="empty-result"><div><strong>Start with what failed.</strong><p>Select a primary symptom. The ranking will become useful after timing and “what still works” answers.</p></div></div>`;
      return;
    }
    if (!results.length) {
      rankedResults.innerHTML = `<div class="empty-result"><div><strong>No safe pattern match yet.</strong><p>Add timing, survivor, scope, and evidence checks. Unknown is better than a false diagnosis.</p></div></div>`;
      return;
    }
    rankedResults.innerHTML = results.map((r, index) => `
      <article class="result-card">
        <div class="result-card-head">
          <span class="rank">${String(index + 1).padStart(2, "0")}</span>
          <div><span class="result-kicker">${escapeHtml(r.kicker)}</span><h3>${escapeHtml(r.title)}</h3></div>
          <span class="confidence">${escapeHtml(r.confidence)}</span>
        </div>
        <p class="result-why">${escapeHtml(r.why)}</p>
        <details>
          <summary>Open evidence and action boundary · ${r.matched.length} selected facts matched</summary>
          <div class="result-detail">
            <div><h4>Collect</h4><ul>${r.evidence.map((x) => `<li>${escapeHtml(x)}</li>`).join("")}</ul></div>
            <div><h4>Safe next steps</h4><ul>${r.steps.map((x) => `<li>${escapeHtml(x)}</li>`).join("")}</ul></div>
            <div><h4>Your matched facts</h4><ul>${r.matched.map((id) => `<li>${escapeHtml(optionById.get(id) || id)}</li>`).join("")}</ul></div>
          </div>
          <p class="avoid-box"><strong>Avoid:</strong> ${escapeHtml(r.avoid)}</p>
          <a class="result-link" href="${escapeHtml(guideHref(r.link))}">Open the full diagnostic guide →</a>
        </details>
      </article>`).join("");
  }

  function renderSafety() {
    const unsafe = ["smoke","swelling","liquid","sparking","port-damage","hot-off"].filter((id) => selected.has(id));
    const banner = document.querySelector("#safety-banner");
    banner.hidden = !unsafe.length;
    if (unsafe.length) document.querySelector("#safety-copy").textContent = `${unsafe.map((id) => optionById.get(id)).join(", ")}. Disconnect power if safe, do not charge/open/stress-test it, and contact Steam Support.`;
  }

  function renderFacts() {
    const facts = [...selected].filter((id) => optionById.has(id));
    document.querySelector("#selection-count").textContent = `${facts.length} selected`;
    document.querySelector("#selected-facts").innerHTML = facts.length ? facts.map((id) => `<span class="fact-chip">${escapeHtml(optionById.get(id))}</span>`).join("") : `<span class="suggestion-empty">No incident facts selected yet.</span>`;
  }

  function updateProgress() {
    let touched = 0;
    questions.forEach((group) => {
      const count = group.options.filter(([id]) => selected.has(id)).length;
      if (count) touched += 1;
      document.querySelector(`[data-count-for="${group.id}"]`).textContent = `${count} selected`;
    });
    document.querySelector("#answered-count").textContent = String(touched);
    document.querySelector("#group-count").textContent = String(questions.length);
    document.querySelector("#progress-bar").style.width = `${touched / questions.length * 100}%`;
  }

  function updateUrl() {
    const url = new URL(window.location.href);
    const facts = [...selected].filter((id) => optionById.has(id));
    if (facts.length) url.searchParams.set("s", facts.join(",")); else url.searchParams.delete("s");
    history.replaceState(null, "", url);
  }

  function update() {
    document.querySelectorAll("[data-option]").forEach((button) => button.setAttribute("aria-pressed", selected.has(button.dataset.option) ? "true" : "false"));
    const suggestions = currentSuggestions();
    renderSuggestions(suggestions);
    renderSafety();
    updateProgress();
    renderFacts();
    const results = getResults();
    renderResults(results);
    renderConstellation(layerWeights(results));
    document.querySelector("#os-warning").hidden = !selected.has("windows");
    document.querySelector("#suggestion-explainer").textContent = suggestions.length ? "These unanswered checks create the largest split between the current branches. Click one to add it." : "Choose a primary symptom and DeckMD will offer the answers that split its major branches.";
    updateUrl();
  }

  function openOption(id) {
    const groupId = groupByOption.get(id);
    const detail = document.querySelector(`[data-group="${CSS.escape(groupId)}"]`);
    if (detail) detail.open = true;
    toggleOption(id, true);
    document.querySelector(`[data-option="${CSS.escape(id)}"]`)?.scrollIntoView({behavior:"smooth", block:"center"});
  }

  function caseSummary() {
    const lines = ["DeckMD incident checklist", "========================"];
    questions.forEach((group) => {
      const facts = group.options.filter(([id]) => selected.has(id)).map(([,label]) => `- ${label}`);
      if (facts.length) lines.push(`\n${group.title}`, ...facts);
    });
    const results = getResults();
    if (results.length) lines.push("\nRanked diagnostic branches", ...results.slice(0,5).map((r, i) => `${i+1}. ${r.title} — ${r.confidence}`));
    lines.push("\nGenerated locally by DeckMD. Rankings are triage priorities, not diagnoses.");
    return lines.join("\n");
  }

  async function copyText(text, button) {
    try {
      await navigator.clipboard.writeText(text);
      const old = button.textContent;
      button.textContent = "Copied";
      setTimeout(() => { button.textContent = old; }, 1600);
    } catch (_) {
      const area = document.createElement("textarea");
      area.value = text; document.body.append(area); area.select(); document.execCommand("copy"); area.remove();
    }
  }

  renderQuestions();

  const initial = new URLSearchParams(location.search).get("s");
  if (initial) initial.split(",").forEach((id) => { if (optionById.has(id)) selected.add(id); });

  suggestionRail.addEventListener("click", (event) => {
    const chip = event.target.closest("[data-suggestion]");
    if (chip) openOption(chip.dataset.suggestion);
  });

  document.querySelector("#option-search").addEventListener("input", (event) => {
    const query = event.target.value.trim().toLowerCase();
    document.querySelectorAll(".question-group").forEach((group) => {
      let matches = 0;
      group.querySelectorAll(".option-card").forEach((button) => {
        const visible = !query || button.dataset.label.includes(query);
        button.hidden = !visible;
        if (visible) matches += 1;
      });
      group.hidden = Boolean(query && !matches);
      if (query && matches) group.open = true;
    });
  });

  document.querySelector("#expand-all").addEventListener("click", (event) => {
    const groups = [...document.querySelectorAll(".question-group:not([hidden])")];
    const expand = groups.some((group) => !group.open);
    groups.forEach((group) => { group.open = expand; });
    event.currentTarget.textContent = expand ? "Collapse all sections" : "Expand all sections";
  });
  document.querySelector("#reset-all").addEventListener("click", () => { selected.clear(); update(); });
  document.querySelector("#copy-summary").addEventListener("click", (event) => copyText(caseSummary(), event.currentTarget));
  document.querySelector("#copy-link").addEventListener("click", (event) => copyText(location.href, event.currentTarget));

  update();
})();
