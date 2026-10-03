shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 color_de_fibra : source_color = vec4(0.72, 0.70, 0.62, 1.0);
uniform vec2 flexion = vec2(0.0);
uniform vec4 color_del_agua : source_color = vec4(0.74, 0.89, 0.98, 1.0);
uniform float humedad = 0.0;

void vertex() {
	float tramo = clamp((-0.774 - VERTEX.y) / 0.104, 0.0, 1.0);
	float peso = tramo * tramo;
	float variacion = 0.85 + 0.15 * sin(VERTEX.x * 65.0 + VERTEX.z * 48.0);
	vec2 cambio = flexion * peso * variacion;
	VERTEX.xz += cambio;
	// La inversa transpuesta del gradiente mantiene la iluminación al curvar la fibra.
	float derivada = -2.0 * tramo / 0.104;
	NORMAL.y -= dot(NORMAL.xz, flexion * derivada * variacion);
	NORMAL = normalize(NORMAL);
}

void fragment() {
	ALBEDO = mix(color_de_fibra.rgb, color_del_agua.rgb * 0.8, humedad);
	ROUGHNESS = mix(0.9, 0.6, humedad);
}
