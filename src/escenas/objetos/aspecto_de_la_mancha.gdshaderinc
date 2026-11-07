uniform int tipo_de_suciedad = 0;
uniform bool acuosa = false;
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

vec2 girar(vec2 punto, float coseno, float seno) {
	return vec2(coseno * punto.x - seno * punto.y, seno * punto.x + coseno * punto.y);
}

float granos(vec2 punto) {
	vec2 celda = floor(punto);
	vec2 local = fract(punto) - 0.5;
	vec2 centro = vec2(azar(celda + 7.0), azar(celda + 19.0)) * 0.4 - 0.2;
	float radio = mix(0.06, 0.24, azar(celda + 31.0));
	return (1.0 - smoothstep(radio, radio + 0.04, length(local - centro)))
		* step(0.35, azar(celda));
}

void pintar_mancha(vec2 uv, out vec3 albedo, out float alpha, out float rugosidad,
	out float especular) {
	vec2 punto = (uv - 0.5) * 2.0;
	float distancia = length(punto);
	float mascara = 1.0 - smoothstep(0.80, 0.98, distancia);
	vec3 pintura = color_del_agua.rgb;
	float opacidad = transparencia;
	if (tipo_de_suciedad == 0) {
		// Moho como el cartel: borde roto, huecos y grumos sueltos.
		// Cada octava gira el dominio: ningún borde ni hueco queda alineado a la grilla.
		vec2 giro_a = girar(uv, 0.7986, 0.6018);
		vec2 giro_b = girar(uv, 0.9205, -0.3907);
		float grueso = 0.65 * ruido(giro_a * 12.0 + vec2(17.3, 5.1))
			+ 0.35 * ruido(giro_b * 27.0 + vec2(3.7, 29.9));
		float medio = 0.6 * ruido(giro_b * 31.0 + vec2(41.1, 11.7))
			+ 0.4 * ruido(giro_a * 67.0 + vec2(7.9, 23.3));
		float fino = ruido(giro_a * 57.0 + vec2(13.1, 37.7));
		grueso = (grueso - 0.5) * 1.3 + 0.5;
		medio = (medio - 0.5) * 1.3 + 0.5;
		float borde = 0.22 + 0.38 * grueso + 0.10 * medio;
		float cuerpo = 1.0 - smoothstep(borde - 0.015, borde + 0.025, distancia);
		float hueco = 0.36 * distancia / max(borde, 0.01);
		cuerpo *= smoothstep(hueco - 0.12, hueco + 0.12, medio);
		mascara *= max(cuerpo, granos(uv * 13.0));
		pintura *= mix(0.6, 1.35, grueso * 0.65 + fino * 0.35);
		rugosidad = 0.94;
	} else if (tipo_de_suciedad == 1) {
		// Suciedad marrón salpicada: borde roto y pequeños grumos.
		float grueso = ruido(uv * 12.0);
		float fino = ruido(uv * 57.0);
		float borde = 0.40 + 0.19 * ruido(uv * 13.0) + 0.085 * ruido(uv * 31.0);
		float cuerpo = 1.0 - smoothstep(borde - 0.015, borde + 0.025, distancia);
		mascara *= max(cuerpo, granos(uv * 19.0) * 0.65);
		pintura *= mix(0.50, 1.18, grueso * 0.65 + fino * 0.35);
		rugosidad = 0.80;
	} else {
		// Reutiliza el dibujo del cartel; el papel queda transparente.
		vec2 recorte = clamp((uv - 0.5) / 0.78 + 0.5, vec2(0.0), vec2(1.0));
		vec3 tinta = texture(guia_de_manchas,
			vec2(0.585, 0.704) + recorte * vec2(0.369, 0.250)).rgb;
		float claridad = dot(tinta, vec3(0.299, 0.587, 0.114));
		mascara = 1.0 - smoothstep(0.18, 0.48, claridad);
		pintura = pow(tinta, vec3(2.2));
		opacidad = 0.96;
		rugosidad = 0.95;
	}
	albedo = pintura;
	alpha = color_del_agua.a * opacidad * mascara;
	especular = 0.10;
}
