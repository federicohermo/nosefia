// Visor del almacén con Three.js. Lee lo que vuelca `herramientas/volcar.gd` y las texturas que
// Godot ya importó (BC1/BC3/BC5 y el lightmap en BC6H), sin recomprimir nada.
//
//   ?api=webgpu | webgl2   ·   ?vista=mostrador|gondola|heladera|pasillo|deposito|bano
//
// Lo que hace distinto del prototipo anterior:
//  - el lightmap lleva sus cuatro capas (L0 y L1 direccional) y se evalúa como Godot;
//  - las sondas del `.lmbake` alumbran lo que no tiene lightmap, por instancia;
//  - las luces de área son `RectAreaLight` de verdad, con su tamaño;
//  - las texturas son las mismas BC, no PNG.

import * as THREE from 'three/webgpu';
import {
	Fn, texture, screenUV, uv, float, vec2, vec3, vec4, uniform, normalMap, normalWorld,
	transformDirection, cameraWorldMatrix, instanceIndex, textureLoad, ivec2, positionView,
	smoothstep, fog, select, uniformArray, materialColor, mix, Loop, LTC_Evaluate, LTC_Uv, mat3, cameraPosition, positionWorld,
} from 'three/tsl';
import { RectAreaLightTexturesLib } from 'three/addons/lights/RectAreaLightTexturesLib.js';
import { DynamicLighting } from 'three/addons/lighting/DynamicLighting.js';

const T0 = performance.timeOrigin;
const marca = {};
const anotar = (n) => { marca[n] = Math.round(performance.now()); };
anotar('modulo');

const PARAMS = new URLSearchParams(location.search);
const API = PARAMS.get('api') ?? 'webgpu';
const VISTA = PARAMS.get('vista') ?? 'pasillo';
const K_LM = Number(PARAMS.get('klm') ?? 6);
const K_SH = Number(PARAMS.get('ksh') ?? 1);
const K_LUZ = Number(PARAMS.get('kluz') ?? Math.PI);
const AMBIENTE = Number(PARAMS.get('amb') ?? 0);
const SIN_SONDAS = PARAMS.get('sondas') === '0';
const SIN_AREA = PARAMS.get('area') === '0';
const SIN_L1 = PARAMS.get('l1') === '0';
const DEBUG = PARAMS.get('debug') ?? '';
const SALTAR_COMPILAR = PARAMS.get('compilar') === '0';
const SIN_FUSION = PARAMS.get('fusion') === '0';
// 'datos': las luces puntuales y focos van a arreglos con un lazo y las de área a un lazo propio.
// 'nativas': una luz de Three por cada luz de Godot, desenrolladas en el shader.
const LUCES = PARAMS.get('luces') ?? 'datos';
// En WebGPU lo estático se graba una vez en un bundle (`bundle=0` lo apaga). Lo que se mueva en el
// juego tiene que quedar afuera del bundle.

const panel = document.getElementById('datos');
const decir = (t) => { if (panel) panel.textContent = t; };

// ---------------------------------------------------------------------------------------------
// Datos
// ---------------------------------------------------------------------------------------------
const bajar = async (u, tipo) => {
	const r = await fetch(u);
	return tipo === 'json' ? r.json() : r.arrayBuffer();
};
const [datos, lightmapJson, geometria, texJson, texBin, sondasBin] = await Promise.all([
	bajar('/datos/escena.json', 'json'),
	bajar('/datos/lightmap.json', 'json'),
	bajar('/datos/geometria.bin'),
	bajar('/datos/texturas.json', 'json'),
	bajar('/datos/texturas.bin'),
	bajar('/datos/sondas.bin'),
]);
anotar('datos');

// ---------------------------------------------------------------------------------------------
// Renderer
// ---------------------------------------------------------------------------------------------
const renderer = new THREE.WebGPURenderer({
	antialias: false,
	forceWebGL: API === 'webgl2',
	powerPreference: 'high-performance',
});
renderer.setPixelRatio(1);
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.toneMapping = THREE.NoToneMapping;
renderer.outputColorSpace = THREE.LinearSRGBColorSpace;
document.body.appendChild(renderer.domElement);
await renderer.init();
anotar('renderer');
let ltcTablas = null;
const backend = renderer.backend?.isWebGPUBackend ? 'webgpu' : 'webgl2';
const EN_BUNDLE = backend === 'webgpu' && PARAMS.get('bundle') !== '0';
RectAreaLightNode_setup();
if (LUCES === 'datos') renderer.lighting = new DynamicLighting({ maxPointLights: 4, maxSpotLights: 16, maxDirectionalLights: 1, maxHemisphereLights: 1 });

function RectAreaLightNode_setup() {
	ltcTablas = RectAreaLightTexturesLib.init();
	THREE.RectAreaLightNode.setLTC(ltcTablas);
}

const escena = new THREE.Scene();
const entorno = datos.entorno;
const FONDO = vec3(entorno.fondo[0], entorno.fondo[1], entorno.fondo[2]);
renderer.setClearColor(0x000000, 0);

// La niebla de profundidad de Godot: sube de `inicio` a `fin` con su curva y llega a `densidad`.
{
	const color = new THREE.Color(
		entorno.niebla_color[0] * entorno.niebla_energia,
		entorno.niebla_color[1] * entorno.niebla_energia,
		entorno.niebla_color[2] * entorno.niebla_energia,
	);
	const z = positionView.z.negate();
	const t = smoothstep(entorno.niebla_inicio, entorno.niebla_fin, z).pow(entorno.niebla_curva);
	if (PARAMS.get('sinfog') !== '1') escena.fogNode = fog(vec3(color.r, color.g, color.b), t.mul(entorno.niebla_densidad));
}
const camara = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.05, 300);

