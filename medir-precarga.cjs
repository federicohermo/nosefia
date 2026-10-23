const { chromium } = require('playwright');
const { writeFileSync, readFileSync } = require('node:fs');
const { createHash } = require('node:crypto');

async function main() {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const results = [];
  try {
    for (const side of process.argv.slice(2)) {
      const context = await browser.newContext({ viewport: { width: 1536, height: 760 } });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', error => errors.push(String(error)));
      page.on('console', message => {
        if (message.type() === 'error') errors.push(message.text());
      });
      await page.addInitScript(() => {
        window.readbacks = [];
        const original = WebGL2RenderingContext.prototype.readPixels;
        WebGL2RenderingContext.prototype.readPixels = function (...args) {
          const start = performance.now();
          const result = original.apply(this, args);
          window.readbacks.push({ width: args[2], height: args[3], ms: performance.now() - start });
          return result;
        };
      });
      const menu = page.waitForEvent('console', { predicate: m => m.text().includes('[carga] menú visible'), timeout: 180000 });
      const store = page.waitForEvent('console', { predicate: m => m.text().includes('[carga] almacén en pantalla'), timeout: 180000 });
      await page.goto(`http://localhost:8631/${side}/`, { timeout: 180000 });
      await menu;
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const canvas = await page.locator('canvas').boundingBox();
      const start = Date.now();
      await page.mouse.click(canvas.x + canvas.width / 2, canvas.y + canvas.height * 0.56);
      await store;
      const loadMs = Date.now() - start;
      const data = await page.evaluate(() => {
        const gl = document.createElement('canvas').getContext('webgl2');
        const info = gl.getExtension('WEBGL_debug_renderer_info');
        return { readbacks: window.readbacks, renderer: gl.getParameter(info.UNMASKED_RENDERER_WEBGL) };
      });
      if (errors.length) throw new Error(JSON.stringify(errors));
      if (/swiftshader|llvmpipe|software/i.test(data.renderer)) throw new Error(data.renderer);
      const pck = createHash('sha256').update(readFileSync(`export/${side}/index.pck`)).digest('hex');
      results.push({ side, pck, loadMs, ...data, errors });
      console.log(JSON.stringify(results.at(-1)));
      writeFileSync('reports/cami-631/precarga-web.json', JSON.stringify(results, null, 2));
      await context.close();
    }
  } finally {
    await browser.close();
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
