#!/usr/bin/env node
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// Submits the editable App Store version of one platform for App Review. 🚨 This is the irreversible step:
// run it with --apply ONLY on the owner's explicit consent, after asc-audit-version.mjs passed. Without
// --apply it checks the gates and changes nothing. Gates (any failure aborts before anything is created):
//   • the version is editable and its build is attached, processed (VALID) and the newest uploaded build;
//   • no other open review submission of this platform holds an app version (Apple allows one alongside
//     a submission of other items, such as a product page test).
//
//   ASC_ISSUER_ID=… ASC_KEY_ID=… ASC_PRIVATE_KEY_PATH=… PLATFORM=IOS node scripts/asc-submit-for-review.mjs [--apply]
import { readFileSync } from "node:fs";
import { createSign } from "node:crypto";

const APP_ID = "6824033636";
const PLATFORM = process.env.PLATFORM ?? "IOS";
const APPLY = process.argv.includes("--apply");
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
  if (!r.ok) throw new Error(`${method} ${path} → ${r.status}\n${t.slice(0, 800)}`);
  return t ? JSON.parse(t) : null;
}
const die = (m) => { console.error(`ABORTED: ${m}`); process.exit(1); };

const editable = ["PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"];
const versions = await api(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=${PLATFORM}&include=build&limit=10`);
const v = versions.data.find((x) => editable.includes(x.attributes.appStoreState));
if (!v) die(`no editable ${PLATFORM} version`);
const buildId = v.relationships.build.data?.id;
if (!buildId) die("no build attached");
const build = versions.included.find((i) => i.id === buildId);
if (build.attributes.processingState !== "VALID") die(`build ${build.attributes.version} is ${build.attributes.processingState}`);
const pv = await api(`/v1/builds?filter[app]=${APP_ID}&filter[preReleaseVersion.platform]=${PLATFORM}&sort=-uploadedDate&limit=1`);
if (pv.data[0]?.id !== buildId) die(`build ${build.attributes.version} is not the newest uploaded build (${pv.data[0]?.attributes.version})`);
const open = await api(`/v1/reviewSubmissions?filter[app]=${APP_ID}&filter[platform]=${PLATFORM}&filter[state]=READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES`);
// Apple allows one submission holding an app version, plus one holding only other items (product page tests,
// custom pages, events). Abort only if an open submission already holds an app version, or is an unsent draft.
for (const s of open.data) {
  const items = (await api(`/v1/reviewSubmissions/${s.id}/items?include=appStoreVersion&limit=50`)).data;
  const hasVersion = items.some((i) => i.relationships?.appStoreVersion?.data);
  if (hasVersion || s.attributes.state === "READY_FOR_REVIEW")
    die(`a ${PLATFORM} review submission is already open (${s.id}, ${s.attributes.state}${hasVersion ? ", holds an app version" : ", unsent draft"})`);
  console.log(`• open ${PLATFORM} submission ${s.id} (${s.attributes.state}) holds no app version (${items.length} other item(s)): allowed alongside`);
}
console.log(`✓ ${PLATFORM} ${v.attributes.versionString} (${v.attributes.appStoreState}) with build ${build.attributes.version} (VALID, newest)`);
if (!APPLY) { console.log("Gates pass. Nothing was submitted (run with --apply on the owner's consent)."); process.exit(0); }

const sub = await api("/v1/reviewSubmissions", "POST", { data: { type: "reviewSubmissions", attributes: { platform: PLATFORM },
  relationships: { app: { data: { type: "apps", id: APP_ID } } } } });
await api("/v1/reviewSubmissionItems", "POST", { data: { type: "reviewSubmissionItems",
  relationships: { reviewSubmission: { data: { type: "reviewSubmissions", id: sub.data.id } },
    appStoreVersion: { data: { type: "appStoreVersions", id: v.id } } } } });
const done = await api(`/v1/reviewSubmissions/${sub.data.id}`, "PATCH", { data: { type: "reviewSubmissions", id: sub.data.id,
  attributes: { submitted: true } } });
console.log(`📤 Submitted for App Review: ${PLATFORM} ${v.attributes.versionString} (${build.attributes.version}), submission ${sub.data.id}, state ${done.data.attributes.state}`);
