#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const root = path.resolve(__dirname, "..");
const markdown = [path.join(root, "README.md"), path.join(root, "ROADMAP.md")];

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(file);
    else if (entry.name.endsWith(".md")) markdown.push(file);
  }
}
walk(path.join(root, "docs"));

const failures = [];
for (const file of markdown) {
  const contents = fs.readFileSync(file, "utf8");
  for (const match of contents.matchAll(/\[[^\]]*\]\(([^)]+)\)/g)) {
    const raw = match[1].trim();
    if (/^(?:[a-z]+:|#)/i.test(raw)) continue;
    const target = raw.split("#")[0];
    if (!target) continue;
    const plain = path.resolve(path.dirname(file), target);
    const candidates = path.extname(target) ? [plain] : [plain, `${plain}.md`];
    if (!candidates.some(fs.existsSync)) failures.push(`${path.relative(root, file)} -> ${raw}`);
  }
}

const html = fs.readFileSync(path.join(root, "docs/index.html"), "utf8");
for (const match of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
  const raw = match[1];
  if (/^(?:https?:|#)/.test(raw)) continue;
  const target = path.resolve(root, "docs", raw.replace(/^\.\//, ""));
  if (!fs.existsSync(target)) failures.push(`docs/index.html -> ${raw}`);
}

if (failures.length) {
  console.error(`Broken local links:\n${failures.join("\n")}`);
  process.exit(1);
}
console.log(`Local links valid across ${markdown.length} Markdown files and docs/index.html.`);
