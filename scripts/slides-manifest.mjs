#!/usr/bin/env node
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// The store slide manifest (Marketing standing rule, 2026-11-25): one row per slide file with its store,
// device, slide number, the app screen it shows, the languages it serves and its sha256. Proves what changed.
//
//   node scripts/slides-manifest.mjs           write store/slides-manifest.json
//   node scripts/slides-manifest.mjs --diff    list slides that differ from the saved manifest (writes nothing)
import { readFileSync, readdirSync, writeFileSync, existsSync } from "node:fs";
import { createHash } from "node:crypto";

const ROOT = decodeURIComponent(new URL("..", import.meta.url).pathname);
const OUT = `${ROOT}store/slides-manifest.json`;
const screens = (file) => JSON.parse(readFileSync(`${ROOT}store/${file}`, "utf8")).slides.map((s) => s.screen);
const APP_STORE = "en-US (shown in every App Store language)";
const PLAY = "every Play language (same image)";
const SETS = [
  { store: "App Store", device: "iPhone 6.9", dir: "iphone-6.9", screens: screens("slides.json"), languages: APP_STORE },
  { store: "App Store", device: "iPad 13", dir: "ipad-13", screens: screens("slides.json"), languages: APP_STORE },
  { store: "App Store", device: "iPhone Duo", dir: "duo", screens: null, languages: APP_STORE },
  { store: "App Store", device: "Mac", dir: "mac", screens: screens("slides-mac.json"), languages: APP_STORE },
  { store: "Google Play", device: "Phone", dir: "android-phone", screens: screens("slides-android.json"), languages: PLAY },
  { store: "Google Play", device: "Tablet (7 and 10 inch)", dir: "android-tablet", screens: screens("slides-android.json"), languages: PLAY },
];

const rows = [];
for (const s of SETS) {
  const files = readdirSync(`${ROOT}store/slides/${s.dir}`).filter((f) => f.endsWith(".png")).sort();
  files.forEach((f, i) => rows.push({
    store: s.store, device: s.device, slide: i + 1, file: `store/slides/${s.dir}/${f}`,
    // Duo slides name their pose and screen in the file name (01-closed-results).
    screen: s.screens ? s.screens[i] : f.replace(/^\d+-/, "").replace(/\.png$/, ""),
    languages: s.languages,
    sha256: createHash("sha256").update(readFileSync(`${ROOT}store/slides/${s.dir}/${f}`)).digest("hex"),
  }));
}
for (const f of ["play-icon-512.png", "play-feature-1024x500.png"])
  rows.push({ store: "Google Play", device: f.includes("icon") ? "Icon" : "Feature graphic", slide: 1, file: `store/slides/${f}`,
    screen: "-", languages: PLAY, sha256: createHash("sha256").update(readFileSync(`${ROOT}store/slides/${f}`)).digest("hex") });

if (process.argv.includes("--diff")) {
  if (!existsSync(OUT)) { console.log("No saved manifest yet: run without --diff first."); process.exit(0); }
  const saved = new Map(JSON.parse(readFileSync(OUT, "utf8")).slides.map((r) => [r.file, r.sha256]));
  const changed = rows.filter((r) => saved.get(r.file) !== r.sha256);
  const removed = [...saved.keys()].filter((f) => !rows.some((r) => r.file === f));
  for (const r of changed) console.log(`changed: ${r.store} · ${r.device} · slide ${r.slide} (${r.screen}) · ${r.file}`);
  for (const f of removed) console.log(`removed: ${f}`);
  const byStore = (st) => `${st}: ${changed.filter((r) => r.store === st).length} changed / ${rows.filter((r) => r.store === st).length - changed.filter((r) => r.store === st).length} kept`;
  console.log(`${byStore("App Store")}; ${byStore("Google Play")}${removed.length ? `; ${removed.length} removed` : ""}`);
  process.exit(0);
}
writeFileSync(OUT, JSON.stringify({ updated: new Date().toISOString().slice(0, 10), slides: rows }, null, 2) + "\n");
console.log(`${rows.length} files in store/slides-manifest.json`);
