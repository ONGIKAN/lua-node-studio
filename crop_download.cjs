const path = require('path');
const puppeteer = require('puppeteer-core');

const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const LIVE = 'https://ongikan.github.io/lua-node-studio/';
const OUT = 'C:/Users/35378/Documents/deepseek-harness/default-workspace/site_deploy';

(async () => {
  const browser = await puppeteer.launch({
    executablePath: EDGE,
    headless: 'new',
    args: ['--no-sandbox', '--disable-crash-reporter'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: 1440, height: 1100, deviceScaleFactor: 1 });
  await page.goto(LIVE, { waitUntil: 'networkidle2', timeout: 60000 });
  await page.evaluate(async () => {
    document.documentElement.style.scrollBehavior = 'auto';
    document.querySelectorAll('.reveal').forEach((el) => el.classList.add('in'));
    await new Promise((r) => setTimeout(r, 300));
    document.querySelector('#download').scrollIntoView({ block: 'start' });
    await new Promise((r) => setTimeout(r, 400));
  });
  const el = await page.$('#download');
  await el.screenshot({ path: path.join(OUT, 'live_download_section.png') });
  const box = await el.boundingBox();
  console.log(JSON.stringify({ box }, null, 2));
  await browser.close();
})();
