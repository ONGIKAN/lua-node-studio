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
  const errors = [];
  const badResponses = [];
  const page = await browser.newPage();
  page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  page.on('requestfailed', (r) => errors.push('requestfailed: ' + r.url() + ' :: ' + (r.failure() && r.failure().errorText)));
  page.on('response', (r) => { if (r.status() >= 400) badResponses.push(r.status() + ' ' + r.url()); });
  await page.setViewport({ width: 1440, height: 950, deviceScaleFactor: 1 });

  const resp = await page.goto(LIVE, { waitUntil: 'networkidle2', timeout: 60000 });
  await new Promise((r) => setTimeout(r, 2500));

  await page.evaluate(async () => {
    document.documentElement.style.scrollBehavior = 'auto';
    const h = document.documentElement.scrollHeight;
    for (let y = 0; y < h; y += 400) {
      window.scrollTo(0, y);
      await new Promise((r) => setTimeout(r, 60));
    }
    window.scrollTo(0, 0);
  });
  await page.evaluate(() => {
    document.querySelectorAll('.reveal:not(.in)').forEach((el) => { el.style.transition = 'none'; el.classList.add('in'); });
  });
  await new Promise((r) => setTimeout(r, 500));
  await page.screenshot({ path: path.join(OUT, 'live_pages_full.png'), fullPage: true });

  const zh = await page.evaluate(() => ({
    url: location.href,
    title: document.title,
    lang: document.documentElement.lang,
    heroBadge: document.querySelector('[data-i18n="heroBadge"]').textContent.trim(),
    dlLead: document.querySelector('[data-i18n="dlLead"]').textContent.trim(),
    dlAndroidMeta: document.querySelector('[data-i18n="dlAndroidMeta"]').textContent.trim(),
    dlWinMeta: document.querySelector('[data-i18n="dlWinMeta"]').textContent.trim(),
    latestLinks: [...document.querySelectorAll('a[href*="releases/latest"]')].map((a) => a.href),
    oldVersionInText: /v?1\.6/.test(document.body.innerText),
    assets: [...document.images].map((i) => ({ src: i.src, w: i.naturalWidth, h: i.naturalHeight, complete: i.complete })),
    revealTotal: document.querySelectorAll('.reveal').length,
    revealIn: document.querySelectorAll('.reveal.in').length,
  }));

  await page.click('#langBtn');
  await new Promise((r) => setTimeout(r, 400));
  const en = await page.evaluate(() => ({
    lang: document.documentElement.lang,
    heroBadge: document.querySelector('[data-i18n="heroBadge"]').textContent.trim(),
    dlLead: document.querySelector('[data-i18n="dlLead"]').textContent.trim(),
    oldVersionInText: /v?1\.6/.test(document.body.innerText),
  }));

  console.log(JSON.stringify({ httpStatus: resp && resp.status(), zh, en, errors, badResponses }, null, 2));
  await browser.close();
})();
