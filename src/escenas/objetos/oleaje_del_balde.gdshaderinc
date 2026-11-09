// Las formas de `ondas_del_balde.gd`, en el mismo orden. Un cambio allá va también acá.
uniform bool ondas_en_vertices = false;
uniform vec4 modos_a = vec4(0.0);
uniform vec4 modos_b = vec4(0.0);
uniform vec2 inclinacion = vec2(0.0);
uniform float nivel = 1.0;
uniform float descenso = 0.0;
uniform float fondo = -1.0;
uniform float limite = 1.0;
uniform float borde = 1.0;
uniform float radio_del_disco = 0.6;
uniform float relieve_de_las_ondas = 1.8;

const float MEDIA_DEL_MODO_AXIAL = 0.405;

float ondas_en(vec2 punto) {
	float radio = min(length(punto), 1.0);
	vec2 direccion = radio > 0.00001 ? punto / length(punto) : vec2(1.0, 0.0);
	float c1 = direccion.x;
	float s1 = direccion.y;
	float c2 = c1 * c1 - s1 * s1;
	float s2 = 2.0 * c1 * s1;
	float c3 = c2 * c1 - s2 * s1;
	float s3 = s2 * c1 + c2 * s1;
	float anillo = sin(radio * PI * 0.5);
	float anillo2 = anillo * anillo;
	float radial = sin(radio * PI * 1.5);
	return dot(modos_a, vec4(cos(radio * PI) + MEDIA_DEL_MODO_AXIAL, radial * c1, radial * s1,
			anillo2 * c2))
		+ dot(modos_b, vec4(anillo2 * s2, anillo2 * anillo * c3, anillo2 * anillo * s3,
			cos(radio * 2.0 * PI)));
}

// La altura sin recortar del agua en un punto de la malla quieta, en metros locales.
float altura_libre(vec2 punto) {
	return (dot(inclinacion, punto * borde)
		+ ondas_en(punto / radio_del_disco) * relieve_de_las_ondas) * nivel - descenso;
}

// La normal por píxel, de la pendiente de la altura. Donde el agua toca el tope o el fondo,
// la superficie queda plana.
vec3 normal_del_balde(vec2 punto) {
	float h = altura_libre(punto);
	if (h <= fondo || h >= limite) {
		return vec3(0.0, 1.0, 0.0);
	}
	float e = radio_del_disco * 0.01;
	float dx = altura_libre(punto + vec2(e, 0.0)) - altura_libre(punto - vec2(e, 0.0));
	float dz = altura_libre(punto + vec2(0.0, e)) - altura_libre(punto - vec2(0.0, e));
	// El borde se escala en xz; la pendiente se mide sobre el punto ya escalado.
	return normalize(vec3(-dx, 2.0 * e * borde, -dz));
}
