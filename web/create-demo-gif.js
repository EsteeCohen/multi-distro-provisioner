#!/usr/bin/env node
// create-demo-gif.js — captures browser screenshots and encodes them as an
// animated GIF for the README.
//
// Run:  node web/create-demo-gif.js
// Deps: npm install playwright sharp gif-encoder-2  (already done)

const { chromium } = require('playwright');
const GIFEncoder   = require('gif-encoder-2');
const sharp        = require('sharp');
const http         = require('http');
const fs           = require('fs');
const path         = require('path');

const OUT_DIR    = path.join(__dirname, '..', 'screenshots');
const GIF_W      = 1280;
const GIF_H      = 800;
const FRAME_DELAY = 3200;   // ms each frame is shown

const FRAMES = [
  {
    url:   'http://localhost:8080/dashboard.html',
    wait:  4500,   // wait for JS health-check fetch to resolve
    label: 'dashboard — both VMs',
    file:  'dashboard.png',
  },
  {
    url:   'http://localhost:8080',
    wait:  2500,
    label: 'ubuntu-node status page',
    file:  'ubuntu-node.png',
  },
  {
    url:   'http://localhost:8081',
    wait:  2500,
    label: 'fedora-node status page',
    file:  'fedora-node.png',
  },
];

// ---- helpers ----

function checkVM(port) {
  return new Promise((ok, fail) => {
    http.get(`http://localhost:${port}/health`, r => {
      r.statusCode === 200 ? ok() : fail(new Error(`HTTP ${r.statusCode}`));
    }).on('error', e => fail(e));
  });
}

async function captureScreenshots(browser) {
  if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR);
  const page = await browser.newPage();
  await page.setViewportSize({ width: 1440, height: 900 });

  for (const f of FRAMES) {
    process.stdout.write(`  [screenshot] ${f.label}... `);
    await page.goto(f.url, { waitUntil: 'networkidle' });
    await page.waitForTimeout(f.wait);
    await page.screenshot({ path: path.join(OUT_DIR, f.file), fullPage: false });
    console.log('saved');
  }
  await page.close();
}

async function buildGif() {
  const gifPath = path.join(OUT_DIR, 'demo.gif');

  // gif-encoder-2: 'neuquant' algorithm, optimizer on, totalFrames supplied
  const enc = new GIFEncoder(GIF_W, GIF_H, 'neuquant', true, FRAMES.length);
  enc.setDelay(FRAME_DELAY);
  enc.setRepeat(0);   // loop forever
  enc.setQuality(10); // 1 = best quality / slowest, 20 = fastest / worst

  const chunks = [];
  enc.createReadStream().on('data', d => chunks.push(d));

  enc.start();

  for (const f of FRAMES) {
    process.stdout.write(`  [encode]     ${f.label}... `);
    const src = path.join(OUT_DIR, f.file);

    // sharp: resize to GIF dimensions, output raw RGBA
    const raw = await sharp(src)
      .resize(GIF_W, GIF_H, { fit: 'cover', position: 'top' })
      .ensureAlpha()
      .raw()
      .toBuffer();

    // gif-encoder-2 accepts Buffer of RGBA bytes directly
    enc.addFrame(raw);
    console.log('encoded');
  }

  enc.finish();

  // flush remaining data and write file
  const gifBuf = Buffer.concat(chunks);
  fs.writeFileSync(gifPath, gifBuf);
  return gifPath;
}

// ---- main ----

(async () => {
  console.log('\nmulti-distro-provisioner — README GIF capture\n');

  // 0. verify VMs are up
  for (const port of [8080, 8081]) {
    await checkVM(port).catch(e => {
      console.error(`\nVM on port ${port} not reachable (${e.message})`);
      console.error('Run:  make up  and  make provision-all\n');
      process.exit(1);
    });
  }
  console.log('both VMs reachable\n');

  const browser = await chromium.launch();
  try {
    console.log('step 1/2 — screenshots');
    await captureScreenshots(browser);

    console.log('\nstep 2/2 — GIF');
    const gifPath = await buildGif();

    const kb = Math.round(fs.statSync(gifPath).size / 1024);
    console.log(`\ndone  screenshots/demo.gif  (${kb} KB)`);
    console.log('      screenshots/dashboard.png');
    console.log('      screenshots/ubuntu-node.png');
    console.log('      screenshots/fedora-node.png\n');
  } finally {
    await browser.close();
  }
})().catch(e => {
  console.error('error:', e.message);
  process.exit(1);
});