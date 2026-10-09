shader_type spatial;
render_mode unshaded, cull_disabled;

#include "exterior_proyeccion.gdshaderinc"

uniform bool es_vegetacion = false;
uniform bool es_pintura = false;
uniform float altura_superior = 0.10223747;
uniform vec3 color_del_hormigon : source_color = vec3(0.23, 0.265, 0.24);
uniform vec3 color_de_la_pintura : source_color = vec3(0.38, 0.40, 0.32);

void vertex() {
	punto_mundial = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (es_vegetacion) {
		ALBEDO = vegetacion_baja(punto_mundial.xz);
	} else if (es_pintura) {
		float desgaste = smoothstep(0.3, 0.5, ruido(punto_mundial.xz * 24.0));
		ALBEDO = mix(asfalto(punto_mundial.xz), color_de_la_pintura, desgaste * 0.75);
	} else {
		vec2 losa = punto_mundial.xz / 1.2;
		vec2 borde = min(fract(losa), 1.0 - fract(losa)) * 1.2;
		float junta = 1.0 - smoothstep(0.003, 0.009 + length(fwidth(punto_mundial.xz)) * 0.4,
			min(borde.x, borde.y));
		float relieve = ruido(punto_mundial.xz * 12.0);
		float lateral = smoothstep(0.004, 0.02, altura_superior - punto_mundial.y);
		ALBEDO = color_del_hormigon * (0.82 + relieve * 0.18) * (1.0 - junta * 0.50)
			* (1.0 - lateral * 0.22);
	}
}
