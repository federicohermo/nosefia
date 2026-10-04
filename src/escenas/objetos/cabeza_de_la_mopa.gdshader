shader_type spatial;

uniform vec4 color_plastico : source_color = vec4(0.12, 0.35, 0.5, 1.0);
uniform float rugosidad = 0.6;
#include "res://src/escenas/objetos/articulacion_de_cabeza.gdshaderinc"

void vertex() {
	articular_cabeza(VERTEX, NORMAL);
}

void fragment() {
	ALBEDO = color_plastico.rgb;
	ROUGHNESS = rugosidad;
}
