#!/usr/bin/env node
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Localises the approved English Play listing (GooglePlayConsole/listing-en-US.md) into every
// Google Play language with Gemini, writing GooglePlayConsole/localized/<play code>.json. Each
// result is checked against Play's limits and our wording rules; failures are retried with the
// reasons, then reported. Languages that share a translation (English variants, Persian variants…)
// are copied from their source rather than translated twice.
//
//   node scripts/gemini-localize-play.mjs [play code …] [--model name] [--force]
//   node scripts/gemini-localize-play.mjs --notes-only   (redo the release note only; each
//     language keeps its own descriptions)
//
// The key comes from GEMINI_API_KEY in the environment or in the gitignored .env file.

import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";

const argv = process.argv.slice(2);
const opt = (name, fallback) => { const i = argv.indexOf(name); return i >= 0 ? argv.splice(i, 2)[1] : fallback; };
const MODEL = opt("--model", "gemini-3.7-flash");
const FORCE = argv.includes("--force");
if (FORCE) argv.splice(argv.indexOf("--force"), 1);
// Marketing standing rule (2026-11-25): never re-translate a whole set without the owner's yes.
const APPROVED_FULL = argv.includes("--approved-full");
if (APPROVED_FULL) argv.splice(argv.indexOf("--approved-full"), 1);
if (FORCE && !APPROVED_FULL) { console.error("--force re-translates every language. Ask the owner first, then add --approved-full. Default (no flag): only changed lines are translated."); process.exit(1); }
const NOTES_ONLY = argv.includes("--notes-only");
if (NOTES_ONLY) argv.splice(argv.indexOf("--notes-only"), 1);
const envFile = new URL("../.env", import.meta.url);
const KEY = process.env.GEMINI_API_KEY || (existsSync(envFile) ? (readFileSync(envFile, "utf8").split("\n")
  .find((l) => l.startsWith("GEMINI_API_KEY=")) ?? "").slice(15).trim() : "");
if (!KEY || KEY.startsWith("PASTE_")) { console.error("Add GEMINI_API_KEY to .env first"); process.exit(1); }

const md = readFileSync(new URL("../GooglePlayConsole/listing-en-US.md", import.meta.url), "utf8");
const section = (name) => md.split(`## ${name}\n`)[1].split("\n## ")[0].trim();
const BRAND = section("App name (30)");
const en = { shortDescription: section("Short description (80)"), fullDescription: section("Full description (4000)"),
  releaseNotes: section("Release notes (500)") };
const OUT = new URL("../GooglePlayConsole/localized/", import.meta.url);
mkdirSync(OUT, { recursive: true });

