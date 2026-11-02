// Visor del almacén con PlayCanvas 2.x (WebGL2). Mismos datos y mismas texturas BC que el de Three.js.
//
//   ?vista=mostrador|gondola|heladera|pasillo|deposito|bano
//
// Los muebles horneados llevan un material propio (GLSL) que evalúa el lightmap direccional como
// Godot. Lo que no tiene lightmap usa `StandardMaterial` con las luces reales del motor.

import * as pc from 'playcanvas';

const marca = {};
const anotar = (n) => { marca[n] = Math.round(performance.now()); };
anotar('modulo');
const PARAMS = new URLSearchParams(location.search);
const VISTA = PARAMS.get('vista') ?? 'pasillo';
const K_LM = Number(PARAMS.get('klm') ?? 6);
const K_LUZ = Number(PARAMS.get('kluz') ?? 2.5);
const K_AMB = Number(PARAMS.get('kamb') ?? 2.5);
const API = PARAMS.get('api') ?? 'webgl2';
const panel = document.getElementById('datos');

const bajar = async (u, tipo) => { const r = await fetch(u); return tipo === 'json' ? r.json() : r.arrayBuffer(); };
const [datos, lightmapJson, geometria, texJson, texBin, sondasBin, ltc, VISTAS] = await Promise.all([
	bajar('/datos/escena.json', 'json'), bajar('/datos/lightmap.json', 'json'), bajar('/datos/geometria.bin'),
	bajar('/datos/texturas.json', 'json'), bajar('/datos/texturas.bin'), bajar('/datos/sondas.bin'),
	bajar('/datos/ltc.json', 'json'), bajar('/datos/vistas.json', 'json'),
]);
anotar('datos');

// ---------------------------------------------------------------------------------------------
// Dispositivo y aplicación
// ---------------------------------------------------------------------------------------------
const canvas = document.createElement('canvas');
document.body.appendChild(canvas);
canvas.style.cssText = 'display:block;width:100%;height:100%';
const device = await pc.createGraphicsDevice(canvas, {
	deviceTypes: [API], antialias: false, powerPreference: 'high-performance',
});
anotar('dispositivo');
const opciones = new pc.AppOptions();
opciones.graphicsDevice = device;
opciones.componentSystems = [pc.RenderComponentSystem, pc.CameraComponentSystem, pc.LightComponentSystem];
opciones.resourceHandlers = [];
const app = new pc.AppBase(canvas);
app.init(opciones);
app.setCanvasFillMode(pc.FILLMODE_NONE);
device.maxPixelRatio = 1;
const W = window.innerWidth, H = window.innerHeight;
app.setCanvasResolution(pc.RESOLUTION_FIXED, W, H);
const backend = device.isWebGPU ? 'webgpu' : 'webgl2';

const escenaPC = app.scene;
escenaPC.lighting.areaLightsEnabled = true;
app.setAreaLightLuts(ltc.a, ltc.b);
escenaPC.lighting.shadowsEnabled = false;
escenaPC.gammaCorrection = pc.GAMMA_NONE;
escenaPC.toneMapping = pc.TONEMAP_NONE;
const entorno = datos.entorno;

