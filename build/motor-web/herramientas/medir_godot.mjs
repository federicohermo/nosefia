// Una corrida de medición contra un export servido: bytes por la red, tiempo hasta ver el almacén,
// cuadros en tres vistas y caminando, y la memoria de los procesos de ese Chrome.
// Uso: node medir.mjs <url> <salida.json> [--etiqueta=x] [--sin-limite] [--cpu=4] [--software]
//        [--tarde] [--segundos=8]
// --sin-limite: Chrome sin vsync ni tope de cuadros (el tiempo de cuadro sale del costo real).
// --cpu=N: frena la CPU N veces con CDP. --software: WebGPU y WebGL por software (SwiftShader).
// --tarde: hace el clic en «Nuevo juego» apenas aparece el menú, sin esperar el calentamiento.
import { chromium, firefox } from 'playwright';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { execFileSync } from 'node:child_process';

const [url, salida, ...opciones] = process.argv.slice(2);
const opt = (n) => opciones.find((o) => o === `--${n}` || o.startsWith(`--${n}=`));
const valor = (n, d) => { const o = opt(n); return o && o.includes('=') ? o.split('=')[1] : d; };
const etiqueta = valor('etiqueta', 'sin-nombre');
const sinLimite = !!opt('sin-limite');
const cpu = Number(valor('cpu', 1));
const software = !!opt('software');
const clicRapido = !!opt('tarde');
const segundos = Number(valor('segundos', 8));

const perfilFijo = valor('perfil', null);
const perfil = perfilFijo ?? mkdtempSync(join(tmpdir(), 'medir-'));
const args = ['--mute-audio', '--disable-features=CalculateNativeWinOcclusion', '--disable-backgrounding-occluded-windows', '--disable-renderer-backgrounding'];
if (sinLimite) args.push('--disable-gpu-vsync', '--disable-frame-rate-limit');
if (software) args.push(...(valor('software', 'webgpu') === 'webgl' ? ['--enable-unsafe-swiftshader', '--use-angle=swiftshader', '--use-gl=angle'] : ['--use-webgpu-adapter=swiftshader', '--enable-unsafe-webgpu', '--enable-features=Vulkan', '--use-vulkan=swiftshader', '--ignore-gpu-blocklist']));
const esFirefox = !!opt('firefox');
const ctx = esFirefox
  ? await firefox.launchPersistentContext(perfil, { headless: false, viewport: { width: 1536, height: 760 }, firefoxUserPrefs: { 'media.volume_scale': '0.0', 'widget.windows.window_occlusion_tracking.enabled': false } })
  : await chromium.launchPersistentContext(perfil, { channel: 'chrome', headless: false, viewport: { width: 1536, height: 760 }, args });
const pag = ctx.pages()[0] ?? (await ctx.newPage());
const cdp = esFirefox ? { send: async () => {}, on: () => {} } : await ctx.newCDPSession(pag);
if (cpu > 1) await cdp.send('Emulation.setCPUThrottlingRate', { rate: cpu });
await cdp.send('Network.enable');
const urls = new Map(); const bytes = new Map();
cdp.on('Network.responseReceived', (e) => urls.set(e.requestId, e.response.url));
cdp.on('Network.loadingFinished', (e) => bytes.set(e.requestId, (bytes.get(e.requestId) ?? 0) + e.encodedDataLength));

await pag.addInitScript(() => {
  window.__cuadros = [];
  const f = (t) => { window.__cuadros.push(t); if (window.__cuadros.length > 900000) window.__cuadros.shift(); requestAnimationFrame(f); };
  requestAnimationFrame(f);
  window.__largo = 0; let ultimo = performance.now();
  const g = (t) => { window.__largo = Math.max(window.__largo, t - ultimo); ultimo = t; requestAnimationFrame(g); };
  requestAnimationFrame(g);
});
const lineas = []; const t0 = Date.now();
pag.on('console', (m) => lineas.push({ t: Date.now() - t0, tipo: m.type(), texto: m.text() }));
pag.on('pageerror', (e) => lineas.push({ t: Date.now() - t0, tipo: 'pageerror', texto: e.message }));
const marca = (t) => lineas.find((l) => l.texto.includes(t))?.t ?? null;
const esperar = async (t, ms) => { const d = Date.now(); while (Date.now() - d < ms) { if (marca(t) !== null) return marca(t); await pag.waitForTimeout(200); } return null; };

