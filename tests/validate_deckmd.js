#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const root = path.resolve(__dirname, "..");
const context = { window: {} };
vm.createContext(context);
for (const file of ["docs/assets/questionnaire.js", "docs/assets/knowledge.js"]) {
  vm.runInContext(fs.readFileSync(path.join(root, file), "utf8"), context, { filename: file });
}

const questions = context.window.DECKDOC_QUESTIONNAIRE;
const knowledge = context.window.DECKDOC_KNOWLEDGE;
const related = context.window.DECKDOC_RELATED_CHECKS;
const failures = [];

if (!Array.isArray(questions) || questions.length < 8) failures.push("questionnaire must contain at least 8 sections");
if (!Array.isArray(knowledge) || knowledge.length < 12) failures.push("knowledge base must contain at least 12 diagnostic branches");

const primary = new Set((questions.find((group) => group.id === "symptom") || { options: [] }).options.map(([id]) => id));
const allIds = questions.flatMap((group) => group.options.map(([id]) => id));
const uniqueIds = new Set(allIds);
const duplicates = [...new Set(allIds.filter((id, index) => allIds.indexOf(id) !== index))];
if (duplicates.length) failures.push(`duplicate option IDs: ${duplicates.join(", ")}`);

for (const rule of knowledge) {
  for (const key of ["symptoms", "requiresAll", "contextsAny"]) {
    for (const id of rule[key] || []) if (!uniqueIds.has(id)) failures.push(`${rule.id}.${key} references missing ${id}`);
  }
  if (!rule.link || !fs.existsSync(path.join(root, "docs", `${rule.link}.md`))) failures.push(`${rule.id} has a missing wiki route`);
}

for (const [symptom, suggestions] of Object.entries(related || {})) {
  if (!primary.has(symptom)) failures.push(`related-check map uses non-primary symptom ${symptom}`);
  for (const id of suggestions) if (!uniqueIds.has(id)) failures.push(`${symptom} suggests missing ${id}`);
}

const displayChecks = related?.display || [];
for (const required of ["sound-works", "screen-backlight", "screen-no-light", "input-works", "ssh-works", "during-game", "after-wake"]) {
  if (!displayChecks.includes(required)) failures.push(`display follow-ups omit ${required}`);
}

if (allIds.length < 100) failures.push(`expected a massive checklist; found only ${allIds.length} facts`);

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}
console.log(`DeckMD schema valid: ${questions.length} sections, ${allIds.length} unique facts, ${knowledge.length} ranked branches.`);
