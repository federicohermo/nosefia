// La vista previa conserva cada textura y su brillo, en gris y sin ocultar el estante.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(1.0);
uniform sampler2D textura : source_color, filter_nearest_mipmap, repeat_enable;
uniform float rugosidad : hint_range(0.0, 1.0) = 0.5;
uniform float metalico : hint_range(0.0, 1.0) = 0.0;
uniform float especular : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec3 base = color.rgb * texture(textura, UV).rgb;
	float gris = dot(base, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = vec3(gris);
	METALLIC = metalico;
	ROUGHNESS = rugosidad;
	SPECULAR = especular;
	ALPHA = 0.75;
}
