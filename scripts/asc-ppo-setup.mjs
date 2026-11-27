#!/usr/bin/env node
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Sets up the App Store product page test (Product Page Optimization) for slide 1, WITHOUT starting it and
// WITHOUT sending anything for review: the test, versions A and B, their en-US localization, and a full screenshot
// set per device class of the default page that tests support (iPhone 6.9", iPad 13", iPhone Duo; tests are iOS
// only). Slide 1 comes from store/slides/ppo/<A|B>/<device>/, slides 2-7 are the default page's own.
// Re-runnable: finds the test and versions by name. App Store Connect starts each new version as a copy of today's
// page, so held screenshots are reused by checksum: only slide 1 is uploaded, extras removed, then the order set.
// --dry-run plans only. Over 20 uploads needs --approved-uploads N (the owner's yes first).
// 🚨 Never starts the test and never submits: both need the owner's explicit consent.
//
//   ASC_ISSUER_ID=… ASC_KEY_ID=… ASC_PRIVATE_KEY_PATH=… node scripts/asc-ppo-setup.mjs [--dry-run]

import { readFileSync, readdirSync, statSync } from "node:fs";
import { createHash, createSign } from "node:crypto";
import { join } from "node:path";

const APP_ID = "6824033636";
const TEST_NAME = "Slide 1: what apps know vs score rise";
const TRAFFIC = 66;   // % of visitors shown a version; split evenly, so A 33%, B 33%, today's page 34%
const VERSIONS = [{ key: "A", name: "A: What do your apps know" }, { key: "B", name: "B: Watch your score go up" }];
const DEVICES = [
  { dir: "iphone-6.9", type: "APP_IPHONE_67" },
  { dir: "ipad-13", type: "APP_IPAD_PRO_3GEN_129" },
  { dir: "duo", type: "APP_IPHONE_DUO" },
];
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
const md5 = (p) => createHash("md5").update(readFileSync(p)).digest("hex");

// The slides each version should hold, per device: its own slide 1, then the default page's 2-7.
function slidesFor(v, d) {
  const own = readdirSync(`store/slides/ppo/${v}/${d.dir}`).filter((f) => f.endsWith(".png")).sort()
    .map((f) => join(`store/slides/ppo/${v}/${d.dir}`, f));
  const rest = readdirSync(`store/slides/${d.dir}`).filter((f) => /^0[2-9].*\.png$/.test(f)).sort()
    .map((f) => join(`store/slides/${d.dir}`, f));
  if (own.length !== 1 || rest.length !== 6) throw new Error(`${v}/${d.dir}: expected 1 + 6 slides, found ${own.length} + ${rest.length}`);
  return [...own, ...rest].map((path) => ({ path, f: `${v}-${path.split("/").pop()}`, md5: md5(path) }));
}

// 1. The test.
const tests = (await api(`/v1/apps/${APP_ID}/appStoreVersionExperimentsV2?limit=50`)).data;
let test = tests.find((t) => t.attributes.name === TEST_NAME);
if (test && !["PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"].includes(test.attributes.state)) {
  console.error(`The test is ${test.attributes.state}: it can no longer be changed here. Nothing was changed.`);
  process.exit(1);
}
console.log(test ? `= test "${TEST_NAME}" (${test.attributes.state})` : `+ test "${TEST_NAME}", ${TRAFFIC}% of visitors`);

