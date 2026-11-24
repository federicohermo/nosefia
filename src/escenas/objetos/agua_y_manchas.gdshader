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
		float y = clamp(altura_libre(punto_del_balde), fondo, limite);
		// Sigue la conicidad del balde: la cresta acompaña la pared y el valle no la atraviesa.
		VERTEX.xz *= clamp(borde + y * 0.24, 0.86, 1.015);
		VERTEX.y = y;
	}
}

void fragment() {
	if (es_mancha) {
		pintar_mancha(UV, ALBEDO, ALPHA, ROUGHNESS, SPECULAR);
		ALBEDO *= ALPHA;
		SPECULAR *= ALPHA;
	} else {
		mat3 vista_modelo = mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX);
		float altura_balde = 0.0;
		float agitacion = 0.0;
		if (ondas_en_vertices) {
			NORMAL = normalize(
				vista_modelo * normal_del_balde(punto_del_balde, altura_balde, agitacion)
			);
		}
		pintar_agua(UV, vista_modelo, VIEW, NORMAL, ALBEDO, ALPHA, ROUGHNESS);
		if (ondas_en_vertices) {
			// Absorción analítica por columna de agua reutilizando la altura ya evaluada.
			float profundidad = max(clamp(altura_balde, fondo, limite) - fondo, 0.0);
			float camino = profundidad / max(dot(NORMAL, VIEW), 0.35);
			float cuerpo = 1.0 - exp(-camino * mix(4.5, 9.0, densidad_de_solucion));
			ALPHA = mix(ALPHA * 0.72, ALPHA, cuerpo);
			ALBEDO = mix(ALBEDO * 0.85, ALBEDO, cuerpo);
			// Espuma fina en el borde cuando el agua con jabón se sacude.
			if (agitacion > 0.001 && densidad_de_solucion > 0.001) {
				float radio = length(punto_del_balde) / max(radio_del_disco, 0.0001);
				float espuma = smoothstep(0.84, 0.99, radio) * agitacion
					* densidad_de_solucion * 0.45;
				ALBEDO = mix(ALBEDO, vec3(0.95), espuma);
				ROUGHNESS = mix(ROUGHNESS, 0.45, espuma);
			}
		}
		// Sólo el color se apaga con la transparencia: el reflejo de la sonda queda entero.
		ALBEDO *= ALPHA;
	}
}