// ---------------------------------------------------------------------------------------------
// Texturas BC: los bytes salen tal cual del paquete
// ---------------------------------------------------------------------------------------------
const FORMATOS = {
	bc1: THREE.RGBA_S3TC_DXT1_Format,
	bc3: THREE.RGBA_S3TC_DXT5_Format,
	bc5: THREE.RED_GREEN_RGTC2_Format,
	bc6hu: THREE.RGB_BPTC_UNSIGNED_Format,
};
const texturasBC = new Map();
function texturaBC(clave, espacio) {
	const info = texJson[clave];
	if (!info) return null;
	const id = `${clave}|${espacio}`;
	if (texturasBC.has(id)) return texturasBC.get(id);
	const mipmaps = info.niveles.map((n) => ({
		data: new Uint8Array(texBin, n.o, n.n),
		width: n.w,
		height: n.h,
	}));
	const t = new THREE.CompressedTexture(mipmaps, info.w, info.h, FORMATOS[info.f], THREE.UnsignedByteType);
	t.colorSpace = espacio;
	t.generateMipmaps = false;
	t.minFilter = mipmaps.length > 1 ? THREE.LinearMipmapLinearFilter : THREE.LinearFilter;
	t.magFilter = THREE.LinearFilter;
	t.wrapS = THREE.RepeatWrapping;
	t.wrapT = THREE.RepeatWrapping;
	t.anisotropy = 4;
	t.flipY = false;
	t.needsUpdate = true;
	texturasBC.set(id, t);
	return t;
}

// El lightmap: cuatro capas BC6H (L0, L1 y, z, x), recortadas a las filas usadas.
const capasLM = [0, 1, 2, 3].map((k) => {
	const t = texturaBC(`__lightmap${k}__`, THREE.NoColorSpace);
	t.wrapS = THREE.ClampToEdgeWrapping;
	t.wrapT = THREE.ClampToEdgeWrapping;
	t.anisotropy = 1;
	return t;
});
const ALTO_LM = lightmapJson.alto;

// ---------------------------------------------------------------------------------------------
// Sondas: tetraedros y armónicos esféricos de 9 coeficientes por punto
// ---------------------------------------------------------------------------------------------
const sondas = (() => {
	const cab = new Uint32Array(sondasBin, 0, 3);
	const [np, nt, nsh] = cab;
	let o = 12;
	const puntos = new Float32Array(sondasBin, o, np * 3); o += np * 12;
	const tetra = new Int32Array(sondasBin, o, nt * 4); o += nt * 16;
	const sh = new Float32Array(sondasBin, o, nsh * 4);
	return { np, nt, puntos, tetra, sh };
})();

// Los cuatro puntos de cada tetraedro y su inversa, para las coordenadas baricéntricas.
const tetraedros = (() => {
	const { nt, puntos, tetra } = sondas;
	const mats = new Float64Array(nt * 9);
	const cajas = new Float32Array(nt * 6);
	for (let i = 0; i < nt; i += 1) {
		const p = [0, 1, 2, 3].map((k) => tetra[i * 4 + k] * 3);
		const a = [puntos[p[0]], puntos[p[0] + 1], puntos[p[0] + 2]];
		const c = [1, 2, 3].map((k) => [puntos[p[k]] - a[0], puntos[p[k] + 1] - a[1], puntos[p[k] + 2] - a[2]]);
		const m = new THREE.Matrix3().set(c[0][0], c[1][0], c[2][0], c[0][1], c[1][1], c[2][1], c[0][2], c[1][2], c[2][2]);
		const inv = m.invert();
		mats.set(inv.elements, i * 9);
		for (let k = 0; k < 3; k += 1) {
			let lo = Infinity, hi = -Infinity;
			for (let j = 0; j < 4; j += 1) { const v = puntos[p[j] + k]; lo = Math.min(lo, v); hi = Math.max(hi, v); }
			cajas[i * 6 + k] = lo; cajas[i * 6 + 3 + k] = hi;
		}
	}
	return { mats, cajas };
})();

const SH_DE_CERO = new Float32Array(36);
// Interpola los 9 coeficientes en `p`; si ningún tetraedro lo contiene, usa la sonda más cercana.
function muestrearSondas(x, y, z) {
	const { nt, puntos, tetra, sh } = sondas;
	const { mats, cajas } = tetraedros;
	for (let i = 0; i < nt; i += 1) {
		const c = i * 6;
		if (x < cajas[c] - 1e-4 || y < cajas[c + 1] - 1e-4 || z < cajas[c + 2] - 1e-4
			|| x > cajas[c + 3] + 1e-4 || y > cajas[c + 4] + 1e-4 || z > cajas[c + 5] + 1e-4) continue;
		const a = tetra[i * 4] * 3;
		const dx = x - puntos[a], dy = y - puntos[a + 1], dz = z - puntos[a + 2];
		const m = i * 9;
		const b1 = mats[m] * dx + mats[m + 1] * dy + mats[m + 2] * dz;
		const b2 = mats[m + 3] * dx + mats[m + 4] * dy + mats[m + 5] * dz;
		const b3 = mats[m + 6] * dx + mats[m + 7] * dy + mats[m + 8] * dz;
		const b0 = 1 - b1 - b2 - b3;
		if (b0 < -1e-4 || b1 < -1e-4 || b2 < -1e-4 || b3 < -1e-4) continue;
		const w = [b0, b1, b2, b3];
		const salida = new Float32Array(27);
		for (let k = 0; k < 4; k += 1) {
			const s = tetra[i * 4 + k] * 9;
			for (let j = 0; j < 9; j += 1) {
				salida[j * 3] += w[k] * sh[(s + j) * 4];
				salida[j * 3 + 1] += w[k] * sh[(s + j) * 4 + 1];
				salida[j * 3 + 2] += w[k] * sh[(s + j) * 4 + 2];
			}
		}
		return salida;
	}
	// Fuera de todos: la sonda más cercana.
	let mejor = 0, d2 = Infinity;
	for (let i = 0; i < sondas.np; i += 1) {
		const dx = x - puntos[i * 3], dy = y - puntos[i * 3 + 1], dz = z - puntos[i * 3 + 2];
		const d = dx * dx + dy * dy + dz * dz;
		if (d < d2) { d2 = d; mejor = i; }
	}
	const salida = new Float32Array(27);
	for (let j = 0; j < 9; j += 1) {
		for (let c = 0; c < 3; c += 1) salida[j * 3 + c] = sh[(mejor * 9 + j) * 4 + c];
	}
	return salida;
}

