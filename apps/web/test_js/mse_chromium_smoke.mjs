import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve('apps/web/web');
const temporary = mkdtempSync(join(tmpdir(), 'aegivue-browser-mse-'));
const makeRecording = (name, tone) => {
  const file = join(temporary, name);
  const result = spawnSync('ffmpeg', [
    '-y', '-hide_banner', '-loglevel', 'error', '-nostdin',
    '-f', 'lavfi', '-i', `color=c=${tone}:s=160x90:r=10:d=2`,
    '-an', '-c:v', 'libx264', '-profile:v', 'baseline', '-level:v', '3.0',
    '-pix_fmt', 'yuv420p', '-g', '10', '-keyint_min', '10', '-sc_threshold', '0',
    '-bf', '0', '-movflags', 'frag_keyframe+empty_moov+default_base_moof',
    '-f', 'mp4', file,
  ], { encoding: 'utf8', timeout: 30000 });
  if (result.status !== 0) throw new Error(`FFmpeg failed: ${result.stderr}`);
  return file;
};

let server;
let browser;
try {
  const first = makeRecording('first.mp4', 'black');
  const second = makeRecording('second.mp4', 'blue');
  const routes = new Map([
    ['/mse_continuity_harness.html', join(root, 'mse_continuity_harness.html')],
    ['/timeline_stream_player.js', join(root, 'timeline_stream_player.js')],
    ['/first.mp4', first],
    ['/second.mp4', second],
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
  browser = await chromium.launch({ channel: 'chrome', headless: true, args: ['--autoplay-policy=no-user-gesture-required'] });
  const page = await browser.newPage();
  page.on('pageerror', (e) => console.error('Browser error:', e));
  await page.goto(`http://127.0.0.1:${address.port}/mse_continuity_harness.html`);
  const supported = await page.evaluate(() => ({
    mse: typeof MediaSource !== 'undefined',
    h264: typeof MediaSource !== 'undefined' && MediaSource.isTypeSupported('video/mp4; codecs="avc1.42C01E"'),
    userAgent: navigator.userAgent,
  }));
  console.log('Browser codec capabilities:', supported);
  assert.equal(supported.h264, true, 'Google Chrome must support H.264 MSE');
  const result = await page.evaluate(async () => window.runMseContinuity({
    mimeType: 'video/mp4; codecs="avc1.42C01E"',
    fragments: [
      { url: '/first.mp4', timestampOffset: 0, appendWindowStart: 0, appendWindowEnd: 2 },
      { url: '/second.mp4', timestampOffset: 2, appendWindowStart: 2, appendWindowEnd: 4 },
    ],
    expectedBoundary: 2,
  }));
  assert.equal(result.passed, true);
  assert.equal(result.sourceBufferCount, 1);
  assert(result.finalTime > 2.25);
  console.log('Chromium MSE continuity smoke test passed:', result);
} finally {
  await browser?.close();
  await new Promise((done) => server ? server.close(done) : done());
  rmSync(temporary, { recursive: true, force: true });
}
