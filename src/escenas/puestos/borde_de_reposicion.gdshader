shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 color : source_color;
uniform vec2 tamano;

void fragment() {
	vec2 borde = min(UV, vec2(1.0) - UV) * tamano;
	ALBEDO = color.rgb;
	ALPHA = mix(0.12, 0.85, 1.0 - step(0.006, min(borde.x, borde.y)));
}
