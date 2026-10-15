// La vista previa gris ignora la iluminación para que una sombra no oculte la colocación.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0);
uniform sampler2D textura : source_color, filter_nearest_mipmap, repeat_enable;

void fragment() {
	vec3 base = color.rgb * texture(textura, UV).rgb;
	float gris = dot(base, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = vec3(gris);
	ALPHA = 0.75;
}
