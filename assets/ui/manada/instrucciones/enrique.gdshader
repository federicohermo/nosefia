shader_type canvas_item;

// El original de Figma es transparente y su desenfoque aumenta hacia los pies.
void fragment() {
	float progreso = clamp((UV.y - 0.558484) / 0.549423, 0.0, 1.0);
	vec2 paso = TEXTURE_PIXEL_SIZE * 20.0 * progreso;
	vec4 acumulado = vec4(0.0);
	float peso_total = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			float peso = exp(-float(x * x + y * y) / 2.0);
			acumulado += texture(TEXTURE, UV + vec2(float(x), float(y)) * paso) * peso;
			peso_total += peso;
		}
	}
	COLOR *= acumulado / peso_total;
	COLOR.rgb = clamp(COLOR.rgb * 1.394744, 0.0, 1.0);
}
