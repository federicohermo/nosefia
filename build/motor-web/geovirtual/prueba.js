// Prueba de three-virtual-geometry sobre las mallas horneadas del almacén.
//   ?modo=normal|vg   ?copias=N (rejilla N x N del almacén entero)   ?vista=pasillo
import * as THREE from 'three/webgpu';
import { VirtualGeometry, buildVirtualMesh, fromBufferGeometry, encodeVirtualMesh } from 'three-virtual-geometry';

const P = new URLSearchParams(location.search);
const MODO = P.get('modo') ?? 'vg';
const COPIAS = Number(P.get('copias') ?? 1);
const VISTA = P.get('vista') ?? 'pasillo';
const marca = {};
const t0 = performance.now();
const bajar = async (u, j) => { const r = await fetch(u); return j ? r.json() : r.arrayBuffer(); };
const [datos, geo, vistas] = await Promise.all([bajar('/datos/escena.json', true), bajar('/datos/geometria.bin'), bajar('/datos/vistas.json', true)]);

const comoMatriz = (t) => [t[0], t[1], t[2], 0, t[3], t[4], t[5], 0, t[6], t[7], t[8], 0, t[9], t[10], t[11], 1];
// Todas las superficies del almacén en una sola geometría, con la matriz del mundo aplicada.
const pos = [], nor = [], uv0 = [], idx = [];
let base = 0, triangulos = 0;
for (const d of datos.dibujos) {
	if (!d.visible) continue;
	const malla = datos.mallas[d.malla];
	if (!malla) continue;
	const m4 = new THREE.Matrix4().fromArray(comoMatriz(d.transform));
	const nm = new THREE.Matrix3().getNormalMatrix(m4);
	const espejo = m4.determinant() < 0;
	for (const s of malla) {
		const P3 = new Float32Array(geo, s.pos[0], s.vertices * 3), N3 = new Float32Array(geo, s.nor[0], s.vertices * 3);
		const U = s.uv[1] > 0 ? new Float32Array(geo, s.uv[0], s.vertices * 2) : null;
		const v = new THREE.Vector3();
		for (let i = 0; i < s.vertices; i += 1) {
			v.set(P3[i * 3], P3[i * 3 + 1], P3[i * 3 + 2]).applyMatrix4(m4); pos.push(v.x, v.y, v.z);
			v.set(N3[i * 3], N3[i * 3 + 1], N3[i * 3 + 2]).applyMatrix3(nm).normalize(); nor.push(v.x, v.y, v.z);
			uv0.push(U ? U[i * 2] : 0, U ? U[i * 2 + 1] : 0);
		}
		const I = new Uint32Array(geo, s.indices[0], s.cuantos_indices);
		for (let i = 0; i < I.length; i += 3) {
			idx.push(base + I[i], base + I[i + (espejo ? 1 : 2)], base + I[i + (espejo ? 2 : 1)]);
		}
		base += s.vertices; triangulos += I.length / 3;
	}
}
const g = new THREE.BufferGeometry();
g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
g.setAttribute('normal', new THREE.Float32BufferAttribute(nor, 3));
g.setAttribute('uv', new THREE.Float32BufferAttribute(uv0, 2));
g.setIndex(idx);
marca.geometria = Math.round(performance.now() - t0);

const renderer = new THREE.WebGPURenderer({ antialias: false, powerPreference: 'high-performance' });
renderer.setSize(innerWidth, innerHeight);
document.body.appendChild(renderer.domElement);
await renderer.init();
const escena = new THREE.Scene();
escena.background = new THREE.Color(0x101820);
const camara = new THREE.PerspectiveCamera(75, innerWidth / innerHeight, 0.05, 600);
const vp = vistas[VISTA];
camara.matrixAutoUpdate = false;
camara.matrix.set(vp[0], vp[3], vp[6], vp[9], vp[1], vp[4], vp[7], vp[10], vp[2], vp[5], vp[8], vp[11], 0, 0, 0, 1);
camara.matrixWorld.copy(camara.matrix);
camara.matrixWorldInverse.copy(camara.matrixWorld).invert();
escena.add(new THREE.HemisphereLight(0xcfe8ff, 0x302820, 1.6));
const sol = new THREE.DirectionalLight(0xffffff, 2.2);
sol.position.set(3, 8, 5);
escena.add(sol);
const material = new THREE.MeshStandardNodeMaterial({ color: 0xbbbbbb, roughness: 0.8 });

const matrices = new Float32Array(16 * COPIAS * COPIAS);
const lado = 30;
for (let i = 0; i < COPIAS; i += 1) {
	for (let j = 0; j < COPIAS; j += 1) {
		new THREE.Matrix4().makeTranslation((i - (COPIAS - 1) / 2) * lado, 0, (j - (COPIAS - 1) / 2) * lado).toArray(matrices, (i * COPIAS + j) * 16);
	}
}
let vg = null;
const info = { triangulosOrigen: triangulos, instancias: COPIAS * COPIAS };
if (MODO === 'vg') {
	const a = performance.now();
	const datosVG = await buildVirtualMesh(fromBufferGeometry(g));
	info.construccion_ms = Math.round(performance.now() - a);
	info.claves = Object.keys(datosVG);
	try { info.bytes_vgeo = encodeVirtualMesh(datosVG).byteLength; } catch (e) { info.bytes_vgeo_error = String(e).slice(0, 120); }
	vg = new VirtualGeometry();
	escena.add(vg.createMesh(datosVG, material, { matrices }));
} else {
	const inst = new THREE.InstancedMesh(g, material, COPIAS * COPIAS);
	inst.instanceMatrix.array.set(matrices);
	inst.frustumCulled = false;
	escena.add(inst);
}
const a = performance.now();
try { await renderer.compileAsync(escena, camara); } catch (e) { info.compile_error = String(e).slice(0, 160); }
info.compilar_ms = Math.round(performance.now() - a);

const cpu = [], entre = [];
let ultimo = 0;
function bucle(t) {
	if (ultimo) entre.push(t - ultimo);
	ultimo = t;
	const c = performance.now();
	renderer.render(escena, camara);
	cpu.push(performance.now() - c);
	requestAnimationFrame(bucle);
}
requestAnimationFrame(bucle);
const q = (arr, p) => { const e = arr.slice().sort((x, y) => x - y); return +e[Math.floor((e.length - 1) * p)].toFixed(2); };
window.__medir = async (ms) => {
	cpu.length = 0; entre.length = 0;
	await new Promise((r) => setTimeout(r, ms));
	return { cpu_p50: q(cpu, 0.5), entre_p50: q(entre, 0.5), entre_p95: q(entre, 0.95), cuadros: entre.length };
};
window.__info = async () => {
	const out = { ...info, modo: MODO, marca };
	if (vg) { try { out.stats = await vg.readStats(renderer); } catch (e) { out.stats_error = String(e).slice(0, 120); } }
	return out;
};
window.__listo = true;
