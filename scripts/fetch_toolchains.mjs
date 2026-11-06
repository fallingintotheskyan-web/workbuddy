// Downloads the toolchain archives required to build the Flutter client.
// Everything lands under .toolchains/downloads so no admin rights are needed.
// Usage: node scripts/fetch_toolchains.mjs
import { createWriteStream } from 'node:fs';
import { mkdir, stat, rename, writeFile, rm } from 'node:fs/promises';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import path from 'node:path';

const PROJECT = process.cwd();
const DL = path.join(PROJECT, '.toolchains', 'downloads');
await mkdir(DL, { recursive: true });

const HEADERS = { 'user-agent': 'classroom-notes-setup/1.0' };

async function getJson(url) {
  const res = await fetch(url, { headers: HEADERS, redirect: 'follow' });
  if (!res.ok) throw new Error(`GET ${url} -> HTTP ${res.status}`);
  return res.json();
}

async function getText(url) {
  const res = await fetch(url, { headers: HEADERS, redirect: 'follow' });
  if (!res.ok) throw new Error(`GET ${url} -> HTTP ${res.status}`);
  return res.text();
}

async function download(url, dest, label) {
  try {
    const s = await stat(dest);
    if (s.size > 5 * 1024 * 1024) {
      console.log(`[skip] ${label} already present (${(s.size / 1048576).toFixed(1)} MB)`);
      return dest;
    }
  } catch {
    // not downloaded yet
  }
  for (let attempt = 1; attempt <= 3; attempt++) {
    const tmp = `${dest}.part`;
    try {
      const res = await fetch(url, { headers: HEADERS, redirect: 'follow' });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      if (!res.body) throw new Error('empty body');
      const total = Number(res.headers.get('content-length') || 0);
      let got = 0;
      let last = 0;
      const body = Readable.fromWeb(res.body);
      body.on('data', (chunk) => {
        got += chunk.length;
        const now = Date.now();
        if (now - last > 3000) {
          last = now;
          const totalTxt = total ? `/${(total / 1048576).toFixed(1)}` : '';
          console.log(`[dl] ${label} ${(got / 1048576).toFixed(1)}${totalTxt} MB`);
        }
      });
      await pipeline(body, createWriteStream(tmp));
      if (got < 1024 * 1024) throw new Error(`file too small: ${got} bytes`);
      await rename(tmp, dest);
      console.log(`[ok] ${label} ${(got / 1048576).toFixed(1)} MB`);
      return dest;
    } catch (err) {
      console.log(`[retry ${attempt}/3] ${label}: ${err.message}`);
      await rm(`${dest}.part`, { force: true });
      if (attempt === 3) throw err;
      await new Promise((r) => setTimeout(r, 3000 * attempt));
    }
  }
}

// 1. Flutter stable
const releases = await getJson(
  'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json',
);
const stableHash = releases.current_release.stable;
const release = releases.releases.find((r) => r.hash === stableHash);
if (!release) throw new Error('could not resolve the current stable Flutter release');
await download(
  `${releases.base_url}/${release.archive}`,
  path.join(DL, `flutter-${release.version}-stable.zip`),
  `Flutter ${release.version}`,
);
await writeFile(path.join(DL, 'flutter-version.txt'), `${release.version}\n`);
console.log(`[info] Flutter stable = ${release.version} (${release.archive})`);

// 2. Temurin JDK 17 (zip, no installer, no admin)
await download(
  'https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse?project=jdk',
  path.join(DL, 'jdk17-win-x64.zip'),
  'Temurin JDK 17',
);

// 3. Android command-line tools (resolve the current win archive from the repo XML)
const repoXml = await getText('https://dl.google.com/android/repository/repository2-3.xml');
const names = [...repoXml.matchAll(/commandlinetools-win-(\d+)_latest\.zip/g)].map((m) => m[0]);
if (names.length === 0) throw new Error('commandlinetools-win archive not found in repository2-3.xml');
const cmdTools = [...new Set(names)].sort((a, b) => {
  const na = Number(a.match(/(\d+)_latest/)[1]);
  const nb = Number(b.match(/(\d+)_latest/)[1]);
  return na - nb;
}).at(-1);
await download(
  `https://dl.google.com/android/repository/${cmdTools}`,
  path.join(DL, cmdTools),
  `Android cmdline-tools (${cmdTools})`,
);
await writeFile(path.join(DL, 'cmdline-tools-name.txt'), `${cmdTools}\n`);

// 4. MinGit (portable git; Flutter uses it for version detection)
try {
  const gitRelease = await getJson('https://api.github.com/repos/git-for-windows/git/releases/latest');
  const asset = gitRelease.assets.find((a) => /^MinGit-.*-64-bit\.zip$/.test(a.name));
  if (asset) {
    await download(asset.browser_download_url, path.join(DL, asset.name), asset.name);
  } else {
    console.log('[warn] MinGit asset not found in latest git-for-windows release; skipping git');
  }
} catch (err) {
  console.log(`[warn] MinGit download skipped: ${err.message}`);
}

console.log('[done] toolchain downloads finished');
