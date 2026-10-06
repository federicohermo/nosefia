// Estimar cuánta memoria piden las texturas de WebGL, a partir de las llamadas que las definen.
//
// Es lo que decide `medir_memoria_de_texturas.mjs`. No toca el navegador ni el disco: recibe
// cada llamada ya resumida, con su contexto, la textura enlazada y sus argumentos numéricos, y
// lleva la cuenta de qué imágenes siguen vivas.
//
// Una imagen es un nivel de una cara de una textura. El total cuenta cada una una sola vez.
// El tamaño es el nominal del formato: el driver puede alinear, convertir o guardar copias, y
// eso no se ve desde las llamadas.

export const NO_MIDE = ['VRAM física', 'renderbuffers', 'memoria del driver', 'copias en CPU'];

export const FASES = ['menu', 'almacen'];

const CARA_X_POSITIVA = 0x8515;
const TIPO_POR_DESTINO = new Map([
  [0x0de1, '2D'],
  [0x806f, '3D'],
  [0x8513, 'cubo'],
  [0x8c1a, 'array 2D'],
]);

/** El parámetro que contesta qué textura está enlazada en cada destino. */
export const ENLACE_POR_DESTINO = {
  0x0de1: 0x8069,
  0x806f: 0x806a,
  0x8513: 0x8514,
  0x8c1a: 0x8c1d,
  ...Object.fromEntries([0, 1, 2, 3, 4, 5].map((cara) => [CARA_X_POSITIVA + cara, 0x8514])),
};

/** `TEXTURE_BASE_LEVEL` y `TEXTURE_MAX_LEVEL`: acotan lo que genera `generateMipmap`. */
export const NIVELES_DE_MIPS = [0x813c, 0x813d];

// La profundidad de 24 bits va en 4 bytes y la de 32 con stencil en 8: ninguna GPU las guarda
// más apretadas.
const BYTES_POR_PIXEL = new Map([
  [0x8229, ['R8', 1]],
  [0x8f94, ['R8_SNORM', 1]],
  [0x8232, ['R8UI', 1]],
  [0x8231, ['R8I', 1]],
  [0x822a, ['R16', 2]],
  [0x822d, ['R16F', 2]],
  [0x8234, ['R16UI', 2]],
  [0x8233, ['R16I', 2]],
  [0x822e, ['R32F', 4]],
  [0x8236, ['R32UI', 4]],
  [0x8235, ['R32I', 4]],
  [0x822b, ['RG8', 2]],
  [0x8f95, ['RG8_SNORM', 2]],
  [0x8238, ['RG8UI', 2]],
  [0x8237, ['RG8I', 2]],
  [0x822c, ['RG16', 4]],
  [0x822f, ['RG16F', 4]],
  [0x823a, ['RG16UI', 4]],
  [0x8239, ['RG16I', 4]],
  [0x8230, ['RG32F', 8]],
  [0x823c, ['RG32UI', 8]],
  [0x823b, ['RG32I', 8]],
  [0x8051, ['RGB8', 3]],
  [0x8c41, ['SRGB8', 3]],
  [0x8f96, ['RGB8_SNORM', 3]],
  [0x8d7d, ['RGB8UI', 3]],
  [0x8d8f, ['RGB8I', 3]],
  [0x8d62, ['RGB565', 2]],
  [0x8c3a, ['R11F_G11F_B10F', 4]],
  [0x8c3d, ['RGB9_E5', 4]],
  [0x8054, ['RGB16', 6]],
  [0x881b, ['RGB16F', 6]],
  [0x8d77, ['RGB16UI', 6]],
  [0x8d89, ['RGB16I', 6]],
  [0x8815, ['RGB32F', 12]],
  [0x8d71, ['RGB32UI', 12]],
  [0x8d83, ['RGB32I', 12]],
  [0x8058, ['RGBA8', 4]],
  [0x8c43, ['SRGB8_ALPHA8', 4]],
  [0x8f97, ['RGBA8_SNORM', 4]],
  [0x8d7c, ['RGBA8UI', 4]],
  [0x8d8e, ['RGBA8I', 4]],
  [0x8057, ['RGB5_A1', 2]],
  [0x8056, ['RGBA4', 2]],
  [0x8059, ['RGB10_A2', 4]],
  [0x906f, ['RGB10_A2UI', 4]],
  [0x805b, ['RGBA16', 8]],
  [0x881a, ['RGBA16F', 8]],
  [0x8d76, ['RGBA16UI', 8]],
  [0x8d88, ['RGBA16I', 8]],
  [0x8814, ['RGBA32F', 16]],
  [0x8d70, ['RGBA32UI', 16]],
  [0x8d82, ['RGBA32I', 16]],
  [0x81a5, ['DEPTH_COMPONENT16', 2]],
  [0x81a6, ['DEPTH_COMPONENT24', 4]],
  [0x8cac, ['DEPTH_COMPONENT32F', 4]],
  [0x88f0, ['DEPTH24_STENCIL8', 4]],
  [0x8cad, ['DEPTH32F_STENCIL8', 8]],
]);

