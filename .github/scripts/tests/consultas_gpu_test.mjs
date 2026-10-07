//     node --test .github/scripts/tests/consultas_gpu_test.mjs

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { deflateSync } from 'node:zlib';
import {
  decodificarPng,
  diferenciaRgb,
  mediana,
  mismaImagen,
  tiemposPorCuadro,
} from '../lib/consultas_gpu.mjs';

function trozo(tipo, datos) {
  const largo = Buffer.alloc(4);
  largo.writeUInt32BE(datos.length);
  // El decodificador no verifica el CRC: lo que llega es una captura recién hecha.
  return Buffer.concat([largo, Buffer.from(tipo, 'latin1'), datos, Buffer.alloc(4)]);
}

// `filas` son los bytes ya filtrados de cada fila, con su tipo de filtro adelante.
function png(ancho, alto, tipoDeColor, filas, { bits = 8, entrelazado = 0 } = {}) {
  const cabecera = Buffer.alloc(13);
  cabecera.writeUInt32BE(ancho, 0);
  cabecera.writeUInt32BE(alto, 4);
  cabecera.set([bits, tipoDeColor, 0, 0, entrelazado], 8);
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    trozo('IHDR', cabecera),
    // Dos trozos: Chrome parte los datos de una captura grande en varios.
    trozo('IDAT', deflateSync(Buffer.from(filas.flat())).subarray(0, 5)),
    trozo('IDAT', deflateSync(Buffer.from(filas.flat())).subarray(5)),
    trozo('IEND', Buffer.alloc(0)),
  ]);
}

function imagen(ancho, alto, canales, pixeles) {
  return { ancho, alto, canales, pixeles: Uint8Array.from(pixeles) };
}

test('las consultas de un mismo cuadro se suman, en milisegundos', () => {
  const consultas = [
    { cuadro: 7, ns: 1_000_000, disjunta: false },
    { cuadro: 7, ns: 500_000, disjunta: false },
    { cuadro: 8, ns: 2_000_000, disjunta: false },
  ];
  assert.deepEqual(tiemposPorCuadro(consultas), [1.5, 2]);
});

test('un cuadro con una consulta disjunta se descarta entero', () => {
  const consultas = [
    { cuadro: 1, ns: 1_000_000, disjunta: false },
    { cuadro: 2, ns: 1_000_000, disjunta: false },
    { cuadro: 2, ns: 9_000_000, disjunta: true },
    { cuadro: 3, ns: 3_000_000, disjunta: false },
  ];
  assert.deepEqual(tiemposPorCuadro(consultas), [1, 3]);
});

test('un cuadro con una consulta sin resultado se descarta entero', () => {
  const consultas = [
    { cuadro: 1, ns: 4_000_000, disjunta: false },
    { cuadro: 1, ns: null, disjunta: false },
    { cuadro: 2, ns: 0, disjunta: false },
  ];
  assert.deepEqual(tiemposPorCuadro(consultas), [0]);
});

test('la mediana no confunde un pico con el centro ni reordena lo que recibe', () => {
  const valores = [90, 2, 3, 1, 4];
  assert.equal(mediana(valores), 3);
  assert.deepEqual(valores, [90, 2, 3, 1, 4]);
  assert.equal(mediana([4, 1, 3, 2]), 2.5);
  assert.throws(() => mediana([]), /sin muestras/);
});

test('una captura RGB se decodifica con sus filtros Sub y Up', () => {
  const captura = png(2, 2, 2, [
    [1, 10, 20, 30, 5, 5, 5],
    [2, 1, 1, 1, 2, 2, 2],
  ]);
  assert.deepEqual(
    decodificarPng(captura),
    imagen(2, 2, 3, [10, 20, 30, 15, 25, 35, 11, 21, 31, 17, 27, 37])
  );
});

test('una captura RGBA se decodifica con sus filtros None, Average y Paeth', () => {
  const captura = png(2, 3, 6, [
    [0, 10, 20, 30, 255, 40, 50, 60, 255],
    [3, 1, 1, 1, 0, 2, 2, 2, 0],
    [4, 1, 1, 1, 0, 3, 3, 3, 0],
  ]);
  assert.deepEqual(
    decodificarPng(captura),
    imagen(
      2,
      3,
      4,
      [
        [10, 20, 30, 255, 40, 50, 60, 255],
        // Average suma la mitad entera de izquierda más arriba.
        [6, 11, 16, 127, 25, 32, 40, 191],
        // Paeth elige acá el píxel de arriba en los dos casos.
        [7, 12, 17, 127, 28, 35, 43, 191],
      ].flat()
    )
  );
});

test('lo que no es una captura de 8 bits sin entrelazar se rechaza', () => {
  assert.throws(() => decodificarPng(Buffer.from('no es un png')), /no es un PNG/);
  const fila = [[0, 1, 2, 3]];
  assert.throws(() => decodificarPng(png(1, 1, 2, fila, { entrelazado: 1 })), /formato/);
  assert.throws(() => decodificarPng(png(1, 1, 2, fila, { bits: 16 })), /formato/);
  assert.throws(() => decodificarPng(png(1, 1, 3, [[0, 1]])), /formato/);
});

test('la diferencia cuenta píxeles distintos y el mayor salto por canal, sin mirar el alfa', () => {
  const base = imagen(2, 1, 4, [10, 20, 30, 255, 40, 50, 60, 255]);
  assert.deepEqual(diferenciaRgb(base, base), { pixeles: 0, niveles: 0 });
  const otroAlfa = imagen(2, 1, 4, [10, 20, 30, 0, 40, 50, 60, 0]);
  assert.deepEqual(diferenciaRgb(base, otroAlfa), { pixeles: 0, niveles: 0 });
  const unNivel = imagen(2, 1, 4, [10, 20, 30, 255, 40, 51, 60, 255]);
  assert.deepEqual(diferenciaRgb(base, unNivel), { pixeles: 1, niveles: 1 });
  const dosPixeles = imagen(2, 1, 4, [7, 20, 30, 255, 40, 50, 62, 255]);
  assert.deepEqual(diferenciaRgb(base, dosPixeles), { pixeles: 2, niveles: 3 });
});

test('una captura RGB y una RGBA del mismo tamaño se comparan píxel a píxel', () => {
  const conAlfa = imagen(2, 1, 4, [10, 20, 30, 255, 40, 50, 60, 255]);
  const sinAlfa = imagen(2, 1, 3, [10, 20, 30, 40, 50, 61]);
  assert.deepEqual(diferenciaRgb(conAlfa, sinAlfa), { pixeles: 1, niveles: 1 });
});

test('dos capturas de distinto tamaño no se comparan', () => {
  const ancha = imagen(2, 1, 3, [1, 2, 3, 4, 5, 6]);
  const alta = imagen(1, 2, 3, [1, 2, 3, 4, 5, 6]);
  assert.throws(() => diferenciaRgb(ancha, alta), /tamaño/);
});

test('sin tolerancia declarada, un solo nivel de diferencia ya es otra imagen', () => {
  assert.equal(mismaImagen({ pixeles: 0, niveles: 0 }), true);
  assert.equal(mismaImagen({ pixeles: 1, niveles: 1 }), false);
});

test('la tolerancia de un caso limita los píxeles y los niveles a la vez', () => {
  const tolerancia = { pixeles: 1, niveles: 1 };
  assert.equal(mismaImagen({ pixeles: 1, niveles: 1 }, tolerancia), true);
  assert.equal(mismaImagen({ pixeles: 2, niveles: 1 }, tolerancia), false);
  assert.equal(mismaImagen({ pixeles: 1, niveles: 2 }, tolerancia), false);
});
