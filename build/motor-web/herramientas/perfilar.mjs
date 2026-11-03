// Perfila un visor: milisegundos de CPU por cuadro, llamadas de dibujo y dónde se va el tiempo.
// Uso: node perfilar.mjs <url> <salida.json> [--vista=gondola] [--segundos=4] [--cpu=1] [--sin-perfil]
// --sin-perfil no enciende el muestreador (que suma costo) y sólo mide la CPU por cuadro.
// Pide un visor con `window.__listo`, `__vista`, `__cpu` y `__info`. Chrome sin vsync.
import { chromium } from 'playwright';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [url, salida, ...op] = process.argv.slice(2);
const val = (n, d) => (op.find((o) => o.startsWith(`--${n}=`)) ?? `=${d}`).split('=')[1];
const sinPerfil = op.includes('--sin-perfil');
const vista = val('vista', 'gondola'), segundos = Number(val('segundos', 4)), cpu = Number(val('cpu', 1));
const perfil = mkdtempSync(join(tmpdir(), 'mv-p-'));
const ctx = await chromium.launchPersistentContext(perfil, { channel: 'chrome', headless: false, viewport: { width: 1536, height: 760 },
  args: ['--mute-audio', '--disable-features=CalculateNativeWinOcclusion', '--disable-backgrounding-occluded-windows', '--disable-renderer-backgrounding', '--disable-gpu-vsync', '--disable-frame-rate-limit'] });
const pag = ctx.pages()[0] ?? (await ctx.newPage());
const cdp = await ctx.newCDPSession(pag);
if (cpu > 1) await cdp.send('Emulation.setCPUThrottlingRate', { rate: cpu });
await pag.goto(url + (url.includes('?') ? '&' : '?') + `vista=${vista}`);
await pag.waitForFunction(() => window.__listo === true, null, { timeout: 300000, polling: 100 });
await pag.waitForTimeout(1500);
const info = await pag.evaluate(() => window.__info?.());
await pag.evaluate(() => window.__cpu(true));
if (!sinPerfil) { await cdp.send('Profiler.enable'); await cdp.send('Profiler.setSamplingInterval', { interval: 100 }); await cdp.send('Profiler.start'); }
const t0 = Date.now();
await pag.waitForTimeout(segundos * 1000);
const profile = sinPerfil ? { nodes: [], samples: [], timeDeltas: [] } : (await cdp.send('Profiler.stop')).profile;
const cpuMs = await pag.evaluate(() => window.__cpu(true));
const reloj = (Date.now() - t0) / 1000;

const porId = new Map(profile.nodes.map((n) => [n.id, n]));
const propio = new Map();
const dt = profile.timeDeltas;
for (let i = 0; i < profile.samples.length; i += 1) {
  const n = porId.get(profile.samples[i]);
  const f = n.callFrame;
  const nombre = f.functionName || '(anónima)';
  const clave = f.url ? `${nombre} ${f.url.split('/').slice(-1)[0]}:${f.lineNumber}` : nombre;
  propio.set(clave, (propio.get(clave) ?? 0) + (dt[i] ?? 0));
}
const total = [...propio.values()].reduce((a, b) => a + b, 0);
const top = [...propio.entries()].sort((a, b) => b[1] - a[1]).slice(0, 40)
  .map(([k, v]) => ({ funcion: k, ms_por_s: +(v / 1000 / reloj).toFixed(1), pct: +((v / total) * 100).toFixed(1) }));
const libre = propio.get('(idle)') ?? 0;
const entre = await pag.evaluate(() => window.__medir ? window.__medir(1500) : null);
const resumen = { url, vista, cpu, segundos: reloj, info, cpu_por_cuadro_ms: cpuMs, entre_cuadros: entre, ocupado_pct: total ? +(100 - (libre / total) * 100).toFixed(1) : null, top };
writeFileSync(salida, JSON.stringify(resumen, null, 1));
console.log(JSON.stringify(sinPerfil ? { vista, cpu: cpuMs, entre: entre, llamadas: info?.render?.drawCalls ?? info?.llamadas } : { vista, cpu_por_cuadro_ms: cpuMs, ocupado_pct: resumen.ocupado_pct, top5: top.slice(0, 8) }));
await ctx.close();
try { rmSync(perfil, { recursive: true, force: true }); } catch {}
