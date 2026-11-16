shader_type spatial;
render_mode unshaded, fog_disabled, blend_mul, depth_test_disabled, depth_draw_never, cull_disabled;

uniform sampler2D profundidad : hint_depth_texture, repeat_disable, filter_nearest;
// Radio en metros: hasta dónde un vecino puede tapar la luz.
uniform float radio : hint_range(0.05, 3.0) = 0.4;
uniform float intensidad : hint_range(0.0, 6.0) = 1.0;
uniform float sesgo : hint_range(0.0, 0.5) = 0.08;
// Más allá de esta distancia el efecto se apaga: ahorra ruido y evita halos en el fondo.
uniform float alcance : hint_range(1.0, 60.0) = 22.0;

const int MUESTRAS = 8;
const vec2 GIRO_AUREO = vec2(-0.737368878, 0.675490294);

// La proyección de la cámara del juego es perspectiva sin desfase: con sus cuatro números alcanza
// para recuperar la posición, sin multiplicar una matriz entera por cada muestra.
vec3 posicion_de_vista(vec2 uv, vec4 proyeccion) {
	float d = textureLod(profundidad, uv, 0.0).x * 2.0 - 1.0;
	float z = -proyeccion.w / (d + proyeccion.z);
	return vec3((uv * 2.0 - 1.0) / proyeccion.xy * -z, z);
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
	if (distancia > alcance || distancia < 0.01) {
		ALBEDO = vec3(1.0);
	} else {
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
		float ao = clamp(1.0 - intensidad * oclusion / float(MUESTRAS), 0.0, 1.0);
		ALBEDO = vec3(mix(1.0, ao, suave));
	}
}
