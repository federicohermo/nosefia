// Película de agua temporal que deja la mopa: refleja nítidamente las luces y la sonda del local
// sobre una superficie plana con premultiplied alpha, manteniendo la rugosidad constante para no
// generar halos blancos en el borde. Al secarse cae primero el reflejo y por último la humedad.
shader_type spatial;
render_mode blend_premul_alpha, cull_back, depth_draw_never;

uniform vec4 color : source_color = vec4(0.74, 0.89, 0.98, 1.0);
uniform float opacidad = 1.0;
uniform float expansion = 0.9;
uniform float fase = 0.0;

void fragment() {
	vec2 punto = (UV - vec2(0.5)) * 2.0 / expansion;
	float angulo = atan(punto.y + 0.00001, punto.x + 0.00001);
	float borde = 0.84
		+ 0.07 * sin(angulo * 3.0 + fase)
		+ 0.045 * cos(angulo * 5.0 - fase * 1.3)
		+ 0.02 * sin(angulo * 8.0 + fase * 2.1);
	float distancia = length(punto);
	float cobertura = 1.0 - smoothstep(borde - 0.06, borde, distancia);
	if (cobertura <= 0.001 || opacidad <= 0.001) {
		discard;
	}
	// Al secarse, el reflejo cae primero y el rastro húmedo se desvanece al final.
	float humedad = smoothstep(0.0, 0.45, opacidad);
	float pelicula = smoothstep(0.18, 0.90, opacidad);
	float nv = 1.0 - max(dot(NORMAL, VIEW), 0.0);
	float nv2 = nv * nv;
	float fresnel = 0.04 + 0.96 * nv2 * nv2 * nv;
	float brillo = pelicula * cobertura * sqrt(cobertura);
	// Premultiplied alpha con albedo acuoso (nunca negro): si dos charcos vecinos se rozan
	// convergen a agua limpia y no a una mancha oscura ni a un brillo quemado.
	ALPHA = cobertura
		* clamp(mix(0.20 * humedad, 0.44 * max(humedad, pelicula), fresnel), 0.0, 0.48)
		* color.a;
	ALBEDO = color.rgb * mix(0.48, 0.72, pelicula) * ALPHA;
	// Rugosidad baja y constante: evita el lóbulo difuso claro que ensanchaba el borde.
	ROUGHNESS = mix(0.12, 0.05, pelicula);
	SPECULAR = 0.32 * brillo;
}
