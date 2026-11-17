shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_linear;
uniform float radio : hint_range(1.0, 16.0) = 8.0;
uniform float intensidad : hint_range(0.0, 3.0) = 0.65;
uniform float umbral : hint_range(0.0, 1.0) = 0.9;
uniform float suavidad : hint_range(0.01, 0.3) = 0.06;
// Cuánto se mezcla la imagen suavizada en los bordes. En 0 el pase dibuja sin suavizar.
uniform float suavizado : hint_range(0.0, 1.0) = 1.0;

// Un borde cuenta desde este contraste de brillo, o desde esta fracción del brillo máximo vecino.
const float CONTRASTE_MINIMO = 0.0625;
const float CONTRASTE_RELATIVO = 0.166;
// Cuántos píxeles se recorre cada borde en cada sentido para ubicar sus extremos.
const int PASOS_DEL_BORDE = 8;

float peso(int desplazamiento) {
	int distancia = abs(desplazamiento);
	return distancia == 0 ? 6.0 : (distancia == 1 ? 4.0 : 1.0);
}

float brillo_de(vec3 color) {
	return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

float brillo_en(vec2 uv) {
	return brillo_de(textureLod(pantalla, uv, 0.0).rgb);
}

// Suavizado de bordes por brillo, al estilo de FXAA. Sin profundidad ni una copia más de la
// pantalla. Un borde largo se desplaza medio píxel hacia su lado claro; un trazo corto, como una
// letra, casi no se mueve porque sus extremos quedan al lado.
vec3 suavizar_bordes(vec2 uv, vec3 centro) {
	vec2 px = SCREEN_PIXEL_SIZE;
	float c = brillo_de(centro);
	float norte = brillo_en(uv + vec2(0.0, -px.y));
	float sur = brillo_en(uv + vec2(0.0, px.y));
	float oeste = brillo_en(uv + vec2(-px.x, 0.0));
	float este = brillo_en(uv + vec2(px.x, 0.0));
	float maximo = max(c, max(max(norte, sur), max(oeste, este)));
	float minimo = min(c, min(min(norte, sur), min(oeste, este)));
	if (maximo - minimo < max(CONTRASTE_MINIMO, maximo * CONTRASTE_RELATIVO)) {
		return centro;
	}
	float no = brillo_en(uv + vec2(-px.x, -px.y));
	float ne = brillo_en(uv + vec2(px.x, -px.y));
	float so = brillo_en(uv + vec2(-px.x, px.y));
	float se = brillo_en(uv + vec2(px.x, px.y));
	float horizontal = abs(-2.0 * oeste + no + so) + 2.0 * abs(-2.0 * c + norte + sur) + abs(-2.0 * este + ne + se);
	float vertical = abs(-2.0 * norte + no + ne) + 2.0 * abs(-2.0 * c + oeste + este) + abs(-2.0 * sur + so + se);
	bool es_horizontal = horizontal >= vertical;
	// El borde separa a este píxel del vecino que más difiere, a un lado o al otro.
	float lado_a = es_horizontal ? norte : oeste;
	float lado_b = es_horizontal ? sur : este;
	bool gana_a = abs(lado_a - c) >= abs(lado_b - c);
	float gradiente = 0.25 * max(abs(lado_a - c), abs(lado_b - c));
	float promedio = 0.5 * ((gana_a ? lado_a : lado_b) + c);
	float paso = es_horizontal ? px.y : px.x;
	paso = gana_a ? -paso : paso;
	vec2 sobre_el_borde = uv + (es_horizontal ? vec2(0.0, 0.5 * paso) : vec2(0.5 * paso, 0.0));
	vec2 a_lo_largo = es_horizontal ? vec2(px.x, 0.0) : vec2(0.0, px.y);
	vec2 uv_a = sobre_el_borde - a_lo_largo;
	vec2 uv_b = sobre_el_borde + a_lo_largo;
	float extremo_a = brillo_en(uv_a) - promedio;
	float extremo_b = brillo_en(uv_b) - promedio;
	bool llego_a = abs(extremo_a) >= gradiente;
	bool llego_b = abs(extremo_b) >= gradiente;
	if (!llego_a) {
		uv_a -= a_lo_largo;
	}
	if (!llego_b) {
		uv_b += a_lo_largo;
	}
	for (int i = 2; i < PASOS_DEL_BORDE && !(llego_a && llego_b); i++) {
		if (!llego_a) {
			extremo_a = brillo_en(uv_a) - promedio;
			llego_a = abs(extremo_a) >= gradiente;
			if (!llego_a) {
				uv_a -= a_lo_largo;
			}
		}
		if (!llego_b) {
			extremo_b = brillo_en(uv_b) - promedio;
			llego_b = abs(extremo_b) >= gradiente;
			if (!llego_b) {
				uv_b += a_lo_largo;
			}
		}
	}
	float distancia_a = es_horizontal ? uv.x - uv_a.x : uv.y - uv_a.y;
	float distancia_b = es_horizontal ? uv_b.x - uv.x : uv_b.y - uv.y;
	bool cerca_a = distancia_a < distancia_b;
	float largo = distancia_a + distancia_b;
	float desplazamiento = 0.5 - min(distancia_a, distancia_b) / largo;
	// Sólo se desplaza si el extremo más cercano cambia en el mismo sentido que este píxel.
	bool centro_oscuro = c < promedio;
	bool variacion_correcta = ((cerca_a ? extremo_a : extremo_b) < 0.0) != centro_oscuro;
	if (!variacion_correcta) {
		return centro;
	}
	vec2 destino = uv + (es_horizontal ? vec2(0.0, desplazamiento * paso) : vec2(desplazamiento * paso, 0.0));
	return textureLod(pantalla, destino, 0.0).rgb;
}

void fragment() {
	vec3 base = textureLod(pantalla, SCREEN_UV, 0.0).rgb;
	vec3 halo = vec3(0.0);
	vec2 paso = SCREEN_PIXEL_SIZE * radio * 0.5;
	// Extraer los brillos antes de difuminar evita levantar las zonas oscuras.
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec3 muestra = textureLod(pantalla, SCREEN_UV + vec2(float(x), float(y)) * paso, 0.0).rgb;
			float brillo = brillo_de(muestra);
			float seleccion = smoothstep(umbral, umbral + suavidad, brillo);
			halo += muestra * seleccion * peso(x) * peso(y);
		}
	}
	halo *= intensidad / 256.0;
	if (suavizado > 0.0) {
		base = mix(base, suavizar_bordes(SCREEN_UV, base), suavizado);
	}
	// Atenuar el aporte sobre el núcleo conserva su textura sin apagar el halo.
	float brillo_base = brillo_de(base);
	halo *= 1.0 - 0.75 * smoothstep(umbral, umbral + suavidad, brillo_base);
	COLOR = vec4(1.0 - (1.0 - base) * (1.0 - clamp(halo, vec3(0.0), vec3(1.0))), 1.0);
}
