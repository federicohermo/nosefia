// Los casos de `lib/memoria_de_texturas.mjs`.
//
//     node --test .github/scripts/tests/memoria_de_texturas_test.mjs
//
// Los códigos de WebGL van escritos acá y no se importan del módulo: un código mal copiado en
// su tabla tiene que dar rojo.

import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  NO_MIDE,
  aplicar,
  bytesDeImagen,
  crearRegistro,
  esRenderizadoPorSoftware,
  inventario,
  motivosDeRechazo,
  perderContexto,
} from '../lib/memoria_de_texturas.mjs';

const TEXTURE_2D = 0x0de1;
const TEXTURE_3D = 0x806f;
const TEXTURE_CUBE_MAP = 0x8513;
const CARA_X_POSITIVA = 0x8515;
const TEXTURE_2D_ARRAY = 0x8c1a;

const RGB = 0x1907;
const RGBA = 0x1908;
const LUMINANCE = 0x1909;
const RGBA_INTEGER = 0x8d99;
const UNSIGNED_BYTE = 0x1401;
const UNSIGNED_SHORT_5_6_5 = 0x8363;
const FLOAT = 0x1406;

const R8 = 0x8229;
const RGBA8 = 0x8058;
const RGBA8UI = 0x8d7c;
const RGBA16F = 0x881a;
const DXT1 = 0x83f1;
const DXT5 = 0x83f3;
const RGTC1 = 0x8dbb;
const BPTC = 0x8e8c;
const ETC2_RGBA8 = 0x9278;
const ASTC_6X6 = 0x93b4;
const FORMATO_INVENTADO = 0x9999;

const GPU = 'ANGLE (NVIDIA, NVIDIA GeForce RTX 4050 Laptop GPU Direct3D11 vs_5_0 ps_5_0, D3D11)';

/** Un registro después de las llamadas dadas, todas del contexto 1 salvo que digan otro. */
function tras(...llamadas) {
  const registro = crearRegistro();
  for (const llamada of llamadas) aplicar(registro, { contexto: 1, ...llamada });
  return registro;
}

function imagen2D(textura, nivel, formato, ancho, alto) {
  return {
    textura,
    metodo: 'texImage2D',
    args: [TEXTURE_2D, nivel, formato, ancho, alto, 0, RGBA, UNSIGNED_BYTE, null],
  };
}

function bytes(formato, ancho, alto, tipo) {
  return bytesDeImagen({ formato, tipo, ancho, alto });
}

// --- bytes por formato ---

test('un formato sin comprimir pesa sus bytes por píxel', () => {
  assert.equal(bytes(RGBA8, 4, 4), 64);
  assert.equal(bytes(R8, 4, 4), 16);
  assert.equal(bytes(RGBA16F, 2, 2), 32);
});

test('una RGBA8UI de 4 × 4 pesa 64 bytes', () => {
  assert.equal(bytes(RGBA8UI, 4, 4), 64);
  const registro = tras({
    textura: 1,
    metodo: 'texImage2D',
    args: [TEXTURE_2D, 0, RGBA8UI, 4, 4, 0, RGBA_INTEGER, UNSIGNED_BYTE, null],
  });
  assert.equal(inventario(registro).texturas[0].formato, 'RGBA8UI');
  assert.equal(inventario(registro).bytes_estimados, 64);
});

test('un formato sin tamaño se mide por el tipo de sus datos', () => {
  assert.equal(bytes(RGBA, 4, 4, UNSIGNED_BYTE), 64);
  assert.equal(bytes(LUMINANCE, 4, 4, UNSIGNED_BYTE), 16);
  assert.equal(bytes(RGB, 4, 4, UNSIGNED_SHORT_5_6_5), 32);
});

test('un formato por bloques pesa por bloque, y el bloque incompleto cuenta entero', () => {
  assert.equal(bytes(DXT1, 8, 8), 32);
  assert.equal(bytes(DXT5, 16, 16), 256);
  assert.equal(bytes(DXT5, 5, 5), 64);
  assert.equal(bytes(DXT5, 1, 1), 16);
  assert.equal(bytes(RGTC1, 4, 4), 8);
  assert.equal(bytes(BPTC, 4, 4), 16);
  assert.equal(bytes(ETC2_RGBA8, 8, 4), 32);
});

