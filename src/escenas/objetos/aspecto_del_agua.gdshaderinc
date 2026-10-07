uniform sampler2D ondas : filter_linear, repeat_disable;
uniform vec2 texel = vec2(0.01, 0.01);
uniform float relieve = 12.0;
uniform vec4 color_previo : source_color = vec4(0.55, 0.6, 0.55, 0.35);
// Uno conserva el agua habitual del baño; sólo el balde inicia esta mezcla en cero.
uniform float progreso_de_mezcla : hint_range(0.0, 1.0) = 1.0;
// Sólo el balde con producto refuerza su tinte; el agua limpia mantiene su transparencia.
uniform float densidad_de_solucion : hint_range(0.0, 1.0) = 0.0;
uniform float densidad_previa : hint_range(0.0, 1.0) = 0.0;
// El reflejo de la luz del techo es falso: la luz del baño está horneada y no da brillo.
uniform vec3 hacia_la_luz = vec3(0.0, 1.0, 0.0);
uniform float brillo = 1.2;
// El balde trae alturas y normales calculadas en CPU; el baño sigue leyendo su textura.
uniform bool normal_de_la_malla = false;

float mezcla_en(vec2 uv) {
	vec2 punto = (uv - vec2(0.5)) * 2.0;
	float radio = length(punto);
	float angulo = radio > 0.00001 ? atan(punto.y, punto.x) : 0.0;
	float remolino = sin(angulo * 3.0 + radio * 14.0 - progreso_de_mezcla * 9.0);
	float demora = 0.06 + 0.52 * clamp(radio + 0.12 * remolino, 0.0, 1.0);
	return smoothstep(demora, demora + 0.32, progreso_de_mezcla);
}

float onda_de_mezcla(vec2 uv) {
	float radio = length((uv - vec2(0.5)) * 2.0);
	return sin(radio * 28.0 - progreso_de_mezcla * 12.0)
		* sin(progreso_de_mezcla * 3.141592654) * 0.001;
}

void pintar_agua(vec2 uv, mat4 vista, mat4 modelo, vec3 mirada, inout vec3 normal,
	out vec3 albedo, out float alpha, out float rugosidad, out vec3 emision) {
	if (!normal_de_la_malla) {
		float dx = texture(ondas, uv + vec2(texel.x, 0.0)).r
			- texture(ondas, uv - vec2(texel.x, 0.0)).r;
		float dz = texture(ondas, uv + vec2(0.0, texel.y)).r
			- texture(ondas, uv - vec2(0.0, texel.y)).r;
		vec3 normal_local = normalize(vec3(-dx * relieve, 1.0, -dz * relieve));
		normal = normalize((vista * modelo * vec4(normal_local, 0.0)).xyz);
	}
	vec4 color_visible = color_del_agua;
	float densidad_visible = densidad_de_solucion;
	if (progreso_de_mezcla < 1.0) {
		float mezclado = mezcla_en(uv);
		color_visible = mix(color_previo, color_del_agua, mezclado);
		densidad_visible = mix(densidad_previa, densidad_de_solucion, mezclado);
		// Ondas de brillo muy pequeñas acompañan el frente, sin mover el nivel del recipiente.
		float mx = (onda_de_mezcla(uv + vec2(0.002, 0.0))
			- onda_de_mezcla(uv - vec2(0.002, 0.0))) / 0.004;
		float mz = (onda_de_mezcla(uv + vec2(0.0, 0.002))
			- onda_de_mezcla(uv - vec2(0.0, 0.002))) / 0.004;
		vec3 desviacion = (vista * modelo * vec4(-mx, 0.0, -mz, 0.0)).xyz;
		normal = normalize(normal + desviacion);
	}
	albedo = color_visible.rgb;
	alpha = color_visible.a * mix(transparencia, 0.85, densidad_visible);
	rugosidad = 0.05;
	vec3 luz = normalize((vista * vec4(hacia_la_luz, 0.0)).xyz);
	float reflejo = pow(max(dot(reflect(-mirada, normal), luz), 0.0), 12.0);
	// El reflejo blanco y el fondo azul lavaban los colores rosa y amarillo según el ángulo.
	float reflejo_visible = reflejo * mix(1.0, 0.4, densidad_visible);
	vec3 tinte_del_reflejo = mix(vec3(1.0), vec3(0.5) + color_visible.rgb * 0.5, densidad_visible);
	emision = tinte_del_reflejo * brillo * reflejo_visible;
	alpha = max(alpha, reflejo_visible);
}
