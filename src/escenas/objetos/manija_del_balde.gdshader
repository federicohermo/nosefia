shader_type spatial;
render_mode cull_disabled;

uniform vec4 color : source_color;
uniform float rugosidad = 0.65;
uniform float metal = 0.0;
uniform sampler2D textura : source_color, hint_default_white, filter_nearest_mipmap;

#include "res://src/escenas/objetos/giro_de_manija.gdshaderinc"

void vertex() {
	girar_manija(VERTEX, NORMAL, UV2);
}

void fragment() {
	ALBEDO = color.rgb * texture(textura, UV).rgb;
	ROUGHNESS = rugosidad;
	METALLIC = metal;
}
