shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 color_de_fibra : source_color = vec4(0.72, 0.70, 0.62, 1.0);
uniform vec4 color_del_agua : source_color = vec4(0.74, 0.89, 0.98, 1.0);
uniform float humedad = 0.0;

#include "res://src/escenas/objetos/deformacion_de_fibras.gdshaderinc"

void vertex() {
	deformar_fibras(VERTEX, NORMAL, MODEL_MATRIX, UV2);
}

void fragment() {
	ALBEDO = mix(color_de_fibra.rgb, color_del_agua.rgb * 0.8, humedad);
	ROUGHNESS = mix(0.9, 0.6, humedad);
}
