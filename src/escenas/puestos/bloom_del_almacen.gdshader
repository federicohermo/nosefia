shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform float radio : hint_range(1.0, 16.0) = 8.0;
uniform float intensidad : hint_range(0.0, 3.0) = 0.65;
uniform float umbral : hint_range(0.0, 1.0) = 0.9;
uniform float suavidad : hint_range(0.01, 0.3) = 0.06;

vec3 aporte_de_brillo(vec3 muestra) {
	float brillo = dot(muestra, vec3(0.2126, 0.7152, 0.0722));
	return muestra * smoothstep(umbral, umbral + suavidad, brillo);
}

void fragment() {
	vec3 base = textureLod(pantalla, SCREEN_UV, 0.0).rgb;
	// Aproximación de 9 muestras (pesos [5, 6, 5], suma 16^2 = 256) al núcleo binomial 5x5,
	// con desplazamiento entero en píxeles de igual varianza (sqrt(1.6) ≈ 1.265) para muestrear
	// centros de texel antes del umbral y reutilizar `base` en el centro.
	vec2 d = SCREEN_PIXEL_SIZE * max(1.0, round(radio * 0.5 * 1.265));
	vec3 halo = aporte_de_brillo(base) * 36.0;
	halo += (
		aporte_de_brillo(textureLod(pantalla, SCREEN_UV + vec2(-d.x, 0.0), 0.0).rgb)
		+ aporte_de_brillo(textureLod(pantalla, SCREEN_UV + vec2(d.x, 0.0), 0.0).rgb)
		+ aporte_de_brillo(textureLod(pantalla, SCREEN_UV + vec2(0.0, -d.y), 0.0).rgb)
		+ aporte_de_brillo(textureLod(pantalla, SCREEN_UV + vec2(0.0, d.y), 0.0).rgb)
	) * 30.0;
	halo += (
		aporte_de_brillo(textureLod(pantalla, SCREEN_UV + vec2(-d.x, -d.y), 0.0).rgb)
		+ aporte_de_brillo(textureLod(pantalla, SCREEN_UV + vec2(d.x, -d.y), 0.0).rgb)
		+ aporte_de_brillo(textureLod(pantalla, SCREEN_UV + vec2(-d.x, d.y), 0.0).rgb)
		+ aporte_de_brillo(textureLod(pantalla, SCREEN_UV + vec2(d.x, d.y), 0.0).rgb)
	) * 25.0;
	halo *= intensidad / 256.0;
	// Atenuar el aporte sobre el núcleo conserva su textura sin apagar el halo.
	float brillo_base = dot(base, vec3(0.2126, 0.7152, 0.0722));
	halo *= 1.0 - 0.75 * smoothstep(umbral, umbral + suavidad, brillo_base);
	COLOR = vec4(1.0 - (1.0 - base) * (1.0 - clamp(halo, vec3(0.0), vec3(1.0))), 1.0);
}
