// Downloads a specific (known-good) Android command-line tools archive.
// The latest 16xxxxxx build ships an experimental "Android CLI" that fails to
// install SDK packages on this machine, so we pin 13114758 instead.
// Usage: node scripts/fetch_cmdline_tools.mjs
import { createWriteStream } from 'node:fs';
import { mkdir, stat, rename, rm } from 'node:fs/promises';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import path from 'node:path';

const VERSION = '13114758';
const URL = `https://dl.google.com/android/repository/commandlinetools-win-${VERSION}_latest.zip`;
const DL = path.join(process.cwd(), '.toolchains', 'downloads');
await mkdir(DL, { recursive: true });

const dest = path.join(DL, `commandlinetools-win-${VERSION}_latest.zip`);
try {
  const s = await stat(dest);
  if (s.size > 5 * 1024 * 1024) {
    console.log(`[skip] already downloaded (${(s.size / 1048576).toFixed(1)} MB)`);
    process.exit(0);
  }
} catch {}

const res = await fetch(URL, { redirect: 'follow' });
if (!res.ok) throw new Error(`${URL} -> ${res.status}`);
let got = 0;
const body = Readable.fromWeb(res.body);
body.on('data', (c) => {
  got += c.length;
  if (got % (20 * 1048576) < c.length) console.log(`[dl] ${(got / 1048576).toFixed(1)} MB`);
});
await pipeline(body, createWriteStream(`${dest}.part`));
if (got < 1024 * 1024) throw new Error('download too small');
await rm(dest, { force: true });
await rename(`${dest}.part`, dest);
console.log(`[ok] ${path.basename(dest)} ${(got / 1048576).toFixed(1)} MB`);
