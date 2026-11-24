shader_type spatial;
render_mode diffuse_lambert;

uniform vec4 color_de_fibra : source_color = vec4(0.72, 0.70, 0.62, 1.0);
uniform vec4 color_del_agua : source_color = vec4(0.74, 0.89, 0.98, 1.0);
uniform float humedad = 0.0;
uniform sampler2D textura : source_color, hint_default_white, filter_nearest_mipmap;

#include "res://src/escenas/objetos/deformacion_de_fibras.gdshaderinc"
#include "res://src/escenas/objetos/oclusion_de_contacto.gdshaderinc"

void vertex() {
	deformar_fibras(VERTEX, NORMAL, MODEL_MATRIX, UV2);
	contacto = contacto_del_vertice(MODEL_MATRIX, VERTEX, NORMAL);
}

void fragment() {
	vec3 tex = texture(textura, UV).rgb;
	vec3 fibra = color_de_fibra.rgb * tex;
	if (humedad <= 0.001) {
		ALBEDO = oscurecer_por_contacto(fibra);
		ROUGHNESS = 0.92;
		SPECULAR = 0.08;
	} else {
		// Humedad por porosidad: oscurece y satura el algodón (0..0,35) sin pow() por canal;
		// recién después cae la rugosidad y sube el brillo de la película superficial.
		float poro = clamp(humedad / 0.35, 0.0, 1.0);
		vec3 empapada = mix(fibra, fibra * fibra * 0.92, poro);
		// El agua limpia oscurece la fibra natural; el jabón teñido conserva su color identificable.
		float croma = max(color_del_agua.r, max(color_del_agua.g, color_del_agua.b))
			- min(color_del_agua.r, min(color_del_agua.g, color_del_agua.b));
		float tinte = smoothstep(0.28, 0.55, croma) * clamp(humedad * 1.15, 0.0, 0.8);
		vec3 color_final = mix(empapada, color_del_agua.rgb * mix(0.65, 0.88, tex.r), tinte);
		ALBEDO = oscurecer_por_contacto(color_final);
		ROUGHNESS = mix(0.92, 0.22, smoothstep(0.18, 0.65, humedad));
		SPECULAR = mix(0.08, 0.45, smoothstep(0.18, 0.55, humedad));
	}
}