// Una fila por instancia en una textura de flotantes: 9 texels RGBA por fila.
const filasSH = [];
function filaDeSH(x, y, z) {
	filasSH.push(SIN_SONDAS ? SH_DE_CERO : muestrearSondas(x, y, z));
	return filasSH.length - 1;
}

// ---------------------------------------------------------------------------------------------
// Luces de área en una tabla: cuatro vértices por luz, un solo lazo en el shader
// ---------------------------------------------------------------------------------------------
const rectas = LUCES === 'datos' && !SIN_AREA ? datos.luces.filter((l) => l.tipo === 'AreaLight3D') : [];
const tablaRectas = (() => {
	const n = Math.max(rectas.length, 1);
	const centro = [], mitadAncho = [], mitadAlto = [], color = [];
	for (let i = 0; i < n; i += 1) {
		const l = rectas[i];
		if (!l) { [centro, mitadAncho, mitadAlto, color].forEach((a) => a.push(new THREE.Vector3())); continue; }
		const m = new THREE.Matrix4().fromArray([l.transform[0], l.transform[1], l.transform[2], 0, l.transform[3], l.transform[4], l.transform[5], 0, l.transform[6], l.transform[7], l.transform[8], 0, l.transform[9], l.transform[10], l.transform[11], 1]);
		const x = new THREE.Vector3().setFromMatrixColumn(m, 0).normalize();
		const y = new THREE.Vector3().setFromMatrixColumn(m, 1).normalize();
		centro.push(new THREE.Vector3().setFromMatrixPosition(m));
		mitadAncho.push(x.multiplyScalar(l.area_tamano[0] / 2));
		mitadAlto.push(y.multiplyScalar(l.area_tamano[1] / 2));
		color.push(new THREE.Vector3(l.color[0], l.color[1], l.color[2]).multiplyScalar(l.energia * K_LUZ));
	}
	// Un solo arreglo (un solo bloque de uniformes): centro, mitad de ancho, mitad de alto y color de cada luz.
	const todo = [];
	for (let i = 0; i < n; i += 1) todo.push(centro[i], mitadAncho[i], mitadAlto[i], color[i]);
	return { n: rectas.length, tabla: uniformArray(todo, 'vec3') };
})();
// Luz de todos los rectángulos sobre el punto: difusa con la matriz identidad y especular con la
// matriz de la tabla LTC, como `RectAreaLightNode` de Three pero en un solo lazo.
const luzDeArea = (N, rugosidad, albedo, metalico) => Fn(() => {
	if (tablaRectas.n === 0) return vec3(0);
	const V = cameraPosition.sub(positionWorld).normalize();
	const uvLtc = LTC_Uv({ N, V, roughness: rugosidad });
	const t1 = texture(ltcTablas.LTC_FLOAT_1, uvLtc), t2 = texture(ltcTablas.LTC_FLOAT_2, uvLtc);
	const mInv = mat3(vec3(t1.x, 0, t1.y), vec3(0, 1, 0), vec3(t1.z, 0, t1.w));
	const f0 = mix(vec3(0.04), albedo, metalico);
	const fresnel = f0.mul(t2.x).add(vec3(1).sub(f0).mul(t2.y));
	const difuso = albedo.mul(float(1).sub(metalico));
	const identidad = mat3(1, 0, 0, 0, 1, 0, 0, 0, 1);
	const acc = vec3(0).toVar();
	Loop(tablaRectas.n, ({ i }) => {
		const c = tablaRectas.tabla.element(i.mul(4)), hw = tablaRectas.tabla.element(i.mul(4).add(1)), hh = tablaRectas.tabla.element(i.mul(4).add(2));
		const colorLuz = tablaRectas.tabla.element(i.mul(4).add(3));
		const p0 = c.add(hw).sub(hh), p1 = c.sub(hw).sub(hh), p2 = c.sub(hw).add(hh), p3 = c.add(hw).add(hh);
		const espec = LTC_Evaluate({ N, V, P: positionWorld, mInv, p0, p1, p2, p3 });
		const dif = LTC_Evaluate({ N, V, P: positionWorld, mInv: identidad, p0, p1, p2, p3 });
		acc.addAssign(DEBUG === 'area0' ? colorLuz.mul(0.01) : DEBUG === 'area1' ? dif.mul(colorLuz) : colorLuz.mul(fresnel.mul(espec).add(difuso.mul(dif))));
	});
	return acc;
})();

// ---------------------------------------------------------------------------------------------
// Materiales
// ---------------------------------------------------------------------------------------------
const PI = Math.PI;
const filaSH = uniform(0); // por objeto, con onObjectUpdate
const MAX_FILAS = 1024;
const datosSH = new Float32Array(9 * MAX_FILAS * 4);
const texSH = new THREE.DataTexture(datosSH, 9, MAX_FILAS, THREE.RGBAFormat, THREE.FloatType);
texSH.minFilter = THREE.NearestFilter;
texSH.magFilter = THREE.NearestFilter;
const texSHNodo = () => texture(texSH);