// 2. Plan the versions and their sets.
const plans = [];
let treatments = test ? (await api(`/v2/appStoreVersionExperiments/${test.id}/appStoreVersionExperimentTreatments?limit=10`)).data : [];
for (const v of VERSIONS) {
  const tr = treatments.find((t) => t.attributes.name === v.name);
  const loc = tr ? (await api(`/v1/appStoreVersionExperimentTreatments/${tr.id}/appStoreVersionExperimentTreatmentLocalizations`)).data
    .find((l) => l.attributes.locale === "en-US") : null;
  const sets = loc ? (await api(`/v1/appStoreVersionExperimentTreatmentLocalizations/${loc.id}/appScreenshotSets?limit=50`)).data : [];
  for (const d of DEVICES) {
    const local = slidesFor(v.key, d);
    const target = sets.find((s) => s.attributes.screenshotDisplayType === d.type);
    // A new version starts as a copy of today's page (App Store Connect copies every set), so that is what it holds.
    const held = target ? (await api(`/v1/appScreenshotSets/${target.id}/appScreenshots?limit=50`)).data.map((x) => x.attributes.sourceFileChecksum)
      : loc ? [] : readdirSync(`store/slides/${d.dir}`).filter((f) => f.endsWith(".png")).sort().map((f) => md5(join(`store/slides/${d.dir}`, f)));
    const up = local.filter((x) => !held.includes(x.md5));
    const extra = held.filter((m) => !local.some((x) => x.md5 === m)).length;
    plans.push({ v, d, up });
    console.log(`  ${v.key} ${d.dir}: ${local.length - up.length} reused, ${up.length} to upload${extra ? `, ${extra} to remove` : ""}`);
  }
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

// 3. Create what's missing, then upload.
if (!test) test = (await api("/v2/appStoreVersionExperiments", "POST", { data: { type: "appStoreVersionExperiments",
  attributes: { name: TEST_NAME, platform: "IOS", trafficProportion: TRAFFIC },
  relationships: { app: { data: { type: "apps", id: APP_ID } } } } })).data;
for (const v of VERSIONS) {
  let tr = treatments.find((t) => t.attributes.name === v.name);
  if (!tr) {
    tr = (await api("/v1/appStoreVersionExperimentTreatments", "POST", { data: { type: "appStoreVersionExperimentTreatments",
      attributes: { name: v.name },
      relationships: { appStoreVersionExperimentV2: { data: { type: "appStoreVersionExperiments", id: test.id } } } } })).data;
    console.log(`+ version ${v.name}`);
  }
  let loc = (await api(`/v1/appStoreVersionExperimentTreatments/${tr.id}/appStoreVersionExperimentTreatmentLocalizations`)).data
    .find((l) => l.attributes.locale === "en-US");
  if (!loc) loc = (await api("/v1/appStoreVersionExperimentTreatmentLocalizations", "POST", { data: {
    type: "appStoreVersionExperimentTreatmentLocalizations", attributes: { locale: "en-US" },
    relationships: { appStoreVersionExperimentTreatment: { data: { type: "appStoreVersionExperimentTreatments", id: tr.id } } } } })).data;
  const sets = (await api(`/v1/appStoreVersionExperimentTreatmentLocalizations/${loc.id}/appScreenshotSets?limit=50`)).data;
  for (const p of plans.filter((p) => p.v.key === v.key)) {
    const local = slidesFor(v.key, p.d);
    let target = sets.find((s) => s.attributes.screenshotDisplayType === p.d.type);
    if (!target) target = (await api("/v1/appScreenshotSets", "POST", { data: { type: "appScreenshotSets",
      attributes: { screenshotDisplayType: p.d.type },
      relationships: { appStoreVersionExperimentTreatmentLocalization: { data: { type: "appStoreVersionExperimentTreatmentLocalizations", id: loc.id } } } } })).data;
    // Reuse every held screenshot whose checksum matches a wanted slide; remove the rest first (a set holds 10 at most).
    const held = (await api(`/v1/appScreenshotSets/${target.id}/appScreenshots?limit=50`)).data;
    const ids = new Array(local.length).fill(null), used = new Set();
    local.forEach((x, i) => { const h = held.find((h) => !used.has(h.id) && h.attributes.sourceFileChecksum === x.md5); if (h) { ids[i] = h.id; used.add(h.id); } });
    const gone = held.filter((h) => !used.has(h.id));
    for (const h of gone) await api(`/v1/appScreenshots/${h.id}`, "DELETE");
    let n = 0;
    for (const [i, { f, path, md5: sum }] of local.entries()) {
      if (ids[i]) continue;
      const bytes = readFileSync(path);
      const reserved = (await api("/v1/appScreenshots", "POST", { data: { type: "appScreenshots",
        attributes: { fileName: f, fileSize: statSync(path).size },
        relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: target.id } } } } })).data;
      for (const op of reserved.attributes.uploadOperations) {
        const headers = Object.fromEntries(op.requestHeaders.map((h) => [h.name, h.value]));
        const r = await fetch(op.url, { method: op.method, headers, body: bytes.subarray(op.offset, op.offset + op.length) });
        if (!r.ok) throw new Error(`upload ${f} → ${r.status}`);
      }
      await api(`/v1/appScreenshots/${reserved.id}`, "PATCH", { data: { type: "appScreenshots", id: reserved.id,
        attributes: { uploaded: true, sourceFileChecksum: sum } } });
      ids[i] = reserved.id; n++;
    }
    await api(`/v1/appScreenshotSets/${target.id}/relationships/appScreenshots`, "PATCH",
      { data: ids.map((id) => ({ type: "appScreenshots", id })) });
    console.log(`✓ ${v.key} ${p.d.dir}: ${n} uploaded, ${local.length - n} reused, ${gone.length} removed, order set → ${p.d.type}`);
  }
}
console.log("The test is set up and NOT started; nothing was submitted for review.");