// 🚨 Play's codes, not the App Store's: a wrong code is accepted and makes a listing nobody sees.
export const LANGUAGES = {
  af: "Afrikaans", am: "Amharic", ar: "Arabic", "az-AZ": "Azerbaijani", be: "Belarusian",
  bg: "Bulgarian", "bn-BD": "Bengali", ca: "Catalan", "cs-CZ": "Czech", "da-DK": "Danish",
  "de-DE": "German", "el-GR": "Greek", "es-419": "Spanish (Latin America)", "es-ES": "Spanish (Spain)",
  et: "Estonian", "eu-ES": "Basque", fa: "Persian", "fi-FI": "Finnish", fil: "Filipino",
  "fr-CA": "French (Canada)", "fr-FR": "French (France)", "gl-ES": "Galician", gu: "Gujarati",
  "hi-IN": "Hindi", hr: "Croatian", "hu-HU": "Hungarian", "hy-AM": "Armenian", id: "Indonesian",
  "is-IS": "Icelandic", "it-IT": "Italian", "iw-IL": "Hebrew", "ja-JP": "Japanese", "ka-GE": "Georgian",
  kk: "Kazakh", "km-KH": "Khmer", "kn-IN": "Kannada", "ko-KR": "Korean", "ky-KG": "Kyrgyz",
  "lo-LA": "Lao", lt: "Lithuanian", lv: "Latvian", "mk-MK": "Macedonian", "ml-IN": "Malayalam",
  "mn-MN": "Mongolian", "mr-IN": "Marathi", ms: "Malay", "my-MM": "Burmese", "ne-NP": "Nepali",
  "nl-NL": "Dutch", "no-NO": "Norwegian (Bokmål)", pa: "Punjabi (Gurmukhi)", "pl-PL": "Polish",
  "pt-BR": "Portuguese (Brazil)", "pt-PT": "Portuguese (Portugal)", rm: "Romansh", ro: "Romanian",
  "ru-RU": "Russian", "si-LK": "Sinhala", sk: "Slovak", sl: "Slovenian", sq: "Albanian",
  sr: "Serbian (Cyrillic)", "sv-SE": "Swedish", sw: "Swahili", "ta-IN": "Tamil", "te-IN": "Telugu",
  th: "Thai", "tr-TR": "Turkish", uk: "Ukrainian", ur: "Urdu", vi: "Vietnamese",
  "zh-CN": "Chinese (Simplified)", "zh-HK": "Chinese (Traditional, Hong Kong)",
  "zh-TW": "Chinese (Traditional, Taiwan)", zu: "Zulu",
};
// Same text as another language: copied, not translated again.
export const COPIES = {
  "en-AU": "en-US", "en-CA": "en-US", "en-GB": "en-US", "en-IN": "en-US", "en-SG": "en-US", "en-ZA": "en-US",
  "es-US": "es-419", "ms-MY": "ms", "fa-AE": "fa", "fa-AF": "fa", "fa-IR": "fa",
};
// "Phone" in the languages where Gemini reached for it: the listing serves tablets too.
const PHONE = /phone|mobile|smartphone|móvil|mòbil|móbil|celular|telemóvel|telefon|телефон|смартфон|फ़ोन|फोन|ফোন|ફોન|ਫ਼ੋਨ|ਫੋਨ|ఫోన్|ಫೋನ್|ഫോൺ|فون|موبایل|گوشی|هاتف|جوال|טלפון|ስልክ|手机|手機|携帯|スマホ|휴대폰|스마트폰|điện thoại|โทรศัพท์|ဖုန်း|foon|cellulare/i;
const MICROPHONE = /(?:micro|mikro|mic|ميكرو|میکرو|माइक्रो|मायक्रो|मैक्रो|ಮೈಕ್ರೊ|ಮೈಕ್ರೋ|മൈക്രോ|మైక్రో|மைக்ரோ|মাইক্রো|ਮਾਈਕ੍ਰੋ|માઇક્રો|מיקרו|ማይክሮ|მიკრო|микро|μικρό|麦克|麥克|マイク|마이크|ไมโคร|မိုက်ခရို)\S*/giu;
// Extra private terms can be added with BANNED_TERMS=a|b in the gitignored .env file.
const extraBanned = (existsSync(envFile) ? readFileSync(envFile, "utf8").split("\n").find((l) => l.startsWith("BANNED_TERMS=")) ?? "" : "").slice(13).trim();
const BANNED = new RegExp(`${extraBanned ? `${extraBanned}|` : ""}spyware|spying apps?|malware|anti-?virus|\\bvirus\\b|#\\s*1|\\bbest\\b`, "i");