test('un formato ASTC cuenta bloques del tamaño que declara', () => {
  assert.equal(bytes(ASTC_6X6, 12, 12), 64);
  assert.equal(bytes(ASTC_6X6, 13, 12), 96);
});

test('un megabyte de píxeles da un MiB', () => {
  const fase = inventario(tras(imagen2D(1, 0, RGBA8, 512, 512)));
  assert.equal(fase.bytes_estimados, 1_048_576);
  assert.equal(fase.MiB_estimados, 1);
  const otra = inventario(tras(imagen2D(1, 0, RGBA8, 1000, 1000)));
  assert.equal(otra.MiB_estimados, 3.81);
});

// --- mips ---

test('cada nivel definido a mano suma una vez', () => {
  const fase = inventario(
    tras(imagen2D(7, 0, RGBA8, 4, 4), imagen2D(7, 1, RGBA8, 2, 2), imagen2D(7, 2, RGBA8, 1, 1))
  );
  assert.deepEqual(fase.texturas, [
    {
      contexto: 1,
      textura: 7,
      tipo: '2D',
      ancho: 4,
      alto: 4,
      formato: 'RGBA8',
      mips: 3,
      capas: 1,
      caras: 1,
      bytes_estimados: 84,
    },
  ]);
  assert.equal(fase.cantidad, 1);
  assert.equal(fase.bytes_estimados, 84);
});

test('generar los mips baja hasta 1 × 1, también con lados desparejos', () => {
  const fase = inventario(
    tras(imagen2D(1, 0, RGBA8, 5, 3), {
      textura: 1,
      metodo: 'generateMipmap',
      args: [TEXTURE_2D, 0, 1000],
    })
  );
  // 5 × 3, 2 × 1 y 1 × 1.
  assert.equal(fase.texturas[0].mips, 3);
  assert.equal(fase.bytes_estimados, (15 + 2 + 1) * 4);
});

test('generar los mips no pasa del nivel máximo de la textura', () => {
  const fase = inventario(
    tras(imagen2D(1, 0, RGBA8, 8, 8), {
      textura: 1,
      metodo: 'generateMipmap',
      args: [TEXTURE_2D, 0, 1],
    })
  );
  assert.equal(fase.texturas[0].mips, 2);
  assert.equal(fase.bytes_estimados, (64 + 16) * 4);
});

test('un almacenamiento fijo reserva todos sus niveles', () => {
  const almacenada = { textura: 1, metodo: 'texStorage2D', args: [TEXTURE_2D, 4, RGBA8, 8, 8] };
  const fase = inventario(tras(almacenada));
  assert.equal(fase.texturas[0].mips, 4);
  assert.equal(fase.bytes_estimados, (64 + 16 + 4 + 1) * 4);
  const conMips = inventario(
    tras(almacenada, { textura: 1, metodo: 'generateMipmap', args: [TEXTURE_2D, 0, 1000] })
  );
  assert.equal(conMips.bytes_estimados, fase.bytes_estimados);
});

test('un nivel comprimido reemplazado no se suma dos veces', () => {
  const nivel = (ancho) => ({
    textura: 1,
    metodo: 'compressedTexImage2D',
    args: [TEXTURE_2D, 1, DXT5, ancho, ancho, 0, null],
  });
  assert.equal(inventario(tras(nivel(8), nivel(4))).bytes_estimados, 16);
});

// --- capas y caras ---

test('un cubemap cuenta sus seis caras como una sola textura', () => {
  const caras = [0, 1, 2, 3, 4, 5].map((cara) => ({
    textura: 3,
    metodo: 'texImage2D',
    args: [CARA_X_POSITIVA + cara, 0, RGBA8, 4, 4, 0, RGBA, UNSIGNED_BYTE, null],
  }));
  const fase = inventario(tras(...caras));
  assert.equal(fase.cantidad, 1);
  assert.equal(fase.texturas[0].tipo, 'cubo');
  assert.equal(fase.texturas[0].caras, 6);
  assert.equal(fase.bytes_estimados, 6 * 64);
});