// ---------------------------------------------------------------------------------------------
// Texturas BC: los bytes salen tal cual del paquete
// ---------------------------------------------------------------------------------------------
const FORMATOS = {
	bc1: [pc.PIXELFORMAT_DXT1, pc.PIXELFORMAT_DXT1_SRGB],
	bc3: [pc.PIXELFORMAT_DXT5, pc.PIXELFORMAT_DXT5_SRGBA],
	bc6hu: [pc.PIXELFORMAT_BC6UF, pc.PIXELFORMAT_BC6UF],
};
const texturas = new Map();
function texturaBC(clave, srgb) {
	const info = texJson[clave];
	if (!info || !FORMATOS[info.f]) return null;
	const id = `${clave}|${srgb}`;
	if (texturas.has(id)) return texturas.get(id);
	const niveles = info.niveles.map((n) => new Uint8Array(texBin, n.o, n.n));
	const t = new pc.Texture(device, {
		name: clave, width: info.w, height: info.h, format: FORMATOS[info.f][srgb ? 1 : 0],
		mipmaps: niveles.length > 1, levels: niveles, minFilter: niveles.length > 1 ? pc.FILTER_LINEAR_MIPMAP_LINEAR : pc.FILTER_LINEAR,
		magFilter: pc.FILTER_LINEAR, addressU: pc.ADDRESS_REPEAT, addressV: pc.ADDRESS_REPEAT, anisotropy: 4,
	});
	texturas.set(id, t);
	return t;
}
const capasLM = [0, 1, 2, 3].map((k) => {
	const t = texturaBC(`__lightmap${k}__`, false);
	t.addressU = pc.ADDRESS_CLAMP_TO_EDGE; t.addressV = pc.ADDRESS_CLAMP_TO_EDGE; t.anisotropy = 1;
	return t;
});
const ALTO_LM = lightmapJson.alto;

// ---------------------------------------------------------------------------------------------
// Material de lo horneado: lightmap direccional × albedo, y la niebla de Godot
// ---------------------------------------------------------------------------------------------
const vertice = `
attribute vec3 aPosition;
attribute vec3 aNormal;
attribute vec2 aUv0;
attribute vec2 aUv1;
uniform mat4 matrix_model;
uniform mat4 matrix_viewProjection;
uniform mat4 matrix_view;
varying vec2 vUv0;
varying vec2 vUv1;
varying vec3 vNormal;
varying float vProfundidad;
void main(void) {
	vec4 mundo = matrix_model * vec4(aPosition, 1.0);
	gl_Position = matrix_viewProjection * mundo;
	vUv0 = aUv0;
	vUv1 = aUv1;
	vNormal = mat3(matrix_model) * aNormal;
	vProfundidad = -(matrix_view * mundo).z;
}`;
const fragmento = `
varying vec2 vUv0;
varying vec2 vUv1;
varying vec3 vNormal;
varying float vProfundidad;
uniform sampler2D uAlbedo;
uniform sampler2D uL0;
uniform sampler2D uL1y;
uniform sampler2D uL1z;
uniform sampler2D uL1x;
uniform vec4 uColor;
uniform vec3 uEmision;
uniform float uTieneAlbedo;
uniform sampler2D uEmisionTex;
uniform float uTieneEmision;
uniform float uK;
uniform vec3 uFogColor;
uniform vec3 uFog;
void main(void) {
	vec3 n = normalize(vNormal);
	if (!gl_FrontFacing) n = -n;
	vec3 l0 = texture2D(uL0, vUv1).rgb;
	vec3 l1y = (texture2D(uL1y, vUv1).rgb - 0.5) * 2.0;
	vec3 l1z = (texture2D(uL1z, vUv1).rgb - 0.5) * 2.0;
	vec3 l1x = (texture2D(uL1x, vUv1).rgb - 0.5) * 2.0;
	vec3 irr = l0 * (0.282095 + 0.32573 * (l1y * n.y + l1z * n.z + l1x * n.x));
	vec3 albedo = uColor.rgb;
	if (uTieneAlbedo > 0.5) albedo *= texture2D(uAlbedo, vUv0).rgb;
	vec3 emision = uEmision;
	if (uTieneEmision > 0.5) emision *= texture2D(uEmisionTex, vUv0).rgb;
	vec3 c = max(irr, vec3(0.0)) * albedo * uK + emision;
	float t = pow(smoothstep(uFog.x, uFog.y, vProfundidad), uFog.z);
	c = mix(c, uFogColor, t * uFog.z * 0.0 + t * ${entorno.niebla_densidad.toFixed(4)});
	gl_FragColor = vec4(c, 1.0);
}`;

// El pixel de un material sin albedo: una textura blanca de 1x1 para no dejar el sampler vacío.
const blanca = new pc.Texture(device, { width: 1, height: 1, format: pc.PIXELFORMAT_RGBA8, mipmaps: false, levels: [new Uint8Array([255, 255, 255, 255])] });