function check(l) {
  const issues = [];
  const len = (s) => [...(s ?? "")].length;
  if (!l.shortDescription || len(l.shortDescription) > 80) issues.push(`shortDescription is ${len(l.shortDescription)} characters (max 80)`);
  if (/\bfree\b|gratuit|gratis|kostenlos|無料|免费|免費|무료|бесплат|مجان|ücretsiz|grátis|darmow|zdarma|ingyenes|miễn phí|gratuita|ฟรี/i.test(l.shortDescription ?? "")) issues.push("shortDescription must not mention free or price");
  if (!l.fullDescription || len(l.fullDescription) > 4000) issues.push(`fullDescription is ${len(l.fullDescription)} characters (max 4000)`);
  for (const f of ["shortDescription", "fullDescription"]) {
    // Letter-aware edges: in many scripts \b treats accented letters as breaks ("…ios" in Lithuanian).
    if (/(?<!\p{L})(?:iphone|ipad|ios|macos|mac)(?!\p{L})/iu.test(l[f] ?? "")) issues.push(`${f} must not name an Apple device or system`);
    // "Microphone" contains "phone" in most languages; it isn't a device name, so it's allowed.
    const phone = (l[f] ?? "").replace(MICROPHONE, "").match(PHONE);
    if (phone) issues.push(`${f} says "${phone[0]}": use the neutral word for "device" instead`);
    if (BANNED.test(l[f] ?? "")) issues.push(`${f} uses a banned word (${l[f].match(BANNED)[0]})`);
  }
  if (!l.fullDescription?.includes(BRAND)) issues.push(`fullDescription must keep the name "${BRAND}" untranslated`);
  if (!l.releaseNotes || len(l.releaseNotes) > 500) issues.push(`releaseNotes is ${len(l.releaseNotes)} characters (max 500)`);
  else if (l.releaseNotes.trim().split("\n").length !== en.releaseNotes.split("\n").length) issues.push("releaseNotes must keep the same lines as the English");
  // The app is in English, so a page it names must keep its English name, or people look for a page that isn't there.
  for (const page of PAGES) if (en.releaseNotes.includes(page) && !l.releaseNotes?.includes(page)) issues.push(`releaseNotes must keep the page name "${page}" in English`);
  return issues;
}

/** The app's own page names, as its English navigation bar shows them ("Settings" is left out: in the listing it
 *  means the system's Settings app, which has a local name). */
const PAGES = ["Score", "Footprint", "Sensitive apps", "Tracker", "Check-up"];

function prompt(language, feedback) {
  return `You localise Google Play store listings. Localise this approved English listing for a free, open-source privacy app into ${language}, for people searching Google Play in that language.

Rules:
- Natural, native wording; calm and plain, never alarmist or hyped. Not a word-for-word translation.
- Google Play search reads the full description, so use the local everyday terms people really search for: privacy check, app permissions, device fingerprint, digital footprint, trackers. Let them appear naturally a few times; no keyword stuffing.
- shortDescription: at most 80 characters. Same message as the English: see what apps know about your device, then fix it, privately. No price or payment words such as "free" (Google's metadata rules).
- fullDescription must open with a faithful translation of its first line, "${en.fullDescription.split("\n")[0]}"
- fullDescription: at most 4000 characters, plain text. Keep the structure: paragraphs, the UPPERCASE section headings (translated, still uppercase where the script has case) and the • bullets. Keep "${BRAND}" and "hYYa" unchanged. "Settings" is the system's own localised name for the Settings app. Keep "Android" and "Google" where the English has them, but never name iPhone, iPad, iOS or Mac.
- Stay device-neutral: the listing is for phones and tablets alike, so say "device" (the local neutral word) wherever the English says "device". Never write "phone", "mobile", "smartphone", "cell" or "tablet".
- The app itself is in English, so when the release note names one of its pages (${PAGES.map((p) => `"${p}"`).join(", ")}), keep that name in English exactly as written; local quotation marks around it are fine.
- releaseNotes: the release note. Keep every line in order: each "•" feature line, and on the last line a faithful translation of the fixed sentence "This release contains general bug fixes and stability improvements."
- Never mention other apps or companies (other than Google and Android as in the English), viruses, malware or spyware, and make no ranking claims.
${feedback ? `\nYour previous attempt had these problems; fix all of them:\n- ${feedback.join("\n- ")}\n` : ""}
English listing (JSON):
${JSON.stringify(NOTES_ONLY ? { releaseNotes: en.releaseNotes } : en, null, 1)}`;
}

const schema = NOTES_ONLY
  ? { type: "OBJECT", required: ["releaseNotes"], properties: { releaseNotes: { type: "STRING" } } }
  : { type: "OBJECT", required: ["shortDescription", "fullDescription", "releaseNotes"], properties: {
      shortDescription: { type: "STRING" }, fullDescription: { type: "STRING" }, releaseNotes: { type: "STRING" } } };

