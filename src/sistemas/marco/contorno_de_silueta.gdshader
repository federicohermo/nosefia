shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform sampler2D figura : source_color, filter_nearest;
uniform vec4 color : source_color;

void fragment() {
	vec2 paso = 1.0 / vec2(textureSize(figura, 0));
	float alfa = texture(figura, UV).a;
	float vecino = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec2 punto = UV + vec2(float(x), float(y)) * paso;
			if (all(greaterThanEqual(punto, vec2(0.0))) && all(lessThanEqual(punto, vec2(1.0)))) {
				vecino = max(vecino, texture(figura, punto).a);
			}
		}
	}
	ALBEDO = color.rgb;
	ALPHA = alfa <= 0.0 && vecino > 0.0 ? color.a : 0.0;
}