const horneados = new Map();
function materialHorneado(clave) {
	if (horneados.has(clave)) return horneados.get(clave);
	const m = datos.materiales[clave];
	const mat = new pc.ShaderMaterial({
		uniqueName: 'horneado',
		attributes: { aPosition: pc.SEMANTIC_POSITION, aNormal: pc.SEMANTIC_NORMAL, aUv0: pc.SEMANTIC_TEXCOORD0, aUv1: pc.SEMANTIC_TEXCOORD1 },
		vertexGLSL: vertice, fragmentGLSL: fragmento,
	});
	const albedo = m.albedo_textura ? texturaBC(m.albedo_textura, true) : null;
	mat.setParameter('uAlbedo', albedo ?? blanca);
	mat.setParameter('uTieneAlbedo', albedo ? 1 : 0);
	mat.setParameter('uColor', [m.albedo[0], m.albedo[1], m.albedo[2], 1]);
	const e = m.emision ? m.emision_color.slice(0, 3).map((v) => v * m.emision_energia) : [0, 0, 0];
	mat.setParameter('uEmision', e);
	const et = m.emision && m.emision_textura ? texturaBC(m.emision_textura, true) : null;
	mat.setParameter('uEmisionTex', et ?? blanca);
	mat.setParameter('uTieneEmision', et ? 1 : 0);
	mat.setParameter('uL0', capasLM[0]); mat.setParameter('uL1y', capasLM[1]);
	mat.setParameter('uL1z', capasLM[2]); mat.setParameter('uL1x', capasLM[3]);
	mat.setParameter('uK', K_LM);
	mat.setParameter('uFogColor', entorno.niebla_color.slice(0, 3).map((v) => v * entorno.niebla_energia));
	mat.setParameter('uFog', [entorno.niebla_inicio, entorno.niebla_fin, entorno.niebla_curva]);
	mat.cull = m.cull === 2 ? pc.CULLFACE_NONE : pc.CULLFACE_BACK;
	mat.update();
	horneados.set(clave, mat);
	return mat;
}

// ---------------------------------------------------------------------------------------------
// Materiales con luces: los de lo que no tiene lightmap (productos, puertas, objetos)
// ---------------------------------------------------------------------------------------------
const dinamicos = new Map();
function materialDinamico(clave) {
	if (dinamicos.has(clave)) return dinamicos.get(clave);
	const m = datos.materiales[clave];
	const mat = new pc.StandardMaterial();
	mat.useMetalness = true;
	mat.diffuse = new pc.Color(m.albedo[0], m.albedo[1], m.albedo[2]);
	const albedo = m.albedo_textura ? texturaBC(m.albedo_textura, true) : null;
	if (albedo) mat.diffuseMap = albedo;
	mat.metalness = m.metalico;
	mat.gloss = 1 - m.rugosidad;
	if (m.orm_textura) {
		const orm = texturaBC(m.orm_textura, false);
		if (orm) {
			mat.glossMap = orm; mat.glossMapChannel = 'g'; mat.glossInvert = true;
			mat.metalnessMap = orm; mat.metalnessMapChannel = 'b';
			mat.gloss = 1; mat.metalness = m.metalico;
		}
	}
	if (m.emision) {
		mat.emissive = new pc.Color(m.emision_color[0], m.emision_color[1], m.emision_color[2]);
		mat.emissiveIntensity = m.emision_energia;
		const e = m.emision_textura ? texturaBC(m.emision_textura, true) : null;
		if (e) mat.emissiveMap = e;
	}
	mat.cull = m.cull === 2 ? pc.CULLFACE_NONE : pc.CULLFACE_BACK;
	if (m.transparencia === 1) { mat.blendType = pc.BLEND_NORMAL; mat.opacity = m.albedo[3]; if (albedo) mat.opacityMap = albedo; mat.depthWrite = false; }
	else if (m.transparencia >= 2) { mat.alphaTest = m.alpha_scissor ?? 0.5; if (albedo) mat.opacityMap = albedo; }
	mat.useLighting = true;
	mat.useSkybox = false;
	mat.update();
	dinamicos.set(clave, mat);
	return mat;
}

