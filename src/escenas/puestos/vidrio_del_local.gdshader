shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D reflejo_del_techo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D marcas_del_vidrio : filter_linear_mipmap, repeat_enable;
uniform vec3 tinte : source_color = vec3(0.21, 0.32, 0.30);

void fragment() {
	vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 vista = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 punto = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 rebote = reflect(-vista, normal);
	float rasante = pow(1.0 - abs(dot(normal, vista)), 4.0);
	vec3 reflejo = vec3(0.0);
	if (rebote.y > 0.001 && punto.y < 4.26) {
		vec3 techo = punto + rebote * ((4.26 - punto.y) / rebote.y);
		if (techo.x > -2.48 && techo.x < 7.87 && techo.z > -7.87 && techo.z < 6.28) {
			vec2 celda = vec2(techo.x + 2.48, -techo.z + 6.28)
				/ vec2(0.8625, 0.884375);
			vec2 modulo = floor(celda);
			vec2 atlas = mod(modulo, 4.0);
			if (modulo.x < 1.0 || modulo.x >= 11.0
					|| modulo.y < 1.0 || modulo.y >= 15.0) {
				atlas = vec2(0.0);
			}
			vec2 uv = (atlas + fract(celda)) / 4.0;
			uv.y = 1.0 - uv.y;
			reflejo = texture(reflejo_del_techo, uv).rgb;
		}
	}
	float luz = max(reflejo.r, max(reflejo.g, reflejo.b));
	// Las marcas pertenecen a la hoja, también cuando se abre o no refleja luces.
	float marcas = smoothstep(0.19, 0.37, texture(marcas_del_vidrio, UV).r);
	// La capa refleja las luminarias y aumenta su opacidad sólo en vista rasante.
	ALBEDO = mix(tinte + vec3(marcas * 0.24), reflejo, clamp(luz * 1.3, 0.0, 0.9));
	ALPHA = clamp(0.10 + marcas * 0.28 + rasante * 0.30 + luz * 0.28, 0.0, 0.65);
}