// Un formato sin tamaño lo fija el tipo de sus datos.
const BYTES_POR_PIXEL_SEGUN_EL_TIPO = new Map(
  [
    [0x1906, 0x1401, 'ALPHA/UNSIGNED_BYTE', 1],
    [0x1909, 0x1401, 'LUMINANCE/UNSIGNED_BYTE', 1],
    [0x190a, 0x1401, 'LUMINANCE_ALPHA/UNSIGNED_BYTE', 2],
    [0x1907, 0x1401, 'RGB/UNSIGNED_BYTE', 3],
    [0x1907, 0x8363, 'RGB/UNSIGNED_SHORT_5_6_5', 2],
    [0x1908, 0x1401, 'RGBA/UNSIGNED_BYTE', 4],
    [0x1908, 0x8033, 'RGBA/UNSIGNED_SHORT_4_4_4_4', 2],
    [0x1908, 0x8034, 'RGBA/UNSIGNED_SHORT_5_5_5_1', 2],
  ].map(([formato, tipo, nombre, bytes]) => [`${formato}/${tipo}`, [nombre, bytes]])
);

// Nombre, ancho y alto del bloque, y bytes por bloque.
const BLOQUES = new Map([
  [0x83f0, ['COMPRESSED_RGB_S3TC_DXT1_EXT', 4, 4, 8]],
  [0x83f1, ['COMPRESSED_RGBA_S3TC_DXT1_EXT', 4, 4, 8]],
  [0x83f2, ['COMPRESSED_RGBA_S3TC_DXT3_EXT', 4, 4, 16]],
  [0x83f3, ['COMPRESSED_RGBA_S3TC_DXT5_EXT', 4, 4, 16]],
  [0x8c4c, ['COMPRESSED_SRGB_S3TC_DXT1_EXT', 4, 4, 8]],
  [0x8c4d, ['COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT', 4, 4, 8]],
  [0x8c4e, ['COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT', 4, 4, 16]],
  [0x8c4f, ['COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT', 4, 4, 16]],
  [0x8dbb, ['COMPRESSED_RED_RGTC1_EXT', 4, 4, 8]],
  [0x8dbc, ['COMPRESSED_SIGNED_RED_RGTC1_EXT', 4, 4, 8]],
  [0x8dbd, ['COMPRESSED_RED_GREEN_RGTC2_EXT', 4, 4, 16]],
  [0x8dbe, ['COMPRESSED_SIGNED_RED_GREEN_RGTC2_EXT', 4, 4, 16]],
  [0x8e8c, ['COMPRESSED_RGBA_BPTC_UNORM_EXT', 4, 4, 16]],
  [0x8e8d, ['COMPRESSED_SRGB_ALPHA_BPTC_UNORM_EXT', 4, 4, 16]],
  [0x8e8e, ['COMPRESSED_RGB_BPTC_SIGNED_FLOAT_EXT', 4, 4, 16]],
  [0x8e8f, ['COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT_EXT', 4, 4, 16]],
  [0x8d64, ['COMPRESSED_RGB_ETC1_WEBGL', 4, 4, 8]],
  [0x9270, ['COMPRESSED_R11_EAC', 4, 4, 8]],
  [0x9271, ['COMPRESSED_SIGNED_R11_EAC', 4, 4, 8]],
  [0x9272, ['COMPRESSED_RG11_EAC', 4, 4, 16]],
  [0x9273, ['COMPRESSED_SIGNED_RG11_EAC', 4, 4, 16]],
  [0x9274, ['COMPRESSED_RGB8_ETC2', 4, 4, 8]],
  [0x9275, ['COMPRESSED_SRGB8_ETC2', 4, 4, 8]],
  [0x9276, ['COMPRESSED_RGB8_PUNCHTHROUGH_ALPHA1_ETC2', 4, 4, 8]],
  [0x9277, ['COMPRESSED_SRGB8_PUNCHTHROUGH_ALPHA1_ETC2', 4, 4, 8]],
  [0x9278, ['COMPRESSED_RGBA8_ETC2_EAC', 4, 4, 16]],
  [0x9279, ['COMPRESSED_SRGB8_ALPHA8_ETC2_EAC', 4, 4, 16]],
]);

