// Cuenta cuántos shaders distintos arma Three.js para el almacén y cuánto pesan.
// Uso: node programas.mjs <url-del-visor> [carpeta-donde-volcar-los-shaders]  (el visor expone window.__renderer)
import { chromium } from 'playwright';
import { mkdtempSync, rmSync, writeFileSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const perfil = mkdtempSync(join(tmpdir(), 'mv-prog-'));
const ctx = await chromium.launchPersistentContext(perfil, { channel: 'chrome', headless: false, viewport: { width: 1536, height: 760 }, args: ['--mute-audio'] });
const pag = ctx.pages()[0];
await pag.goto(process.argv[2]);
await pag.waitForFunction(() => window.__listo === true, null, { timeout: 300000 });
const r = await pag.evaluate(() => {
  const estados = [...window.__renderer._nodes.nodeBuilderCache.values()];
  const frag = estados.map((e) => e.fragmentShader ?? e.fragment ?? '');
  const unicos = [...new Set(frag)];
  return { estadosDeNodos: estados.length, shadersDeFragmentoUnicos: unicos.length, kbDeFragmento: unicos.map((f) => Math.round(f.length / 1024)).sort((a, b) => b - a), marca: window.__marca, info: window.__info().memoria?.programs };
});
console.log(JSON.stringify(r));
if (process.argv[3]) {
  mkdirSync(process.argv[3], { recursive: true });
  const fr = await pag.evaluate(() => [...new Set([...window.__renderer._nodes.nodeBuilderCache.values()].map((e) => e.fragmentShader ?? ''))].filter((f) => f.length > 20000));
  fr.forEach((f, i) => writeFileSync(join(process.argv[3], `fragmento${i}.glsl`), f));
}
await ctx.close();
try { rmSync(perfil, { recursive: true, force: true }); } catch {}
