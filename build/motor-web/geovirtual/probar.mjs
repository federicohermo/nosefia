// Abre la página de prueba, mide cuadros y guarda una captura.
// Uso: node probar.mjs <url> [captura.png]
import { chromium } from 'playwright';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [url, png] = process.argv.slice(2);
const perfil = mkdtempSync(join(tmpdir(), 'vg-'));
const ctx = await chromium.launchPersistentContext(perfil, {
  channel: 'chrome', headless: false, viewport: { width: 1536, height: 760 },
  args: ['--mute-audio', '--disable-features=CalculateNativeWinOcclusion', '--disable-gpu-vsync', '--disable-frame-rate-limit'],
});
const pag = ctx.pages()[0];
const log = [];
pag.on('console', (m) => { if (/error|warn/i.test(m.type())) log.push(m.text().slice(0, 200)); });
pag.on('pageerror', (e) => log.push('PAGEERROR ' + e.message.slice(0, 200)));
await pag.goto(url);
const ok = await pag.waitForFunction(() => window.__listo === true, null, { timeout: 240000 }).then(() => true).catch(() => false);
if (ok) {
  await pag.waitForTimeout(1500);
  const medida = await pag.evaluate(() => window.__medir(4000));
  const info = await pag.evaluate(() => window.__info());
  if (png) await pag.screenshot({ path: png });
  console.log(JSON.stringify({ medida, info, log: log.slice(0, 5) }));
} else console.log(JSON.stringify({ listo: false, log: log.slice(0, 6) }));
await ctx.close();
try { rmSync(perfil, { recursive: true, force: true }); } catch {}