// Los catorce tamaños de bloque de ASTC van seguidos, y la variante sRGB arranca 0x20 después.
[
  [4, 4],
  [5, 4],
  [5, 5],
  [6, 5],
  [6, 6],
  [8, 5],
  [8, 6],
  [8, 8],
  [10, 5],
  [10, 6],
  [10, 8],
  [10, 10],
  [12, 10],
  [12, 12],
].forEach(([ancho, alto], indice) => {
  const bloque = `ASTC_${ancho}x${alto}_KHR`;
  BLOQUES.set(0x93b0 + indice, [`COMPRESSED_RGBA_${bloque}`, ancho, alto, 16]);
  BLOQUES.set(0x93d0 + indice, [`COMPRESSED_SRGB8_ALPHA8_${bloque}`, ancho, alto, 16]);
});

function formatoConocido(formato, tipo) {
  const porPixel =
    BYTES_POR_PIXEL.get(formato) ?? BYTES_POR_PIXEL_SEGUN_EL_TIPO.get(`${formato}/${tipo}`);
  if (porPixel) {
    return { nombre: porPixel[0], bytes: (ancho, alto) => ancho * alto * porPixel[1] };
  }
  const bloque = BLOQUES.get(formato);
  if (!bloque) return null;
  const [nombre, anchoDelBloque, altoDelBloque, bytesDelBloque] = bloque;
  return {
    nombre,
    bytes: (ancho, alto) =>
      Math.ceil(ancho / anchoDelBloque) * Math.ceil(alto / altoDelBloque) * bytesDelBloque,
  };
}

/** Los bytes de una imagen, o `null` si el formato no está en las tablas. */
export function bytesDeImagen({ formato, tipo, ancho, alto, profundidad = 1 }) {
  const conocido = formatoConocido(formato, tipo);
  return conocido ? conocido.bytes(ancho, alto) * profundidad : null;
}

function nombreDeFormato(formato, tipo) {
  const hex = (codigo) => `0x${codigo.toString(16)}`;
  return (
    formatoConocido(formato, tipo)?.nombre ??
    (tipo == null ? hex(formato) : `${hex(formato)}/${hex(tipo)}`)
  );
}

export function crearRegistro() {
  return { texturas: new Map(), perdidos: new Set() };
}

function definir(textura, destino, nivel, imagen) {
  const esCara = destino >= CARA_X_POSITIVA && destino < CARA_X_POSITIVA + 6;
  const cara = esCara ? destino - CARA_X_POSITIVA : 0;
  textura.tipo = esCara ? 'cubo' : TIPO_POR_DESTINO.get(destino);
  textura.imagenes.set(`${cara}:${nivel}`, { cara, nivel, ...imagen });
}

function reducida(imagen, pasos, tipo) {
  const mitad = (lado) => Math.max(1, lado >> pasos);
  return {
    ...imagen,
    ancho: mitad(imagen.ancho),
    alto: mitad(imagen.alto),
    // Un array conserva sus capas en todos los niveles.
    profundidad: tipo === '3D' ? mitad(imagen.profundidad) : imagen.profundidad,
  };
}

