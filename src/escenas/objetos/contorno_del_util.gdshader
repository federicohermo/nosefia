shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never;

uniform vec4 color : source_color;
uniform float grosor;
// Un solo programa de contorno conserva la deformación propia de cada parte.
uniform int deformacion = 0;

#include "res://src/escenas/objetos/articulacion_de_cabeza.gdshaderinc"
#include "res://src/escenas/objetos/deformacion_de_fibras.gdshaderinc"
#include "res://src/escenas/objetos/giro_de_manija.gdshaderinc"

void vertex() {
	if (deformacion == 0) {
		deformar_fibras(VERTEX, NORMAL, MODEL_MATRIX, UV2);
	} else if (deformacion == 1) {
		articular_cabeza(VERTEX, NORMAL);
	} else {
		girar_manija(VERTEX, NORMAL, UV2);
	}
	vec4 punto = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	punto.xyz += normalize(MODELVIEW_NORMAL_MATRIX * NORMAL) * grosor;
	POSITION = PROJECTION_MATRIX * punto;
}

void fragment() {
	ALBEDO = color.rgb;
}
