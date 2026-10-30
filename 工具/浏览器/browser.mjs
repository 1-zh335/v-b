#!/usr/bin/env node
/**
 * browser.mjs - Edge(CDP) + Playwright-core driver for DSH/Trae agents.
 *
 * Prerequisite: Edge running with --remote-debugging-port (start it with start-edge.ps1).
 * Usage: node browser.mjs <action> [--options]
 *
 * Actions:
 *   status                 Browser version + pages overview
 *   list                   List pages (index/title/url)
 *   goto  --url URL        Navigate current page (or --new to open a new page)
 *   shot  --out PATH       Screenshot current page (--full for full page)
 *   text                   Print page innerText (--max chars)
 *   html                   Print page HTML (--selector optional)
 *   click --selector|--text  Click element
 *   type  --selector --text  Fill input
 *   eval  --js CODE        Evaluate JS, print JSON result
 *   close                  Close the CDP-connected browser instance
 *
 * Common options: --port 9222 --timeout 30000 --page N --wait load|domcontentloaded|networkidle --new --shot PATH
 */
import { chromium } from 'playwright-core';
import fs from 'node:fs';
import path from 'node:path';

const argv = process.argv.slice(2);
const action = (argv.shift() || 'status').toLowerCase();
const opts = {};
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (!a.startsWith('--')) continue;
  const eq = a.indexOf('=');
  if (eq > 0) { opts[a.slice(2, eq)] = a.slice(eq + 1); continue; }
  const key = a.slice(2);
  const next = argv[i + 1];
  if (next !== undefined && !next.startsWith('--')) { opts[key] = next; i++; }
  else opts[key] = true;
}

const port = Number(opts.port || 9222);
const cdp = `http://127.0.0.1:${port}`;
const timeout = Number(opts.timeout || 30000);
const pageIndex = Number(opts.page || 0);
const waitUntil = opts.wait || 'load';

const ok = (msg) => console.log('[OK] ' + msg);
const info = (msg) => console.log('[INFO] ' + msg);
const fail = (msg, err) => {
  console.error('[FAIL] ' + msg);
  if (err) console.error(String((err && err.stack) || err));
  process.exit(1);
};

async function connect() {
  try {
    return await chromium.connectOverCDP(cdp, { timeout: 15000 });
  } catch (e) {
    fail(`无法连接 ${cdp}，请先运行: powershell -NoProfile -ExecutionPolicy Bypass -File "工具\\浏览器\\start-edge.ps1"（或加 -Headless）`, e);
  }
}

function firstContext(browser) {
  const ctxs = browser.contexts();
  if (!ctxs.length) fail('CDP 已连接但没有浏览器上下文');
  return ctxs[0];
}

async function currentPage(browser) {
  const ctx = firstContext(browser);
  const pages = ctx.pages();
  if (!pages.length) return await ctx.newPage();
  return pages[Math.min(pageIndex, pages.length - 1)];
}

async function shotPage(page, out, full) {
  if (!out) fail('截图需要 --out <path>');
  fs.mkdirSync(path.dirname(path.resolve(out)), { recursive: true });
  await page.screenshot({ path: out, fullPage: !!full });
  const size = fs.statSync(out).size;
  ok(`截图: ${out} (${size} bytes)`);
}

async function describePages(browser) {
  const ctx = firstContext(browser);
  const pages = ctx.pages();
  info(`pages: ${pages.length}`);
  for (let i = 0; i < pages.length; i++) {
    const p = pages[i];
    let title = '';
    try { title = await p.title(); } catch { }
    console.log(`  [${i}] ${title || '(no title)'} | ${p.url()}`);
  }
}

async function run() {
  if (action === 'help' || opts.help) {
    console.log('actions: status|list|goto|shot|text|html|click|type|eval|close');
    return;
  }
  const browser = await connect();
  ok(`connected ${cdp} | browser ${browser.version()} | contexts ${browser.contexts().length}`);

  try {
    if (action === 'status') {
      await describePages(browser);
    } else if (action === 'list') {
      await describePages(browser);
    } else if (action === 'goto' || action === 'open') {
      if (!opts.url) fail('goto/open 需要 --url <URL>');
      let page;
      if (opts.new || action === 'open') {
        const ctx = firstContext(browser);
        page = await ctx.newPage();
        info('opened new page');
      } else {
        page = await currentPage(browser);
      }
      const resp = await page.goto(opts.url, { waitUntil, timeout });
      ok(`navigated: ${page.url()}`);
      ok(`title: ${await page.title()}`);
      if (resp) info(`http status: ${resp.status()}`);
      if (opts.shot) await shotPage(page, opts.shot, opts.full);
    } else if (action === 'shot') {
      const page = await currentPage(browser);
      await shotPage(page, opts.out, opts.full);
    } else if (action === 'text') {
      const page = await currentPage(browser);
      let text = await page.evaluate(() => (document.body ? document.body.innerText : ''));
      const max = Number(opts.max || 0);
      if (max > 0 && text.length > max) text = text.slice(0, max) + '\n...[truncated]';
      console.log(text);
      ok(`text length: ${text.length}`);
    } else if (action === 'html') {
      const page = await currentPage(browser);
      let html;
      if (opts.selector) {
        html = await page.locator(opts.selector).first().evaluate((el) => el.outerHTML);
      } else {
        html = await page.content();
      }
      const max = Number(opts.max || 4000);
      console.log(html.slice(0, max) + (html.length > max ? '\n...[truncated]' : ''));
      ok(`html length: ${html.length}`);
    } else if (action === 'click') {
      const page = await currentPage(browser);
      if (opts.text) {
        await page.getByText(opts.text, { exact: !!opts.exact }).first().click({ timeout });
        ok(`clicked text: ${opts.text}`);
      } else if (opts.selector) {
        await page.locator(opts.selector).first().click({ timeout });
        ok(`clicked selector: ${opts.selector}`);
      } else {
        fail('click 需要 --selector 或 --text');
      }
      if (opts.shot) await shotPage(page, opts.shot, opts.full);
    } else if (action === 'type') {
      const page = await currentPage(browser);
      if (!opts.selector) fail('type 需要 --selector 和 --text');
      await page.locator(opts.selector).first().fill(String(opts.text ?? ''), { timeout });
      ok(`filled ${opts.selector}`);
      if (opts.shot) await shotPage(page, opts.shot, opts.full);
    } else if (action === 'eval') {
      const page = await currentPage(browser);
      if (!opts.js) fail('eval 需要 --js <code>');
      const result = await page.evaluate(opts.js);
      console.log(JSON.stringify(result, null, 2));
      ok('eval done');
    } else if (action === 'close') {
      // For connectOverCDP, browser.close() only disconnects. Explicitly ask Edge to exit via CDP.
      try {
        const session = await browser.newBrowserCDPSession();
        await session.send('Browser.close');
        info('sent CDP Browser.close');
      } catch (e) {
        info('Browser.close failed, fallback to disconnect: ' + String((e && e.message) || e));
      }
      await browser.close().catch(() => { });
      ok(`close requested for CDP browser at ${cdp}`);
      return;
    } else {
      fail(`未知 action: ${action}（可用: status|list|goto|shot|text|html|click|type|eval|close）`);
    }
  } finally {
    if (action !== 'close') await browser.close().catch(() => { });
  }
}

run().catch((e) => fail('执行失败', e));
