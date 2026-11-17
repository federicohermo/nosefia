shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled;

uniform sampler2D profundidad : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D pantalla : hint_screen_texture, repeat_disable, filter_nearest;
// Radio en metros: hasta dónde un vecino puede tapar la luz.
uniform float radio : hint_range(0.05, 3.0) = 0.1;
uniform float intensidad : hint_range(0.0, 6.0) = 0.4;
uniform float sesgo : hint_range(0.0, 0.5) = 0.08;
// Más allá de esta distancia el efecto se apaga: ahorra ruido y evita halos en el fondo.
uniform float alcance : hint_range(1.0, 60.0) = 22.0;

// Brillo de la imagen ya dibujada: por debajo de `penumbra` el pase actúa entero, por encima de `luz`
// casi no actúa. Una superficie que recibe luz directa sale clara; la penumbra sale oscura.
uniform float penumbra : hint_range(0.0, 1.0) = 0.06;
uniform float luz : hint_range(0.0, 2.0) = 0.35;
uniform float resto_en_la_luz : hint_range(0.0, 1.0) = 0.1;

// Cuánto se mezcla cada borde de geometría con sus vecinos. En 0 el pase sólo oscurece rincones.
uniform float suavizado : hint_range(0.0, 1.0) = 0.25;

const int MUESTRAS = 8;
const vec2 GIRO_AUREO = vec2(-0.737368878, 0.675490294);
// Cuánto tiene que quebrarse el plano de una superficie, como tangente del giro de un píxel al
// siguiente, para contar como borde: desde `BORDE_DESDE` suaviza y entero desde `BORDE_ENTERO`.
const float BORDE_DESDE = 0.25;
const float BORDE_ENTERO = 0.6;

// La proyección de la cámara del juego es perspectiva sin desfase: con sus cuatro números alcanza
// para recuperar la posición, sin multiplicar una matriz entera por cada muestra.
vec3 posicion_de_vista(vec2 uv, vec4 proyeccion) {
	float d = textureLod(profundidad, uv, 0.0).x * 2.0 - 1.0;
	float z = -proyeccion.w / (d + proyeccion.z);
	return vec3((uv * 2.0 - 1.0) / proyeccion.xy * -z, z);
}

float profundidad_en(vec2 uv) {
	return textureLod(profundidad, uv, 0.0).x * 2.0 - 1.0;
}

// La profundidad normalizada es una función lineal de la inversa de la profundidad de vista, y ésta
// es lineal en pantalla sobre un plano. Un plano da entonces una diferencia segunda nula, una
// arista da un quiebre y un contorno da un salto. Una textura no cuenta: no mueve la profundidad.
// El resultado es el cambio de la tangente de la pendiente entre un píxel y el siguiente.
float quiebre(vec2 uv, vec2 paso, float centro, float escala, float z) {
	float a = profundidad_en(uv - paso);
	float b = profundidad_en(uv + paso);
	float mayor = max(abs(centro + z), max(abs(a + z), abs(b + z)));
	return abs(a + b - 2.0 * centro) / (max(mayor, 1e-5) * escala);
}

float ruido(vec2 pixel) {
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec4 proy = vec4(PROJECTION_MATRIX[0][0], PROJECTION_MATRIX[1][1], PROJECTION_MATRIX[2][2], PROJECTION_MATRIX[3][2]);
	vec3 p = posicion_de_vista(SCREEN_UV, proy);
	float distancia = -p.z;
	float factor = 1.0;
	if (distancia <= alcance && distancia >= 0.01) {
		vec3 n = normalize(cross(dFdx(p), dFdy(p)));
		// La normal tiene que mirar hacia la cámara.
		n *= sign(dot(n, -p));
		float giro = ruido(FRAGCOORD.xy) * 6.2831853;
		vec2 direccion = vec2(cos(giro), sin(giro));
		vec2 escala = radio * proy.xy * 0.5 / distancia;
		float oclusion = 0.0;
		for (int i = 0; i < MUESTRAS; i++) {
			float t = (float(i) + 0.5) / float(MUESTRAS);
			direccion = vec2(direccion.x * GIRO_AUREO.x - direccion.y * GIRO_AUREO.y, direccion.x * GIRO_AUREO.y + direccion.y * GIRO_AUREO.x);
			vec3 q = posicion_de_vista(SCREEN_UV + direccion * sqrt(t) * escala, proy);
			vec3 v = q - p;
			float d2 = dot(v, v);
			float cara = max(dot(n, v) * inversesqrt(d2 + 1e-5) - sesgo, 0.0);
			oclusion += cara * (1.0 - smoothstep(radio * 0.5, radio * 1.5, sqrt(d2)));
		}
		// Un salto brusco de profundidad es un contorno y no un rincón: ahí la normal sale mal.
		float salto = max(abs(dFdx(p.z)), abs(dFdy(p.z))) / distancia;
		float suave = (1.0 - smoothstep(alcance * 0.6, alcance, distancia)) * (1.0 - smoothstep(0.04, 0.16, salto));
		float brillo = dot(textureLod(pantalla, SCREEN_UV, 0.0).rgb, vec3(0.2126, 0.7152, 0.0722));
		suave *= mix(1.0, resto_en_la_luz, smoothstep(penumbra, luz, brillo));
		float ao = clamp(1.0 - intensidad * oclusion / float(MUESTRAS), 0.0, 1.0);
		factor = mix(1.0, ao, suave);
	}

	// Cuánto se mezcla este píxel con sus vecinos de cada eje: sólo donde la geometría se quiebra.
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 bordes = vec2(0.0);
	if (suavizado > 0.0) {
		float centro = profundidad_en(SCREEN_UV);
		bordes.x = quiebre(SCREEN_UV, vec2(px.x, 0.0), centro, 2.0 * px.x / abs(proy.x), proy.z);
		bordes.y = quiebre(SCREEN_UV, vec2(0.0, px.y), centro, 2.0 * px.y / abs(proy.y), proy.z);
		bordes = smoothstep(BORDE_DESDE, BORDE_ENTERO, bordes);
	}
	// El píxel pasa a ser `(1 - entra)` de sí mismo y `entra` del promedio de sus vecinos, y todo
	// se oscurece por `factor`. `blend_mix` resuelve ambas cosas a la vez sobre lo ya dibujado:
	// `ALPHA` es lo que se reemplaza, y con `ALBEDO` en cero sólo queda lo oscurecido.
	float entra = 0.5 * suavizado * (bordes.x + bordes.y);
	vec3 vecinos = vec3(0.0);
	if (entra > 0.0) {
		vec3 horizontales = textureLod(pantalla, SCREEN_UV + vec2(px.x, 0.0), 0.0).rgb + textureLod(pantalla, SCREEN_UV - vec2(px.x, 0.0), 0.0).rgb;
		vec3 verticales = textureLod(pantalla, SCREEN_UV + vec2(0.0, px.y), 0.0).rgb + textureLod(pantalla, SCREEN_UV - vec2(0.0, px.y), 0.0).rgb;
		vecinos = (bordes.x * horizontales + bordes.y * verticales) / (2.0 * (bordes.x + bordes.y));
	}
	float alfa = 1.0 - factor * (1.0 - entra);
	ALBEDO = alfa > 1e-4 ? factor * entra * vecinos / alfa : vec3(0.0);
	ALPHA = alfa;
}
