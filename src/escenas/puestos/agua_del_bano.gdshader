// La superficie del agua. La malla queda plana y las ondas sólo tuercen la normal: el nivel del
// agua no se mueve, y la onda se ve en el brillo.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

// Sin textura, el campo es constante y el agua queda plana: es el caso sin simulación.
uniform sampler2D ondas : filter_linear, repeat_disable;
uniform vec2 texel = vec2(0.01, 0.01);
uniform float relieve = 12.0;
uniform vec4 color_del_agua : source_color = vec4(0.55, 0.6, 0.55, 0.35);
uniform vec4 color_previo : source_color = vec4(0.55, 0.6, 0.55, 0.35);
// Uno conserva el agua habitual del baño; sólo el balde inicia esta mezcla en cero.
uniform float progreso_de_mezcla : hint_range(0.0, 1.0) = 1.0;
// El reflejo de la luz del techo es falso: la luz del baño está horneada y no da brillo.
uniform vec3 hacia_la_luz = vec3(0.0, 1.0, 0.0);
uniform float brillo = 1.2;
// El balde trae alturas y normales calculadas en CPU; el baño sigue leyendo su textura.
uniform bool normal_de_la_malla = false;
uniform float transparencia = 1.0;

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

void fragment() {
	float dx = texture(ondas, UV + vec2(texel.x, 0.0)).r - texture(ondas, UV - vec2(texel.x, 0.0)).r;
	float dz = texture(ondas, UV + vec2(0.0, texel.y)).r - texture(ondas, UV - vec2(0.0, texel.y)).r;
	vec3 normal_local = normalize(vec3(-dx * relieve, 1.0, -dz * relieve));
	if (!normal_de_la_malla) {
		NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(normal_local, 0.0)).xyz);
	}
	vec4 color_visible = color_del_agua;
	if (progreso_de_mezcla < 1.0) {
		color_visible = mix(color_previo, color_del_agua, mezcla_en(UV));
		// Ondas de brillo muy pequeñas acompañan el frente, sin mover el nivel del recipiente.
		float mx = (onda_de_mezcla(UV + vec2(0.002, 0.0))
			- onda_de_mezcla(UV - vec2(0.002, 0.0))) / 0.004;
		float mz = (onda_de_mezcla(UV + vec2(0.0, 0.002))
			- onda_de_mezcla(UV - vec2(0.0, 0.002))) / 0.004;
		vec3 desviacion = (VIEW_MATRIX * MODEL_MATRIX * vec4(-mx, 0.0, -mz, 0.0)).xyz;
		NORMAL = normalize(NORMAL + desviacion);
	}
	ALBEDO = color_visible.rgb;
	ALPHA = color_visible.a * transparencia;
	ROUGHNESS = 0.05;
	vec3 luz = normalize((VIEW_MATRIX * vec4(hacia_la_luz, 0.0)).xyz);
	float reflejo = pow(max(dot(reflect(-VIEW, NORMAL), luz), 0.0), 12.0);
	EMISSION = vec3(brillo * reflejo);
	ALPHA = max(ALPHA, reflejo);
}
