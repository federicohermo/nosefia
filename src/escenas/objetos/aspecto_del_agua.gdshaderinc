uniform sampler2D ondas : filter_linear, repeat_disable;
uniform vec2 texel = vec2(0.01, 0.01);
uniform float relieve = 12.0;
uniform vec4 color_previo : source_color = vec4(0.55, 0.6, 0.55, 0.35);
// Uno conserva el agua habitual del baño; sólo el balde inicia esta mezcla en cero.
uniform float progreso_de_mezcla : hint_range(0.0, 1.0) = 1.0;
// Sólo el balde con producto refuerza su tinte; el agua limpia mantiene su transparencia.
uniform float densidad_de_solucion : hint_range(0.0, 1.0) = 0.0;
uniform float densidad_previa : hint_range(0.0, 1.0) = 0.0;
// El balde calcula su normal en el shader; el baño la lee de su textura de ondas.
uniform bool normal_de_la_malla = false;

float mezcla_en(vec2 punto, float radio) {
	float angulo = radio > 0.00001 ? atan(punto.y, punto.x) : 0.0;
	float remolino = sin(angulo * 3.0 + radio * 14.0 - progreso_de_mezcla * 9.0);
	float demora = 0.06 + 0.52 * clamp(radio + 0.12 * remolino, 0.0, 1.0);
	return smoothstep(demora, demora + 0.32, progreso_de_mezcla);
}

void pintar_agua(vec2 uv, mat3 vista_modelo, vec3 mirada, inout vec3 normal,
	out vec3 albedo, out float alpha, out float rugosidad) {
	if (!normal_de_la_malla) {
		float dx = texture(ondas, uv + vec2(texel.x, 0.0)).r
			- texture(ondas, uv - vec2(texel.x, 0.0)).r;
		float dz = texture(ondas, uv + vec2(0.0, texel.y)).r
			- texture(ondas, uv - vec2(0.0, texel.y)).r;
		// Dos micro-ondas en contrafase con velocidades no múltiplos evitan un espejo congelado.
		float micro_x = 0.006 * cos(uv.x * 17.0 + uv.y * 9.0 + TIME * 0.37)
			+ 0.004 * sin(uv.x * 29.0 - uv.y * 19.0 - TIME * 0.51);
		float micro_z = 0.006 * sin(uv.y * 19.0 - uv.x * 11.0 + TIME * 0.43)
			+ 0.004 * cos(uv.y * 31.0 + uv.x * 17.0 - TIME * 0.59);
		vec3 normal_local = normalize(vec3(-dx * relieve - micro_x, 1.0, -dz * relieve - micro_z));
		normal = normalize(vista_modelo * normal_local);
	}
	vec4 color_visible = color_del_agua;
	float densidad_visible = densidad_de_solucion;
	if (progreso_de_mezcla < 1.0) {
		vec2 punto = (uv - vec2(0.5)) * 2.0;
		float radio = length(punto);
		float mezclado = mezcla_en(punto, radio);
		color_visible = mix(color_previo, color_del_agua, mezclado);
		densidad_visible = mix(densidad_previa, densidad_de_solucion, mezclado);
		// Derivada radial analítica de las ondas de mezcla (evita cuatro llamadas con length/sin).
		float pendiente = cos(radio * 28.0 - progreso_de_mezcla * 12.0)
			* sin(progreso_de_mezcla * 3.141592654) * 0.056;
		vec2 dir = radio > 0.0001 ? punto / radio : vec2(0.0);
		vec3 desviacion = vista_modelo * vec3(-dir.x * pendiente, 0.0, -dir.y * pendiente);
		normal = normalize(normal + desviacion);
	}
	// Atenúa la inclinación en ángulos muy rasantes para no reflejar el piso oscuro de la sonda.
	vec3 arriba_vista = normalize(vista_modelo[1]);
	float rasante = smoothstep(0.0, 0.3, max(dot(arriba_vista, mirada), 0.0));
	normal = normalize(mix(arriba_vista, normal, mix(0.45, 1.0, rasante)));
	albedo = color_visible.rgb;
	alpha = color_visible.a * mix(transparencia, 0.85, densidad_visible);
	// Varianza de normales en pantalla: frena el centelleo especular bajo MSAA 2x sin mapas extra.
	vec3 dndx = dFdx(normal);
	vec3 dndy = dFdy(normal);
	float varianza = dot(dndx, dndx) + dot(dndy, dndy);
	rugosidad = clamp(0.05 + sqrt(varianza) * 0.35, 0.05, 0.40);
	// Fresnel de Schlick con el índice del agua (multiplicaciones en lugar de pow).
	float nv = 1.0 - max(dot(normal, mirada), 0.0);
	float nv2 = nv * nv;
	float fresnel = 0.02 + 0.98 * nv2 * nv2 * nv;
	alpha = mix(alpha, 1.0, fresnel);
	albedo *= 1.0 - fresnel;
}
