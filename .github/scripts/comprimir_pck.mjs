// Comprimir el `.pck` del export, que es lo que lo deja entrar en Vercel.
//
//     node .github/scripts/comprimir_pck.mjs export/web
//
// Vercel no acepta un archivo de más de 100 MB y el `.pck` de este juego pesa 113.233.684
// bytes: publicado tal como lo escribe Godot, **el deploy falla entero** con «File size limit
// exceeded». Comprimido con brotli calidad 11 pesa 43.706.584, entra, y se baja 7,7 MB menos que
// gzip y que lo que el CDN comprime al vuelo.
//
// ## Por qué node y no Python
//
// La stdlib de Python no tiene brotli y la de node sí: `zlib.brotliCompressSync` viene adentro.
// Las herramientas de `.claude/scripts` son sólo stdlib por regla, así que el compresor vive acá.
// Lo que decide —qué archivo y con qué codificación— no está escrito en este archivo: se lee de
// `vercel.json`, que es el mismo lugar de donde sale el header que lo declara. Si los dos se
// separaran, el navegador entregaría un `.pck` que no es y el juego no arranca.
//
// ## Qué comprueba antes de escribir
//
// Descomprime lo que acaba de comprimir y exige que empiece con `GDPC` y que mida lo que
// `index.html` declara en `fileSizes`, que es por donde divide la barra de carga. Si algo no
// cierra, sale distinto de cero sin tocar el archivo.
//
// Correrlo dos veces no comprime dos veces: reconoce un cuerpo que ya descomprime.

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import zlib from 'node:zlib';

const AQUI = dirname(fileURLToPath(import.meta.url));
const RAIZ = resolve(AQUI, '..', '..');
const MAGIA_DE_PCK = 'GDPC';

/** Las `source` de `vercel.json` que cubren todas las rutas, tal como las documenta Vercel. */
const UNIVERSALES = new Set(['/(.*)', '/:path*']);

/** Los archivos que `vercel.json` declara comprimidos, con su codificación. */
export function codificados(configuracion) {
  const salida = new Map();
  for (const regla of configuracion.headers ?? []) {
    // `/(.*)` matchearía como si fuera un archivo llamado `(.*)`: las universales se saltean
    // antes de mirar la forma de la ruta.
    if (UNIVERSALES.has(regla.source)) continue;
    const coincidencia = /^\/([^/]+)$/.exec(regla.source ?? '');
    if (!coincidencia) continue;
    for (const header of regla.headers ?? []) {
      if (String(header.key).toLowerCase() === 'content-encoding') {
        salida.set(coincidencia[1], String(header.value).toLowerCase());
      }
    }
  }
  return salida;
}

/** El tamaño que la barra de carga declara para un archivo, o `null`. */
export function tamanoDeclarado(html, nombre) {
  const encontrado = /"fileSizes"\s*:\s*(\{[^}]*\})/.exec(html);
  if (!encontrado) return null;
  const tamanos = JSON.parse(encontrado[1]);
  return Number.isInteger(tamanos[nombre]) ? tamanos[nombre] : null;
}

function comprimir(datos, codificacion) {
  if (codificacion === 'br') {
    return zlib.brotliCompressSync(datos, {
      params: {
        [zlib.constants.BROTLI_PARAM_QUALITY]: 11,
        [zlib.constants.BROTLI_PARAM_LGWIN]: 24,
        [zlib.constants.BROTLI_PARAM_SIZE_HINT]: datos.length,
      },
    });
  }
  if (codificacion === 'gzip') return zlib.gzipSync(datos, { level: 9 });
  throw new Error(`codificación sin compresor acá: ${codificacion}`);
}

function descomprimir(datos, codificacion) {
  if (codificacion === 'br') return zlib.brotliDecompressSync(datos);
  if (codificacion === 'gzip') return zlib.gunzipSync(datos);
  throw new Error(`codificación sin descompresor acá: ${codificacion}`);
}

function esUnPck(datos) {
  return datos.subarray(0, 4).toString('latin1') === MAGIA_DE_PCK;
}

