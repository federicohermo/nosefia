uniform sampler2D fotografia : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 origen = vec3(-1.4, 1.8, -1.3);
uniform vec2 focal = vec2(0.20769, 0.42);
uniform float horizonte = 0.49;
uniform vec3 color_del_asfalto : source_color = vec3(0.105, 0.17, 0.16);
uniform vec3 color_de_la_vegetacion : source_color = vec3(0.045, 0.10, 0.065);

varying vec3 punto_mundial;

vec2 proyectar(vec3 punto) {
	vec3 q = punto - origen;
	float profundidad = max(-q.x, 0.001);
	return vec2(0.5 - focal.x * q.z / profundidad,
		horizonte - focal.y * q.y / profundidad);
}

float ruido(vec2 p) {
	vec2 celda = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	vec4 n = fract(sin(vec4(dot(celda, vec2(127.1, 311.7)),
		dot(celda + vec2(1.0, 0.0), vec2(127.1, 311.7)),
		dot(celda + vec2(0.0, 1.0), vec2(127.1, 311.7)),
		dot(celda + vec2(1.0), vec2(127.1, 311.7)))) * 43758.5453);
	return mix(mix(n.x, n.y, f.x), mix(n.z, n.w, f.x), f.y);
}

vec3 asfalto(vec2 punto) {
	// La superficie sencilla conserva la misma escala en toda la playa.
	// El grano subpíxel se promedia para evitar parpadeos al mover la cámara.
	float huella = max(length(dFdx(punto)), length(dFdy(punto))) * 55.0;
	float grano = mix(ruido(punto * 55.0), 0.5, smoothstep(0.5, 1.5, huella));
	float manchas = ruido(punto * 0.75);
	return color_del_asfalto * (0.80 + grano * 0.12 + manchas * 0.18);
}

vec3 vegetacion_baja(vec2 punto) {
	return color_de_la_vegetacion * (0.70 + ruido(punto * 16.0) * 0.30 + ruido(punto * 1.8) * 0.25);
}
