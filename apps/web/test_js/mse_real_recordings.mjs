import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { chromium } from 'playwright';

// Explicit opt-in: node apps/web/test_js/mse_real_recordings.mjs first.mp4 second.mp4
// AEGIVUE_MSE_MIME must be based on the actual H.264 decoder configuration.
const [firstInput, secondInput] = process.argv.slice(2);
const mimeType = process.env.AEGIVUE_MSE_MIME;
if (!firstInput || !secondInput || !mimeType) {
  throw new Error('Provide two real MP4 paths and AEGIVUE_MSE_MIME');
}
const work = mkdtempSync(join(tmpdir(), 'aegivue-real-mse-'));
const run = (bin, args) => {
  const r = spawnSync(bin, args, { encoding: 'utf8', timeout: 60000, maxBuffer: 8 * 1024 * 1024 });
  if (r.status !== 0) throw new Error(`${bin} failed: ${r.stderr}`);
  return r.stdout;
};
const probe = (file) => {
  const data = JSON.parse(run('ffprobe', ['-v', 'error', '-select_streams', 'v:0',
    '-show_streams', '-show_data_hash', 'sha256', '-of', 'json', file]));
  const s = data.streams?.[0];
  if (!s || s.codec_name !== 'h264' || !s.extradata_hash) {
    throw new Error('Only H.264 clips with known decoder configuration are supported');
  }
  return s;
};
const remux = (input, output) => {
  run('ffmpeg', ['-y', '-hide_banner', '-loglevel', 'error', '-nostdin',
    '-i', resolve(input), '-map', '0:v:0', '-an', '-c:v', 'copy',
    '-movflags', 'frag_keyframe+empty_moov+default_base_moof',
    '-f', 'mp4', output]);
};
const timing = (file) => {
  const { packets } = JSON.parse(run('ffprobe', ['-v', 'error', '-select_streams', 'v:0',
    '-show_packets', '-show_entries', 'packet=pts_time,duration_time,flags',
    '-of', 'json', file]));
  if (!packets?.length || !packets[0].flags?.includes('K')) {
    throw new Error('Fragment must start at a video keyframe');
  }
  const start = Math.min(...packets.map((p) => Number(p.pts_time)));
  const end = Math.max(...packets.map((p) => Number(p.pts_time) + Number(p.duration_time)));
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
    throw new Error('Invalid measured fragment presentation timestamps');
  }
  return { start, duration: end - start };
};
let browser;
let server;
try {
  const first = probe(firstInput);
  const second = probe(secondInput);
  for (const key of ['codec_name', 'profile', 'level', 'width', 'height',
    'pix_fmt', 'extradata_hash']) {
    assert.equal(first[key], second[key], `Incompatible video ${key}`);
  }
  const a = join(work, 'a.mp4');
  const b = join(work, 'b.mp4');
  remux(firstInput, a);
  remux(secondInput, b);
  const ta = timing(a);
  const tb = timing(b);
  const boundary = ta.duration;
  const root = resolve('apps/web/web');
  const routes = new Map([
    ['/mse_continuity_harness.html', join(root, 'mse_continuity_harness.html')],
    ['/timeline_stream_player.js', join(root, 'timeline_stream_player.js')],
    ['/a.mp4', a], ['/b.mp4', b],
  ]);
  server = createServer((req, res) => {
    const file = routes.get(req.url?.split('?')[0]);
    if (!file) { res.writeHead(404); res.end(); return; }
    res.setHeader('Content-Type', file.endsWith('.js') ? 'text/javascript'
      : file.endsWith('.html') ? 'text/html' : 'video/mp4');
    res.end(readFileSync(file));
  });
  await new Promise((done) => server.listen(0, '127.0.0.1', done));
  const address = server.address();
  assert(address && typeof address !== 'string');
  browser = await chromium.launch({ channel: 'chrome', headless: true,
    args: ['--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage();
  page.on('pageerror', (e) => console.error('Page error:', e));
  await page.goto(`http://127.0.0.1:${address.port}/mse_continuity_harness.html`);
  const supported = await page.evaluate((mime) => MediaSource.isTypeSupported(mime), mimeType);
  assert(supported, `Browser does not support ${mimeType}`);
  const result = await page.evaluate((args) => window.runMseContinuity(args), {
    mimeType, expectedBoundary: boundary,
    fragments: [
      { url: '/a.mp4', timestampOffset: -ta.start,
        appendWindowStart: 0, appendWindowEnd: boundary },
      { url: '/b.mp4', timestampOffset: boundary - tb.start,
        appendWindowStart: boundary, appendWindowEnd: boundary + tb.duration },
    ],
  });
  assert.equal(result.passed, true);
  assert.equal(result.sourceBufferCount, 1);
  console.log(JSON.stringify({ result, first: ta, second: tb }, null, 2));
} finally {
  await browser?.close();
  await new Promise((done) => server ? server.close(done) : done());
  rmSync(work, { recursive: true, force: true });
}
