#!/usr/bin/env node
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Localises the approved English listing (store/listing-en-US.json) into every App Store locale
// with Gemini, writing store/localized/<locale>.json. Each result is checked against App Store
// limits and our wording rules; failures are retried with the reasons, then reported.
//
//   node scripts/gemini-localize-listing.mjs [locale …] [--model name] [--force]
//   node scripts/gemini-localize-listing.mjs --text-only   (redo promotional text, description and
//     What's New only; each language keeps its own subtitle and keywords, so search ranking holds)
//   node scripts/gemini-localize-listing.mjs --whats-new   (redo What's New only; everything else
//     in each language stays as it is)
//   node scripts/gemini-localize-listing.mjs --whats-new-mac   (redo the Mac's own What's New,
//     whatsNewMac, from the English whatsNewMac; everything else stays as it is)
//   node scripts/gemini-localize-listing.mjs --search-only   (redo subtitle and keywords only, the
//     fields App Store search reads; descriptions and promotional text stay as they are)
//   node scripts/gemini-localize-listing.mjs --keywords-only   (redo keywords only, written to fit each
//     language's own approved subtitle, which stays as it is)
//
// The key comes from GEMINI_API_KEY in the environment or in the gitignored .env file.

import { generate, batch, report } from "./gemini-client.mjs";
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";

const argv = process.argv.slice(2);
const opt = (name, fallback) => { const i = argv.indexOf(name); return i >= 0 ? argv.splice(i, 2)[1] : fallback; };
const MODEL = opt("--model", "gemini-3.7-flash");
const FORCE = argv.includes("--force");
if (FORCE) argv.splice(argv.indexOf("--force"), 1);
// Marketing standing rule (2026-11-25): never re-translate a whole set without the owner's yes.
const APPROVED_FULL = argv.includes("--approved-full");
if (APPROVED_FULL) argv.splice(argv.indexOf("--approved-full"), 1);
const TEXT_ONLY = argv.includes("--text-only");
if (TEXT_ONLY) argv.splice(argv.indexOf("--text-only"), 1);
const WHATS_NEW_ONLY = argv.includes("--whats-new");
if (WHATS_NEW_ONLY) argv.splice(argv.indexOf("--whats-new"), 1);
const WHATS_NEW_MAC = argv.includes("--whats-new-mac");
if (WHATS_NEW_MAC) argv.splice(argv.indexOf("--whats-new-mac"), 1);
let SEARCH_ONLY = argv.includes("--search-only");
if (SEARCH_ONLY) argv.splice(argv.indexOf("--search-only"), 1);
const KEYWORDS_ONLY = argv.includes("--keywords-only");
if (KEYWORDS_ONLY) { argv.splice(argv.indexOf("--keywords-only"), 1); SEARCH_ONLY = true; }
const envFile = new URL("../.env", import.meta.url);
const KEY = process.env.GEMINI_API_KEY || (existsSync(envFile) ? (readFileSync(envFile, "utf8").split("\n")
  .find((l) => l.startsWith("GEMINI_API_KEY=")) ?? "").slice(15).trim() : "");
if (!KEY || KEY.startsWith("PASTE_")) { console.error("Add GEMINI_API_KEY to .env first"); process.exit(1); }

const en = JSON.parse(readFileSync(new URL("../store/listing-en-US.json", import.meta.url), "utf8"));
// The Mac's note runs through the What's New path, then is saved as whatsNewMac.
if (WHATS_NEW_MAC) en.whatsNew = en.whatsNewMac;
const WHATS_NEW = WHATS_NEW_ONLY || WHATS_NEW_MAC;
const OUT = new URL("../store/localized/", import.meta.url);
mkdirSync(OUT, { recursive: true });

