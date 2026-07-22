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
const categories = context.window.DECKDOC_CATEGORIES;
const conflicts = context.window.DECKDOC_CONFLICTS;
const failures = [];

if (!Array.isArray(questions) || questions.length < 8) failures.push("questionnaire must contain at least 8 sections");
if (!Array.isArray(knowledge) || knowledge.length < 12) failures.push("knowledge base must contain at least 12 diagnostic branches");

const primary = new Set((questions.find((group) => group.id === "symptom") || { options: [] }).options.map(([id]) => id));
const allIds = questions.flatMap((group) => group.options.map(([id]) => id));
const uniqueIds = new Set(allIds);
const groupByOption = new Map(questions.flatMap((group) => group.options.map(([id]) => [id, group.id])));
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
  const guidedGroups = new Set(suggestions.map((id) => groupByOption.get(id)).filter((group) => group && group !== "symptom"));
  if (guidedGroups.size < 3) failures.push(`${symptom} needs at least 3 nested follow-up groups`);
}

if (!Array.isArray(categories) || categories.length !== 6) failures.push("guided start must contain exactly 6 broad categories");
const categorySymptoms = (categories || []).flatMap((category) => category.symptoms || []);
for (const symptom of primary) {
  const count = categorySymptoms.filter((id) => id === symptom).length;
  if (count !== 1) failures.push(`${symptom} must appear in exactly one broad category; found ${count}`);
}
for (const category of categories || []) {
  if (!category.title || !category.description || !category.code) failures.push(`${category.id} is missing category copy`);
  if (!category.symptoms?.length || category.symptoms.length > 3) failures.push(`${category.id} must expose 1-3 nested symptoms`);
  for (const id of category.symptoms || []) if (!primary.has(id)) failures.push(`${category.id} contains non-primary symptom ${id}`);
}

if (!Array.isArray(conflicts) || conflicts.length < 20) failures.push("contradiction rules are incomplete");
for (const [left, right, reason] of conflicts || []) {
  if (!uniqueIds.has(left) || !uniqueIds.has(right)) failures.push(`conflict references missing option: ${left}/${right}`);
  if (!reason) failures.push(`conflict ${left}/${right} has no explanation`);
}
const conflictKeys = new Set((conflicts || []).map(([left, right]) => [left, right].sort().join("|")));
for (const pair of [["screen-backlight", "screen-no-light"], ["oled", "screen-backlight"], ["no-response", "ssh-works"], ["device-missing", "connected-icon"]]) {
  if (!conflictKeys.has(pair.sort().join("|"))) failures.push(`required contradiction is missing: ${pair.join("/")}`);
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
console.log(`DeckMD schema valid: ${categories.length} broad categories, ${primary.size} nested symptoms, ${allIds.length} unique facts, ${conflicts.length} contradiction rules, ${knowledge.length} ranked branches.`);
