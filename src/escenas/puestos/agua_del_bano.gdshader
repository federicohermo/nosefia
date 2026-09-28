// La superficie del agua. La malla queda plana y las ondas sólo tuercen la normal: el nivel del
// agua no se mueve, y la onda se ve en el brillo.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

// Sin textura, el campo es constante y el agua queda plana: es el caso sin simulación.
uniform sampler2D ondas : filter_linear, repeat_disable;
uniform vec2 texel = vec2(0.01, 0.01);
uniform float relieve = 12.0;
uniform vec4 color_del_agua : source_color = vec4(0.55, 0.6, 0.55, 0.35);
// El reflejo de la luz del techo es falso: la luz del baño está horneada y no da brillo.
uniform vec3 hacia_la_luz = vec3(0.0, 1.0, 0.0);
uniform float brillo = 1.2;

void fragment() {
	float dx = texture(ondas, UV + vec2(texel.x, 0.0)).r - texture(ondas, UV - vec2(texel.x, 0.0)).r;
	float dz = texture(ondas, UV + vec2(0.0, texel.y)).r - texture(ondas, UV - vec2(0.0, texel.y)).r;
	vec3 normal_local = normalize(vec3(-dx * relieve, 1.0, -dz * relieve));
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(normal_local, 0.0)).xyz);
	ALBEDO = color_del_agua.rgb;
	ALPHA = color_del_agua.a;
	ROUGHNESS = 0.05;
	vec3 luz = normalize((VIEW_MATRIX * vec4(hacia_la_luz, 0.0)).xyz);
	float reflejo = pow(max(dot(reflect(-VIEW, NORMAL), luz), 0.0), 12.0);
	EMISSION = vec3(brillo * reflejo);
	ALPHA = max(ALPHA, reflejo);
}