test('un cubemap de almacenamiento fijo reserva cada nivel en las seis caras', () => {
  const fase = inventario(
    tras({ textura: 3, metodo: 'texStorage2D', args: [TEXTURE_CUBE_MAP, 2, RGBA8, 4, 4] })
  );
  assert.equal(fase.texturas[0].caras, 6);
  assert.equal(fase.texturas[0].mips, 2);
  assert.equal(fase.bytes_estimados, 6 * (16 + 4) * 4);
});

test('generar los mips de un cubemap los genera en cada cara', () => {
  const caras = [0, 1, 2, 3, 4, 5].map((cara) => ({
    textura: 3,
    metodo: 'texImage2D',
    args: [CARA_X_POSITIVA + cara, 0, RGBA8, 2, 2, 0, RGBA, UNSIGNED_BYTE, null],
  }));
  const fase = inventario(
    tras(...caras, { textura: 3, metodo: 'generateMipmap', args: [TEXTURE_CUBE_MAP, 0, 1000] })
  );
  assert.equal(fase.bytes_estimados, 6 * (4 + 1) * 4);
});

test('un array conserva sus capas en cada nivel', () => {
  const fase = inventario(
    tras({ textura: 4, metodo: 'texStorage3D', args: [TEXTURE_2D_ARRAY, 2, RGBA8, 4, 4, 3] })
  );
  assert.equal(fase.texturas[0].tipo, 'array 2D');
  assert.equal(fase.texturas[0].capas, 3);
  assert.equal(fase.bytes_estimados, (16 * 3 + 4 * 3) * 4);
});

test('una textura 3D achica también su profundidad', () => {
  const fase = inventario(
    tras({ textura: 4, metodo: 'texStorage3D', args: [TEXTURE_3D, 2, RGBA8, 4, 4, 4] })
  );
  assert.equal(fase.texturas[0].tipo, '3D');
  assert.equal(fase.bytes_estimados, (64 + 8) * 4);
});

test('un array comprimido pesa sus bloques por capa', () => {
  const fase = inventario(
    tras({
      textura: 4,
      metodo: 'compressedTexImage3D',
      args: [TEXTURE_2D_ARRAY, 0, DXT5, 8, 8, 2, 0, null],
    })
  );
  assert.equal(fase.texturas[0].capas, 2);
  assert.equal(fase.bytes_estimados, 4 * 16 * 2);
});

test('un array definido nivel por nivel lee el tipo de sus datos', () => {
  const fase = inventario(
    tras({
      textura: 4,
      metodo: 'texImage3D',
      args: [TEXTURE_2D_ARRAY, 0, RGBA, 4, 4, 5, 0, RGBA, UNSIGNED_BYTE, null],
    })
  );
  assert.equal(fase.bytes_estimados, 16 * 5 * 4);
});

// --- ciclo de vida ---

test('sin texturas, el total es cero y la cobertura es completa', () => {
  assert.deepEqual(inventario(crearRegistro()), {
    cantidad: 0,
    bytes_estimados: 0,
    MiB_estimados: 0,
    cobertura_completa: true,
    formatos_desconocidos: [],
    contextos_perdidos: [],
    texturas: [],
  });
});

test('volver a definir la misma imagen no duplica su almacenamiento', () => {
  const fase = inventario(tras(imagen2D(1, 0, RGBA8, 4, 4), imagen2D(1, 0, RGBA8, 4, 4)));
  assert.equal(fase.cantidad, 1);
  assert.equal(fase.bytes_estimados, 64);
});

test('actualizar una región no cambia el almacenamiento', () => {
  const actualizaciones = [
    ['texSubImage2D', [TEXTURE_2D, 0, 0, 0, 2, 2, RGBA, UNSIGNED_BYTE, null]],
    ['compressedTexSubImage2D', [TEXTURE_2D, 0, 0, 0, 4, 4, DXT5, null]],
    ['copyTexSubImage2D', [TEXTURE_2D, 0, 0, 0, 0, 0, 2, 2]],
    ['texSubImage3D', [TEXTURE_2D, 0, 0, 0, 0, 2, 2, 1, RGBA, UNSIGNED_BYTE, null]],
    ['compressedTexSubImage3D', [TEXTURE_2D, 0, 0, 0, 0, 4, 4, 1, DXT5, null]],
    ['copyTexSubImage3D', [TEXTURE_2D, 0, 0, 0, 0, 0, 0, 2, 2]],
  ].map(([metodo, args]) => ({ textura: 1, metodo, args }));
  const fase = inventario(tras(imagen2D(1, 0, RGBA8, 4, 4), ...actualizaciones));
  assert.equal(fase.cantidad, 1);
  assert.equal(fase.bytes_estimados, 64);
});

