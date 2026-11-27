#!/usr/bin/env node
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Sends ONE product page test to App Review, alone in its own review submission. Never starts the test (a separate
// owner yes) and never adds anything else. Without --apply it reads back and checks only.
// 🚨 --apply only on the owner's explicit consent for this exact test.
//
//   ASC_ISSUER_ID=… ASC_KEY_ID=… ASC_PRIVATE_KEY_PATH=… node scripts/asc-ppo-submit.mjs "<test name>" [--apply]
//   … node scripts/asc-ppo-submit.mjs "<test name>" --status     (review state and each version's state)

import { readFileSync } from "node:fs";
import { createSign } from "node:crypto";

const APP_ID = "6824033636";
const NAME = process.argv[2];
const APPLY = process.argv.includes("--apply");
const STATUS = process.argv.includes("--status");
if (!NAME) { console.error("Name the test."); process.exit(1); }
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

const test = (await api(`/v1/apps/${APP_ID}/appStoreVersionExperimentsV2?limit=50`)).data.find((t) => t.attributes.name === NAME);
if (!test) { console.error(`No test named "${NAME}". Nothing was changed.`); process.exit(1); }
const a = test.attributes;
console.log(`Test "${a.name}" (${test.id}): state ${a.state}, ${a.platform}, traffic ${a.trafficProportion}%, start ${a.startDate ?? "not started"}`);
const treatments = (await api(`/v2/appStoreVersionExperiments/${test.id}/appStoreVersionExperimentTreatments?limit=10`)).data;
for (const tr of treatments) {
  const locs = (await api(`/v1/appStoreVersionExperimentTreatments/${tr.id}/appStoreVersionExperimentTreatmentLocalizations`)).data;
  for (const l of locs) {
    const sets = (await api(`/v1/appStoreVersionExperimentTreatmentLocalizations/${l.id}/appScreenshotSets?limit=50`)).data;
    const line = [];
    for (const s of sets) {
      const shots = (await api(`/v1/appScreenshotSets/${s.id}/appScreenshots?limit=50`)).data;
      const bad = shots.filter((x) => x.attributes.assetDeliveryState?.state !== "COMPLETE").length;
      line.push(`${s.attributes.screenshotDisplayType} ${shots.length}${bad ? ` (${bad} not processed)` : ""} first=${shots[0]?.attributes.fileName}`);
    }
    console.log(`  ${tr.attributes.name} [${l.attributes.locale}]: ${line.join("; ")}`);
  }
}
const open = (await api(`/v1/reviewSubmissions?filter[app]=${APP_ID}&filter[platform]=IOS&filter[state]=READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES&include=items&limit=20`));
for (const s of open.data) console.log(`Open review submission ${s.id}: ${s.attributes.state}, submitted ${s.attributes.submittedDate ?? "-"}`);
if (STATUS) process.exit(0);

if (a.state !== "PREPARE_FOR_SUBMISSION") { console.error(`The test is ${a.state}, not ready to send. Nothing was changed.`); process.exit(1); }
if (open.data.some((s) => s.attributes.state !== "READY_FOR_REVIEW")) {
  console.error("Something else is already with App Review; this test goes alone. Nothing was changed."); process.exit(1);
}
if (!APPLY) { console.log("Checks pass. Nothing was submitted (run with --apply on the owner's consent)."); process.exit(0); }

// Reuse an unsent draft only if it is empty; otherwise a fresh one, so nothing else rides along.
let sub = null;
for (const s of open.data.filter((s) => s.attributes.state === "READY_FOR_REVIEW")) {
  const items = (await api(`/v1/reviewSubmissions/${s.id}/items`)).data;
  if (!items.length) { sub = s; break; }
  console.error(`Draft review submission ${s.id} already holds ${items.length} item(s). Nothing was changed.`); process.exit(1);
}
if (!sub) sub = (await api("/v1/reviewSubmissions", "POST", { data: { type: "reviewSubmissions", attributes: { platform: "IOS" },
  relationships: { app: { data: { type: "apps", id: APP_ID } } } } })).data;
await api("/v1/reviewSubmissionItems", "POST", { data: { type: "reviewSubmissionItems",
  relationships: { reviewSubmission: { data: { type: "reviewSubmissions", id: sub.id } },
    appStoreVersionExperimentV2: { data: { type: "appStoreVersionExperiments", id: test.id } } } } });
const done = await api(`/v1/reviewSubmissions/${sub.id}`, "PATCH", { data: { type: "reviewSubmissions", id: sub.id,
  attributes: { submitted: true } } });
console.log(`Submitted ${sub.id}: ${done.data.attributes.state} at ${done.data.attributes.submittedDate}. The test is NOT started.`);
