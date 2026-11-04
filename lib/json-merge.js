// kickoff – JSON-Merge für VS-Code-Settings, genutzt von lib/common.sh und lib/common.ps1.
// node json-merge.js <target> <defaults> <check|write>
// Fehlende Keys aus <defaults> in <target> ergänzen, bestehende Keys gewinnen.
// Exit 0 = nichts zu tun, 10 = geändert (bzw. würde ändern; fehlende Keys auf stdout),
// 20 = Ziel ist kein reines JSON (z. B. Kommentare) – dann wird nichts angefasst.
"use strict";
const fs = require("fs");
const path = require("path");
const [target, defaults, mode] = process.argv.slice(2);
const want = JSON.parse(fs.readFileSync(defaults, "utf8"));
let have = {};
if (fs.existsSync(target)) {
  const raw = fs.readFileSync(target, "utf8").replace(/^﻿/, "");
  if (raw.trim() !== "") {
    try { have = JSON.parse(raw); } catch (e) { process.exit(20); }
  }
}
const missing = Object.keys(want).filter((k) => !(k in have));
if (missing.length === 0) process.exit(0);
if (mode === "write") {
  for (const k of missing) have[k] = want[k];
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, JSON.stringify(have, null, 2) + "\n");
}
console.log(missing.join(", "));
process.exit(10);