const r = { etiqueta, url, sinLimite, cpu, software, clicRapido };
const origen = new URL(url).origin;
await fetch(origen + '/__reset').catch(() => {});
await pag.goto(url);
r.menu_ms = await esperar('[carga] menú visible', 900000);
if (!clicRapido) r.calentado_ms = await esperar('[carga] almacén calentado', 900000);
await pag.waitForTimeout(800);
const tClic = Date.now() - t0;
await pag.mouse.move(768, 430); await pag.mouse.down(); await pag.waitForTimeout(80); await pag.mouse.up();
r.clic_ms = tClic;
r.almacen_ms = await esperar('[carga] almacén en pantalla', 900000);
r.almacen_desde_clic_ms = r.almacen_ms === null ? null : r.almacen_ms - tClic;
if (r.almacen_ms === null) {
  r.error = 'el almacén no llegó';
} else {
  await pag.waitForTimeout(1500);
  for (let i = 0; i < 8; i++) { await pag.mouse.click(1258, 624); await pag.waitForTimeout(700); }
  await pag.waitForTimeout(2500);
  const tomar = async (ms) => {
    const desde = await pag.evaluate(() => { window.__largo = 0; return performance.now(); });
    await pag.waitForTimeout(ms);
    return pag.evaluate((d) => {
      const c = window.__cuadros.filter((t) => t >= d);
      const e = c.slice(1).map((t, i) => t - c[i]).sort((a, b) => a - b);
      if (e.length < 3) return null;
      const q = (p) => +e[Math.floor((e.length - 1) * p)].toFixed(2);
      return { cuadros: c.length, fps: +((c.length - 1) * 1000 / (c[c.length - 1] - c[0])).toFixed(1), p50: q(0.5), p95: q(0.95), p99: q(0.99), max: +e[e.length - 1].toFixed(1), mayores_33: e.filter((x) => x > 33.4).length, mayores_50: e.filter((x) => x > 50).length, mayores_100: e.filter((x) => x > 100).length };
    }, desde);
  };
  const vistas = [['mostrador', [3.0, 2.5], [0.0, 1.2, 5.0]], ['gondola', [2.4, 3.3], [2.4, 1.2, -2.0]], ['pasillo', [6.0, 4.0], [5.0, 1.5, -6.0]]];
  r.vistas = {};
  for (const [n, de, a] of vistas) {
    await pag.evaluate(([x, z, yaw, t]) => window.ir_godot(x, z, yaw, t[0], t[1], t[2]), [de[0], de[1], Math.atan2(-(a[0] - de[0]), -(a[2] - de[1])), a]);
    await pag.waitForTimeout(2500);
    r.vistas[n] = await tomar(segundos * 1000);
  }
  if (opt('recorrido')) {
    // Un recorrido por todo el local, para que aparezcan las variantes que nadie dibujó todavía.
    const paradas = [[5.7, 5.3, [5.7, 1.4, -10]], [3.0, 2.5, [0, 1.2, 5]], [2.4, 3.3, [2.4, 1.2, -2]], [6.0, 4.0, [5, 1.5, -6]], [3.0, -4.0, [0, 1.2, -7.5]], [-2.0, -8.0, [2, 1.2, -12]], [5.5, -9.0, [3, 1.3, -13.5]], [8.0, -12.5, [10.5, 1.2, -14.5]], [9.0, -12.0, [10.0, 1.0, -15.0]], [4.0, -14.0, [4.0, 1.5, -15.5]], [9.5, 1.0, [12, 1.3, 4.5]], [10.9, 2.8, [10.9, 1.3, 4.2]], [12.0, 3.0, [11.0, 2.0, 6.0]], [7.0, 5.0, [3.4, 1.3, 6.3]], [2.0, 6.5, [4.0, 1.6, 12.0]], [5.7, 5.3, [-2, 1.2, -2]]];
    const desdeR = await pag.evaluate(() => { window.__largo = 0; return performance.now(); });
    r.parada_max = [];
    for (const [x, z, a] of paradas) {
      await pag.evaluate(([x, z, yaw, t]) => window.ir_godot(x, z, yaw, t[0], t[1], t[2]), [x, z, Math.atan2(-(a[0] - x), -(a[2] - z)), a]);
      await pag.waitForTimeout(1800);
      r.parada_max.push(await pag.evaluate(() => { const m = window.__largo; window.__largo = 0; return +m.toFixed(1); }));
    }
    r.recorrido = await pag.evaluate((d) => {
      const c = window.__cuadros.filter((t) => t >= d);
      const e = c.slice(1).map((t, i) => t - c[i]).sort((a, b) => a - b);
      const q = (p) => +e[Math.floor((e.length - 1) * p)].toFixed(2);
      return { cuadros: c.length, p50: q(0.5), p95: q(0.95), p99: q(0.99), max: +e[e.length - 1].toFixed(1), mayores_33: e.filter((x) => x > 33.4).length, mayores_50: e.filter((x) => x > 50).length, mayores_100: e.filter((x) => x > 100).length };
    }, desdeR);
  }
  // Caminando: ir y volver por el pasillo, para que aparezcan los tirones al entrar cosas en cuadro.
  await pag.evaluate(([x, z, yaw, t]) => window.ir_godot(x, z, yaw, t[0], t[1], t[2]), [5.7, 5.3, 0, [5.7, 1.4, -10]]);
  await pag.waitForTimeout(1500);
  const desde = await pag.evaluate(() => { window.__largo = 0; return performance.now(); });
  await pag.keyboard.down('KeyW'); await pag.waitForTimeout(6000); await pag.keyboard.up('KeyW');
  await pag.keyboard.down('KeyS'); await pag.waitForTimeout(6000); await pag.keyboard.up('KeyS');
  r.caminando = await pag.evaluate((d) => {
    const c = window.__cuadros.filter((t) => t >= d);
    const e = c.slice(1).map((t, i) => t - c[i]).sort((a, b) => a - b);
    const q = (p) => +e[Math.floor((e.length - 1) * p)].toFixed(2);
    return { cuadros: c.length, p50: q(0.5), p95: q(0.95), p99: q(0.99), max: +e[e.length - 1].toFixed(1), mayores_33: e.filter((x) => x > 33.4).length, mayores_50: e.filter((x) => x > 50).length, mayores_100: e.filter((x) => x > 100).length };
  }, desde);
}
r.bytes_servidor = await (await fetch(origen + '/__bytes')).json().catch(() => null);
r.bytes_red = {}; let total = 0;
for (const [id, b] of bytes) { const u = (urls.get(id) ?? '').split('?')[0].split('/').pop() || 'index.html'; r.bytes_red[u] = (r.bytes_red[u] ?? 0) + b; total += b; }
r.bytes_total = r.bytes_servidor ? Object.values(r.bytes_servidor).reduce((a, b) => a + b, 0) : total;
r.errores = lineas.filter((l) => /error|pageerror/i.test(l.tipo) || /ERROR/.test(l.texto)).slice(0, 8).map((l) => l.texto.slice(0, 160));
r.motor = lineas.find((l) => /WebGPU 1\.0|OpenGL ES|WebGL/.test(l.texto))?.texto ?? null;
r.navegador = await pag.evaluate(() => navigator.userAgent);
try {
  const ps = `Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" | Where-Object { $_.CommandLine -like '*${perfil}*' } | ForEach-Object { $t = if ($_.CommandLine -match '--type=([a-z-]+)') { $Matches[1] } else { 'navegador' }; "$t,$($_.WorkingSetSize)" }`;
  const lineas2 = execFileSync('powershell', ['-NoProfile', '-Command', ps]).toString().trim().split('\n').map((x) => x.trim()).filter(Boolean);
  r.memoria_por_proceso_mb = {};
  let tot = 0;
  for (const l of lineas2) { const [t, b] = l.split(','); r.memoria_por_proceso_mb[t] = (r.memoria_por_proceso_mb[t] ?? 0) + Math.round(Number(b) / 1048576); tot += Number(b); }
  r.memoria_mb = Math.round(tot / 1048576);
} catch (e) { r.memoria_mb = null; }
writeFileSync(salida, JSON.stringify(r, null, 1));
console.log(JSON.stringify({ etiqueta, menu: r.menu_ms, almacen: r.almacen_ms, desde_clic: r.almacen_desde_clic_ms, bytes_MB: +(r.bytes_total / 1048576).toFixed(1), mem_MB: r.memoria_mb, gondola_p50: r.vistas?.gondola?.p50, gondola_p95: r.vistas?.gondola?.p95, camina_p95: r.caminando?.p95, camina_max: r.caminando?.max, recorrido_max: r.recorrido?.max, recorrido_50: r.recorrido?.mayores_50 }));
await ctx.close();
if (!perfilFijo) { try { rmSync(perfil, { recursive: true, force: true }); } catch {} }
