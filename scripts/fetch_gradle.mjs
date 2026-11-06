// Pre-seeds the Gradle wrapper distribution cache because services.gradle.org
// redirects to GitHub assets, which time out on this network.
// The repository keeps the official distributionUrl; only GRADLE_USER_HOME is
// populated here. Run scripts/install_gradle.ps1 afterwards to unzip.
// Usage: node scripts/fetch_gradle.mjs
import { createHash } from 'node:crypto';
import { createWriteStream } from 'node:fs';
import { mkdir, stat, rename, rm } from 'node:fs/promises';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import path from 'node:path';

const DIST_URL = 'https://services.gradle.org/distributions/gradle-9.3.1-all.zip';
const MIRROR = 'https://mirrors.cloud.tencent.com/gradle/gradle-9.3.1-all.zip';
const VERSION = 'gradle-9.3.1';

const hash = BigInt(`0x${createHash('md5').update(DIST_URL).digest('hex')}`).toString(36);
const distDir = path.join(process.cwd(), '.toolchains', 'gradle', 'wrapper', 'dists', 'gradle-9.3.1-all', hash);
await mkdir(distDir, { recursive: true });

const dest = path.join(distDir, 'gradle-9.3.1-all.zip');
try {
  const s = await stat(dest);
  if (s.size > 100 * 1024 * 1024) {
    console.log(`[skip] gradle zip already present (${(s.size / 1048576).toFixed(0)} MB)`);
    console.log(`[dist] ${distDir}`);
    process.exit(0);
  }
} catch {}

const res = await fetch(MIRROR, { redirect: 'follow' });
if (!res.ok) throw new Error(`${MIRROR} -> ${res.status}`);
let got = 0;
const body = Readable.fromWeb(res.body);
body.on('data', (c) => {
  got += c.length;
  if (got % (40 * 1048576) < c.length) console.log(`[dl] ${(got / 1048576).toFixed(0)} MB`);
});
await pipeline(body, createWriteStream(`${dest}.part`));
if (got < 100 * 1024 * 1024) throw new Error('download too small');
await rm(dest, { force: true });
await rename(`${dest}.part`, dest);
console.log(`[ok] ${VERSION}-all ${(got / 1048576).toFixed(0)} MB -> ${distDir}`);
