shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

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
	vec4 punto = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Separa las líneas de la superficie sin mostrarlas a través del estante.
	punto.z += 0.00002 * punto.w;
	POSITION = punto;
}

void fragment() {
	vec3 distancia = coordenadas.xyz / max(fwidth(coordenadas.xyz), vec3(0.00001));
	int mascara = int(round(coordenadas.w));
	float borde = 100000.0;
	// En los laterales curvos sólo quedan los límites de la vista. Los aros y las cajas
	// conservan las aristas reales del envase, sin diagonales entre triángulos.
	if ((mascara & 8) != 0 ? silueta.x > 0.5 : (mascara & 1) != 0) { borde = min(borde, distancia.x); }
	if ((mascara & 16) != 0 ? silueta.y > 0.5 : (mascara & 2) != 0) { borde = min(borde, distancia.y); }
	if ((mascara & 32) != 0 ? silueta.z > 0.5 : (mascara & 4) != 0) { borde = min(borde, distancia.z); }
	if (borde > grosor) { discard; }
	ALBEDO = color.rgb;
	// Dibuja después de la superficie invisible que oculta las aristas traseras del casillero.
	ALPHA = 1.0;
}
