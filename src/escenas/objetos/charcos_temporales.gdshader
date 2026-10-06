shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(0.74, 0.89, 0.98, 1.0);
uniform float opacidad = 1.0;
uniform float expansion = 0.9;
uniform float fase = 0.0;

void fragment() {
	vec2 punto = (UV - vec2(0.5)) * 2.0 / expansion;
	float angulo = atan(punto.y + 0.00001, punto.x + 0.00001);
	float borde = 0.87 + 0.07 * sin(angulo * 3.0 + fase) + 0.035 * cos(angulo * 7.0 - fase);
	float distancia = length(punto);
	float cobertura = 1.0 - smoothstep(borde - 0.07, borde, distancia);
	float reflejo = pow(max(0.0, 1.0 - abs(punto.x + punto.y * 0.45 + 0.18) * 9.0), 12.0);
	ALBEDO = mix(color.rgb, vec3(1.0), reflejo * 0.35);
	ALPHA = cobertura * opacidad * color.a * (0.3 + reflejo * 0.08);
}