// Evalúa la irradiancia de 9 coeficientes de Godot en la normal del mundo `n`.
function irradianciaSH(n, fila) {
	const co = (k) => textureLoad(texSH, ivec2(k, fila)).rgb;
	const c1 = 0.429043, c2 = 0.511664, c3 = 0.743125, c4 = 0.886227, c5 = 0.247708;
	const x = n.x, y = n.y, z = n.z;
	return co(8).mul(c1 * 1).mul(x.mul(x).sub(y.mul(y)))
		.add(co(6).mul(c3).mul(z.mul(z)))
		.add(co(0).mul(c4))
		.sub(co(6).mul(c5))
		.add(co(4).mul(2 * c1).mul(x.mul(y)))
		.add(co(7).mul(2 * c1).mul(x.mul(z)))
		.add(co(5).mul(2 * c1).mul(y.mul(z)))
		.add(co(3).mul(2 * c2).mul(x))
		.add(co(1).mul(2 * c2).mul(y))
		.add(co(2).mul(2 * c2).mul(z));
}

const blanca = new THREE.DataTexture(new Uint8Array([255, 255, 255, 255]), 1, 1, THREE.RGBAFormat);
blanca.needsUpdate = true;
const planaNormal = new THREE.DataTexture(new Uint8Array([128, 128, 255, 255]), 1, 1, THREE.RGBAFormat);
planaNormal.needsUpdate = true;
const materiales = new Map();
const nodoDeNormal = (m) => {
	// Los mapas de normales de Godot son RG (BC5): la z se reconstruye.
	const t = texturaBC(m.normal_textura, THREE.NoColorSpace);
	if (!t) return null;
	const rg = texture(t, uv()).rg;
	const xy = rg.mul(2).sub(1);
	const z = float(1).sub(xy.dot(xy)).max(0).sqrt();
	return vec3(rg, z.mul(0.5).add(0.5));
};

function crearMaterial(clave, baked) {
	const id = `${clave}|${baked ? 'b' : 'd'}`;
	if (materiales.has(id)) return materiales.get(id);
	const m = datos.materiales[clave];
	const albedoTex = m.albedo_textura ? texturaBC(m.albedo_textura, THREE.SRGBColorSpace) : null;
	const color = new THREE.Color(m.albedo[0], m.albedo[1], m.albedo[2]);
	const alfa = texture(albedoTex ?? blanca, uv()).a.mul(uniform(m.albedo[3]));

	let mat;
	if (baked) {
		// Un solo grafo de nodos para todos los horneados (sólo cambian uniformes y texturas), así el
		// motor enlaza un programa por variante de normal y no uno por material.
		const colorU = uniform(new THREE.Color(color.r, color.g, color.b));
		const albedoB = texture(albedoTex ?? blanca, uv()).rgb.mul(colorU);
		const emisionTex = m.emision ? texturaBC(m.emision_textura, THREE.SRGBColorSpace) : null;
		const emisionB = texture(emisionTex ?? blanca, uv()).rgb
			.mul(uniform(new THREE.Color(...(m.emision ? m.emision_color.slice(0, 3) : [0, 0, 0]))))
			.mul(uniform(m.emision ? m.emision_energia : 0));
		// Godot: lightmap × albedo, sin luces en tiempo real.
		mat = new THREE.MeshBasicNodeMaterial();
		const rect = uniform(new THREE.Vector4());
		mat.userData.rect = rect;
		const uv1 = uv(1);
		const normal = m.normal && m.normal_textura
			? transformDirection(normalMap(nodoDeNormal(m), vec2(m.normal_escala)), cameraWorldMatrix)
			: normalWorld;
		const l0 = texture(capasLM[0], uv1).rgb;
		let irr = l0.mul(0.282095);
		if (!SIN_L1) {
			const l1y = texture(capasLM[1], uv1).rgb.sub(0.5).mul(2);
			const l1z = texture(capasLM[2], uv1).rgb.sub(0.5).mul(2);
			const l1x = texture(capasLM[3], uv1).rgb.sub(0.5).mul(2);
			// Las capas L1 guardan la dirección relativa a L0, en [0, 1] con el 0,5 como cero.
			irr = l0.mul(float(0.282095).add(l1y.mul(normal.y).add(l1z.mul(normal.z)).add(l1x.mul(normal.x)).mul(0.32573)));
		}
		const salida = irr.max(0).mul(albedoB).mul(K_LM).add(emisionB);
		const capaDebug = ['l0', 'l1y', 'l1z', 'l1x'].indexOf(DEBUG);
		mat.colorNode = capaDebug >= 0 ? texture(capasLM[capaDebug], uv1).rgb : DEBUG === 'lm' ? irr.max(0).mul(K_LM) : salida;
	} else {
		// Lo dinámico también comparte un solo grafo: las texturas que faltan son una blanca o una normal
		// plana, y lo que cambia entre materiales (color, rugosidad, canales) son uniformes.
		// Así el motor enlaza un programa por forma de transparencia y no uno por material.
		mat = new THREE.MeshStandardNodeMaterial();
		const colorU = uniform(new THREE.Color(color.r, color.g, color.b));
		const albedoD = texture(albedoTex ?? blanca, uv());
		mat.colorNode = albedoD.rgb.mul(colorU);
		const ormTex = m.orm_textura ? texturaBC(m.orm_textura, THREE.NoColorSpace)
			: m.rugosidad_textura ? texturaBC(m.rugosidad_textura, THREE.NoColorSpace) : null;
		const orm = texture(ormTex ?? blanca, uv()).rgb;
		// rugosidad = orm · mascaraR + baseR ; metálico = orm · mascaraM + baseM (valores sólo en uniformes)
		const mascaraR = ormTex ? (m.orm_textura ? [0, m.rugosidad, 0] : [m.rugosidad, 0, 0]) : [0, 0, 0];
		const mascaraM = m.orm_textura ? [0, 0, m.metalico] : [0, 0, 0];
		mat.roughnessNode = orm.dot(uniform(new THREE.Vector3(...mascaraR))).add(uniform(ormTex ? 0 : m.rugosidad));
		mat.metalnessNode = orm.dot(uniform(new THREE.Vector3(...mascaraM))).add(uniform(m.orm_textura ? 0 : m.metalico));
		const normalTex = m.normal && m.normal_textura ? texturaBC(m.normal_textura, THREE.NoColorSpace) : null;
		const rgN = texture(normalTex ?? planaNormal, uv()).rg;
		const xyN = rgN.mul(2).sub(1);
		const mapaN = vec3(rgN, float(1).sub(xyN.dot(xyN)).max(0).sqrt().mul(0.5).add(0.5));
		mat.normalNode = normalMap(mapaN, uniform(new THREE.Vector2(...(normalTex ? [m.normal_escala, m.normal_escala] : [0, 0]))));
		const emTex = m.emision && m.emision_textura ? texturaBC(m.emision_textura, THREE.SRGBColorSpace) : null;
		const emisionD = texture(emTex ?? blanca, uv()).rgb
			.mul(uniform(new THREE.Color(...(m.emision ? m.emision_color.slice(0, 3) : [0, 0, 0]))))
			.mul(uniform(m.emision ? m.emision_energia : 0));
		// Sondas: la luz indirecta es `SH(normal) × albedo × (1 - metálico)`.
		const ind = irradianciaSH(normalWorld, filaSH.add(instanceIndex)).max(0)
			.mul(mat.colorNode).mul(float(1).sub(mat.metalnessNode)).mul(K_SH);
		const area = luzDeArea(normalWorld, mat.roughnessNode, mat.colorNode, mat.metalnessNode);
		mat.emissiveNode = (DEBUG === 'area' || DEBUG === 'area0' || DEBUG === 'area1') ? area.mul(4) : ind.add(emisionD).add(area);
	}
	mat.side = m.cull === 2 ? THREE.DoubleSide : THREE.FrontSide;
	if (m.transparencia === 1) {
		mat.transparent = true;
		mat.opacityNode = alfa;
		mat.depthWrite = false;
	} else if (m.transparencia >= 2) {
		mat.alphaTest = m.alpha_scissor ?? 0.5;
		mat.opacityNode = alfa;
	}
	mat.name = m.nombre || clave;
	materiales.set(id, mat);
	return mat;
}

