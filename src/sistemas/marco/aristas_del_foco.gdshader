shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, shadows_disabled;

uniform vec4 color : source_color;
// Semigrosor en píxeles: no cambia con la escala del envase ni con la distancia.
uniform float grosor;
varying vec4 coordenadas;
varying flat vec3 silueta;

float es_silueta(vec4 plano, vec3 ojo) {
	if (length(plano.xyz) < 0.1) { return 1.0; }
	return dot(plano.xyz, ojo) <= plano.w ? 1.0 : 0.0;
}

void vertex() {
	coordenadas = CUSTOM0;
	vec3 ojo = (inverse(MODELVIEW_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	silueta = vec3(es_silueta(CUSTOM1, ojo), es_silueta(CUSTOM2, ojo), es_silueta(CUSTOM3, ojo));
	// Acerca medio milímetro por el mismo rayo: funciona con ambas convenciones de profundidad
	// y conserva el contorno en pantalla, sin atravesar el estante.
	vec4 punto = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	punto.xyz *= 1.0 - 0.0005 / max(length(punto.xyz), 0.001);
	POSITION = PROJECTION_MATRIX * punto;
}

void fragment() {
	vec3 distancia = coordenadas.xyz / max(fwidth(coordenadas.xyz), vec3(0.00001));
	int mascara = int(round(coordenadas.w));
	float borde = 100000.0;
	// En una curva sólo queda el tramo de aro que es silueta: el contorno, y no las líneas que
	// cruzan el envase por delante. Las cajas y las tapas conservan sus aristas reales, sin
	// diagonales entre triángulos.
	if ((mascara & 8) != 0 ? (mascara & 64) != 0 && silueta.x > 0.5 : (mascara & 1) != 0) { borde = min(borde, distancia.x); }
	if ((mascara & 16) != 0 ? (mascara & 128) != 0 && silueta.y > 0.5 : (mascara & 2) != 0) { borde = min(borde, distancia.y); }
	if ((mascara & 32) != 0 ? (mascara & 256) != 0 && silueta.z > 0.5 : (mascara & 4) != 0) { borde = min(borde, distancia.z); }
	if (borde > grosor) { discard; }
	ALBEDO = color.rgb;
	// El contorno entra en la imagen opaca para conservarse al aplicar el desenfoque selectivo.
}
