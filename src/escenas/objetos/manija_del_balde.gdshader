shader_type spatial;
render_mode cull_disabled;

uniform vec4 color : source_color;
uniform float rugosidad = 0.65;
uniform float metal = 0.0;
uniform sampler2D textura : source_color, hint_default_white, filter_nearest_mipmap;
// Con 0 no gira nada: el cuerpo del balde usa el mismo shader pero no tiene manija.
uniform float gira = 1.0;

#include "res://src/escenas/objetos/giro_de_manija.gdshaderinc"
#include "res://src/escenas/objetos/oclusion_de_contacto.gdshaderinc"

void vertex() {
	if (gira > 0.5) {
		girar_manija(VERTEX, NORMAL, UV2);
	}
	contacto = contacto_del_vertice(MODEL_MATRIX, VERTEX, NORMAL);
}

void fragment() {
	ALBEDO = oscurecer_por_contacto(color.rgb * texture(textura, UV).rgb);
	ROUGHNESS = rugosidad;
	METALLIC = metal;
}
