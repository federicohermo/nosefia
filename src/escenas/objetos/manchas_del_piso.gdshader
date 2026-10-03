shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform vec4 color_del_agua : source_color = vec4(0.3, 0.46, 0.16, 0.85);
uniform int tipo_de_suciedad = 0;
uniform bool acuosa = false;
uniform float transparencia = 0.85;
uniform sampler2D guia_de_manchas : filter_nearest_mipmap, repeat_disable;

float azar(vec2 punto) {
	punto = fract(punto * vec2(123.34, 456.21));
	punto += dot(punto, punto + 45.32);
	return fract(punto.x * punto.y);
}

float ruido(vec2 punto) {
	vec2 celda = floor(punto);
	vec2 local = fract(punto);
	vec2 mezcla = local * local * (3.0 - 2.0 * local);
	return mix(mix(azar(celda), azar(celda + vec2(1.0, 0.0)), mezcla.x),
		mix(azar(celda + vec2(0.0, 1.0)), azar(celda + vec2(1.0)), mezcla.x), mezcla.y);
}

float granos(vec2 punto) {
	vec2 celda = floor(punto);
	vec2 local = fract(punto) - 0.5;
	vec2 centro = vec2(azar(celda + 7.0), azar(celda + 19.0)) * 0.6 - 0.3;
	float radio = mix(0.06, 0.24, azar(celda + 31.0));
	return (1.0 - smoothstep(radio, radio + 0.04, length(local - centro)))
		* step(0.35, azar(celda));
}

void fragment() {
	vec2 punto = (UV - 0.5) * 2.0;
	float distancia = length(punto);
	float grueso = ruido(UV * 12.0);
	float fino = ruido(UV * 57.0);
	float mascara = 1.0 - smoothstep(0.80, 0.98, distancia);
	vec3 pintura = color_del_agua.rgb;
	float opacidad = transparencia;
	if (tipo_de_suciedad == 0) {
		// Colonias de moho, con moteado y esporas alrededor del centro.
		float colonia = smoothstep(0.30, 0.72, grueso * 0.7 + fino * 0.3);
		float nucleo = 1.0 - smoothstep(0.45, 0.88, distancia);
		mascara *= max(nucleo * colonia, granos(UV * 30.0) * 0.65);
		pintura *= mix(0.32, 1.55, colonia);
		ROUGHNESS = 0.94;
	} else if (tipo_de_suciedad == 1) {
		// Suciedad marrón salpicada: borde roto y pequeños grumos.
		float borde = 0.40 + 0.19 * ruido(UV * 13.0) + 0.085 * ruido(UV * 31.0);
		float cuerpo = 1.0 - smoothstep(borde - 0.015, borde + 0.025, distancia);
		mascara *= max(cuerpo, granos(UV * 19.0) * 0.65);
		pintura *= mix(0.50, 1.18, grueso * 0.65 + fino * 0.35);
		ROUGHNESS = 0.80;
	} else {
		// Reutiliza el dibujo del cartel; el papel queda transparente.
		vec2 recorte = clamp((UV - 0.5) / 0.70 + 0.5, vec2(0.0), vec2(1.0));
		vec3 tinta = texture(guia_de_manchas,
			vec2(0.585, 0.704) + recorte * vec2(0.369, 0.250)).rgb;
		float claridad = dot(tinta, vec3(0.299, 0.587, 0.114));
		mascara = 1.0 - smoothstep(0.18, 0.48, claridad);
		pintura = pow(tinta, vec3(2.2));
		opacidad = 0.96;
		ROUGHNESS = 0.95;
	}
	ALBEDO = pintura;
	ALPHA = color_del_agua.a * opacidad * mascara;
	SPECULAR = 0.10;
}
