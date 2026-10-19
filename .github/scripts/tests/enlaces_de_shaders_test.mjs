//     node --test .github/scripts/tests/enlaces_de_shaders_test.mjs

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

const script = readFileSync(new URL('../medir_la_carga.mjs', import.meta.url), 'utf8');
const inicio = script.indexOf('function contarEnlaces(');
const fin = script.indexOf('\nasync function corrida', inicio);
assert.ok(inicio >= 0 && fin > inicio, 'el hook que Playwright serializa sigue en el medidor');

function pagina() {
  const registros = [];
  const llamados = [];
  class WebGL2RenderingContext {
    SHADER_TYPE = 0x8b4f;
    linkProgram(programa) { llamados.push(programa); return 'enlazado'; }
    getAttachedShaders(programa) { return programa; }
    getShaderParameter(shader) { return shader.tipo; }
    getShaderSource(shader) { return shader.fuente; }
  }
  const consola = { log: function (...argumentos) { registros.push({ argumentos, receptor: this }); } };
  const entorno = { window: {}, console: consola, WebGL2RenderingContext };
  // Ejecutar exactamente la función que addInitScript manda al navegador, sin abrir Chrome.
  runInNewContext(script.slice(inicio, fin), entorno);
  entorno.contarEnlaces('[carga] almacén en pantalla');
  return { gl: new WebGL2RenderingContext(), enlaces: entorno.window.__enlaces,
    consola, registros, llamados };
}

function programa(fragmento = 'fragmento') {
  return [{ tipo: 0x8b31, fuente: 'vértice' }, { tipo: 0x8b30, fuente: fragmento }];
}

test('dos programas con las mismas fuentes cuentan un solo par aunque inviertan los shaders', () => {
  const { gl, enlaces, llamados } = pagina();
  const primero = programa();
  assert.equal(gl.linkProgram(primero), 'enlazado');
  gl.linkProgram([...primero].reverse());
  gl.linkProgram(programa('otro fragmento'));
  assert.equal(enlaces.programas, 3);
  assert.equal(enlaces.fuentes.size, 2);
  assert.equal(llamados.length, 3);
});

test('el aviso cierra los conteos antes de que Playwright los lea, sin impedir enlaces posteriores', () => {
  const { gl, enlaces, consola, llamados } = pagina();
  gl.linkProgram(programa());
  consola.log('[carga] almacén en pantalla');
  gl.linkProgram(programa('gameplay posterior al aviso'));
  assert.equal(enlaces.programas, 1);
  assert.equal(enlaces.fuentes.size, 1);
  assert.equal(llamados.length, 2);
});

test('otros avisos no cierran el conteo y la consola conserva argumentos y receptor', () => {
  const { gl, enlaces, consola, registros } = pagina();
  const detalle = { carga: 'menú' };
  consola.log('[carga] menú visible', detalle);
  gl.linkProgram(programa());
  assert.equal(enlaces.programas, 1);
  assert.deepEqual(registros[0].argumentos, ['[carga] menú visible', detalle]);
  assert.equal(registros[0].receptor, consola);
});

test('sin programas antes del aviso ambos conteos quedan en cero', () => {
  const { gl, enlaces, consola } = pagina();
  consola.log('[carga] almacén en pantalla');
  gl.linkProgram(programa());
  assert.equal(enlaces.programas, 0);
  assert.equal(enlaces.fuentes.size, 0);
});

const inicioDelRenderer = script.indexOf('function rendererRechazado(');
const finDelRenderer = script.indexOf('\nfunction aviso(', inicioDelRenderer);

function rendererRechazado(...argumentos) {
  assert.ok(inicioDelRenderer >= 0 && finDelRenderer > inicioDelRenderer,
    'la regla del renderer sigue en el medidor');
  const entorno = {};
  runInNewContext(`${script.slice(inicioDelRenderer, finDelRenderer)}\nthis.regla = rendererRechazado;`, entorno);
  return entorno.regla(...argumentos);
}

test('sin ventana rechaza un renderer por software salvo que la medición lo pida', () => {
  const swiftshader = 'ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device), SwiftShader driver)';
  assert.equal(rendererRechazado(swiftshader, { sinVentana: true, software: false }), true);
  assert.equal(rendererRechazado(null, { sinVentana: true, software: false }), true);
  assert.equal(rendererRechazado(swiftshader, { sinVentana: true, software: true }), false);
  assert.equal(rendererRechazado(null, { sinVentana: true, software: true }), true);
});

test('con ventana o con una GPU real no rechaza el renderer', () => {
  const real = 'ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)';
  assert.equal(rendererRechazado(real, { sinVentana: true, software: false }), false);
  assert.equal(rendererRechazado('SwiftShader', { sinVentana: false, software: false }), false);
});
