// node medir_j1_j2.mjs <url> <salida.json> [--sin-paralelo]
// Un Chrome nuevo por corrida (perfil vacío). Requiere el export con medicion_carga.gd.
import { createRequire } from 'node:module';
import { writeFileSync, mkdirSync } from 'node:fs';
const require = createRequire('D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/package.json');
const { chromium, firefox } = require('playwright');
const enFirefox = process.argv.includes('--firefox');

const [url, salida] = process.argv.slice(2);
const sinParalelo = process.argv.includes('--sin-paralelo');
const ESPERA = 600_000;

function sonda(sinParalelo) {
  const t0 = () => performance.now();
  const d = (window.__d = { marcas: [], dato: [], links: [], cuadros: [], cargando: [], grabando: false, repro: false });
  window.__rep = [];
  d.rep = window.__rep;
  window.__marca = (n, dato) => {
    d.marcas.push([n, t0(), d.links.length]);
    d.dato.push([n, t0(), dato]);
    if (n === 'fin_j1_forzado') d.grabando = true;
    if (n === 'repro_inicio') d.repro = true;
    if (n === 'repro_fin') d.repro = false;
  };
  if (sinParalelo) {
    const get = WebGL2RenderingContext.prototype.getExtension;
    WebGL2RenderingContext.prototype.getExtension = function (n) {
      return n === 'KHR_parallel_shader_compile' ? null : get.call(this, n);
    };
  }
  const enlazar = WebGL2RenderingContext.prototype.linkProgram;
  WebGL2RenderingContext.prototype.linkProgram = function (p) {
    const a = t0();
    const r = enlazar.call(this, p);
    const e = { t: a, ms: t0() - a };
    if (d.grabando) {
      const fr = this.getAttachedShaders(p)
        .filter((s) => this.getShaderParameter(s, this.SHADER_TYPE) === this.FRAGMENT_SHADER)
        .map((s) => this.getShaderSource(s))[0] || '';
      e.defs = fr.split('\n').filter((l) => l.startsWith('#define')).join(' ');
      e.unif = fr.split('\n').filter((l) => /^uniform .*(sampler|vec|float)/.test(l)).slice(-25).join(' | ');
      e.len = fr.length;
    }
    d.links.push(e);
    return r;
  };
  const P = WebGL2RenderingContext.prototype;
  const compilar = P.compileShader;
  P.compileShader = function (sh) {
    const a = t0();
    const r = compilar.call(this, sh);
    if (d.grabando) d.cuadros.push(['compile', a, t0() - a]);
    return r;
  };
  const getSh = P.getShaderParameter;
  P.getShaderParameter = function (sh, k) {
    const a = t0();
    const r = getSh.call(this, sh, k);
    const ms = t0() - a;
    if (d.grabando && ms > 2) d.cuadros.push(['espera_shader', a, ms]);
    return r;
  };
  if (window.__perfil) {
    d.draws = [];
    let n = 0;
    for (const f of ['drawElements', 'drawArrays', 'drawElementsInstanced', 'drawArraysInstanced', 'drawRangeElements']) {
      const o = P[f];
      P[f] = function (...x) { n++; return o.apply(this, x); };
    }
    const contar = (t) => { if (d.grabando) d.draws.push([t, n]); n = 0; requestAnimationFrame(contar); };
    requestAnimationFrame(contar);
  }
  const getParam = WebGL2RenderingContext.prototype.getProgramParameter;
  WebGL2RenderingContext.prototype.getProgramParameter = function (p, k) {
    const a = t0();
    const r = getParam.call(this, p, k);
    const ms = t0() - a;
    if (d.grabando && ms > 5) d.cuadros.push(['espera_link', a, ms]);
    return r;
  };
  const cuadro = (t) => {
    if (d.grabando) d.cuadros.push([t, window.godot_programas_en_cola ?? -1]);
    requestAnimationFrame(cuadro);
  };
  requestAnimationFrame(cuadro);
  new MutationObserver(() => {
    const c = document.body.classList.contains('cargando');
    const u = d.cargando[d.cargando.length - 1];
    if (!u || u[0] !== c) d.cargando.push([c, t0(), d.links.length]);
  }).observe(document.documentElement, { attributes: true, subtree: true, attributeFilter: ['class'] });
}

const navegador = enFirefox ? await firefox.launch({
  headless: false,
  firefoxUserPrefs: { 'webgl.force-enabled': true, 'widget.windows.window_occlusion_tracking.enabled': false, 'dom.min_background_timeout_value': 4 },
}) : await chromium.launch({
  channel: 'chrome',
  headless: false,
  args: [
    '--window-size=1600,900',
    '--disable-backgrounding-occluded-windows',
    '--disable-renderer-backgrounding',
    '--disable-background-timer-throttling',
    '--disable-features=CalculateNativeWinOcclusion',
  ],
});
const captura = process.argv.includes('--captura');
const carpeta = salida.replace('.json', '_capturas');
if (captura) mkdirSync(carpeta, { recursive: true });
const contexto = await navegador.newContext({
  viewport: { width: 1536, height: 760 },
  ...(captura ? { recordVideo: { dir: carpeta, size: { width: 1280, height: 630 } } } : {}),
});
const pagina = await contexto.newPage();
if (process.argv.includes('--perfil')) await pagina.addInitScript(() => { window.__perfil = true; });
await pagina.addInitScript(sonda, sinParalelo);
const consola = [];
let listo;
const terminado = new Promise((r) => (listo = r));
pagina.on('console', (m) => {
  const t = m.text();
  if (t.startsWith('[med]') || t.startsWith('[carga]') || m.type() === 'error') consola.push([Date.now(), t.slice(0, 400)]);
  if (t.includes('[med] LISTO')) listo();
});
const desde = Date.now();
await pagina.goto(url, { waitUntil: 'load', timeout: ESPERA });
const gpu = await pagina.evaluate(() => {
  const gl = document.createElement('canvas').getContext('webgl2');
  const i = gl.getExtension('WEBGL_debug_renderer_info');
  return { gpu: String(i ? gl.getParameter(i.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER)), paralelo: Boolean(gl.getExtension('KHR_parallel_shader_compile')) };
});
let fotos = 0;
let parar = false;
const bucle = captura ? (async () => {
  while (!parar) {
    const activa = await pagina.evaluate(() => window.__d && window.__d.repro).catch(() => false);
    if (activa) {
      const t = await pagina.evaluate(() => performance.now()).catch(() => 0);
      await pagina.screenshot({ path: `${carpeta}/f${String(fotos++).padStart(4, '0')}_${Math.round(t)}.jpg`, type: 'jpeg', quality: 60 }).catch(() => {});
    } else await new Promise((r) => setTimeout(r, 100));
  }
})() : Promise.resolve();
const completa = await Promise.race([terminado.then(() => true), new Promise((r) => setTimeout(() => r(false), ESPERA))]);
parar = true;
await bucle;
if (!completa) await pagina.screenshot({ path: salida.replace('.json', '.png') });
const datos = await pagina.evaluate(() => ({ ...window.__d, rep: window.__rep }));
writeFileSync(salida, JSON.stringify({ navegador: enFirefox ? 'firefox' : 'chrome', url, completa, sinParalelo, perfil: process.argv.includes('--perfil'), gpu, duracion_s: (Date.now() - desde) / 1000, consola, ...datos }));
console.log('ok', salida, gpu);
await navegador.close();
process.exit(0);