// ---------------------------------------------------------------------------------------------
// Geometría
// ---------------------------------------------------------------------------------------------
const mallas = new Map();
function mallaDe(claveMalla, superficie, rect) {
	const id = `${claveMalla}#${superficie}#${rect ? rect.join(',') : 'sin'}`;
	if (mallas.has(id)) return mallas.get(id);
	const dm = datos.mallas[claveMalla];
	if (!dm) return null;
	const s = dm[superficie];
	const m = new pc.Mesh(device);
	m.setPositions(new Float32Array(new Float32Array(geometria, s.pos[0], s.vertices * 3)));
	m.setNormals(new Float32Array(new Float32Array(geometria, s.nor[0], s.vertices * 3)));
	if (s.uv[1] > 0) m.setUvs(0, new Float32Array(new Float32Array(geometria, s.uv[0], s.vertices * 2)));
	if (s.uv2[1] > 0 && rect) {
		const uv2 = new Float32Array(new Float32Array(geometria, s.uv2[0], s.vertices * 2));
		const alto = ALTO_LM / 2048;
		for (let i = 0; i < uv2.length; i += 2) {
			uv2[i] = rect[0] + uv2[i] * rect[2];
			uv2[i + 1] = (rect[1] + uv2[i + 1] * rect[3]) / alto;
		}
		m.setUvs(1, uv2);
	}
	if (s.indices[1] > 0) {
		const idx = new Uint32Array(new Uint32Array(geometria, s.indices[0], s.cuantos_indices));
		for (let i = 0; i < idx.length; i += 3) { const t = idx[i + 1]; idx[i + 1] = idx[i + 2]; idx[i + 2] = t; }
		m.setIndices(idx);
	}
	m.update();
	mallas.set(id, m);
	return m;
}
const rectangulos = lightmapJson.rectangulos;
function rectDe(ruta) {
	if (rectangulos[ruta]) return rectangulos[ruta];
	for (const k of Object.keys(rectangulos)) if (k.endsWith('/' + ruta)) return rectangulos[k];
	return null;
}
const aMat4 = (t) => new pc.Mat4().set([t[0], t[1], t[2], 0, t[3], t[4], t[5], 0, t[6], t[7], t[8], 0, t[9], t[10], t[11], 1]);
const capaMundo = app.scene.layers.getLayerById(pc.LAYERID_WORLD);
const instancias = [];
function entidadDe(m4) {
	const e = new pc.GraphNode();
	e.setLocalPosition(m4.getTranslation());
	e.setLocalScale(m4.getScale());
	const q = new pc.Quat().setFromMat4(m4);
	e.setLocalRotation(q);
	app.root.addChild(e);
	return e;
}
let dibujos = 0, conAtlas = 0;
for (const dibujo of datos.dibujos) {
	if (!dibujo.visible) continue;
	const rect = rectDe(dibujo.ruta);
	const dm = datos.mallas[dibujo.malla];
	if (!dm) continue;
	const m4 = aMat4(dibujo.transform);
	const nodo = entidadDe(m4);
	for (let sup = 0; sup < dm.length; sup += 1) {
		const clave = dibujo.override || dibujo.materiales[sup];
		const malla = mallaDe(dibujo.malla, sup, rect);
		if (!malla || !clave) continue;
		const horneado = rect !== null && datos.mallas[dibujo.malla][sup].uv2[1] > 0;
		if (horneado) conAtlas += 1;
		const mi = new pc.MeshInstance(malla, horneado ? materialHorneado(clave) : materialDinamico(clave), nodo);
		instancias.push(mi);
		dibujos += 1;
	}
}
// Productos: una copia por lugar, una instancia de dibujo por producto.
const formatoInstancia = new pc.VertexFormat(device, [
	{ semantic: pc.SEMANTIC_ATTR12, components: 4, type: pc.TYPE_FLOAT32 },
	{ semantic: pc.SEMANTIC_ATTR13, components: 4, type: pc.TYPE_FLOAT32 },
	{ semantic: pc.SEMANTIC_ATTR14, components: 4, type: pc.TYPE_FLOAT32 },
	{ semantic: pc.SEMANTIC_ATTR15, components: 4, type: pc.TYPE_FLOAT32 },
]);
for (const producto of datos.productos) {
	const copias = producto.principal.concat(producto.guias);
	const dm = datos.mallas[producto.malla];
	if (copias.length === 0 || !dm) continue;
	const buf = new Float32Array(copias.length * 16);
	copias.forEach((c, i) => { const m = aMat4(c); if (PARAMS.get('trans') === '1') m.transpose(); buf.set(m.data, i * 16); });
	for (let sup = 0; sup < dm.length; sup += 1) {
		const malla = mallaDe(producto.malla, sup, null);
		const clave = producto.materiales[sup] ?? producto.materiales[0];
		if (PARAMS.get('noinst') === '1') {
			for (const c of copias) instancias.push(new pc.MeshInstance(malla, materialDinamico(clave), entidadDe(aMat4(c))));
			continue;
		}
		const nodo = new pc.GraphNode();
		app.root.addChild(nodo);
		const mi = new pc.MeshInstance(malla, materialDinamico(clave), nodo);
		mi.setInstancing(new pc.VertexBuffer(device, pc.VertexFormat.getDefaultInstancingFormat(device), copias.length, { data: buf }));
		mi.cull = false;
		instancias.push(mi);
	}
}
capaMundo.addMeshInstances(instancias);
anotar('geometria');