export const LOCALES = {
  "ar-SA": "Arabic", "bn-BD": "Bengali", ca: "Catalan", cs: "Czech", da: "Danish", "de-DE": "German",
  el: "Greek", "en-AU": "English (Australia)", "en-CA": "English (Canada)", "en-GB": "English (UK)",
  "es-ES": "Spanish (Spain)", "es-MX": "Spanish (Mexico)", fi: "Finnish", "fr-CA": "French (Canada)",
  "fr-FR": "French (France)", "gu-IN": "Gujarati", he: "Hebrew", hi: "Hindi", hr: "Croatian",
  hu: "Hungarian", id: "Indonesian", it: "Italian", ja: "Japanese", "kn-IN": "Kannada", ko: "Korean",
  "ml-IN": "Malayalam", "mr-IN": "Marathi", ms: "Malay", "nl-NL": "Dutch", no: "Norwegian (Bokmål)",
  "or-IN": "Odia", "pa-IN": "Punjabi (Gurmukhi)", pl: "Polish", "pt-BR": "Portuguese (Brazil)",
  "pt-PT": "Portuguese (Portugal)", ro: "Romanian", ru: "Russian", sk: "Slovak", "sl-SI": "Slovenian",
  sv: "Swedish", "ta-IN": "Tamil", "te-IN": "Telugu", th: "Thai", tr: "Turkish", uk: "Ukrainian",
  "ur-PK": "Urdu", vi: "Vietnamese", "zh-Hans": "Chinese (Simplified)", "zh-Hant": "Chinese (Traditional)",
};
const ENGLISH = new Set(["en-AU", "en-CA", "en-GB"]);
// Extra private terms can be added with BANNED_TERMS=a|b in the gitignored .env file.
const extraBanned = (existsSync(envFile) ? readFileSync(envFile, "utf8").split("\n").find((l) => l.startsWith("BANNED_TERMS=")) ?? "" : "").slice(13).trim();
const BANNED = new RegExp(`${extraBanned ? `${extraBanned}|` : ""}spyware|spying apps?|malware|anti-?virus|\\bvirus\\b|#\\s*1|\\bbest\\b`, "i");
const BRAND = "hYYa Digital Footprint Check";

function check(l) {
  const issues = [];
  const len = (s) => [...s].length;
  if (!l.subtitle || len(l.subtitle) > 30) issues.push(`subtitle is ${len(l.subtitle ?? "")} characters (max 30)`);
  if (!l.promotionalText || len(l.promotionalText) > 170) issues.push(`promotional text is ${len(l.promotionalText ?? "")} characters (max 170)`);
  if (!l.description || len(l.description) > 4000) issues.push(`description is ${len(l.description ?? "")} characters (max 4000)`);
  for (const f of ["promotionalText", "description"]) if (/\b(?:iphone|ipad|ios|mac|android)\b/i.test(l[f] ?? "")) issues.push(`${f} must not name a device or platform`);
  if (!l.description?.includes(BRAND)) issues.push(`description must keep the name "${BRAND}" untranslated`);
  const kw = l.keywords ?? "";
  if (!kw || Buffer.byteLength(kw) > 100) issues.push(`keywords are ${Buffer.byteLength(kw)} UTF-8 bytes (max 100)`);
  const words = kw.split(",");
  if (words.some((w) => !w || w !== w.trim())) issues.push("keywords: no spaces around commas and no empty items");
  if (new Set(words.map((w) => w.toLowerCase())).size !== words.length) issues.push("keywords: duplicates");
  const taken = `${BRAND} ${l.subtitle ?? ""}`.toLowerCase().split(/[\s,&:،、・]+/).filter((w) => w.length > 1);
  for (const w of words) if (taken.includes(w.toLowerCase())) issues.push(`keyword "${w}" already appears in the name or subtitle`);
  if (en.whatsNew) {
    if (!l.whatsNew || len(l.whatsNew) > 4000) issues.push("whatsNew is missing or too long");
    else {
      if (en.whatsNew.includes("iPhone Duo") && !l.whatsNew.includes("iPhone Duo")) issues.push('whatsNew must keep "iPhone Duo" exactly as written');
      if (l.whatsNew.split("\n").length !== en.whatsNew.split("\n").length) issues.push("whatsNew must keep the same lines as the English");
      for (const page of ["Check-up"]) if (en.whatsNew.includes(page) && !l.whatsNew.includes(page)) issues.push(`whatsNew must keep the page name "${page}" in English`);
    }
  }
  for (const [k, v] of Object.entries(l)) if (BANNED.test(v)) issues.push(`${k} uses a banned word (${v.match(BANNED)[0]})`);
  if (/privacy report|app privacy|datenschutzbericht|rapport de confidentialité|informe de privacidad|プライバシーレポート|隐私报告|隱私權報告|개인정보 보호 리포트/i.test(l.subtitle ?? "")) issues.push("subtitle must not use the App Privacy Report name");
  if (/\bfree\b/i.test(l.subtitle ?? "") || /gratuit|gratis|kostenlos|無料|免费|免費|무료|бесплат|مجان/i.test(l.subtitle ?? "")) issues.push("subtitle must not mention price or free");
  return issues;
}

