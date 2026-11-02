// Cuenta las llamadas a linkProgram de WebGL2 hasta que el visor avisa que está listo.
// Uso: node contar_programas.mjs <url>
import { chromium } from 'playwright';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const [url] = process.argv.slice(2);
const perfil = mkdtempSync(join(tmpdir(), 'cp-'));
const ctx = await chromium.launchPersistentContext(perfil, { channel: 'chrome', headless: false, viewport: { width: 1536, height: 760 }, args: ['--mute-audio', '--disable-features=CalculateNativeWinOcclusion'] });
const pag = ctx.pages()[0] ?? (await ctx.newPage());
await pag.addInitScript(() => {
  window.__enlaces = 0; window.__fuentes = new Set();
  const f = WebGL2RenderingContext.prototype.linkProgram;
  WebGL2RenderingContext.prototype.linkProgram = function (p) { window.__enlaces += 1; return f.call(this, p); };
  const s = WebGL2RenderingContext.prototype.shaderSource;
  WebGL2RenderingContext.prototype.shaderSource = function (sh, src) { window.__fuentes.add(src); return s.call(this, sh, src); };
});
await pag.goto(url);
await pag.waitForFunction(() => window.__listo === true, null, { timeout: 120000 });
await pag.waitForTimeout(1500);
console.log(JSON.stringify(await pag.evaluate(() => ({ enlaces: window.__enlaces, fuentes_distintas: window.__fuentes.size }))));
await ctx.close();
try { rmSync(perfil, { recursive: true, force: true }); } catch {}
