// Downloads MinGit (portable git) only. Flutter refuses to start without a git
// binary because it reads its own version from the SDK's .git directory.
// GitHub's API is rate-limited/blocked here, so the npmmirror binary mirror is
// tried first and GitHub is used as a fallback.
// Usage: node scripts/fetch_git.mjs
import { createWriteStream } from 'node:fs';
import { mkdir, stat, rename, rm } from 'node:fs/promises';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import path from 'node:path';

const DL = path.join(process.cwd(), '.toolchains', 'downloads');
await mkdir(DL, { recursive: true });

const MIRROR = 'https://registry.npmmirror.com/-/binary/git-for-windows/v2.56.0.windows.4/MinGit-2.56.0.4-64-bit.zip';

async function githubAsset() {
  const res = await fetch('https://api.github.com/repos/git-for-windows/git/releases/latest', {
    headers: { 'user-agent': 'classroom-notes-setup/1.0' },
  });
  if (!res.ok) throw new Error(`GitHub API -> ${res.status}`);
  const release = await res.json();
  const asset = release.assets.find((a) => /^MinGit-.*-64-bit\.zip$/.test(a.name));
  if (!asset) throw new Error('MinGit asset not found');
  return { name: asset.name, url: asset.browser_download_url, size: asset.size };
}

let source;
try {
  const head = await fetch(MIRROR, { method: 'HEAD', redirect: 'follow' });
  if (!head.ok) throw new Error(`mirror -> ${head.status}`);
  source = { name: path.basename(MIRROR), url: MIRROR, size: Number(head.headers.get('content-length') || 0) };
} catch (err) {
  console.log(`[warn] mirror unavailable (${err.message}); falling back to GitHub`);
  source = await githubAsset();
}
console.log(`[info] ${source.name} (${(source.size / 1048576).toFixed(1)} MB)`);

const dest = path.join(DL, source.name);
try {
  const s = await stat(dest);
  if (s.size > 5 * 1024 * 1024) {
    console.log('[skip] already downloaded');
    process.exit(0);
  }
} catch {}

const dl = await fetch(source.url, { redirect: 'follow' });
if (!dl.ok) throw new Error(`download -> ${dl.status}`);
let got = 0;
const body = Readable.fromWeb(dl.body);
body.on('data', (c) => {
  got += c.length;
  if (got % (5 * 1048576) < c.length) console.log(`[dl] ${(got / 1048576).toFixed(1)} MB`);
});
await pipeline(body, createWriteStream(`${dest}.part`));
if (got < 1024 * 1024) throw new Error('download too small');
await rm(dest, { force: true });
await rename(`${dest}.part`, dest);
console.log(`[ok] ${source.name} ${(got / 1048576).toFixed(1)} MB`);
