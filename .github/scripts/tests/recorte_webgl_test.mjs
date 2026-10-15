// node --test .github/scripts/tests/recorte_webgl_test.mjs, después de exportar Web.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { runInNewContext } from 'node:vm';

const archivo = process.env.PLANTILLA_WEB_JS ?? new URL('../../../export/web/index.js', import.meta.url);
const codigo = readFileSync(archivo, 'utf8');
const marca = 'blitOffscreenFramebuffer:';
const inicio = codigo.indexOf(marca) + marca.length;
assert.ok(inicio >= marca.length, 'la plantilla conserva la copia del framebuffer');
let fin = codigo.indexOf('{', inicio), profundidad = 1;
while (profundidad && ++fin < codigo.length) {
  if (codigo[fin] === '{') profundidad++;
  if (codigo[fin] === '}') profundidad--;
}
assert.equal(profundidad, 0);
const copiar = runInNewContext(`(${codigo.slice(inicio, fin + 1)})`);

for (const habilitado of [false, true]) {
  test(`copiar sin esperar a la GPU conserva recorte ${habilitado} y framebuffer`, () => {
    let recorte = habilitado, framebuffer = 17, copias = 0;
    const gl = {
      canvas: { width: 320, height: 240 },
      isEnabled(capacidad) { assert.equal(capacidad, 3089); return recorte; },
      getParameter(parametro) {
        assert.equal(parametro, 36006, 'el recorte no debe consultarse a la GPU');
        return framebuffer;
      },
      disable(capacidad) { assert.equal(capacidad, 3089); recorte = false; },
      enable(capacidad) { assert.equal(capacidad, 3089); recorte = true; },
      bindFramebuffer(_destino, id) { framebuffer = id; },
      blitFramebuffer() { assert.equal(recorte, false); copias++; },
    };
    copiar({ GLctx: gl, defaultFbo: 23 });
    assert.equal(copias, 1);
    assert.equal(recorte, habilitado);
    assert.equal(framebuffer, 17);
  });
}
