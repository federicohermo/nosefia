shader_type spatial;

uniform vec4 color_plastico : source_color = vec4(0.12, 0.35, 0.5, 1.0);
uniform float rugosidad = 0.6;
uniform sampler2D textura : source_color, hint_default_white, filter_nearest_mipmap;
#include "res://src/escenas/objetos/articulacion_de_cabeza.gdshaderinc"
#include "res://src/escenas/objetos/oclusion_de_contacto.gdshaderinc"

void vertex() {
	articular_cabeza(VERTEX, NORMAL);
	contacto = contacto_del_vertice(MODEL_MATRIX, VERTEX, NORMAL);
}

void fragment() {
	ALBEDO = oscurecer_por_contacto(color_plastico.rgb * texture(textura, UV).rgb);
	ROUGHNESS = rugosidad;
}
