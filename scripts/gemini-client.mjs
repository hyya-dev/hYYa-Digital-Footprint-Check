// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// One Gemini client for the store-translation scripts (Marketing, 2026-11-25):
// - thinking is OFF in every call (thinkingBudget 0). Hidden "thinking" tokens bill as output: measured
//   2026-11-25 on gemini-3.7-flash, one line cost 389 thinking + 12 output tokens by default, 0 + 12 with it off,
//   same translation.
// - every call's tokens are counted (input, output, thinking) and each run's totals are printed and logged.
// - full-language runs go through the Batch API (half the price); single calls stay direct.
import { appendFileSync, existsSync, readFileSync, mkdirSync } from "node:fs";

const BASE = "https://generativelanguage.googleapis.com/v1beta";
const ROOT = decodeURIComponent(new URL("..", import.meta.url).pathname);
const envFile = `${ROOT}.env`;
export const KEY = process.env.GEMINI_API_KEY || (existsSync(envFile) ? (readFileSync(envFile, "utf8").split("\n")
  .find((l) => l.startsWith("GEMINI_API_KEY=")) ?? "").slice(15).trim() : "");

export const usage = { calls: 0, input: 0, output: 0, thinking: 0, batch: 0 };
const count = (u, batch = false) => {
  usage.calls++; if (batch) usage.batch++;
  usage.input += u?.promptTokenCount ?? 0;
  usage.output += u?.candidatesTokenCount ?? 0;
  usage.thinking += u?.thoughtsTokenCount ?? 0;
};

/** The request body for one prompt: thinking off, JSON out against [schema]. */
export const body = (text, schema, temperature = 0.3) => ({
  contents: [{ role: "user", parts: [{ text }] }],
  generationConfig: { temperature, responseMimeType: "application/json", responseSchema: schema,
    thinkingConfig: { thinkingBudget: 0 } },
});

const parse = (response) => JSON.parse(response.candidates[0].content.parts.map((p) => p.text).join(""));

/** One direct call, retried on 429/500/503. Returns the parsed JSON. */
export async function generate(model, text, schema, temperature) {
  for (let a = 1; a <= 5; a++) {
    const res = await fetch(`${BASE}/models/${model}:generateContent`, {
      method: "POST", headers: { "Content-Type": "application/json", "x-goog-api-key": KEY },
      body: JSON.stringify(body(text, schema, temperature)) });
    const t = await res.text();
    if (res.ok) { const j = JSON.parse(t); count(j.usageMetadata); return parse(j); }
    if (a === 5 || ![429, 500, 503].includes(res.status)) throw new Error(`Gemini ${res.status}: ${t.slice(0, 300)}`);
    await new Promise((r) => setTimeout(r, 5000 * a));
  }
}

/**
 * Many prompts at half price through the Batch API. [items] are { key, text, schema, temperature }.
 * Returns { key: parsed JSON | Error }. Polls until the job ends (usually minutes; Google allows up to 24 h).
 */
export async function batch(model, items, { name = "store-translation", every = 20000, log = console.log } = {}) {
  const requests = items.map((it) => ({ request: body(it.text, it.schema, it.temperature), metadata: { key: it.key } }));
  const res = await fetch(`${BASE}/models/${model}:batchGenerateContent`, {
    method: "POST", headers: { "Content-Type": "application/json", "x-goog-api-key": KEY },
    body: JSON.stringify({ batch: { display_name: name, input_config: { requests: { requests } } } }) });
  const t = await res.text();
  if (!res.ok) throw new Error(`Gemini batch ${res.status}: ${t.slice(0, 300)}`);
  const op = JSON.parse(t);
  const id = op.name;
  log(`  batch ${id}: ${items.length} requests submitted`);
  for (;;) {
    await new Promise((r) => setTimeout(r, every));
    const s = await (await fetch(`${BASE}/${id}`, { headers: { "x-goog-api-key": KEY } })).json();
    const state = s.metadata?.state ?? s.state;
    if (!s.done && !/SUCCEEDED|FAILED|CANCELLED|EXPIRED/.test(String(state))) continue;
    if (!/SUCCEEDED/.test(String(state)) && !s.response) throw new Error(`batch ${id} ended: ${state}`);
    const out = s.response?.inlinedResponses?.inlinedResponses ?? s.metadata?.output?.inlinedResponses?.inlinedResponses ?? [];
    const result = {};
    for (const r of out) {
      const key = r.metadata?.key;
      if (r.error || !r.response) { result[key] = new Error(JSON.stringify(r.error ?? "no response").slice(0, 200)); continue; }
      count(r.response.usageMetadata, true);
      try { result[key] = parse(r.response); } catch (e) { result[key] = e; }
    }
    return result;
  }
}

/** Prints this run's token totals and appends them to the private run log (internal/translation-runs.csv). */
export function report(script, what) {
  const line = `${new Date().toISOString()},${script},${what},${usage.calls},${usage.batch},${usage.input},${usage.output},${usage.thinking}`;
  console.log(`Tokens this run: ${usage.calls} call(s) (${usage.batch} batched), input ${usage.input}, output ${usage.output}, thinking ${usage.thinking}.`);
  const dir = `${ROOT}internal`;
  if (existsSync(dir)) {
    const file = `${dir}/translation-runs.csv`;
    if (!existsSync(file)) appendFileSync(file, "time,script,what,calls,batched,input,output,thinking\n");
    appendFileSync(file, line + "\n");
  }
}
