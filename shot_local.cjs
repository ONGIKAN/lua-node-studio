const path = require('path');
const puppeteer = require('puppeteer-core');

const EDGE = 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const SITE = 'file:///C:/Users/35378/Documents/deepseek-harness/default-workspace/lua-node-studio-website/index.html';
const OUT = 'C:/Users/35378/Documents/deepseek-harness/default-workspace/site_deploy';

(async () => {
  const browser = await puppeteer.launch({
    executablePath: EDGE,
    headless: 'new',
    args: ['--no-sandbox', '--disable-crash-reporter'],
  });
  const errors = [];
  const page = await browser.newPage();
  page.on('console', (m) => { if (m.type() === 'error') errors.push('console: ' + m.text()); });
  page.on('pageerror', (e) => errors.push('pageerror: ' + e.message));
  page.on('requestfailed', (r) => errors.push('requestfailed: ' + r.url()));
  await page.setViewport({ width: 1440, height: 950, deviceScaleFactor: 1 });
  await page.goto(SITE, { waitUntil: 'networkidle0' });

  // Scroll through so IntersectionObserver reveals every .reveal block.
  // scroll-behavior:smooth in style.css would swallow fast programmatic scrolling, so disable it first.
  await page.evaluate(async () => {
    document.documentElement.style.scrollBehavior = 'auto';
    const h = document.documentElement.scrollHeight;
    for (let y = 0; y < h; y += 400) {
      window.scrollTo(0, y);
      await new Promise((r) => setTimeout(r, 80));
    }
    window.scrollTo(0, 0);
    await new Promise((r) => setTimeout(r, 200));
  });
  await new Promise((r) => setTimeout(r, 600));
  // Force any reveal the observer missed, so the full-page shot never has blank sections.
  await page.evaluate(() => {
    document.querySelectorAll('.reveal:not(.in)').forEach((el) => {
      el.style.transition = 'none';
      el.classList.add('in');
    });
  });
  await new Promise((r) => setTimeout(r, 300));

  const revealed = await page.evaluate(() => ({
    total: document.querySelectorAll('.reveal').length,
    revealed: document.querySelectorAll('.reveal.in').length,
  }));
  const hasOldVersion = await page.evaluate(() => /v?1\.6/.test(document.body.innerText));
  await page.screenshot({ path: path.join(OUT, 'local_preview_zh.png'), fullPage: true });

  const zh = await page.evaluate(() => ({
    lang: document.documentElement.lang,
    title: document.title,
    heroBadge: document.querySelector('[data-i18n="heroBadge"]').textContent.trim(),
    scrLead: document.querySelector('[data-i18n="scrLead"]').textContent.trim(),
    dlLead: document.querySelector('[data-i18n="dlLead"]').textContent.trim(),
    dlAndroidMeta: document.querySelector('[data-i18n="dlAndroidMeta"]').textContent.trim(),
    dlAndroidTiny: document.querySelector('[data-i18n="dlAndroidTiny"]').textContent.trim(),
    dlWinMeta: document.querySelector('[data-i18n="dlWinMeta"]').textContent.trim(),
    latestLinks: [...document.querySelectorAll('a[href*="releases/latest"]')].map((a) => a.href),
    downloadBtns: [...document.querySelectorAll('#download .download a.btn')].map((a) => ({
      text: a.textContent.trim(),
      href: a.href,
    })),
    githubLinks: [...document.querySelectorAll('a[href="https://github.com/ONGIKAN/lua-node-studio"]')].length,
  }));

  await page.click('#langBtn');
  await new Promise((r) => setTimeout(r, 400));
  const en = await page.evaluate(() => ({
    lang: document.documentElement.lang,
    heroBadge: document.querySelector('[data-i18n="heroBadge"]').textContent.trim(),
    scrLead: document.querySelector('[data-i18n="scrLead"]').textContent.trim(),
    dlLead: document.querySelector('[data-i18n="dlLead"]').textContent.trim(),
    dlAndroidMeta: document.querySelector('[data-i18n="dlAndroidMeta"]').textContent.trim(),
    dlAndroidTiny: document.querySelector('[data-i18n="dlAndroidTiny"]').textContent.trim(),
    dlWinMeta: document.querySelector('[data-i18n="dlWinMeta"]').textContent.trim(),
    hasOldVersion: /v?1\.6/.test(document.body.innerText),
  }));
  await page.screenshot({ path: path.join(OUT, 'local_preview_en.png'), fullPage: true });

  console.log(JSON.stringify({ revealed, hasOldVersionInZh: hasOldVersion, zh, en, errors }, null, 2));
  await browser.close();
})();
