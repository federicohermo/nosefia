shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform float radio : hint_range(1.0, 16.0) = 8.0;
uniform float intensidad : hint_range(0.0, 3.0) = 0.65;
uniform float umbral : hint_range(0.0, 1.0) = 0.9;
uniform float suavidad : hint_range(0.01, 0.3) = 0.06;

float peso(int desplazamiento) {
	int distancia = abs(desplazamiento);
	return distancia == 0 ? 6.0 : (distancia == 1 ? 4.0 : 1.0);
}

void fragment() {
	vec3 base = textureLod(pantalla, SCREEN_UV, 0.0).rgb;
	vec3 halo = vec3(0.0);
	vec2 paso = SCREEN_PIXEL_SIZE * radio * 0.5;
	// Extraer los brillos antes de difuminar evita levantar las zonas oscuras.
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec3 muestra = textureLod(pantalla, SCREEN_UV + vec2(float(x), float(y)) * paso, 0.0).rgb;
			float brillo = dot(muestra, vec3(0.2126, 0.7152, 0.0722));
			float seleccion = smoothstep(umbral, umbral + suavidad, brillo);
			halo += muestra * seleccion * peso(x) * peso(y);
		}
	}
	halo *= intensidad / 256.0;
	// Atenuar el aporte sobre el núcleo conserva su textura sin apagar el halo.
	float brillo_base = dot(base, vec3(0.2126, 0.7152, 0.0722));
	halo *= 1.0 - 0.75 * smoothstep(umbral, umbral + suavidad, brillo_base);
	COLOR = vec4(1.0 - (1.0 - base) * (1.0 - clamp(halo, vec3(0.0), vec3(1.0))), 1.0);
}
