// Mide un visor de prueba (Three.js o PlayCanvas) como el arnés mide la web de Godot.
// Uso: node medir_visor.mjs <url-sin-vista> <salida.json> <puerto-del-servidor>
//        [--etiqueta=x] [--sin-limite] [--firefox] [--cpu=N] [--segundos=6] [--vistas=a,b]
// El visor tiene que ofrecer: window.__listo, window.__marca.almacen (ms desde la navegación),
// window.__vista(nombre), y el servidor, /__reset y /__bytes.
import { chromium, firefox } from 'playwright';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';

const [url, salida, puerto, ...op] = process.argv.slice(2);
const opt = (n) => op.find((o) => o === `--${n}` || o.startsWith(`--${n}=`));
const val = (n, d) => { const o = opt(n); return o && o.includes('=') ? o.split('=')[1] : d; };
const etiqueta = val('etiqueta', 'visor');
const sinLimite = !!opt('sin-limite');
const esFirefox = !!opt('firefox');
const cpu = Number(val('cpu', 1));
const segundos = Number(val('segundos', 6));
const vistas = val('vistas', 'gondola,pasillo,mostrador,heladera,deposito,bano').split(',');
const origen = `http://127.0.0.1:${puerto}`;

const perfil = mkdtempSync(join(tmpdir(), 'mv-'));
let ctx;
if (esFirefox) {
  ctx = await firefox.launchPersistentContext(perfil, { headless: false, viewport: { width: 1536, height: 760 },
    firefoxUserPrefs: { 'media.volume_scale': '0.0', 'widget.windows.window_occlusion_tracking.enabled': false, 'dom.webgpu.enabled': true, 'gfx.webgpu.ignore-blocklist': true, ...(sinLimite ? { 'layout.frame_rate': 0, 'gfx.vsync.force-disable': true } : {}) } });
} else {
  const args = ['--mute-audio', '--disable-features=CalculateNativeWinOcclusion', '--disable-backgrounding-occluded-windows', '--disable-renderer-backgrounding'];
  if (sinLimite) args.push('--disable-gpu-vsync', '--disable-frame-rate-limit');
  ctx = await chromium.launchPersistentContext(perfil, { channel: 'chrome', headless: false, viewport: { width: 1536, height: 760 }, args });
}
const pag = ctx.pages()[0] ?? (await ctx.newPage());
if (cpu > 1 && !esFirefox) { const cdp = await ctx.newCDPSession(pag); await cdp.send('Emulation.setCPUThrottlingRate', { rate: cpu }); }
await pag.addInitScript(() => {
  window.__cuadros = [];
  const f = (t) => { window.__cuadros.push(t); if (window.__cuadros.length > 900000) window.__cuadros.shift(); requestAnimationFrame(f); };
  requestAnimationFrame(f);
  window.__largo = 0; let u = performance.now();
  const g = (t) => { window.__largo = Math.max(window.__largo, t - u); u = t; requestAnimationFrame(g); };
  requestAnimationFrame(g);
});
const lineas = [];
pag.on('console', (m) => lineas.push({ tipo: m.type(), texto: m.text().slice(0, 240) }));
pag.on('pageerror', (e) => lineas.push({ tipo: 'pageerror', texto: e.message.slice(0, 240) }));

const tomar = async (ms) => {
  const desde = await pag.evaluate(() => { window.__largo = 0; return performance.now(); });
  await pag.waitForTimeout(ms);
  return pag.evaluate((d) => {
    const c = window.__cuadros.filter((t) => t >= d);
    const e = c.slice(1).map((t, i) => t - c[i]).sort((a, b) => a - b);
    if (e.length < 3) return null;
    const q = (p) => +e[Math.floor((e.length - 1) * p)].toFixed(2);
    return { cuadros: c.length, p50: q(0.5), p95: q(0.95), p99: q(0.99), max: +e[e.length - 1].toFixed(1), mayores_33: e.filter((x) => x > 33.4).length, mayores_50: e.filter((x) => x > 50).length };
  }, desde);
};

