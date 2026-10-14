shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D mascara : repeat_disable, filter_nearest;
uniform float radio = 4.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float distancia_de_mascara(vec4 muestra) {
	if (muestra.a < 0.25) { return 100000.0; }
	float base = muestra.r > 0.5 ? 0.6 : 0.1;
	vec3 digitos = vec3(round((muestra.r - base) / 0.02), round((muestra.gb - vec2(0.2)) / 0.04));
	return dot(digitos, vec3(256.0, 16.0, 1.0)) / 256.0;
}

float referencia(vec2 uv, float delante) {
	vec4 muestra = texture(mascara, uv);
	if (muestra.a < 0.25 || muestra.r < 0.5) { return 0.0; }
	float distancia = distancia_de_mascara(muestra);
	// Un primer plano nítido conserva también su borde frente a una referencia desenfocada.
	if (delante + 0.01 < distancia) { return 0.0; }
	return 1.0;
}

void fragment() {
	vec2 paso = radio / VIEWPORT_SIZE;
	vec3 original = texture(pantalla, SCREEN_UV).rgb;
	float delante = distancia_de_mascara(texture(mascara, SCREEN_UV));
	float centro = referencia(SCREEN_UV, delante);
	vec3 suave = vec3(0.0);
	vec3 derrame = vec3(0.0);
	float cobertura = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			float peso = (x == 0 ? 0.5 : 0.25) * (y == 0 ? 0.5 : 0.25);
			vec2 uv = SCREEN_UV + vec2(float(x), float(y)) * paso;
			vec3 color = texture(pantalla, uv).rgb;
			float marca = referencia(uv, delante);
			suave += color * peso;
			derrame += color * peso * marca;
			cobertura += peso * marca;
		}
	}
	// Conservar el píxel original fuera del efecto evita otra conversión de color en el
	// framebuffer, especialmente visible en los tonos oscuros de un producto nítido.
	if (centro < 0.5 && cobertura < 0.0001) { discard; }
	ALBEDO = centro > 0.5 ? suave : derrame + original * (1.0 - cobertura);
	ALPHA = 1.0;
}
