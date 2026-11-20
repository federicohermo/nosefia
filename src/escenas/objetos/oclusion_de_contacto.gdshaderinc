// La parte de la oclusión de contacto que oscurece al objeto: sus caras de abajo y el pie de sus
// costados, según qué tan cerca tienen la superficie de abajo.
//
// Los valores son uniformes del material: en la web los uniformes por instancia llegan en cero,
// así que cada objeto o bloque lleva su propio material. Los escribe `oclusion_de_contacto.gd`
// (en espacio del mundo) o `oclusion_de_la_gondola.gd` (en espacio local, con
// `contacto_en_base_local`). Sin ellos, `oclusion_de_contacto` vale 0 y el material se ve igual
// que sin este archivo.
uniform float oclusion_de_contacto : hint_range(0.0, 1.0) = 0.0;
uniform float suelo_de_contacto = -1000.0;
uniform float alcance_de_contacto = 0.4;
// Si es cierto, la altura se mide desde `suelo_de_contacto` a lo largo de `eje_de_contacto` en el
// espacio local de la malla: sirve para un `MultiMesh` con unidades apoyadas a distintas alturas.
uniform bool contacto_en_base_local = false;
uniform vec3 eje_de_contacto = vec3(0.0, 1.0, 0.0);

const float FUERZA_DEL_CONTACTO = 0.7;

// x: altura del punto sobre la superficie de abajo. y: cuánto mira hacia abajo, de 0 (arriba) a 1.
varying vec2 contacto;

// Se asigna en `vertex()`: un varying no se puede escribir adentro de otra función.
vec2 contacto_del_vertice(mat4 modelo, vec3 vertice, vec3 normal) {
	if (oclusion_de_contacto <= 0.0) {
		return vec2(1000.0, 0.0);
	}
	if (contacto_en_base_local) {
		vec3 eje = normalize(eje_de_contacto);
		return vec2(
				dot(vertice, eje) - suelo_de_contacto,
				0.5 - 0.5 * dot(normalize(normal), eje));
	}
	return vec2(
			(modelo * vec4(vertice, 1.0)).y - suelo_de_contacto,
			0.5 - 0.5 * normalize(mat3(modelo) * normal).y);
}

vec3 oscurecer_por_contacto(vec3 albedo) {
	float cercania = 1.0 - smoothstep(0.0, alcance_de_contacto, contacto.x);
	return albedo * (1.0 - FUERZA_DEL_CONTACTO * oclusion_de_contacto * contacto.y * cercania * cercania);
}