function almacenar(textura, destino, niveles, imagen) {
  const tipo = TIPO_POR_DESTINO.get(destino);
  const caras = tipo === 'cubo' ? 6 : 1;
  textura.inmutable = true;
  textura.imagenes.clear();
  for (let cara = 0; cara < caras; cara++) {
    for (let nivel = 0; nivel < niveles; nivel++) {
      const destinoDeLaCara = tipo === 'cubo' ? CARA_X_POSITIVA + cara : destino;
      definir(textura, destinoDeLaCara, nivel, reducida(imagen, nivel, tipo));
    }
  }
}

function generarMips(textura, nivelBase, nivelMaximo) {
  // Un almacenamiento fijo ya reservó todos sus niveles: generar sólo los rellena.
  if (textura.inmutable) return;
  const bases = [...textura.imagenes.values()].filter((imagen) => imagen.nivel === nivelBase);
  for (const base of bases) {
    const lados = [base.ancho, base.alto, textura.tipo === '3D' ? base.profundidad : 1];
    const ultimo = Math.min(nivelBase + Math.floor(Math.log2(Math.max(...lados))), nivelMaximo);
    for (let nivel = nivelBase + 1; nivel <= ultimo; nivel++) {
      const imagen = { ...reducida(base, nivel - nivelBase, textura.tipo), nivel };
      textura.imagenes.set(`${base.cara}:${nivel}`, imagen);
    }
  }
}

// Los argumentos de cada llamada, en el orden de WebGL2 y sin los píxeles.
const DEFINEN = {
  texImage2D(textura, args) {
    const [destino, nivel, formato] = args;
    // La forma corta toma las dimensiones de un elemento de la página.
    const deUnElemento = args.length === 6;
    const [ancho, alto, tipo] = deUnElemento
      ? [args[5].ancho, args[5].alto, args[4]]
      : [args[3], args[4], args[7]];
    definir(textura, destino, nivel, { formato, tipo, ancho, alto, profundidad: 1 });
  },
  texImage3D(textura, [destino, nivel, formato, ancho, alto, profundidad, , , tipo]) {
    definir(textura, destino, nivel, { formato, tipo, ancho, alto, profundidad });
  },
  compressedTexImage2D(textura, [destino, nivel, formato, ancho, alto]) {
    definir(textura, destino, nivel, { formato, ancho, alto, profundidad: 1 });
  },
  compressedTexImage3D(textura, [destino, nivel, formato, ancho, alto, profundidad]) {
    definir(textura, destino, nivel, { formato, ancho, alto, profundidad });
  },
  copyTexImage2D(textura, [destino, nivel, formato, , , ancho, alto]) {
    definir(textura, destino, nivel, { formato, ancho, alto, profundidad: 1 });
  },
  texStorage2D(textura, [destino, niveles, formato, ancho, alto]) {
    almacenar(textura, destino, niveles, { formato, ancho, alto, profundidad: 1 });
  },
  texStorage3D(textura, [destino, niveles, formato, ancho, alto, profundidad]) {
    almacenar(textura, destino, niveles, { formato, ancho, alto, profundidad });
  },
  // El medidor agrega los dos niveles que acotan la generación: ver `NIVELES_DE_MIPS`.
  generateMipmap(textura, [, nivelBase, nivelMaximo]) {
    generarMips(textura, nivelBase, nivelMaximo);
  },
};

const ACTUALIZAN_UNA_REGION = [
  'texSubImage2D',
  'texSubImage3D',
  'compressedTexSubImage2D',
  'compressedTexSubImage3D',
  'copyTexSubImage2D',
  'copyTexSubImage3D',
];

/** Las llamadas que el medidor tiene que anotar. */
export const METODOS = [...Object.keys(DEFINEN), ...ACTUALIZAN_UNA_REGION, 'deleteTexture'];

