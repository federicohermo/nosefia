//     node --test .github/scripts/tests/comprimir_pck_test.mjs
//
// El paso que deja entrar el `.pck` en Vercel. Lo que se prueba acá es lo que no se puede ver
// mirando el deploy: que el cuerpo comprimido vuelva a ser el mismo `.pck`, que la barra de
// carga siga teniendo su total, y que correrlo dos veces no comprima dos veces.

import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import zlib from 'node:zlib';

import { codificados, comprimirDirectorio, tamanoDeclarado } from '../comprimir_pck.mjs';

const PCK = Buffer.concat([Buffer.from('GDPC', 'latin1'), Buffer.alloc(2048, 7)]);

function carpeta({ codificacion = 'br', declarado = PCK.length, cuerpo = PCK } = {}) {
  const directorio = mkdtempSync(join(tmpdir(), 'comprimir-pck-'));
  writeFileSync(join(directorio, 'index.pck'), cuerpo);
  writeFileSync(
    join(directorio, 'index.html'),
    `const GODOT_CONFIG = {"fileSizes":{"index.pck":${declarado}}};`
  );
  const configuracion = {
    headers: [
      { source: '/(.*)', headers: [{ key: 'Cache-Control', value: 'public, max-age=0' }] },
      { source: '/index.pck', headers: [{ key: 'Content-Encoding', value: codificacion }] },
    ],
  };
  return { directorio, configuracion };
}

function limpio(directorio) {
  rmSync(directorio, { recursive: true, force: true });
}

test('la codificación sale del vercel.json, que es de donde sale el header', () => {
  const { configuracion } = carpeta();
  assert.deepEqual([...codificados(configuracion)], [['index.pck', 'br']]);
  // Una regla universal no comprime nada: el wasm, el js y el html viajan sin codificar.
  const universal = {
    headers: [{ source: '/(.*)', headers: [{ key: 'Content-Encoding', value: 'gzip' }] }],
  };
  assert.equal(codificados(universal).size, 0);
});

test('el total declarado se lee del html del export', () => {
  const html = '{"fileSizes":{"index.pck":1234,"index.wasm":9}}';
  assert.equal(tamanoDeclarado(html, 'index.pck'), 1234);
  assert.equal(tamanoDeclarado('{"fileSizes":{}}', 'index.pck'), null);
});

test('comprime con brotli y lo que queda descomprime al mismo pck', () => {
  const { directorio, configuracion } = carpeta();
  try {
    assert.deepEqual(comprimirDirectorio(directorio, configuracion), []);
    const comprimido = readFileSync(join(directorio, 'index.pck'));
    assert.ok(comprimido.length < PCK.length, 'el archivo comprimido no es más chico');
    assert.deepEqual(zlib.brotliDecompressSync(comprimido), PCK);
  } finally {
    limpio(directorio);
  }
});

test('correrlo dos veces no comprime dos veces', () => {
  const { directorio, configuracion } = carpeta();
  try {
    comprimirDirectorio(directorio, configuracion);
    const primera = readFileSync(join(directorio, 'index.pck'));
    assert.deepEqual(comprimirDirectorio(directorio, configuracion), []);
    assert.deepEqual(readFileSync(join(directorio, 'index.pck')), primera);
  } finally {
    limpio(directorio);
  }
});

test('un paquete comprimido de otro export frena el paso sin tocarlo', () => {
  // El `.pck` comprimido puede ser de una corrida anterior y el `index.html`, nuevo: el juego
  // arrancaría con los recursos de otro lado. Se detecta por la medida y no se reescribe.
  const comprimidoAjeno = zlib.brotliCompressSync(Buffer.concat([PCK, Buffer.alloc(64, 1)]));
  const { directorio, configuracion } = carpeta({ cuerpo: comprimidoAjeno });
  try {
    const problemas = comprimirDirectorio(directorio, configuracion);
    assert.ok(problemas.some((problema) => problema.includes('no se toca')), problemas);
    assert.deepEqual(readFileSync(join(directorio, 'index.pck')), comprimidoAjeno);
  } finally {
    limpio(directorio);
  }
});

test('un total que no es el del contenido frena el paso sin escribir', () => {
  // La barra de carga divide por ese número. Si dice el tamaño comprimido, salta a 100 % a
  // mitad de la descarga y el jugador cree que se colgó.
  const { directorio, configuracion } = carpeta({ declarado: PCK.length * 2 });
  try {
    const problemas = comprimirDirectorio(directorio, configuracion);
    assert.ok(problemas.some((problema) => problema.includes('barra de carga')), problemas);
    assert.deepEqual(readFileSync(join(directorio, 'index.pck')), PCK, 'escribió igual');
  } finally {
    limpio(directorio);
  }
});

test('un archivo que no es un pck frena el paso', () => {
  const otro = Buffer.alloc(2048, 7);
  const { directorio, configuracion } = carpeta({ cuerpo: otro, declarado: otro.length });
  try {
    const problemas = comprimirDirectorio(directorio, configuracion);
    assert.ok(problemas.some((problema) => problema.includes('GDPC')), problemas);
  } finally {
    limpio(directorio);
  }
});

test('el vercel.json de este repo declara los dos paquetes comprimidos', () => {
  const ruta = new URL('../../../vercel.json', import.meta.url);
  assert.deepEqual([...codificados(JSON.parse(readFileSync(ruta, 'utf8')))], [
    ['index.pck', 'br'],
    ['mapa_del_corte.pck', 'br'],
  ]);
  assert.ok(existsSync(new URL('../comprimir_pck.mjs', import.meta.url)));
});
