// Cuánto pesa, con brotli, lo que el prototipo ya lleva, medido dentro del .pck de Godot.
// Uso: node bytes_comparables.mjs <index.pck-con-brotli>
// Cuenta las texturas del modelo, las del lightmap y la escena importada del .glb; deja afuera audio,
// personajes, UI y el panorama de afuera, que el prototipo no tiene.
import { readFileSync } from 'node:fs';
import { brotliDecompressSync, brotliCompressSync, constants } from 'node:zlib';

const crudo = brotliDecompressSync(readFileSync(process.argv[2]));
const dv = new DataView(crudo.buffer, crudo.byteOffset, crudo.byteLength);
let o = 4;
const ver = dv.getUint32(o, true); o += 4;
o += 12; // version mayor, menor, parche
o += 4; // banderas
const base = Number(dv.getBigUint64(o, true)); o += 8;
const dirOff = Number(dv.getBigUint64(o, true)); o += 8;
o = dirOff;
const n = dv.getUint32(o, true); o += 4;
const entradas = [];
for (let i = 0; i < n; i++) {
  const ln = dv.getUint32(o, true); o += 4;
  const ruta = Buffer.from(crudo.subarray(o, o + ln)).toString().replace(/\0+$/, ''); o += ln;
  const off = Number(dv.getBigUint64(o, true)); o += 8;
  const size = Number(dv.getBigUint64(o, true)); o += 8;
  o += 16; o += 4;
  entradas.push({ ruta, off: off + (ver >= 3 ? base : 0), size });
}
const grupos = { texturas_del_modelo: [], lightmap: [], escena_glb: [], resto: [] };
for (const e of entradas) {
  const r = e.ruta;
  if (/almacen\.exr-.*ctexarray$/.test(r)) grupos.lightmap.push(e);
  else if (/SEPT_JUEGOS_PROTOTIPO_.*\.ctex$/.test(r)) grupos.texturas_del_modelo.push(e);
  else if (/SEPT_JUEGOS_PROTOTIPO\.glb-.*\.scn$/.test(r)) grupos.escena_glb.push(e);
  else grupos.resto.push(e);
}
const br = (b) => brotliCompressSync(b, { params: { [constants.BROTLI_PARAM_QUALITY]: 9, [constants.BROTLI_PARAM_LGWIN]: 24 } }).length;
const salida = {};
for (const [g, lista] of Object.entries(grupos)) {
  const crudoTotal = lista.reduce((a, e) => a + e.size, 0);
  const comp = lista.length && g !== 'resto' ? br(Buffer.concat(lista.map((e) => crudo.subarray(e.off, e.off + e.size)))) : null;
  salida[g] = { archivos: lista.length, sin_comprimir_MiB: +(crudoTotal / 1048576).toFixed(2), brotli_MiB: comp ? +(comp / 1048576).toFixed(2) : null };
}
console.log(JSON.stringify(salida, null, 1));