async function gemini(text) {
  for (let a = 1; a <= 5; a++) {
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, {
      method: "POST", headers: { "Content-Type": "application/json", "x-goog-api-key": KEY },
      body: JSON.stringify({ contents: [{ role: "user", parts: [{ text }] }],
        generationConfig: { temperature: 0.3, responseMimeType: "application/json", responseSchema: schema } }),
    });
    const t = await res.text();
    if (res.ok) return JSON.parse(JSON.parse(t).candidates[0].content.parts.map((p) => p.text).join(""));
    if (a === 5 || ![429, 500, 503].includes(res.status)) throw new Error(`Gemini ${res.status}: ${t.slice(0, 300)}`);
    await new Promise((r) => setTimeout(r, 5000 * a));
  }
}

const write = (code, l) => writeFileSync(new URL(`${code}.json`, OUT),
  JSON.stringify({ language: code, title: BRAND, shortDescription: l.shortDescription, fullDescription: l.fullDescription, releaseNotes: l.releaseNotes }, null, 2) + "\n");

async function localise(code) {
  const file = new URL(`${code}.json`, OUT);
  if (!FORCE && !NOTES_ONLY && existsSync(file)) return `${code}: kept`;
  const kept = NOTES_ONLY && existsSync(file) ? JSON.parse(readFileSync(file, "utf8")) : null;
  let result, issues;
  for (let attempt = 1; attempt <= 4; attempt++) {
    result = await gemini(prompt(LANGUAGES[code], issues));
    if (kept) result = { ...kept, releaseNotes: result.releaseNotes };
    issues = check(result);
    if (!issues.length) break;
  }
  if (issues.length) return `${code}: ✗ ${issues.join("; ")}`;
  write(code, result);
  return `${code}: ✓ ${NOTES_ONLY ? result.releaseNotes.split("\n")[0] : result.shortDescription}`;
}

// The English the current translations were made from. Changed-only mode diffs against it.
const SOURCE = new URL(".source-en-US.json", OUT);
const saveSource = () => writeFileSync(SOURCE, JSON.stringify(en, null, 2) + "\n");

