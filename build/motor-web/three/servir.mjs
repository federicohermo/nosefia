// Sirve una carpeta como lo haría Vercel con brotli: Content-Encoding br, ETag y
// `Cache-Control: public, max-age=0, must-revalidate`, más los headers de aislamiento.
// Uso: node servir.mjs <carpeta> <puerto> [--ya-comprimidos=a,b]
//   /__bytes  bytes de cuerpo enviados por archivo desde el último /__reset
//   /__reset  los pone a cero
import { createServer } from 'node:http';
import { readFileSync, writeFileSync, existsSync, statSync } from 'node:fs';
import { brotliCompressSync, constants } from 'node:zlib';
import { createHash } from 'node:crypto';
import { join, extname, normalize, resolve } from 'node:path';

const [raizArg, puerto, ...resto] = process.argv.slice(2);
const raiz = resolve(raizArg);
const ya = new Set(((resto.find((a) => a.startsWith('--ya-comprimidos=')) ?? '').split('=')[1] ?? '').split(',').filter(Boolean));
const TIPOS = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png', '.json': 'application/json', '.bin': 'application/octet-stream', '.ktx2': 'image/ktx2', '.glb': 'model/gltf-binary' };
const COMPRIMIR = new Set(['.html', '.js', '.mjs', '.wasm', '.pck', '.json', '.bin', '.glb']);
const cache = new Map();
let enviados = {};

function cuerpo(ruta, nombre) {
  const mt = statSync(ruta).mtimeMs;
  if (cache.has(ruta) && cache.get(ruta).mt === mt) return cache.get(ruta);
  let datos = readFileSync(ruta);
  let codificado = false;
  if (ya.has(nombre)) codificado = true;
  else if (COMPRIMIR.has(extname(nombre))) {
    if (existsSync(ruta + '.br') && statSync(ruta + '.br').mtimeMs >= mt) datos = readFileSync(ruta + '.br');
    else {
      datos = brotliCompressSync(datos, { params: { [constants.BROTLI_PARAM_QUALITY]: 11, [constants.BROTLI_PARAM_LGWIN]: 24, [constants.BROTLI_PARAM_SIZE_HINT]: datos.length } });
      try { writeFileSync(ruta + '.br', datos); } catch {}
    }
    codificado = true;
  }
  const r = { mt, datos, codificado, etag: '"' + createHash('md5').update(datos).digest('hex').slice(0, 16) + '"' };
  cache.set(ruta, r);
  return r;
}

createServer((req, res) => {
  const url = new URL(req.url, 'http://x');
  let nombre = normalize(decodeURIComponent(url.pathname)).split(String.fromCharCode(92)).join('/').replace(/^\/+/, '');
  if (nombre === '' || nombre.endsWith('/')) nombre += 'index.html';
  if (nombre === '__reset') { enviados = {}; res.writeHead(200); res.end('ok'); return; }
  if (nombre === '__bytes') { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(enviados)); return; }
  const ruta = join(raiz, nombre);
  if (!ruta.startsWith(raiz) || !existsSync(ruta) || !statSync(ruta).isFile()) { res.writeHead(404); res.end(); return; }
  const { datos, codificado, etag } = cuerpo(ruta, nombre);
  const h = {
    'Content-Type': TIPOS[extname(nombre)] ?? 'application/octet-stream',
    'Cross-Origin-Opener-Policy': 'same-origin',
    'Cross-Origin-Embedder-Policy': 'require-corp',
    'Cache-Control': 'public, max-age=0, must-revalidate',
    ETag: etag,
    Vary: 'Accept-Encoding',
  };
  if (req.headers['if-none-match'] === etag) { res.writeHead(304, h); res.end(); enviados[nombre + ' (304)'] = (enviados[nombre + ' (304)'] ?? 0) + 1; return; }
  h['Content-Length'] = datos.length;
  if (codificado) h['Content-Encoding'] = 'br';
  enviados[nombre] = (enviados[nombre] ?? 0) + datos.length;
  res.writeHead(200, h);
  res.end(datos);
}).listen(Number(puerto), '127.0.0.1', () => console.log(`sirviendo ${raiz} en http://127.0.0.1:${puerto}/`));
