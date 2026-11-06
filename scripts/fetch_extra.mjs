// Fetches the remaining toolchains: Temurin 17 from the Microsoft CDN (fast in
// this network) with Adoptium as fallback, plus Android command-line tools.
// Usage: node scripts/fetch_extra.mjs
import { createWriteStream } from 'node:fs';
import { mkdir, stat, rename, rm } from 'node:fs/promises';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import path from 'node:path';

const DL = path.join(process.cwd(), '.toolchains', 'downloads');
await mkdir(DL, { recursive: true });
const HEADERS = { 'user-agent': 'classroom-notes-setup/1.0' };

async function download(url, dest, label) {
  try {
    const s = await stat(dest);
    if (s.size > 5 * 1024 * 1024) {
      console.log(`[skip] ${label} (${(s.size / 1048576).toFixed(1)} MB)`);
      return;
    }
  } catch {}
  const res = await fetch(url, { headers: HEADERS, redirect: 'follow' });
  if (!res.ok) throw new Error(`${label} -> HTTP ${res.status}`);
  const total = Number(res.headers.get('content-length') || 0);
  let got = 0;
  let last = 0;
  const body = Readable.fromWeb(res.body);
  body.on('data', (c) => {
    got += c.length;
    const now = Date.now();
    if (now - last > 3000) {
      last = now;
      console.log(`[dl] ${label} ${(got / 1048576).toFixed(1)}${total ? '/' + (total / 1048576).toFixed(0) : ''} MB`);
    }
  });
  await pipeline(body, createWriteStream(`${dest}.part`));
  if (got < 1024 * 1024) throw new Error(`${label} too small`);
  await rm(dest, { force: true });
  await rename(`${dest}.part`, dest);
  console.log(`[ok] ${label} ${(got / 1048576).toFixed(1)} MB`);
}

const jdkDest = path.join(DL, 'jdk17-win-x64.zip');
const jdkUrls = [
  'https://aka.ms/download-jdk/microsoft-jdk-17-windows-x64.zip',
  'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk',
];

async function fetchJdk() {
  let lastErr;
  for (const url of jdkUrls) {
    try {
      const head = await fetch(url, { method: 'HEAD', redirect: 'follow', headers: HEADERS });
      if (!head.ok) throw new Error(`HEAD ${head.status}`);
      await download(url, jdkDest, `JDK 17 (${new URL(url).host})`);
      return;
    } catch (err) {
      lastErr = err;
      console.log(`[warn] ${new URL(url).host}: ${err.message}`);
    }
  }
  throw lastErr;
}

async function fetchCmdTools() {
  const xml = await (await fetch('https://dl.google.com/android/repository/repository2-3.xml')).text();
  const names = [...xml.matchAll(/commandlinetools-win-(\d+)_latest\.zip/g)].map((m) => m[0]);
  if (names.length === 0) throw new Error('cmdline-tools archive not found');
  const latest = [...new Set(names)].sort((a, b) => {
    return Number(a.match(/(\d+)_latest/)[1]) - Number(b.match(/(\d+)_latest/)[1]);
  }).at(-1);
  await download(`https://dl.google.com/android/repository/${latest}`, path.join(DL, latest), latest);
}

const results = await Promise.allSettled([fetchJdk(), fetchCmdTools()]);
for (const r of results) {
  if (r.status === 'rejected') console.log(`[error] ${r.reason?.message ?? r.reason}`);
}
if (results.some((r) => r.status === 'rejected')) process.exitCode = 1;
console.log('[done] extra downloads finished');