test('actualizar una textura que nunca se definió no la inventa', () => {
  const fase = inventario(
    tras({
      textura: 1,
      metodo: 'texSubImage2D',
      args: [TEXTURE_2D, 0, 0, 0, 2, 2, RGBA, UNSIGNED_BYTE, null],
    })
  );
  assert.equal(fase.cantidad, 0);
});

test('redefinir una imagen reemplaza su tamaño', () => {
  const fase = inventario(tras(imagen2D(1, 0, RGBA8, 4, 4), imagen2D(1, 0, RGBA8, 8, 8)));
  assert.equal(fase.texturas[0].ancho, 8);
  assert.equal(fase.bytes_estimados, 256);
});

test('borrar una textura la retira del total', () => {
  const fase = inventario(
    tras(imagen2D(1, 0, RGBA8, 4, 4), imagen2D(2, 0, RGBA8, 2, 2), {
      textura: 1,
      metodo: 'deleteTexture',
      args: [null],
    })
  );
  assert.deepEqual(
    fase.texturas.map((fila) => fila.textura),
    [2]
  );
  assert.equal(fase.bytes_estimados, 16);
});

test('una textura recreada después de borrada cuenta una sola vez', () => {
  const fase = inventario(
    tras(
      imagen2D(1, 0, RGBA8, 4, 4),
      { textura: 1, metodo: 'deleteTexture', args: [null] },
      imagen2D(2, 0, RGBA8, 4, 4)
    )
  );
  assert.equal(fase.cantidad, 1);
  assert.equal(fase.bytes_estimados, 64);
});

test('la misma textura en dos contextos son dos texturas', () => {
  const registro = tras(imagen2D(1, 0, RGBA8, 4, 4));
  aplicar(registro, { contexto: 2, ...imagen2D(1, 0, RGBA8, 4, 4) });
  assert.equal(inventario(registro).cantidad, 2);
  assert.equal(inventario(registro).bytes_estimados, 128);
});

test('una textura sin datos, como un destino de renderizado, entra en la estimación', () => {
  const fase = inventario(tras(imagen2D(1, 0, RGBA8, 1536, 760)));
  assert.equal(fase.bytes_estimados, 1536 * 760 * 4);
});

test('una imagen que sale de un elemento de la página toma sus dimensiones', () => {
  const fase = inventario(
    tras({
      textura: 1,
      metodo: 'texImage2D',
      args: [TEXTURE_2D, 0, RGBA, RGBA, UNSIGNED_BYTE, { ancho: 8, alto: 2 }],
    })
  );
  assert.equal(fase.bytes_estimados, 64);
});

test('una imagen copiada del framebuffer toma el tamaño de la copia', () => {
  const fase = inventario(
    tras({ textura: 1, metodo: 'copyTexImage2D', args: [TEXTURE_2D, 0, RGBA8, 10, 20, 4, 2, 0] })
  );
  assert.equal(fase.bytes_estimados, 32);
});

test('una llamada sin textura enlazada no define nada', () => {
  assert.equal(inventario(tras(imagen2D(null, 0, RGBA8, 4, 4))).cantidad, 0);
});

test('una llamada que el módulo no contempla falla en vez de perderse', () => {
  assert.throws(
    () => tras({ textura: 1, metodo: 'texImagenNueva', args: [] }),
    /texImagenNueva/
  );
});

test('las texturas salen ordenadas de la más pesada a la más liviana', () => {
  const fase = inventario(
    tras(imagen2D(1, 0, RGBA8, 2, 2), imagen2D(2, 0, RGBA8, 8, 8), imagen2D(3, 0, RGBA8, 4, 4))
  );
  assert.deepEqual(
    fase.texturas.map((fila) => fila.textura),
    [2, 3, 1]
  );
});

// --- cobertura ---