/**
 * Anota una llamada: `{ contexto, textura, metodo, args }`.
 *
 * `textura` es la que estaba enlazada en el destino de la llamada, o la que se borra. Una
 * llamada sin textura no define nada: WebGL también la rechaza.
 */
export function aplicar(registro, { contexto, textura, metodo, args }) {
  if (!METODOS.includes(metodo)) throw new Error(`llamada sin contemplar: ${metodo}`);
  if (textura == null || registro.perdidos.has(contexto)) return;
  const clave = `${contexto}:${textura}`;
  if (metodo === 'deleteTexture') {
    registro.texturas.delete(clave);
    return;
  }
  if (!DEFINEN[metodo]) return;
  const entrada = registro.texturas.get(clave) ?? { contexto, textura, imagenes: new Map() };
  DEFINEN[metodo](entrada, args);
  if (entrada.imagenes.size) registro.texturas.set(clave, entrada);
}

/** Las texturas de un contexto perdido ya no existen, y lo que el juego recree no se ve. */
export function perderContexto(registro, contexto) {
  registro.perdidos.add(contexto);
  for (const [clave, textura] of registro.texturas) {
    if (textura.contexto === contexto) registro.texturas.delete(clave);
  }
}

/** El inventario de las texturas vivas, con sus totales y lo que quedó sin medir. */
export function inventario(registro) {
  const sinMedida = new Map();
  const texturas = [];
  for (const { contexto, textura, tipo, imagenes } of registro.texturas.values()) {
    const todas = [...imagenes.values()];
    const base = todas.reduce((menor, imagen) => (imagen.nivel < menor.nivel ? imagen : menor));
    let bytes = 0;
    for (const imagen of todas) {
      const deLaImagen = bytesDeImagen(imagen);
      if (deLaImagen === null) {
        const formato = nombreDeFormato(imagen.formato, imagen.tipo);
        sinMedida.set(formato, (sinMedida.get(formato) ?? 0) + 1);
        bytes = null;
      } else if (bytes !== null) {
        bytes += deLaImagen;
      }
    }
    texturas.push({
      contexto,
      textura,
      tipo,
      ancho: base.ancho,
      alto: base.alto,
      formato: nombreDeFormato(base.formato, base.tipo),
      mips: new Set(todas.map((imagen) => imagen.nivel)).size,
      capas: base.profundidad,
      caras: new Set(todas.map((imagen) => imagen.cara)).size,
      bytes_estimados: bytes,
    });
  }
  texturas.sort(
    (a, b) =>
      (b.bytes_estimados ?? -1) - (a.bytes_estimados ?? -1) ||
      a.contexto - b.contexto ||
      a.textura - b.textura
  );
  const total = texturas.reduce((suma, fila) => suma + (fila.bytes_estimados ?? 0), 0);
  return {
    cantidad: texturas.length,
    bytes_estimados: total,
    MiB_estimados: Number((total / 2 ** 20).toFixed(2)),
    cobertura_completa: sinMedida.size === 0 && registro.perdidos.size === 0,
    formatos_desconocidos: [...sinMedida].map(([formato, cuantas]) => ({
      formato,
      imagenes: cuantas,
    })),
    contextos_perdidos: [...registro.perdidos],
    texturas,
  };
}

export function esRenderizadoPorSoftware(renderer) {
  return !renderer || /swiftshader|llvmpipe|software|basic render driver|warp/i.test(renderer);
}

/**
 * Por qué una corrida no sirve como informe. Vacío si sirve.
 *
 * `corte` es el motivo por el que la corrida paró antes de terminar. Ahí lo que no llegó a
 * medirse no se juzga: sería repetir el corte con otras palabras.
 */
export function motivosDeRechazo({ corte = null, motor, errores, fases }) {
  const delJuego = errores.map((error) => `error del juego: ${error}`);
  if (corte) return [corte, ...delJuego];
  const motivos = [];
  if (!motor) motivos.push('el juego no anunció la versión del motor');
  for (const fase of FASES) {
    if (!fases[fase]) motivos.push(`falta la fase «${fase}»`);
  }
  return [...motivos, ...delJuego];
}
