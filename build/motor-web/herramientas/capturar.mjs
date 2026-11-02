// Abre un visor, espera a que esté listo y guarda una captura de 1536x760.
// Uso: node capturar.mjs <url> <salida.png> [--firefox] [--ancho=1536] [--alto=760]
import { chromium, firefox } from 'playwright';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const [url, salida, ...op] = process.argv.slice(2);
const val = (n, d) => (op.find((o) => o.startsWith(`--${n}=`)) ?? `=${d}`).split('=')[1];
const ancho = Number(val('ancho', 1536)), alto = Number(val('alto', 760));
const perfil = mkdtempSync(join(tmpdir(), 'cap-'));
let ctx;
if (op.includes('--firefox')) {
  ctx = await firefox.launchPersistentContext(perfil, { headless: false, viewport: { width: ancho, height: alto }, firefoxUserPrefs: { 'media.volume_scale': '0.0', 'widget.windows.window_occlusion_tracking.enabled': false } });
} else {
  ctx = await chromium.launchPersistentContext(perfil, { channel: 'chrome', headless: false, viewport: { width: ancho, height: alto }, args: ['--mute-audio', '--disable-features=CalculateNativeWinOcclusion', '--disable-backgrounding-occluded-windows', '--disable-renderer-backgrounding'] });
}
const pag = ctx.pages()[0] ?? (await ctx.newPage());
const lineas = [];
pag.on('console', (m) => lineas.push(`[${m.type()}] ${m.text().slice(0, 300)}`));
pag.on('response', (r) => { if (r.status() >= 400) lineas.push('HTTP ' + r.status() + ' ' + r.url()); });
pag.on('pageerror', (e) => lineas.push(`PAGEERROR ${e.message.slice(0, 300)}`));
await pag.goto(url);
try { await pag.waitForFunction(() => window.__listo === true, null, { timeout: 180000 }); } catch { console.log('NO LLEGÓ A __listo'); }
await pag.waitForTimeout(1500);
await pag.screenshot({ path: salida });
console.log(lineas.filter((l) => !/Download the React|GPU stall/i.test(l)).slice(0, 12).join('\n'));
console.log(JSON.stringify(await pag.evaluate(() => ({ marca: window.__marca, info: window.__info?.() })).catch(() => null)));
await ctx.close();
try { rmSync(perfil, { recursive: true, force: true }); } catch {}
