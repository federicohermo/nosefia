shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 centro = (UV - vec2(0.5)) * vec2(1.0, 1.15);
	// El centro apenas iluminado cae a negro en los bordes, como el vidrio de una pantalla.
	float vineta = 1.0 - smoothstep(0.12, 0.72, length(centro));
	COLOR = vec4(vec3(0.022, 0.026, 0.025) * vineta, 1.0);
}
