shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D mascara : repeat_disable, filter_nearest;
uniform sampler2D profundidad : hint_depth_texture, repeat_disable, filter_nearest;

// Desplazamiento en píxeles (xy) y peso (z) de cada toma, de DesenfoqueDeReferencias.tomas().
uniform vec3 tomas[49];

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
	vec2 pixel = 1.0 / VIEWPORT_SIZE;
	float delante = distancia_del_mundo(SCREEN_UV, INV_PROJECTION_MATRIX);
	float centro = referencia(SCREEN_UV, delante, INV_PROJECTION_MATRIX);
	if (centro > 0.5) {
		vec3 suave = vec3(0.0);
		for (int i = 0; i < 49; i++) {
			suave += texture(pantalla, SCREEN_UV + tomas[i].xy * pixel).rgb * tomas[i].z;
		}
		ALBEDO = suave;
		ALPHA = 1.0;
		return;
	}
	vec3 derrame = vec3(0.0);
	float cobertura = 0.0;
	for (int i = 0; i < 49; i++) {
		vec2 uv = SCREEN_UV + tomas[i].xy * pixel;
		if (referencia(uv, delante, INV_PROJECTION_MATRIX) > 0.0) {
			derrame += texture(pantalla, uv).rgb * tomas[i].z;
			cobertura += tomas[i].z;
		}
	}
	// Conservar el píxel original fuera del efecto evita otra conversión de color en el
	// framebuffer, especialmente visible en los tonos oscuros de un producto nítido.
	if (cobertura < 0.0001) { discard; }
	ALBEDO = derrame + texture(pantalla, SCREEN_UV).rgb * (1.0 - cobertura);
	ALPHA = 1.0;
}
