// El material de un producto de la góndola.
//
// Reproduce lo que el `StandardMaterial3D` del modelo hace con los campos que los productos usan:
// la textura de color, la rugosidad, lo metálico y el especular, con el mismo filtro y los mismos
// modos de luz.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(1.0);
uniform sampler2D textura : source_color, filter_nearest_mipmap, repeat_enable;
uniform float rugosidad : hint_range(0.0, 1.0) = 0.5;
uniform float metalico : hint_range(0.0, 1.0) = 0.0;
uniform float especular : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	ALBEDO = color.rgb * texture(textura, UV).rgb;
	METALLIC = metalico;
	ROUGHNESS = rugosidad;
	SPECULAR = especular;
}
