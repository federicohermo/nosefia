shader_type canvas_item;
render_mode unshaded, blend_disabled;

// El halo es un desenfoque gaussiano de los brillos. Cinco muestras por eje con [1,4,6,4,1]
// son una gaussiana de un paso de ancho; tres muestras con [1,2,1] son la misma gaussiana
// (0,707 pasos) con menos lecturas. El paso se estira para que la mancha mida lo mismo: 26
// lecturas por píxel pasan a 10, y en una GPU donde el relleno es el tope eso es la mitad del
// costo del pase.
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform float radio : hint_range(1.0, 16.0) = 8.0;
uniform float intensidad : hint_range(0.0, 3.0) = 0.65;
uniform float umbral : hint_range(0.0, 1.0) = 0.9;
uniform float suavidad : hint_range(0.01, 0.3) = 0.06;

// La gaussiana de tres muestras mide 0,707 pasos y la de cinco, un paso: el paso se estira por
// 1/0,707 para que el halo conserve el ancho de siempre.
const float PASO_POR_RADIO = 0.7071;

float peso(int desplazamiento) {
	return abs(desplazamiento) == 0 ? 2.0 : 1.0;
}

void fragment() {
	vec3 base = textureLod(pantalla, SCREEN_UV, 0.0).rgb;
	vec3 halo = vec3(0.0);
	vec2 paso = SCREEN_PIXEL_SIZE * radio * PASO_POR_RADIO;
	// Extraer los brillos antes de difuminar evita levantar las zonas oscuras.
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec3 muestra = textureLod(pantalla, SCREEN_UV + vec2(float(x), float(y)) * paso, 0.0).rgb;
			float brillo = dot(muestra, vec3(0.2126, 0.7152, 0.0722));
			float seleccion = smoothstep(umbral, umbral + suavidad, brillo);
			halo += muestra * seleccion * peso(x) * peso(y);
		}
	}
	// La suma de los pesos es 16; el brillo conserva el mismo normalizador de antes.
	halo *= intensidad / 16.0;
	// Atenuar el aporte sobre el núcleo conserva su textura sin apagar el halo.
	float brillo_base = dot(base, vec3(0.2126, 0.7152, 0.0722));
	halo *= 1.0 - 0.75 * smoothstep(umbral, umbral + suavidad, brillo_base);
	COLOR = vec4(1.0 - (1.0 - base) * (1.0 - clamp(halo, vec3(0.0), vec3(1.0))), 1.0);
}
