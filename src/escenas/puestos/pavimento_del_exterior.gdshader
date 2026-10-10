shader_type spatial;
render_mode unshaded, cull_disabled;

#include "exterior_proyeccion.gdshaderinc"

uniform vec3 surtidor_cercano;
uniform vec3 surtidor_lejano;
uniform vec3 auto_estacionado;

void vertex() {
	punto_mundial = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 color = asfalto(punto_mundial.xz);
	// Contacto estático del edificio. El cielo no puede escribir esta sombra sobre el piso.
	float junto_al_lateral = exp(-abs(punto_mundial.x + 2.50) * 4.0)
		* step(-16.5, punto_mundial.z) * step(punto_mundial.z, 6.4);
	float junto_al_frente = exp(-abs(punto_mundial.z - 6.30) * 4.0)
		* step(-2.6, punto_mundial.x) * step(punto_mundial.x, 14.5);
	vec2 cerca = (punto_mundial.xz - surtidor_cercano.xz) / vec2(0.9, 1.75);
	vec2 lejos_del_surtidor = (punto_mundial.xz - surtidor_lejano.xz) / vec2(0.85, 2.0);
	float contacto_de_islas = max(exp(-dot(cerca, cerca)), exp(-dot(lejos_del_surtidor, lejos_del_surtidor)));
	vec2 bajo_el_auto = (punto_mundial.xz - auto_estacionado.xz) / vec2(0.45, 1.5);
	float contacto_del_auto = exp(-dot(bajo_el_auto, bajo_el_auto));
	float contacto = max(max(junto_al_lateral, junto_al_frente), max(contacto_de_islas, contacto_del_auto));
	ALBEDO = color * (1.0 - 0.55 * contacto);
	ROUGHNESS = 0.95;
}