// ---------------------------------------------------------------------------------------------
// Geometría
// ---------------------------------------------------------------------------------------------
const geometrias = new Map();
function geometriaDe(claveMalla, superficie, rect) {
	const id = `${claveMalla}#${superficie}#${rect ? rect.join(',') : 'sin'}`;
	if (geometrias.has(id)) return geometrias.get(id);
	const datosMalla = datos.mallas[claveMalla];
	if (!datosMalla) return null;
	const s = datosMalla[superficie];
	const g = new THREE.BufferGeometry();
	g.setAttribute('position', new THREE.BufferAttribute(new Float32Array(geometria, s.pos[0], s.vertices * 3), 3));
	g.setAttribute('normal', new THREE.BufferAttribute(new Float32Array(geometria, s.nor[0], s.vertices * 3), 3));
	if (s.uv[1] > 0) {
		g.setAttribute('uv', new THREE.BufferAttribute(new Float32Array(geometria, s.uv[0], s.vertices * 2), 2));
	}
	if (s.uv2[1] > 0 && rect) {
		const uv2 = new Float32Array(new Float32Array(geometria, s.uv2[0], s.vertices * 2));
		const alto = ALTO_LM / 2048;
		for (let i = 0; i < uv2.length; i += 2) {
			uv2[i] = rect[0] + uv2[i] * rect[2];
			uv2[i + 1] = (rect[1] + uv2[i + 1] * rect[3]) / alto;
		}
		g.setAttribute('uv1', new THREE.BufferAttribute(uv2, 2));
	}
	if (s.indices[1] > 0) {
		const indices = new Uint32Array(new Uint32Array(geometria, s.indices[0], s.cuantos_indices));
		for (let i = 0; i < indices.length; i += 3) {
			const t = indices[i + 1]; indices[i + 1] = indices[i + 2]; indices[i + 2] = t;
		}
		g.setIndex(new THREE.BufferAttribute(indices, 1));
	}
	g.computeBoundingSphere();
	geometrias.set(id, g);
	return g;
}

const rectangulos = lightmapJson.rectangulos;
function rectDe(ruta) {
	if (rectangulos[ruta]) return rectangulos[ruta];
	for (const clave of Object.keys(rectangulos)) {
		if (clave.endsWith('/' + ruta)) return rectangulos[clave];
	}
	return null;
}
const comoMatriz = (t) => [t[0], t[1], t[2], 0, t[3], t[4], t[5], 0, t[6], t[7], t[8], 0, t[9], t[10], t[11], 1];

const mundo = EN_BUNDLE ? new THREE.BundleGroup() : new THREE.Group();
if (EN_BUNDLE) mundo.static = true;
escena.add(mundo);
let dibujos = 0, conAtlas = 0;
const dinamicos = [];
const horneados = new Map();
for (const dibujo of datos.dibujos) {
	if (!dibujo.visible) continue;
	const rect = rectDe(dibujo.ruta);
	const malla = datos.mallas[dibujo.malla];
	if (!malla) continue;
	if (rect) conAtlas += 1;
	const m4 = new THREE.Matrix4().fromArray(comoMatriz(dibujo.transform));
	for (let sup = 0; sup < malla.length; sup += 1) {
		const g = geometriaDe(dibujo.malla, sup, rect);
		const clave = dibujo.override || dibujo.materiales[sup];
		if (!g || !clave) continue;
		const baked = rect !== null && g.getAttribute('uv1') !== undefined;
		const mat = crearMaterial(clave, baked);
		if (baked && !SIN_FUSION) {
			if (!horneados.has(mat)) horneados.set(mat, []);
			horneados.get(mat).push({ g, m4 });
			dibujos += 1;
			continue;
		}
		// Lo dinámico va como instancia de a una: así comparte programa con los productos instanciados.
		let nodo;
		if (baked) {
			nodo = new THREE.Mesh(g, mat);
			nodo.matrixAutoUpdate = false;
			nodo.matrix.copy(m4);
		} else {
			nodo = new THREE.InstancedMesh(g, mat, 1);
			nodo.setMatrixAt(0, m4);
			nodo.frustumCulled = false;
		}
		if (!baked) {
			nodo.userData.fila = filaDeSH(m4.elements[12], m4.elements[13], m4.elements[14]);
			dinamicos.push(nodo);
		}
		const solo = PARAMS.get('solo');
		nodo.visible = !(solo === 'baked' && !baked) && !(solo === 'dyn' && baked);
		mundo.add(nodo);
		dibujos += 1;
	}
}

