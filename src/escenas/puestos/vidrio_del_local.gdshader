shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D marcas_del_vidrio : filter_linear_mipmap, repeat_enable;
uniform vec3 tinte : source_color = vec3(0.21, 0.32, 0.30);

void fragment() {
	float marcas = smoothstep(0.19, 0.37, texture(marcas_del_vidrio, UV).r);
	float rasante = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 4.0);
	ALBEDO = tinte + vec3(marcas * 0.24);
	ALPHA = clamp(0.10 + marcas * 0.28 + rasante * 0.30, 0.0, 0.65);
}
