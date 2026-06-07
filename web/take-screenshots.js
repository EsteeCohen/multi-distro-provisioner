#!/usr/bin/env node
// take-screenshots.js -- captures README screenshots while both VMs are running.
//
// Requirements (run once):
//   npm install playwright
//   npx playwright install chromium
//
// Run:
//   node web/take-screenshots.js

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const OUT_DIR = path.join(__dirname, '..', 'screenshots');
if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR);

async function shot(page, url, filename, waitMs = 3500) {
  console.log(`  -> ${url}`);
  await page.goto(url, { waitUntil: 'networkidle' });
  await page.waitForTimeout(waitMs);
  const file = path.join(OUT_DIR, filename);
  await page.screenshot({ path: file, fullPage: true });
  console.log(`     saved: screenshots/${filename}`);
}

(async () => {
  const browser = await chromium.launch();
  const page    = await browser.newPage();

  // Wide viewport -- matches a typical laptop screen
  await page.setViewportSize({ width: 1440, height: 900 });

  console.log('\ntaking screenshots (both VMs must be running)...\n');

  // 1. main comparison dashboard -- wait longer for health-check JS to fire
  await shot(page, 'http://localhost:8080/dashboard.html', 'dashboard.png', 4000);

  // 2. ubuntu-node individual status page
  await shot(page, 'http://localhost:8080', 'ubuntu-node.png', 2000);

  // 3. fedora-node individual status page
  await shot(page, 'http://localhost:8081', 'fedora-node.png', 2000);

  await browser.close();
  console.log('\ndone. files in screenshots/\n');
})().catch(err => {
  console.error('error:', err.message);
  console.error('make sure both VMs are running: make up');
  process.exit(1);
});