/** Comprime un archivo del directorio y dice qué hizo. Devuelve los problemas encontrados. */
export function comprimirArchivo(directorio, nombre, codificacion, html) {
  const ruta = join(directorio, nombre);
  const datos = readFileSync(ruta);
  // El segundo barrido: si ya descomprime y da un `.pck`, no se toca. Comprimir un cuerpo ya
  // comprimido deja un archivo que el navegador descomprime una vez y entrega basura.
  try {
    const vuelta = descomprimir(datos, codificacion);
    if (esUnPck(vuelta)) {
      // Ya está comprimido. Queda una última comprobación: que el paquete que hay adentro sea
      // el que declara el HTML. Un `.pck` comprimido de un export anterior, con un `index.html`
      // nuevo, arranca el juego con los recursos de otro lado y no hay quién lo note.
      const declarado = tamanoDeclarado(html, nombre);
      if (declarado !== null && vuelta.length !== declarado) {
        const problema =
          `\`index.html\` declara ${declarado} bytes para \`${nombre}\` y el paquete que hay ` +
          `adentro mide ${vuelta.length}: no se toca, pero así no se publica.`;
        console.error(problema);
        return [problema];
      }
      console.log(
        `\`${nombre}\` ya está en \`${codificacion}\`: ${datos.length} bytes, sin tocar.`
      );
      return [];
    }
  } catch {
    // No descomprime: es el `.pck` crudo que dejó Godot. Se comprime.
  }
  const cuerpo = comprimir(datos, codificacion);
  const vuelta = descomprimir(cuerpo, codificacion);
  const problemas = [];
  if (!esUnPck(vuelta)) {
    problemas.push(`al descomprimir \`${nombre}\` no empieza con \`${MAGIA_DE_PCK}\`.`);
  }
  const declarado = tamanoDeclarado(html, nombre);
  if (declarado === null) {
    problemas.push(`\`index.html\` no declara el tamaño de \`${nombre}\` en \`fileSizes\`.`);
  } else if (vuelta.length !== declarado) {
    problemas.push(
      `\`index.html\` declara ${declarado} bytes para \`${nombre}\` y al descomprimirlo mide ` +
        `${vuelta.length}: la barra de carga avanza contra un total que no es.`
    );
  }
  if (problemas.length) {
    for (const problema of problemas) console.error(problema);
    console.error(`\`${nombre}\` no se escribe.`);
    return problemas;
  }
  writeFileSync(ruta, cuerpo);
  console.log(
    `\`${nombre}\` en \`${codificacion}\`: ${datos.length} -> ${cuerpo.length} bytes ` +
      `(${((cuerpo.length * 100) / datos.length).toFixed(1)} %).`
  );
  return [];
}

export function comprimirDirectorio(directorio, configuracion) {
  const html = readFileSync(join(directorio, 'index.html'), 'utf8');
  const problemas = [];
  for (const [nombre, codificacion] of codificados(configuracion)) {
    if (!existsSync(join(directorio, nombre))) {
      // Que falte un archivo del export lo dice `verificar_export.py`, y decirlo dos veces con
      // dos mensajes distintos confunde.
      console.log(`no está \`${nombre}\`: se saltea.`);
      continue;
    }
    problemas.push(...comprimirArchivo(directorio, nombre, codificacion, html));
  }
  return problemas;
}

function configuracionDe(directorio) {
  // El workflow copia `vercel.json` adentro del directorio que publica; en local se lo busca ahí
  // y, si no está, en la raíz del repo. El header y el cuerpo salen siempre del mismo archivo.
  for (const ruta of [join(directorio, 'vercel.json'), join(RAIZ, 'vercel.json')]) {
    if (existsSync(ruta)) return JSON.parse(readFileSync(ruta, 'utf8'));
  }
  throw new Error('no hay `vercel.json` ni en el directorio ni en la raíz del repo');
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const directorio = process.argv[2];
  if (!directorio) {
    console.error('uso: node .github/scripts/comprimir_pck.mjs <directorio>');
    process.exit(2);
  }
  try {
    const problemas = comprimirDirectorio(directorio, configuracionDe(directorio));
    process.exit(problemas.length ? 1 : 0);
  } catch (error) {
    console.error(String(error));
    process.exit(1);
  }
}
