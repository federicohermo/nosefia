shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 color : source_color;
// Semigrosor en píxeles: no cambia con la escala del envase ni con la distancia.
uniform float grosor;
varying vec4 coordenadas;

void vertex() {
	coordenadas = CUSTOM0;
	vec4 punto = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// Separa las líneas de la superficie sin mostrarlas a través del estante.
	punto.z += 0.00002 * punto.w;
	POSITION = punto;
}

void fragment() {
	vec3 distancia = coordenadas.xyz / max(fwidth(coordenadas.xyz), vec3(0.00001));
	int mascara = int(round(coordenadas.w));
	float borde = 100000.0;
	if ((mascara & 1) != 0) { borde = min(borde, distancia.x); }
	if ((mascara & 2) != 0) { borde = min(borde, distancia.y); }
	if ((mascara & 4) != 0) { borde = min(borde, distancia.z); }
	if (borde > grosor) { discard; }
	ALBEDO = color.rgb;
	// Dibuja después de la superficie invisible que oculta las aristas traseras del casillero.
	ALPHA = 1.0;
}