async function geminiLines(language, lines, context) {
  const body = { contents: [{ role: "user", parts: [{ text: `You localise a Google Play listing into ${language}. Translate ONLY the numbered English lines below, each into one line, keeping "${BRAND}" and "hYYa" unchanged, the same tone (calm, plain), and any leading "•" bullet. Follow the same rules as the existing translation; never name iPhone, iPad, iOS or Mac; say "device", never "phone" or "tablet".
Full English listing, for context only:
${context}

Lines to translate (JSON array, same order):
${JSON.stringify(lines)}` }] }],
    generationConfig: { temperature: 0.2, responseMimeType: "application/json",
      responseSchema: { type: "OBJECT", required: ["lines"], properties: { lines: { type: "ARRAY", items: { type: "STRING" } } } } } };
  for (let a = 1; a <= 5; a++) {
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`, {
      method: "POST", headers: { "Content-Type": "application/json", "x-goog-api-key": KEY }, body: JSON.stringify(body) });
    const t = await res.text();
    if (res.ok) return JSON.parse(JSON.parse(t).candidates[0].content.parts.map((p) => p.text).join("")).lines;
    if (a === 5 || ![429, 500, 503].includes(res.status)) throw new Error(`Gemini ${res.status}: ${t.slice(0, 300)}`);
    await new Promise((r) => setTimeout(r, 5000 * a));
  }
}

// Default (no --force, no --notes-only, no language list): translate only what changed in English since
// the last run, line by line, and splice it into each language's existing text.
if (!FORCE && !NOTES_ONLY && !argv.length && existsSync(SOURCE)) {
  const old = JSON.parse(readFileSync(SOURCE, "utf8"));
  const fields = ["shortDescription", "fullDescription", "releaseNotes"];
  const plan = {};
  for (const f of fields) {
    const a = old[f].split("\n"), b = en[f].split("\n");
    if (a.join("\n") === b.join("\n")) continue;
    plan[f] = a.length === b.length ? b.map((l, i) => (l !== a[i] ? i : -1)).filter((i) => i >= 0) : null; // null: structure changed
  }
  if (!Object.keys(plan).length) { console.log("English unchanged since the last translation: nothing to translate."); process.exit(0); }
  // TEST_LANGS=de-DE,ja-JP limits a trial run to a few languages; it then saves nothing but those files.
  const codes = process.env.TEST_LANGS ? process.env.TEST_LANGS.split(",") : Object.keys(LANGUAGES);
  const lineCount = Object.values(plan).reduce((n, v) => n + (v ? v.length : 999), 0);
  console.log(`Changed: ${Object.entries(plan).map(([f, v]) => `${f} (${v ? v.length + " line(s)" : "structure changed"})`).join(", ")}; ${codes.length} languages.`);
  if (Object.values(plan).some((v) => v === null) && !APPROVED_FULL) {
    console.error("A field changed its line structure, so it needs a full re-translation of that field in every language. Ask the owner first, then re-run with --approved-full."); process.exit(1);
  }
  const queue2 = [...codes]; let done = 0, fails = [];
  await Promise.all(Array.from({ length: 6 }, async () => {
    while (queue2.length) {
      const code = queue2.shift();
      const file = new URL(`${code}.json`, OUT);
      if (!existsSync(file)) { fails.push(`${code}: no existing translation`); continue; }
      const cur = JSON.parse(readFileSync(file, "utf8"));
      try {
        for (const [f, idx] of Object.entries(plan)) {
          const mine = cur[f].split("\n");
          if (!idx || mine.length !== en[f].split("\n").length) { fails.push(`${code} ${f}: line structure differs, needs a full field translation`); continue; }
          const tr = await geminiLines(LANGUAGES[code], idx.map((i) => en[f].split("\n")[i]), en[f]);
          if (tr.length !== idx.length) throw new Error(`${f}: got ${tr.length} lines for ${idx.length}`);
          idx.forEach((i, k) => { mine[i] = tr[k]; });
          cur[f] = mine.join("\n");
        }
        const issues = check(cur);
        if (issues.length) { fails.push(`${code}: ${issues.join("; ")}`); continue; }
        write(code, cur); done++;
      } catch (e) { fails.push(`${code}: ${e.message}`); }
    }
  }));
  for (const [code, from] of Object.entries(process.env.TEST_LANGS ? {} : COPIES)) {
    if (from === "en-US") { write(code, en); continue; }
    const src = new URL(`${from}.json`, OUT); if (existsSync(src)) write(code, JSON.parse(readFileSync(src, "utf8")));
  }
  console.log(`Changed lines translated in ${done} languages; ${fails.length} need attention${fails.length ? ":\n  " + fails.join("\n  ") : "."}`);
  if (!fails.length && !process.env.TEST_LANGS) saveSource();
  process.exit(fails.length ? 1 : 0);
}

const wanted = argv.length ? argv.filter((c) => LANGUAGES[c]) : Object.keys(LANGUAGES);
const queue = [...wanted];
await Promise.all(Array.from({ length: 6 }, async () => {
  while (queue.length) {
    const code = queue.shift();
    try { console.log(await localise(code)); } catch (e) { console.log(`${code}: ✗ ${e.message}`); }
  }
}));

// Copies, once their source exists.
for (const [code, from] of Object.entries(COPIES)) {
  if (argv.length && !argv.includes(code) && !argv.includes(from)) continue;
  if (from === "en-US") { write(code, en); console.log(`${code}: = en-US`); continue; }
  const src = new URL(`${from}.json`, OUT);
  if (!existsSync(src)) { console.log(`${code}: ✗ waiting for ${from}`); continue; }
  write(code, JSON.parse(readFileSync(src, "utf8")));
  console.log(`${code}: = ${from}`);
}

// Remember the English these translations were made from, for the next changed-only run.
if (FORCE || !existsSync(SOURCE)) saveSource();