// Lo horneado no se mueve: las piezas de un mismo material se funden en una malla, con la matriz
// del mundo aplicada a los vértices. Son menos objetos que el motor tiene que recorrer en cada cuadro.
function fundir(partes) {
	let nv = 0, ni = 0;
	for (const { g } of partes) { nv += g.getAttribute('position').count; ni += g.index ? g.index.count : g.getAttribute('position').count; }
	const pos = new Float32Array(nv * 3), nor = new Float32Array(nv * 3), uv0 = new Float32Array(nv * 2), uv1 = new Float32Array(nv * 2);
	const idx = new Uint32Array(ni);
	const v = new THREE.Vector3(), nm = new THREE.Matrix3();
	let ov = 0, oi = 0;
	for (const { g, m4 } of partes) {
		const P = g.getAttribute('position'), N = g.getAttribute('normal'), U0 = g.getAttribute('uv'), U1 = g.getAttribute('uv1');
		nm.getNormalMatrix(m4);
		for (let i = 0; i < P.count; i += 1) {
			v.fromBufferAttribute(P, i).applyMatrix4(m4).toArray(pos, (ov + i) * 3);
			v.fromBufferAttribute(N, i).applyMatrix3(nm).normalize().toArray(nor, (ov + i) * 3);
			if (U0) { uv0[(ov + i) * 2] = U0.getX(i); uv0[(ov + i) * 2 + 1] = U0.getY(i); }
			uv1[(ov + i) * 2] = U1.getX(i); uv1[(ov + i) * 2 + 1] = U1.getY(i);
		}
		const espejo = m4.determinant() < 0;
		const n = g.index ? g.index.count : P.count;
		for (let i = 0; i < n; i += 3) {
			const a = g.index ? g.index.getX(i) : i, b = g.index ? g.index.getX(i + 1) : i + 1, c = g.index ? g.index.getX(i + 2) : i + 2;
			idx[oi + i] = ov + a;
			idx[oi + i + 1] = ov + (espejo ? c : b);
			idx[oi + i + 2] = ov + (espejo ? b : c);
		}
		ov += P.count; oi += n;
	}
	const salida = new THREE.BufferGeometry();
	salida.setAttribute('position', new THREE.BufferAttribute(pos, 3));
	salida.setAttribute('normal', new THREE.BufferAttribute(nor, 3));
	salida.setAttribute('uv', new THREE.BufferAttribute(uv0, 2));
	salida.setAttribute('uv1', new THREE.BufferAttribute(uv1, 2));
	salida.setIndex(new THREE.BufferAttribute(idx, 1));
	salida.computeBoundingSphere();
	return salida;
}
let fundidos = 0;
for (const [mat, partes] of horneados) {
	const malla = new THREE.Mesh(fundir(partes), mat);
	malla.matrixAutoUpdate = false;
	mundo.add(malla);
	fundidos += 1;
}

// Productos: una copia por lugar, una fila de sondas por copia.
for (const producto of datos.productos) {
	const copias = producto.principal.concat(producto.guias);
	const malla = datos.mallas[producto.malla];
	if (copias.length === 0 || !malla) continue;
	const base = filasSH.length;
	for (const c of copias) {
		const m = new THREE.Matrix4().fromArray(comoMatriz(c));
		filaDeSH(m.elements[12], m.elements[13], m.elements[14]);
	}
	for (let sup = 0; sup < malla.length; sup += 1) {
		const g = geometriaDe(producto.malla, sup, null);
		const clave = producto.materiales[sup] ?? producto.materiales[0];
		const inst = new THREE.InstancedMesh(g, crearMaterial(clave, false), copias.length);
		const m = new THREE.Matrix4();
		for (let i = 0; i < copias.length; i += 1) {
			m.fromArray(comoMatriz(copias[i]));
			inst.setMatrixAt(i, m);
		}
		inst.instanceMatrix.needsUpdate = true;
		inst.frustumCulled = false;
		inst.userData.fila = base;
		dinamicos.push(inst);
		mundo.add(inst);
	}
}

// Se llenan las filas de la textura de sondas (9 texels RGBA por fila).
if (filasSH.length > MAX_FILAS) throw new Error('más copias que filas de sondas');
filasSH.forEach((f, r) => {
	for (let j = 0; j < 9; j += 1) {
		datosSH[(r * 9 + j) * 4] = f[j * 3];
		datosSH[(r * 9 + j) * 4 + 1] = f[j * 3 + 1];
		datosSH[(r * 9 + j) * 4 + 2] = f[j * 3 + 2];
	}
});
texSH.needsUpdate = true;
filaSH.onObjectUpdate(({ object }) => object.userData.fila ?? 0);
anotar('geometria');