// ---------------------------------------------------------------------------------------------
// Luces
// ---------------------------------------------------------------------------------------------
const giroDeLuz = new pc.Quat().setFromEulerAngles(90, 0, 0);
let luces = 0;
for (const l of datos.luces) {
	const m4 = aMat4(l.transform);
	const e = new pc.Entity();
	const color = new pc.Color(l.color[0], l.color[1], l.color[2]);
	let cfg;
	if (l.tipo === 'SpotLight3D') {
		cfg = { type: 'spot', color, intensity: l.energia * K_LUZ, range: l.rango, outerConeAngle: l.angulo, innerConeAngle: l.angulo * 0.6, falloffMode: pc.LIGHTFALLOFF_INVERSESQUARED, castShadows: false };
	} else if (l.tipo === 'OmniLight3D') {
		cfg = { type: 'omni', color, intensity: l.energia * K_LUZ, range: l.rango, falloffMode: pc.LIGHTFALLOFF_INVERSESQUARED, castShadows: false };
	} else if (l.tipo === 'AreaLight3D' && PARAMS.get('area') !== '0') {
		cfg = { type: 'spot', shape: pc.LIGHTSHAPE_RECT, color, intensity: l.energia * K_LUZ, range: l.area_rango, outerConeAngle: 90, innerConeAngle: 80, falloffMode: pc.LIGHTFALLOFF_INVERSESQUARED, castShadows: false, normalOffsetBias: 0 };
	} else continue;
	e.addComponent('light', cfg);
	e.setLocalPosition(m4.getTranslation());
	const q = new pc.Quat().setFromMat4(m4).mul(giroDeLuz);
	e.setLocalRotation(q);
	if (l.tipo === 'AreaLight3D') e.setLocalScale(l.area_tamano[0], 1, l.area_tamano[1]);
	app.root.addChild(e);
	luces += 1;
}
// Sin sondas por instancia: la luz indirecta de lo dinámico es el promedio de las sondas.
{
	const cab = new Uint32Array(sondasBin, 0, 3);
	const [np, nt, nsh] = cab;
	const sh = new Float32Array(sondasBin, 12 + np * 12 + nt * 16, nsh * 4);
	const prom = [0, 0, 0];
	for (let i = 0; i < np; i += 1) for (let c = 0; c < 3; c += 1) prom[c] += sh[i * 9 * 4 + c] * 0.886227 / np;
	escenaPC.ambientLight = new pc.Color(prom[0] * K_AMB, prom[1] * K_AMB, prom[2] * K_AMB);
}

