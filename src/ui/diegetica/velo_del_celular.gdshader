shader_type canvas_item;
render_mode unshaded;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;

void fragment() {
	// Compatibility no genera mipmaps de pantalla: el filtro toma muestras del nivel original.
	vec3 suma = vec3(0.0);
	float peso_total = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			float peso = exp(-float(x * x + y * y) / 3.0);
			vec2 offset = vec2(float(x), float(y)) * SCREEN_PIXEL_SIZE * 7.0;
			suma += texture(pantalla, SCREEN_UV + offset).rgb * peso;
			peso_total += peso;
		}
	}
	COLOR = vec4(suma / peso_total * 0.58, 1.0);
}
