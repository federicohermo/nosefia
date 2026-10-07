import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import { runInNewContext } from 'node:vm';

const script = readFileSync(new URL('../medir_la_carga.mjs', import.meta.url), 'utf8');
const inicio = script.indexOf('function vigilarLaPagina(');
const fin = script.indexOf('\n// Corre en la página', inicio);

function pagina() {
  const callbacks = [];
  const reloj = { ahora: 0 };
  const window = {};
  const consola = { log() {} };
  runInNewContext(`${script.slice(inicio, fin)}\nvigilarLaPagina({ avisoDelAlmacen: 'almacén' });`, {
    window, console: consola,
    performance: { now: () => reloj.ahora },
    requestAnimationFrame: (callback) => callbacks.push(callback),
  });
  return { window, consola, reloj, cuadro(ahora) {
    reloj.ahora = ahora;
    callbacks.shift()(ahora);
  } };
}

test('el aviso incluye el bloqueo anterior al cuadro siguiente', () => {
  const p = pagina();
  p.cuadro(10);
  p.cuadro(26);
  p.reloj.ahora = 1026;
  p.consola.log('almacén');
  assert.equal(p.window.__cuadros.masLargo, 1000);
  p.cuadro(5000);
  assert.equal(p.window.__cuadros.masLargo, 1000);
});

test('el tramo final conserva el cuadro más largo anterior', () => {
  const p = pagina();
  p.cuadro(10);
  p.cuadro(210);
  p.reloj.ahora = 220;
  p.consola.log('almacén');
  assert.equal(p.window.__cuadros.masLargo, 200);
});

test('el aviso repetido no agrega tiempo después del cierre', () => {
  const p = pagina();
  p.cuadro(10);
  p.reloj.ahora = 30;
  p.consola.log('almacén');
  p.reloj.ahora = 5000;
  p.consola.log('almacén');
  assert.equal(p.window.__cuadros.masLargo, 20);
});