function prompt(language, feedback, subtitle) {
  return `You localise App Store listings. Localise this approved English listing for a free, open-source privacy app into ${language}, for people searching the App Store in that language.

Rules:
- Natural, native wording; calm and plain, never alarmist or hyped. Not a word-for-word translation.
- subtitle: at most 30 characters. Translate the English subtitle's meaning, "a privacy score and an app tracker", into the local everyday words people search for. Never use the phrase "App Privacy Report" or its local name (it is the system's own feature name). No price, no "free", no superlatives.
- keywords: comma-separated search terms people in this language really type, no spaces after commas, at most 100 UTF-8 bytes in total, every term longer than two characters where the script allows. Do not repeat any word from the name "${BRAND}" or from your subtitle. Cover the ideas of the English keywords: app permissions, tracking, digital fingerprinting (only in the sense of tracking a device; never a word people use for fingerprint screen locks or biometrics, so leave it out if the local word means that), privacy check-up, lockdown mode, location, camera, microphone, photos, contacts. No widget, safety or settings terms. English terms are fine only where locals commonly search in English.
- promotionalText and description: both must open with a faithful translation of the first sentence, "100% free: no ads, no in-app purchases." Payment words appear nowhere else in the subtitle or keywords.
- promotionalText: at most 170 characters. Keep it device-neutral like the English (phone, tablet or computer): never name iPhone, iPad, Mac or Android.
- description: at most 4000 characters, plain text. Keep the structure: paragraphs, the UPPERCASE section headings (translated, still uppercase where the script has case) and the • bullets. Keep "${BRAND}", "hYYa" and "Mozilla Public License 2.0" unchanged; "Settings" is the system's own localised name for the Settings app. Stay device-neutral like the English ("your device", "the system"): never name iPhone, iPad, iOS, Mac or Android.
- Never mention other apps or companies, viruses, malware or spyware, and make no ranking claims.
- The app itself is in English, so when the release note names one of its pages ("Check-up"), keep that name in English exactly as written; local quotation marks around it are fine.
- whatsNew: the release note. Keep every line in order: each • feature line${en.whatsNew?.includes("iPhone Duo") ? ' (keep "iPhone Duo" exactly as written, it\'s the device\'s name)' : ""} and, on the last line, a faithful translation of the fixed sentence "This release contains general bug fixes and stability improvements."
${KEYWORDS_ONLY && subtitle ? `\nThis language's subtitle is fixed: "${subtitle}". Write only keywords that fit it (no word repeated from it), and return that subtitle unchanged.\n` : ""}${feedback ? `\nYour previous attempt had these problems; fix all of them:\n- ${feedback.join("\n- ")}\n` : ""}
English listing (JSON):
${JSON.stringify(WHATS_NEW ? { whatsNew: en.whatsNew } : SEARCH_ONLY ? { subtitle: en.subtitle, keywords: en.keywords } : TEXT_ONLY ? { promotionalText: en.promotionalText, description: en.description, whatsNew: en.whatsNew }
  : { subtitle: en.subtitle, keywords: en.keywords, promotionalText: en.promotionalText, description: en.description, whatsNew: en.whatsNew }, null, 1)}`;
}

const schema = WHATS_NEW
  ? { type: "OBJECT", required: ["whatsNew"], properties: { whatsNew: { type: "STRING" } } }
  : SEARCH_ONLY
  ? { type: "OBJECT", required: ["subtitle", "keywords"], properties: { subtitle: { type: "STRING" }, keywords: { type: "STRING" } } }
  : TEXT_ONLY
  ? { type: "OBJECT", required: ["promotionalText", "description", "whatsNew"], properties: {
      promotionalText: { type: "STRING" }, description: { type: "STRING" }, whatsNew: { type: "STRING" } } }
  : { type: "OBJECT", required: ["subtitle", "keywords", "promotionalText", "description", "whatsNew"], properties: {
      subtitle: { type: "STRING" }, keywords: { type: "STRING" }, promotionalText: { type: "STRING" }, description: { type: "STRING" }, whatsNew: { type: "STRING" } } };

async function gemini(text) {
  return generate(MODEL, text, schema, 0.3);
}

function merge(result, kept) {
  if (kept) result = WHATS_NEW ? { ...kept, whatsNew: result.whatsNew }
    : SEARCH_ONLY ? { ...kept, subtitle: KEYWORDS_ONLY ? kept.subtitle : result.subtitle, keywords: result.keywords }
    : { subtitle: kept.subtitle, keywords: kept.keywords, ...result };
  delete result.locale; delete result.name;
  result.keywords = result.keywords.split(/\s*[,،、，]\s*/).filter(Boolean).join(",");
  return result;
}

async function localise(locale) {
  const file = new URL(`${locale}.json`, OUT);
  if (!FORCE && !TEXT_ONLY && !WHATS_NEW && !SEARCH_ONLY && existsSync(file)) return `${locale}: kept`;
  const kept = (TEXT_ONLY || WHATS_NEW || SEARCH_ONLY) && existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : null;
  let result, issues;
  if (ENGLISH.has(locale)) {
    result = { subtitle: SEARCH_ONLY ? en.subtitle : kept?.subtitle ?? en.subtitle, keywords: SEARCH_ONLY ? en.keywords : kept?.keywords ?? en.keywords,
               promotionalText: WHATS_NEW ? kept?.promotionalText ?? en.promotionalText : en.promotionalText,
               description: WHATS_NEW ? kept?.description ?? en.description : en.description, whatsNew: en.whatsNew };
    issues = check(result);
  } else {
    for (let attempt = 1; attempt <= 4; attempt++) {
      result = attempt === 1 && firstPass[locale] && !(firstPass[locale] instanceof Error) ? firstPass[locale]
        : await gemini(prompt(LOCALES[locale], issues, kept?.subtitle));
      result = merge(result, kept);
      issues = check(result);
      if (!issues.length) break;
    }
  }
  if (issues.length) return `${locale}: ✗ ${issues.join("; ")}`;
  if (WHATS_NEW_MAC) result = { ...result, whatsNewMac: result.whatsNew, whatsNew: kept?.whatsNew ?? JSON.parse(readFileSync(new URL("../store/listing-en-US.json", import.meta.url), "utf8")).whatsNew };
  writeFileSync(file, JSON.stringify({ locale, name: BRAND, ...result }, null, 2) + "\n");
  return `${locale}: ✓ ${result.subtitle}`;
}

// The English the current translations were made from; the default run diffs against it.
const SOURCE = new URL(".source-en-US.json", OUT);
const TEXT_FIELDS = ["promotionalText", "description", "whatsNew", "whatsNewMac"];
const saveSource = () => writeFileSync(SOURCE, JSON.stringify(Object.fromEntries([...TEXT_FIELDS, "subtitle", "keywords"].map((f) => [f, en[f]])), null, 2) + "\n");
const LINES_SCHEMA = { type: "OBJECT", required: ["lines"], properties: { lines: { type: "ARRAY", items: { type: "STRING" } } } };
const linesPrompt = (language, lines, context) => `You localise an App Store listing into ${language}. Translate ONLY the English lines below, each into one line, keeping "${BRAND}" and "hYYa" unchanged, the same calm, plain tone, and any leading "•" bullet. Never mention Android. Say "device", never "iPhone", "iPad", "phone" or "tablet".
Full English listing, for context only:
${en.description}

Lines to translate (JSON array, same order):
${JSON.stringify(lines)}`;

const modeFlags = FORCE || TEXT_ONLY || WHATS_NEW || SEARCH_ONLY;
if (FORCE && !APPROVED_FULL) { console.error("--force re-translates every locale. Ask the owner first, then add --approved-full. Default (no flag): only changed lines are translated."); process.exit(1); }

if (!modeFlags && !argv.length && existsSync(SOURCE)) {
  const old = JSON.parse(readFileSync(SOURCE, "utf8"));
  if (old.subtitle !== en.subtitle || old.keywords !== en.keywords) {
    console.error("Subtitle or keywords changed: those are per-language search wording, not line translations. With the owner's yes, run --search-only or --keywords-only."); process.exit(1);
  }
  const plan = {};
  for (const f of TEXT_FIELDS) {
    const a = (old[f] ?? "").split("\n"), b = (en[f] ?? "").split("\n");
    if (a.join("\n") === b.join("\n")) continue;
    plan[f] = a.length === b.length ? b.map((l, i) => (l !== a[i] ? i : -1)).filter((i) => i >= 0) : null;
  }
  if (!Object.keys(plan).length) { console.log("English unchanged since the last translation: nothing to translate."); process.exit(0); }
  if (Object.values(plan).some((v) => v === null) && !APPROVED_FULL) { console.error("A field changed its line structure: it needs a full re-translation of that field in every locale. Ask the owner first, then re-run with --approved-full."); process.exit(1); }
  const codes = process.env.TEST_LANGS ? process.env.TEST_LANGS.split(",") : Object.keys(LOCALES).filter((l) => !ENGLISH.has(l));
  const cur = {}, items = [], fails = [];
  for (const l of codes) {
    const file = new URL(`${l}.json`, OUT); if (!existsSync(file)) { fails.push(`${l}: no existing translation`); continue; }
    cur[l] = JSON.parse(readFileSync(file, "utf8"));
    for (const [f, idx] of Object.entries(plan)) {
      if ((cur[l][f] ?? "").split("\n").length !== en[f].split("\n").length) { fails.push(`${l} ${f}: line structure differs`); continue; }
      items.push({ key: `${l}|${f}`, text: linesPrompt(LOCALES[l], idx.map((i) => en[f].split("\n")[i])), schema: LINES_SCHEMA, temperature: 0.2 });
    }
  }
  const answers = items.length > 5 ? await batch(MODEL, items, { name: "appstore-changed-lines" })
    : Object.fromEntries(await Promise.all(items.map(async (it) => [it.key, await generate(MODEL, it.text, it.schema, it.temperature).catch((e) => e)])));
  for (const it of items) {
    const [l, f] = it.key.split("|"); const idx = plan[f]; const tr = answers[it.key];
    if (tr instanceof Error || !tr?.lines || tr.lines.length !== idx.length) { fails.push(`${l} ${f}: translation failed`); delete cur[l]; continue; }
    const mine = cur[l][f].split("\n"); idx.forEach((i, k) => { mine[i] = tr.lines[k]; }); cur[l][f] = mine.join("\n");
  }
  let done = 0;
  for (const [l, r] of Object.entries(cur)) {
    if (fails.some((x) => x.startsWith(l + " ") || x.startsWith(l + ":"))) continue;
    const issues = check(r); if (issues.length) { fails.push(`${l}: ${issues.join("; ")}`); continue; }
    writeFileSync(new URL(`${l}.json`, OUT), JSON.stringify(r, null, 2) + "\n"); done++;
  }
  if (!process.env.TEST_LANGS) for (const l of ENGLISH) { const file = new URL(`${l}.json`, OUT); if (existsSync(file)) { const r = JSON.parse(readFileSync(file, "utf8")); for (const f of Object.keys(plan)) r[f] = en[f]; writeFileSync(file, JSON.stringify(r, null, 2) + "\n"); } }
  console.log(`Changed lines translated in ${done} locales; ${fails.length} need attention${fails.length ? ":\n  " + fails.join("\n  ") : "."}`);
  if (!fails.length && !process.env.TEST_LANGS) saveSource();
  report("gemini-localize-listing", "changed-lines");
  process.exit(fails.length ? 1 : 0);
}

const wanted = argv.length ? argv : Object.keys(LOCALES);
// Mode and full runs over many locales: first pass through the Batch API at half price; anything failing the
// checks is then retried directly with the reasons as feedback.
const firstPass = {};
const toBatch = wanted.filter((l) => !ENGLISH.has(l) && (modeFlags || !existsSync(new URL(`${l}.json`, OUT))));
if (toBatch.length > 5) Object.assign(firstPass, await batch(MODEL, toBatch.map((l) => {
  const file = new URL(`${l}.json`, OUT);
  const kept = (TEXT_ONLY || WHATS_NEW || SEARCH_ONLY) && existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : null;
  return { key: l, text: prompt(LOCALES[l], undefined, kept?.subtitle), schema, temperature: 0.3 };
}), { name: "appstore-full" }));
const queue = [...wanted];
await Promise.all(Array.from({ length: 6 }, async () => {
  while (queue.length) {
    const loc = queue.shift();
    try { console.log(await localise(loc)); } catch (e) { console.log(`${loc}: ✗ ${e.message}`); }
  }
}));
if (FORCE || TEXT_ONLY || !existsSync(SOURCE)) saveSource();
report("gemini-localize-listing", FORCE ? "full" : WHATS_NEW ? "whats-new" : SEARCH_ONLY ? "search" : TEXT_ONLY ? "text" : "new-locales");