test('un formato desconocido queda sin medida y no suma cero', () => {
  const fase = inventario(
    tras(imagen2D(1, 0, RGBA8, 4, 4), {
      textura: 2,
      metodo: 'compressedTexImage2D',
      args: [TEXTURE_2D, 0, FORMATO_INVENTADO, 4, 4, 0, null],
    })
  );
  const desconocida = fase.texturas.find((fila) => fila.textura === 2);
  assert.equal(desconocida.bytes_estimados, null);
  assert.equal(desconocida.formato, '0x9999');
  assert.equal(fase.bytes_estimados, 64);
  assert.deepEqual(fase.formatos_desconocidos, [{ formato: '0x9999', imagenes: 1 }]);
  assert.equal(fase.cobertura_completa, false);
});

test('un formato sin tamaño con un tipo que no se conoce queda sin medida', () => {
  assert.equal(bytes(RGBA, 4, 4, FLOAT), null);
  const fase = inventario(
    tras({
      textura: 1,
      metodo: 'texImage2D',
      args: [TEXTURE_2D, 0, RGBA, 4, 4, 0, RGBA, FLOAT, null],
    })
  );
  assert.deepEqual(fase.formatos_desconocidos, [{ formato: '0x1908/0x1406', imagenes: 1 }]);
  assert.equal(fase.cobertura_completa, false);
});

test('un contexto perdido deja la cobertura incompleta y sus texturas afuera', () => {
  const registro = tras(imagen2D(1, 0, RGBA8, 4, 4));
  aplicar(registro, { contexto: 2, ...imagen2D(1, 0, RGBA8, 2, 2) });
  perderContexto(registro, 1);
  aplicar(registro, { contexto: 1, ...imagen2D(5, 0, RGBA8, 4, 4) });
  const fase = inventario(registro);
  assert.equal(fase.bytes_estimados, 16);
  assert.deepEqual(fase.contextos_perdidos, [1]);
  assert.equal(fase.cobertura_completa, false);
});

test('el informe declara que un renderbuffer no entra', () => {
  assert.ok(NO_MIDE.includes('renderbuffers'));
});

// --- rechazos ---

const FASES_COMPLETAS = { menu: inventario(crearRegistro()), almacen: inventario(crearRegistro()) };
const CORRIDA_SANA = { motor: '4.7.2.stable', errores: [], fases: FASES_COMPLETAS };

test('una corrida sana no tiene motivos de rechazo', () => {
  assert.deepEqual(motivosDeRechazo(CORRIDA_SANA), []);
});

test('se reconoce el renderizado por software y la GPU sin identificar', () => {
  const swiftshader =
    'ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver)';
  for (const renderer of [swiftshader, 'Microsoft Basic Render Driver', 'llvmpipe', null]) {
    assert.equal(esRenderizadoPorSoftware(renderer), true, String(renderer));
  }
  assert.equal(esRenderizadoPorSoftware(GPU), false);
});

test('una corrida cortada informa el corte y lo que dijo el juego, y nada más', () => {
  const motivos = motivosDeRechazo({
    corte: 'no llegó el aviso del menú en 180 s',
    motor: null,
    errores: ['SCRIPT ERROR: se rompió'],
    fases: {},
  });
  assert.equal(motivos.length, 2);
  assert.match(motivos[0], /aviso del menú/);
  assert.match(motivos[1], /se rompió/);
});

test('se rechaza una fase faltante, y se dice cuál', () => {
  const motivos = motivosDeRechazo({ ...CORRIDA_SANA, fases: { menu: FASES_COMPLETAS.menu } });
  assert.equal(motivos.length, 1);
  assert.match(motivos[0], /almacen/);
});

test('se rechaza un error del juego, con su texto', () => {
  const motivos = motivosDeRechazo({ ...CORRIDA_SANA, errores: ['SCRIPT ERROR: se rompió'] });
  assert.equal(motivos.length, 1);
  assert.match(motivos[0], /se rompió/);
});

test('se rechaza un juego que no anuncia su motor', () => {
  const motivos = motivosDeRechazo({ ...CORRIDA_SANA, motor: null });
  assert.equal(motivos.length, 1);
  assert.match(motivos[0], /motor/);
});
