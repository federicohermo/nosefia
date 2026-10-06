// Lo que decide una medición de sombreado: qué cuadros valen y cuándo dos capturas son la misma.
//
// Es puro: recibe lo que el navegador contestó y no abre nada. Su test es
// `.github/scripts/tests/consultas_gpu_test.mjs`.

import { inflateSync } from 'node:zlib';

const FIRMA_DE_PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const CANALES_POR_TIPO_DE_COLOR = { 2: 3, 6: 4 };

// El tiempo de GPU de cada cuadro válido, en milisegundos.
//
// Cada consulta es `{ cuadro, ns, disjunta }`, y `ns` es `null` si su resultado no llegó. Un
// cuadro puede traer varias: el navegador llama a más de un `requestAnimationFrame` por cuadro.
// Una consulta disjunta mide un intervalo que la GPU interrumpió, y vuelve inservible la suma.
export function tiemposPorCuadro(consultas) {
  const cuadros = new Map();
  for (const { cuadro, ns, disjunta } of consultas) {
    const previo = cuadros.has(cuadro) ? cuadros.get(cuadro) : 0;
    cuadros.set(cuadro, disjunta || ns === null || previo === null ? null : previo + ns);
  }
  return [...cuadros.values()].filter((ns) => ns !== null).map((ns) => ns / 1e6);
}

export function mediana(valores) {
  if (!valores.length) throw new Error('sin muestras no hay mediana');
  const orden = [...valores].sort((a, b) => a - b);
  const medio = orden.length >> 1;
  return orden.length % 2 ? orden[medio] : (orden[medio - 1] + orden[medio]) / 2;
}

// Lee una captura de Chrome: 8 bits por canal, RGB o RGBA, sin entrelazar.
export function decodificarPng(bytes) {
  if (bytes.length < 8 || !FIRMA_DE_PNG.equals(bytes.subarray(0, 8))) {
    throw new Error('la captura no es un PNG');
  }
  let ancho = 0;
  let alto = 0;
  let canales;
  const comprimido = [];
  for (let desde = 8; desde < bytes.length; ) {
    const largo = bytes.readUInt32BE(desde);
    const tipo = bytes.toString('latin1', desde + 4, desde + 8);
    const datos = bytes.subarray(desde + 8, desde + 8 + largo);
    if (tipo === 'IHDR') {
      ancho = datos.readUInt32BE(0);
      alto = datos.readUInt32BE(4);
      canales = CANALES_POR_TIPO_DE_COLOR[datos[9]];
      if (datos[8] !== 8 || !canales || datos[12] !== 0) {
        throw new Error('la captura tiene un formato de PNG que este lector no decodifica');
      }
    } else if (tipo === 'IDAT') {
      comprimido.push(datos);
    }
    desde += 12 + largo;
  }
  const filtrado = inflateSync(Buffer.concat(comprimido));
  const fila = ancho * canales;
  const pixeles = new Uint8Array(alto * fila);
  for (let y = 0; y < alto; y++) {
    const filtro = filtrado[y * (fila + 1)];
    for (let x = 0; x < fila; x++) {
      const i = y * fila + x;
      const izquierda = x >= canales ? pixeles[i - canales] : 0;
      const arriba = y ? pixeles[i - fila] : 0;
      const diagonal = x >= canales && y ? pixeles[i - fila - canales] : 0;
      let previsto = 0;
      if (filtro === 1) previsto = izquierda;
      else if (filtro === 2) previsto = arriba;
      else if (filtro === 3) previsto = (izquierda + arriba) >> 1;
      else if (filtro === 4) previsto = paeth(izquierda, arriba, diagonal);
      pixeles[i] = filtrado[y * (fila + 1) + 1 + x] + previsto;
    }
  }
  return { ancho, alto, canales, pixeles };
}

function paeth(izquierda, arriba, diagonal) {
  const estimado = izquierda + arriba - diagonal;
  const aIzquierda = Math.abs(estimado - izquierda);
  const aArriba = Math.abs(estimado - arriba);
  const aDiagonal = Math.abs(estimado - diagonal);
  if (aIzquierda <= aArriba && aIzquierda <= aDiagonal) return izquierda;
  return aArriba <= aDiagonal ? arriba : diagonal;
}

// Cuántos píxeles difieren en algún canal de color, y el mayor salto de un canal.
export function diferenciaRgb(a, b) {
  if (a.ancho !== b.ancho || a.alto !== b.alto) {
    throw new Error(
      `las capturas no tienen el mismo tamaño: ${a.ancho}x${a.alto} y ${b.ancho}x${b.alto}`
    );
  }
  let pixeles = 0;
  let niveles = 0;
  for (let i = 0; i < a.ancho * a.alto; i++) {
    let salto = 0;
    for (let canal = 0; canal < 3; canal++) {
      const enA = a.pixeles[i * a.canales + canal];
      const enB = b.pixeles[i * b.canales + canal];
      salto = Math.max(salto, Math.abs(enA - enB));
    }
    if (salto) pixeles++;
    niveles = Math.max(niveles, salto);
  }
  return { pixeles, niveles };
}

export function mismaImagen(diferencia, tolerancia = { pixeles: 0, niveles: 0 }) {
  return diferencia.pixeles <= tolerancia.pixeles && diferencia.niveles <= tolerancia.niveles;
}
