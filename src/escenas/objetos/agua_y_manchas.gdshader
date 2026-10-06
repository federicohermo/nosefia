// Agua y suciedad comparten los programas de iluminación; el material elige su aspecto.
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_opaque;

uniform bool es_mancha = false;
uniform vec4 color_del_agua : source_color = vec4(0.55, 0.6, 0.55, 0.35);
uniform float transparencia = 1.0;

#include "aspecto_del_agua.gdshaderinc"
#include "aspecto_de_la_mancha.gdshaderinc"

void fragment() {
	if (es_mancha) {
		pintar_mancha(UV, ALBEDO, ALPHA, ROUGHNESS, SPECULAR);
	} else {
		pintar_agua(UV, VIEW_MATRIX, MODEL_MATRIX, VIEW, NORMAL,
			ALBEDO, ALPHA, ROUGHNESS, EMISSION);
	}
}