// ---------------------------------------------------------------------------------------------
// Luces: sólo alumbran lo que no tiene lightmap (los materiales con lightmap no las leen)
// ---------------------------------------------------------------------------------------------
const luces = [];
for (const l of datos.luces) {
	const color = new THREE.Color(l.color[0], l.color[1], l.color[2]);
	const m = new THREE.Matrix4().fromArray(comoMatriz(l.transform));
	const posicion = new THREE.Vector3().setFromMatrixPosition(m);
	const giro = new THREE.Quaternion().setFromRotationMatrix(m);
	let luz = null;
	if (l.tipo === 'SpotLight3D') {
		luz = new THREE.SpotLight(color, l.energia * K_LUZ, l.rango, THREE.MathUtils.degToRad(l.angulo), 0.3, l.atenuacion);
	} else if (l.tipo === 'OmniLight3D') {
		luz = new THREE.PointLight(color, l.energia * K_LUZ, l.rango, l.atenuacion);
	} else if (l.tipo === 'AreaLight3D' && !SIN_AREA && LUCES === 'nativas') {
		// Godot normaliza la energía por el área: el brillo no cambia con el tamaño.
		const [ancho, alto] = l.area_tamano;
		luz = new THREE.RectAreaLight(color, l.energia * K_LUZ, ancho, alto);
	}
	if (luz === null) continue;
	luz.position.copy(posicion);
	luz.quaternion.copy(giro);
	escena.add(luz);
	if (luz.target) {
		luz.target.position.copy(posicion).add(new THREE.Vector3(0, 0, -1).applyQuaternion(giro));
		escena.add(luz.target);
	}
	luces.push(luz);
}
if (AMBIENTE > 0) escena.add(new THREE.AmbientLight(0xffffff, AMBIENTE));

// ---------------------------------------------------------------------------------------------
// Cámara
// ---------------------------------------------------------------------------------------------
// La pose real que tiene la cámara del juego en cada vista (X, Y, Z y origen de su base).
const VISTAS = await bajar('/datos/vistas.json', 'json');
const poner = (nombre) => {
	const v = VISTAS[nombre] ?? VISTAS.pasillo;
	camara.matrixAutoUpdate = false;
	camara.matrix.set(v[0], v[3], v[6], v[9], v[1], v[4], v[7], v[10], v[2], v[5], v[8], v[11], 0, 0, 0, 1);
	camara.matrixWorld.copy(camara.matrix);
	camara.matrixWorldInverse.copy(camara.matrixWorld).invert();
};
poner(VISTA);

// ---------------------------------------------------------------------------------------------
// Postproceso: tono de Godot, ajustes y el bloom del shader del juego
// ---------------------------------------------------------------------------------------------
const ESCALA = renderer.getDrawingBufferSize(new THREE.Vector2());
const rt = new THREE.RenderTarget(ESCALA.x, ESCALA.y, { type: THREE.HalfFloatType, samples: 0, depthBuffer: true });
const rtTono = new THREE.RenderTarget(ESCALA.x, ESCALA.y, { type: THREE.UnsignedByteType, depthBuffer: false });
const U = {
	umbral: uniform(0.9), suavidad: uniform(0.06), intensidad: uniform(0.65),
	paso: uniform(new THREE.Vector2(4 / ESCALA.x, 4 / ESCALA.y)),
	saturacion: uniform(entorno.saturacion), brillo: uniform(entorno.brillo), contraste: uniform(entorno.contraste),
};
const PESO = [1, 4, 6, 4, 1];
// El tono de Godot 4 (Filmic, el de Uncharted 2), después sRGB, después los ajustes de color:
// brillo, contraste y saturación, en ese orden y sobre el color ya codificado.
const tonificar = (lineal, etapa = 9) => {
	const sesgo = 2.0;
	const A = 0.22 * sesgo * sesgo, B = 0.3 * sesgo, C = 0.1, D = 0.2, E = 0.01, F = 0.3;
	const curva = (c) => c.mul(c.mul(A).add(C * B)).add(D * E).div(c.mul(c.mul(A).add(B)).add(D * F)).sub(E / F);
	const blanco = 1.0;
	const bl = (blanco * (A * blanco + C * B) + D * E) / (blanco * (A * blanco + B) + D * F) - E / F;
	let c = curva(lineal.max(vec3(0)).mul(entorno.tono_exposicion)).div(bl).max(vec3(0));
	if (etapa === 1) return c;
	const bajo = c.mul(12.92);
	const alto = c.max(6.10352e-5).pow(1 / 2.4).mul(1.055).sub(0.055);
	c = select(c.lessThan(0.0031308), bajo, alto);
	if (etapa === 2) return c;
	c = c.mul(U.brillo);
	if (etapa === 3) return c;
	c = mix(vec3(0.5), c, U.contraste);
	if (etapa === 4) return c;
	c = mix(vec3(c.dot(vec3(1)).mul(1 / 3)), c, U.saturacion);
	return c.clamp(vec3(0), vec3(1));
};
const materialTono = new THREE.MeshBasicNodeMaterial({ depthTest: false, depthWrite: false });
materialTono.colorNode = Fn(() => {
	const muestra = texture(rt.texture, screenUV).toVar();
	if (DEBUG === 'crudo' || DEBUG === 'lm' || ['l0', 'l1y', 'l1z', 'l1x'].includes(DEBUG)) return vec4(muestra.rgb, 1.0);
	if (DEBUG === 't0') return vec4(tonificar(vec3(0)), 1.0);
	if (DEBUG === 't1') return vec4(tonificar(vec3(0.18)), 1.0);
	if (DEBUG === 's1') return vec4(tonificar(vec3(0.18), 1), 1.0);
	if (DEBUG === 's3') return vec4(tonificar(vec3(0.18), 3), 1.0);
	if (DEBUG === 's4') return vec4(tonificar(vec3(0.18), 4), 1.0);
	if (DEBUG === 'u') return vec4(U.brillo, U.contraste, U.saturacion, 1.0);
	if (DEBUG === 's2') return vec4(tonificar(vec3(0.18), 2), 1.0);
	if (DEBUG === 'fondo') return vec4(FONDO, 1.0);
	const color = tonificar(muestra.rgb);
	const opaco = muestra.a.step(0.5);
	return vec4(mix(FONDO, color, opaco), 1.0);
})();
const materialBloom = new THREE.MeshBasicNodeMaterial({ depthTest: false, depthWrite: false });
materialBloom.colorNode = Fn(() => {
	if (PARAMS.get('sinbloom') === '1' || DEBUG) return vec4(texture(rtTono.texture, screenUV).rgb, 1.0);
	const suave = (s) => s.mul(s).mul(vec3(3).sub(s.mul(2)));
	const base = texture(rtTono.texture, screenUV).rgb.toVar();
	let halo = vec3(0);
	for (let y = -2; y <= 2; y += 1) {
		for (let x = -2; x <= 2; x += 1) {
			const muestra = texture(rtTono.texture, screenUV.add(vec2(x, y).mul(U.paso))).rgb.toVar();
			const l = muestra.dot(vec3(0.2126, 0.7152, 0.0722));
			const t = l.sub(U.umbral).div(U.suavidad).clamp(0, 1);
			halo = halo.add(muestra.mul(suave(t)).mul(PESO[x + 2] * PESO[y + 2]));
		}
	}
	halo = halo.mul(U.intensidad).div(256.0);
	const lc = base.dot(vec3(0.2126, 0.7152, 0.0722));
	const tb = lc.sub(U.umbral).div(U.suavidad).clamp(0, 1);
	halo = halo.mul(suave(tb).mul(-0.75).add(1));
	return vec4(vec3(1).sub(vec3(1).sub(base).mul(vec3(1).sub(halo.clamp(vec3(0), vec3(1))))), 1.0);
})();
const cuadroCon = (mat) => {
	const malla = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), mat);
	malla.frustumCulled = false;
	const g = new THREE.Scene();
	g.add(malla);
	return g;
};
const escenaDelTono = cuadroCon(materialTono);
const escenaDelBloom = cuadroCon(materialBloom);
const camaraDelCuadro = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);

