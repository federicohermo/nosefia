shader_type canvas_item;
render_mode unshaded;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform vec2 direccion = vec2(1.0, 0.0);
uniform float luz = 1.0;

void fragment() {
	// Dos pasadas separables de radio 14 px. El filtrado lineal combina vecinos,
	// sin saltarse texeles ni depender de mipmaps de pantalla en Compatibility.
	vec3 suma = texture(pantalla, SCREEN_UV).rgb;
	float peso_total = 1.0;
	for (int par = 0; par < 7; par++) {
		float a = float(1 + par * 2);
		float b = a + 1.0;
		float peso_a = exp(-a * a / 50.0);
		float peso_b = exp(-b * b / 50.0);
		float peso = peso_a + peso_b;
		vec2 offset = SCREEN_PIXEL_SIZE * direccion * (a * peso_a + b * peso_b) / peso;
		suma += (texture(pantalla, SCREEN_UV + offset).rgb
			+ texture(pantalla, SCREEN_UV - offset).rgb) * peso;
		peso_total += 2.0 * peso;
	}
	COLOR = vec4(suma / peso_total * luz, 1.0);
}
