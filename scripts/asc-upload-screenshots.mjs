#!/usr/bin/env node
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Brings the en-US screenshots of the editable version in line with store/slides/, uploading only
// the slides that changed (checksum and order). --dry-run plans only; over 20 uploads needs
// --approved-uploads N (the owner's yes first).
// 🚨 Uploading screenshots is not a review submission, and this script never submits.
//
//   ASC_ISSUER_ID=… ASC_KEY_ID=… ASC_PRIVATE_KEY_PATH=… node scripts/asc-upload-screenshots.mjs [iphone|ipad]

import { readFileSync, readdirSync, statSync } from "node:fs";
import { createHash, createSign } from "node:crypto";
import { join } from "node:path";

const APP_ID = "6824033636";
// IOS (default) or MAC_OS: which platform's editable version to fill.
const PLATFORM = process.env.PLATFORM ?? "IOS";
const SETS = (process.env.PLATFORM ?? "IOS") === "MAC_OS" ? {
  mac: { dir: "store/slides/mac", type: "APP_DESKTOP" },
} : {
  iphone: { dir: "store/slides/iphone-6.9", type: "APP_IPHONE_67" },
  ipad: { dir: "store/slides/ipad-13", type: "APP_IPAD_PRO_3GEN_129" },
  // iPhone Duo: one set for both screens (1398×2034 folded, 2007×2853 open). The value isn't in
  // Apple's published API reference yet; uploads to it were confirmed working by other tools.
  duo: { dir: "store/slides/duo", type: "APP_IPHONE_DUO" },
};
// ONE size per device class (Marketing standing rule, 2026-11-25): iPhone 6.9", iPad 13", iPhone Duo, Mac.
// Apple scales these for smaller screens, and every image submitted stays in Apple's library forever, so never
// add 6.5"/6.3"/6.1"/5.5" or smaller iPad sets, and use the same sizes for custom product pages.
const ALLOWED = new Set(["APP_IPHONE_67", "APP_IPAD_PRO_3GEN_129", "APP_IPHONE_DUO", "APP_DESKTOP"]);
for (const s of Object.values(SETS)) if (!ALLOWED.has(s.type)) throw new Error(`${s.type}: one size per device class only (standing rule)`);
const only = process.argv.slice(2).find((a, i, all) => !a.startsWith("--") && all[i - 1] !== "--approved-uploads");
const DRY = process.argv.includes("--dry-run");
const { ASC_ISSUER_ID, ASC_KEY_ID, ASC_PRIVATE_KEY_PATH } = process.env;
const key = readFileSync(ASC_PRIVATE_KEY_PATH, "utf8");

const token = () => {
  const b = (o) => Buffer.from(JSON.stringify(o)).toString("base64url");
  const n = Math.floor(Date.now() / 1000);
  const h = b({ alg: "ES256", kid: ASC_KEY_ID, typ: "JWT" });
  const p = b({ iss: ASC_ISSUER_ID, iat: n, exp: n + 900, aud: "appstoreconnect-v1" });
  return `${h}.${p}.${createSign("SHA256").update(`${h}.${p}`).sign({ key, dsaEncoding: "ieee-p1363" }).toString("base64url")}`;
};
async function api(path, method = "GET", body) {
  const r = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    method, headers: { Authorization: `Bearer ${token()}`, "Content-Type": "application/json" },
    body: body ? JSON.stringify(body) : undefined,
  });
  const t = await r.text();
  if (!r.ok) throw new Error(`${method} ${path} → ${r.status}\n${t}`);
  return t ? JSON.parse(t) : null;
}

// A dry run may also read a version in review (read only), to show what an upload would change.
const states = "PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED" + (DRY ? ",WAITING_FOR_REVIEW,IN_REVIEW" : "");
const versions = await api(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=${PLATFORM}&filter[appStoreState]=${states}`);
const version = versions.data[0];
if (!version) { console.log(`No editable ${PLATFORM} version. Nothing was changed.`); process.exit(0); }
const locs = await api(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`);
const loc = locs.data.find((l) => l.attributes.locale === "en-US");

// Plan first (Marketing standing rule, 2026-11-25): compare each set with what App Store Connect holds,
// by MD5 checksum and order, keep the matching prefix, and replace only from the first difference.
const plans = [];
for (const [name, set] of Object.entries(SETS)) {
  if (only && only !== name) continue;
  let files;
  try { files = readdirSync(set.dir).filter((f) => f.endsWith(".png")).sort(); } catch { console.log(`skip ${name}: no ${set.dir}`); continue; }
  if (!files.length) { console.log(`skip ${name}: empty`); continue; }
  const local = files.map((f) => ({ f, path: join(set.dir, f), md5: createHash("md5").update(readFileSync(join(set.dir, f))).digest("hex") }));
  const sets = await api(`/v1/appStoreVersionLocalizations/${loc.id}/appScreenshotSets?limit=50`);
  const target = sets.data.find((s) => s.attributes.screenshotDisplayType === set.type);
  const held = target ? (await api(`/v1/appScreenshotSets/${target.id}/appScreenshots?limit=50`)).data : [];
  let keep = 0;
  while (keep < held.length && keep < local.length && held[keep].attributes.sourceFileChecksum === local[keep].md5) keep++;
  plans.push({ name, set, target, keep, del: held.slice(keep), up: local.slice(keep), total: local.length });
  console.log(`  ${name}: ${keep} kept, ${local.length - keep} to upload${held.length - keep ? `, ${held.length - keep} to replace` : ""}`);
}
const planned = plans.reduce((n, p) => n + p.up.length, 0);
if (planned > 20) {
  const i = process.argv.indexOf("--approved-uploads");
  if (i < 0 || Number(process.argv[i + 1]) !== planned) {
    console.error(`${planned} screenshot uploads planned (over 20). Ask the owner first, then re-run with --approved-uploads ${planned}. Nothing was changed.`);
    process.exit(1);
  }
}
if (DRY) { console.log(`Dry run: ${planned} upload(s) planned. Nothing was changed.`); process.exit(0); }

for (const p of plans) {
  if (!p.up.length && !p.del.length) { console.log(`= ${p.name}: unchanged (${p.total} slides)`); continue; }
  let target = p.target;
  if (!target) target = (await api("/v1/appScreenshotSets", "POST", { data: { type: "appScreenshotSets",
      attributes: { screenshotDisplayType: p.set.type },
      relationships: { appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: loc.id } } } } })).data;
  for (const s of p.del) await api(`/v1/appScreenshots/${s.id}`, "DELETE");
  for (const { f, path, md5 } of p.up) {
    const bytes = readFileSync(path);
    const reserved = (await api("/v1/appScreenshots", "POST", { data: { type: "appScreenshots",
      attributes: { fileName: f, fileSize: statSync(path).size },
      relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: target.id } } } } })).data;
    for (const op of reserved.attributes.uploadOperations) {
      const chunk = bytes.subarray(op.offset, op.offset + op.length);
      const headers = Object.fromEntries(op.requestHeaders.map((h) => [h.name, h.value]));
      const r = await fetch(op.url, { method: op.method, headers, body: chunk });
      if (!r.ok) throw new Error(`upload ${f} → ${r.status}`);
    }
    await api(`/v1/appScreenshots/${reserved.id}`, "PATCH", { data: { type: "appScreenshots", id: reserved.id,
      attributes: { uploaded: true, sourceFileChecksum: md5 } } });
    console.log(`  ${p.name}: ${f}`);
  }
  console.log(`✓ ${p.name}: ${p.up.length} uploaded, ${p.keep} kept → ${p.set.type}`);
}
console.log("Nothing was submitted.");