function redimensionar() {
	const w = window.innerWidth, h = window.innerHeight;
	renderer.setSize(w, h);
	camara.aspect = w / h;
	camara.updateProjectionMatrix();
	rt.setSize(w, h);
	rtTono.setSize(w, h);
	U.paso.value.set(4 / w, 4 / h);
}
window.addEventListener('resize', redimensionar);
redimensionar();

function dibujarUnCuadro() {
	renderer.setRenderTarget(rt);
	renderer.render(escena, camara);
	renderer.setRenderTarget(rtTono);
	renderer.render(escenaDelTono, camaraDelCuadro);
	renderer.setRenderTarget(null);
	renderer.render(escenaDelBloom, camaraDelCuadro);
}

// ---------------------------------------------------------------------------------------------
// Carga: compilar todo antes del primer cuadro, como el calentamiento de Godot pero asíncrono
// ---------------------------------------------------------------------------------------------
decir('compilando');
if (!SALTAR_COMPILAR) {
	renderer.setRenderTarget(rt);
	await renderer.compileAsync(escena, camara);
	renderer.setRenderTarget(null);
	await renderer.compileAsync(escenaDelTono, camaraDelCuadro);
	await renderer.compileAsync(escenaDelBloom, camaraDelCuadro);
}
anotar('compilado');
dibujarUnCuadro();
// Un cuadro más y la GPU terminó: recién ahí la persona ve el almacén.
await new Promise((r) => requestAnimationFrame(() => requestAnimationFrame(r)));
dibujarUnCuadro();
anotar('almacen');
console.log('[carga] almacén en pantalla', JSON.stringify(marca));

const marcas = [];
const cpuCuadros = [];
let corriendo = true;
function bucle(t) {
	if (!corriendo) return;
	marcas.push(t);
	if (marcas.length > 60000) marcas.shift();
	const a = performance.now();
	dibujarUnCuadro();
	cpuCuadros.push(performance.now() - a);
	if (cpuCuadros.length > 60000) cpuCuadros.shift();
	requestAnimationFrame(bucle);
}
requestAnimationFrame(bucle);

window.__medir = async (ms) => {
	const pausa = (t) => new Promise((r) => setTimeout(r, t));
	await pausa(300);
	const desde = performance.now();
	await pausa(ms);
	const tiempos = marcas.filter((t) => t >= desde);
	const entre = tiempos.slice(1).map((t, i) => t - tiempos[i]).sort((a, b) => a - b);
	if (entre.length < 3) return null;
	const q = (p) => +entre[Math.floor((entre.length - 1) * p)].toFixed(2);
	return { cuadros: entre.length, p50: q(0.5), p95: q(0.95), p99: q(0.99), max: +entre[entre.length - 1].toFixed(1) };
};
window.__vista = (n) => { poner(n); return true; };
window.__cpu = (reiniciar = true) => {
	const e = cpuCuadros.slice().sort((a, b) => a - b);
	if (reiniciar) cpuCuadros.length = 0;
	if (e.length < 3) return null;
	const q = (p) => +e[Math.floor((e.length - 1) * p)].toFixed(3);
	return { cuadros: e.length, p50: q(0.5), p95: q(0.95), max: +e[e.length - 1].toFixed(2) };
};
window.__marca = marca;
window.__info = () => ({
	backend, api: API, rectas: tablaRectas.n, dibujos, fundidos, conAtlas, luces: luces.length, materiales: materiales.size,
	geometrias: geometrias.size, texturas: texturasBC.size, filasSH: filasSH.length, memoria: renderer.info?.memory ?? null,
	render: renderer.info?.render ?? null,
});
window.__renderer = renderer;
window.__listo = true;
decir(`${backend}\n${dibujos} dibujos`);
