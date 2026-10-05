shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform vec4 color : source_color;
uniform float grosor;

#include "res://src/escenas/objetos/giro_de_manija.gdshaderinc"

void vertex() {
	girar_manija(VERTEX, NORMAL, UV2);
	vec4 punto = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	punto.xyz += normalize(MODELVIEW_NORMAL_MATRIX * NORMAL) * grosor;
	POSITION = PROJECTION_MATRIX * punto;
}

void fragment() {
	ALBEDO = color.rgb;
}
