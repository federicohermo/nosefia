shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D mascara : repeat_disable, filter_nearest;
uniform sampler2D profundidad : hint_depth_texture, repeat_disable, filter_nearest;
uniform float radio = 4.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float distancia_de_mascara(vec4 muestra) {
	if (muestra.a < 0.25) { return 100000.0; }
	vec3 digitos = round((muestra.rgb - vec3(0.2)) / 0.02);
	return dot(digitos, vec3(1024.0, 32.0, 1.0)) / 256.0;
}

float distancia_del_mundo(vec2 uv, mat4 inversa) {
	float profundidad_del_pixel = texture(profundidad, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, profundidad_del_pixel) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, profundidad_del_pixel);
#endif
	vec4 vista = inversa * vec4(ndc, 1.0);
	return -vista.z / vista.w;
}

float referencia(vec2 uv, float delante, mat4 inversa) {
	vec4 muestra = texture(mascara, uv);
	if (muestra.a < 0.25) { return 0.0; }
	float distancia = distancia_de_mascara(muestra);
	// Cada muestra conserva la oclusión en su propio píxel antes de derramarse al vecino.
	if (distancia_del_mundo(uv, inversa) + 0.01 < distancia) { return 0.0; }
	// Un primer plano nítido conserva también su borde frente a una referencia desenfocada.
	if (delante + 0.01 < distancia) { return 0.0; }
	return 1.0;
}

void fragment() {
	vec2 paso = radio / VIEWPORT_SIZE;
	vec3 original = texture(pantalla, SCREEN_UV).rgb;
	float delante = distancia_del_mundo(SCREEN_UV, INV_PROJECTION_MATRIX);
	float centro = referencia(SCREEN_UV, delante, INV_PROJECTION_MATRIX);
	vec3 suave = vec3(0.0);
	vec3 derrame = vec3(0.0);
	float cobertura = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			float peso = (x == 0 ? 0.5 : 0.25) * (y == 0 ? 0.5 : 0.25);
			vec2 uv = SCREEN_UV + vec2(float(x), float(y)) * paso;
			vec3 color = texture(pantalla, uv).rgb;
			float marca = referencia(uv, delante, INV_PROJECTION_MATRIX);
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