// ---------------------------------------------------------------------------------------------
// Cámara, postproceso (tono de Godot y bloom)
// ---------------------------------------------------------------------------------------------
const colorBuf = new pc.Texture(device, { name: 'escena', width: W, height: H, format: pc.PIXELFORMAT_RGBA16F, mipmaps: false, minFilter: pc.FILTER_NEAREST, magFilter: pc.FILTER_NEAREST, addressU: pc.ADDRESS_CLAMP_TO_EDGE, addressV: pc.ADDRESS_CLAMP_TO_EDGE });
const rt = new pc.RenderTarget({ colorBuffer: colorBuf, depth: true, samples: 1 });
const tonoBuf = new pc.Texture(device, { name: 'tono', width: W, height: H, format: pc.PIXELFORMAT_RGBA8, mipmaps: false, minFilter: pc.FILTER_LINEAR, magFilter: pc.FILTER_LINEAR, addressU: pc.ADDRESS_CLAMP_TO_EDGE, addressV: pc.ADDRESS_CLAMP_TO_EDGE });
const rtTono = new pc.RenderTarget({ colorBuffer: tonoBuf, depth: false, samples: 1 });

const camEntidad = new pc.Entity();
camEntidad.addComponent('camera', {
	fov: 75, nearClip: 0.05, farClip: 300, clearColor: new pc.Color(0, 0, 0, 0), renderTarget: rt,
	toneMapping: pc.TONEMAP_NONE, gammaCorrection: pc.GAMMA_NONE,
});
app.root.addChild(camEntidad);
const poner = (n) => {
	const v = VISTAS[n] ?? VISTAS.pasillo;
	const m = new pc.Mat4().set([v[0], v[1], v[2], 0, v[3], v[4], v[5], 0, v[6], v[7], v[8], 0, v[9], v[10], v[11], 1]);
	camEntidad.setPosition(v[9], v[10], v[11]);
	camEntidad.setRotation(new pc.Quat().setFromMat4(m));
};
poner(VISTA);

const verticeQuad = `
attribute vec2 vertex_position;
varying vec2 vUv;
void main(void) { gl_Position = vec4(vertex_position, 0.5, 1.0); vUv = vertex_position * 0.5 + 0.5; }`;
const sesgo = 2.0, A = 0.22 * sesgo * sesgo, B = 0.3 * sesgo, C = 0.1, D = 0.2, E = 0.01, F = 0.3;
const blancoF = (1 * (A + C * B) + D * E) / (1 * (A + B) + D * F) - E / F;
const fragmentoTono = `
varying vec2 vUv;
uniform sampler2D uEscena;
uniform vec3 uAjustes;
vec3 curva(vec3 c) { return (c * (c * ${A.toFixed(5)} + ${(C * B).toFixed(5)}) + ${(D * E).toFixed(5)}) / (c * (c * ${A.toFixed(5)} + ${B.toFixed(5)}) + ${(D * F).toFixed(5)}) - ${(E / F).toFixed(6)}; }
void main(void) {
	vec4 s = texture2D(uEscena, vUv);
	vec3 c = max(curva(max(s.rgb, vec3(0.0)) * ${entorno.tono_exposicion.toFixed(4)}) / ${blancoF.toFixed(6)}, vec3(0.0));
	c = mix(c * 12.92, pow(max(c, vec3(6.10352e-5)), vec3(1.0 / 2.4)) * 1.055 - 0.055, step(vec3(0.0031308), c));
	c *= uAjustes.x;
	c = mix(vec3(0.5), c, uAjustes.y);
	c = mix(vec3(dot(c, vec3(1.0)) / 3.0), c, uAjustes.z);
	c = clamp(c, 0.0, 1.0);
	vec3 fondo = vec3(${entorno.fondo[0]}, ${entorno.fondo[1]}, ${entorno.fondo[2]});
	gl_FragColor = vec4(mix(fondo, c, step(0.5, s.a)), 1.0);
}`;
const fragmentoBloom = `
varying vec2 vUv;
uniform sampler2D uTono;
uniform vec2 uPaso;
vec3 suave(vec3 s) { return s * s * (3.0 - 2.0 * s); }
void main(void) {
	vec3 base = texture2D(uTono, vUv).rgb;
	vec3 halo = vec3(0.0);
	float pesos[5];
	pesos[0] = 1.0; pesos[1] = 4.0; pesos[2] = 6.0; pesos[3] = 4.0; pesos[4] = 1.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec3 m = texture2D(uTono, vUv + vec2(float(x), float(y)) * uPaso).rgb;
			float l = dot(m, vec3(0.2126, 0.7152, 0.0722));
			float t = clamp((l - 0.9) / 0.06, 0.0, 1.0);
			halo += m * suave(vec3(t)) * pesos[x + 2] * pesos[y + 2];
		}
	}
	halo *= 0.65 / 256.0;
	float lc = dot(base, vec3(0.2126, 0.7152, 0.0722));
	float tb = clamp((lc - 0.9) / 0.06, 0.0, 1.0);
	halo *= 1.0 - 0.75 * suave(vec3(tb)).x;
	gl_FragColor = vec4(vec3(1.0) - (vec3(1.0) - base) * (vec3(1.0) - clamp(halo, 0.0, 1.0)), 1.0);
}`;
const sTono = pc.ShaderUtils.createShader(device, { uniqueName: 'tono', attributes: { vertex_position: pc.SEMANTIC_POSITION }, vertexGLSL: verticeQuad, fragmentGLSL: fragmentoTono });
const sBloom = pc.ShaderUtils.createShader(device, { uniqueName: 'bloom', attributes: { vertex_position: pc.SEMANTIC_POSITION }, vertexGLSL: verticeQuad, fragmentGLSL: fragmentoBloom });
const scope = device.scope;
app.on('postrender', () => {
	scope.resolve('uEscena').setValue(colorBuf);
	scope.resolve('uAjustes').setValue([entorno.brillo, entorno.contraste, entorno.saturacion]);
	pc.drawQuadWithShader(device, rtTono, sTono);
	scope.resolve('uTono').setValue(tonoBuf);
	scope.resolve('uPaso').setValue([4 / W, 4 / H]);
	pc.drawQuadWithShader(device, null, sBloom);
});

