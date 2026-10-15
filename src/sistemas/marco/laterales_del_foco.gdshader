shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, shadows_disabled;

uniform vec4 color : source_color;
uniform float grosor = 3.0;
varying flat float curva;
varying vec3 normal_original;

void vertex() {
	curva = (int(round(CUSTOM0.w)) & 56) != 0 ? 1.0 : 0.0;
	vec3 normal = MODELVIEW_NORMAL_MATRIX * NORMAL;
	normal_original = normal;
	vec2 direccion = normal.xy / max(length(normal.xy), 0.00001);
	vec4 punto = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	punto.xy += direccion * grosor * 2.0 / VIEWPORT_SIZE * punto.w;
	POSITION = punto;
}

void fragment() {
	if (curva < 0.5) { discard; }
	// NORMAL se invierte al dibujar el reverso de una cara; conservar el original evita
	// descartar también la cara trasera que ensancha la silueta del cilindro.
	if (dot(normal_original, VIEW) > 0.0) { discard; }
	ALBEDO = color.rgb;
}