async function visita(n) {
  await fetch(origen + '/__reset').catch(() => {});
  const t0 = Date.now();
  await (n === 1 ? pag.goto(url + (url.includes('?') ? '&' : '?') + 'vista=gondola') : pag.reload());
  const listo = await pag.waitForFunction(() => window.__listo === true, null, { timeout: 300000, polling: 100 }).then(() => true).catch(() => false);
  const r = { listo, hasta_listo_ms: Date.now() - t0 };
  if (!listo) return r;
  r.marca = await pag.evaluate(() => window.__marca);
  r.almacen_ms = r.marca?.almacen ?? null;
  r.bytes = await (await fetch(origen + '/__bytes')).json().catch(() => null);
  r.bytes_total = r.bytes ? Object.entries(r.bytes).filter(([k]) => !k.includes('(304)')).reduce((a, [, b]) => a + b, 0) : null;
  return r;
}

const r = { etiqueta, url, sinLimite, esFirefox, cpu };
r.primera = await visita(1);
if (r.primera.listo) {
  await pag.waitForTimeout(1500);
  r.vistas = {};
  r.info = await pag.evaluate(() => window.__info?.());
  for (const v of vistas) {
    await pag.evaluate((n) => window.__vista(n), v);
    await pag.waitForTimeout(1200);
    await pag.evaluate(() => window.__cpu?.(true));
    r.vistas[v] = await tomar(segundos * 1000);
    r.cpu_cuadro = r.cpu_cuadro ?? {};
    r.cpu_cuadro[v] = await pag.evaluate(() => window.__cpu?.(true) ?? null);
  }
  const d = await pag.evaluate(() => { window.__largo = 0; return performance.now(); });
  for (const v of vistas) { await pag.evaluate((n) => window.__vista(n), v); await pag.waitForTimeout(1500); }
  r.recorrido_max_ms = await pag.evaluate(() => window.__largo);
  r.navegador = await pag.evaluate(() => navigator.userAgent);
  if (!esFirefox) {
    try {
      const ps = `Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object { $_.CommandLine -like '*${perfil}*' } | ForEach-Object { $t = if ($_.CommandLine -match '--type=([a-z-]+)') { $Matches[1] } else { 'navegador' }; "$t,$($_.WorkingSetSize)" }`;
      const l = execFileSync('powershell', ['-NoProfile', '-Command', ps]).toString().trim().split('\n').map((x) => x.trim()).filter(Boolean);
      r.memoria_por_proceso_mb = {}; let tot = 0;
      for (const x of l) { const [t, b] = x.split(','); r.memoria_por_proceso_mb[t] = (r.memoria_por_proceso_mb[t] ?? 0) + Math.round(Number(b) / 1048576); tot += Number(b); }
      r.memoria_mb = Math.round(tot / 1048576);
    } catch { r.memoria_mb = null; }
  }
  if (!opt('una-visita')) { await pag.waitForTimeout(1000); r.segunda = await visita(2); }
}
r.errores = lineas.filter((l) => /error/i.test(l.tipo) && !/Failed to load resource.*404/.test(l.texto)).slice(0, 6);
writeFileSync(salida, JSON.stringify(r, null, 1));
const m = (o) => o?.p50;
console.log(JSON.stringify({ etiqueta, almacen1: r.primera.almacen_ms, almacen2: r.segunda?.almacen_ms, bytesMB: r.primera.bytes_total && +(r.primera.bytes_total / 1048576).toFixed(1), memMB: r.memoria_mb, gondola_p50: m(r.vistas?.gondola), gondola_p95: r.vistas?.gondola?.p95, cpu_gondola: r.cpu_cuadro?.gondola?.p50, errores: r.errores.length }));
await ctx.close();
try { rmSync(perfil, { recursive: true, force: true }); } catch {}