// ---------------------------------------------------------------------------------------------
// Carga y medición
// ---------------------------------------------------------------------------------------------
app.start();
const esperarCuadro = () => new Promise((r) => requestAnimationFrame(() => r()));
for (let i = 0; i < 3; i += 1) await esperarCuadro();
anotar('almacen');
console.log('[carga] almacén en pantalla', JSON.stringify(marca));
const marcas = [];
const anotarCuadro = (t) => { marcas.push(t); if (marcas.length > 60000) marcas.shift(); requestAnimationFrame(anotarCuadro); };
requestAnimationFrame(anotarCuadro);
window.__medir = async (ms) => {
	await new Promise((r) => setTimeout(r, 300));
	const desde = performance.now();
	await new Promise((r) => setTimeout(r, ms));
	const t = marcas.filter((x) => x >= desde);
	const e = t.slice(1).map((x, i) => x - t[i]).sort((a, b) => a - b);
	const q = (p) => +e[Math.floor((e.length - 1) * p)].toFixed(2);
	return { cuadros: e.length, p50: q(0.5), p95: q(0.95), p99: q(0.99), max: +e[e.length - 1].toFixed(1) };
};
window.__vista = (n) => { poner(n); return true; };
window.__marca = marca;
window.__pcdebug = () => ({ area: app.scene.lighting.areaLightsEnabled, luces: app.root.children.filter((e) => e.light).map((e) => ({ tipo: e.light.type, forma: e.light.shape, rango: e.light.range, int: e.light.intensity, enabled: e.light.enabled, pos: e.getPosition().toArray().map((v) => +v.toFixed(2)) })).slice(0, 30) });
window.__info = () => ({ backend, dibujos, conAtlas, luces, materiales: horneados.size + dinamicos.size, mallas: mallas.size, texturas: texturas.size, version: pc.version });
window.__listo = true;
if (panel) panel.textContent = `PlayCanvas ${pc.version}\n${backend}\n${dibujos} dibujos`;
