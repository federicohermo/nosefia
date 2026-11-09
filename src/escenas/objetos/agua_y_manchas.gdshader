// Agua y suciedad comparten los programas de iluminación; el material elige su aspecto.
shader_type spatial;
render_mode blend_premul_alpha, cull_back, depth_draw_opaque;

uniform bool es_mancha = false;
uniform vec4 color_del_agua : source_color = vec4(0.55, 0.6, 0.55, 0.35);
uniform float transparencia = 1.0;

#include "aspecto_del_agua.gdshaderinc"
#include "aspecto_de_la_mancha.gdshaderinc"
#include "oleaje_del_balde.gdshaderinc"

varying vec2 punto_del_balde;

void vertex() {
	punto_del_balde = VERTEX.xz;
	if (ondas_en_vertices) {
		VERTEX.xz *= borde;
		VERTEX.y = clamp(altura_libre(punto_del_balde), fondo, limite);
	}
}

void fragment() {
	if (es_mancha) {
		pintar_mancha(UV, ALBEDO, ALPHA, ROUGHNESS, SPECULAR);
		ALBEDO *= ALPHA;
		SPECULAR *= ALPHA;
	} else {
		if (ondas_en_vertices) {
			NORMAL = normalize(
				(VIEW_MATRIX * MODEL_MATRIX * vec4(normal_del_balde(punto_del_balde), 0.0)).xyz
			);
		}
		pintar_agua(UV, VIEW_MATRIX, MODEL_MATRIX, VIEW, NORMAL,
			ALBEDO, ALPHA, ROUGHNESS);
		// Sólo el color se apaga con la transparencia: el reflejo de la sonda queda entero.
		ALBEDO *= ALPHA;
	}
}
