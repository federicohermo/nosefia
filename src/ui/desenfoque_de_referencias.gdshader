shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform sampler2D mascara : repeat_disable, filter_nearest;
uniform sampler2D profundidad : hint_depth_texture, repeat_disable, filter_nearest;
uniform float radio = 4.0;

// Dieciséis tomas de igual peso en espiral áurea, repartidas como un gaussiano. Sin filas ni
// columnas repetidas no hay cuadrícula, y el filtrado lineal cierra lo que queda entre tomas.
// Los desplazamientos van en unidades de `radio`.
const vec2 DISCO[16] = vec2[](
	vec2(0.2070, 0.0000),
	vec2(-0.2687, 0.2461),
	vec2(0.0418, -0.4765),
	vec2(0.3506, 0.4573),
	vec2(-0.6558, -0.1160),
	vec2(0.6341, -0.4034),
	vec2(-0.2168, 0.8066),
	vec2(-0.4235, -0.8155),
	vec2(0.9433, 0.3445),
	vec2(-1.0102, 0.4170),
	vec2(0.5032, -1.0752),
	vec2(0.3860, 1.2306),
	vec2(-1.2158, -0.7046),
	vec2(1.5054, -0.3309),
	vec2(-0.9864, 1.4030),
	vec2(-0.2541, -1.9610)
);

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
	vec3 suave = original;
	vec3 derrame = original * centro;
	float cobertura = centro;
	for (int i = 0; i < 16; i++) {
		vec2 uv = SCREEN_UV + DISCO[i] * paso;
		vec3 color = texture(pantalla, uv).rgb;
		float marca = referencia(uv, delante, INV_PROJECTION_MATRIX);
		suave += color;
		derrame += color * marca;
		cobertura += marca;
	}
	suave /= 17.0;
	derrame /= 17.0;
	cobertura /= 17.0;
	// Conservar el píxel original fuera del efecto evita otra conversión de color en el
	// framebuffer, especialmente visible en los tonos oscuros de un producto nítido.
	if (centro < 0.5 && cobertura < 0.0001) { discard; }
	ALBEDO = centro > 0.5 ? suave : derrame + original * (1.0 - cobertura);
	ALPHA = 1.0;
}
