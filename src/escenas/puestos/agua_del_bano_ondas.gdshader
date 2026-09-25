// Un paso de la ecuación de onda sobre un campo de alturas. El canal r guarda la altura de este
// paso y el g la del anterior: el esquema necesita los dos, y así viajan en una sola textura.
// La textura sin `use_hdr_2d` es de 8 bits: sin ese ajuste la onda no tiene resolución.
// Guarda la altura más 0,5, porque el dibujo 2D recorta los negativos aun con floats. Medido el
// 2026-09-24: con la altura sin correr, el agua sube con cada paso.
shader_type canvas_item;
render_mode blend_disabled;

// `repeat_disable` hace que el borde se lea a sí mismo, y eso refleja la onda contra la pared.
uniform sampler2D previo : filter_nearest, repeat_disable;
// xy es el punto en UV y z la fuerza. Con z en cero no cae nada.
uniform vec3 gota = vec3(0.5, 0.5, 0.0);
uniform float radio_de_la_gota = 2.0;
uniform float amortiguacion = 0.985;
// El primer paso lee una textura sin escribir, que vale cero y no 0,5: ahí el agua arranca quieta.
uniform bool reiniciar = false;

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(previo, 0));
	vec2 actual = texture(previo, UV).rg - 0.5;
	float vecinos = texture(previo, UV + vec2(texel.x, 0.0)).r
			+ texture(previo, UV - vec2(texel.x, 0.0)).r
			+ texture(previo, UV + vec2(0.0, texel.y)).r
			+ texture(previo, UV - vec2(0.0, texel.y)).r
			- 2.0;
	float altura = (vecinos * 0.5 - actual.g) * amortiguacion;
	vec2 distancia = (UV - gota.xy) / texel;
	altura += gota.z * exp(-dot(distancia, distancia) / (radio_de_la_gota * radio_de_la_gota));
	// La amortiguación ya lleva todo a cero. El tope es para muchas gotas en el mismo punto.
	altura = clamp(altura, -0.5, 0.5);
	COLOR = reiniciar ? vec4(0.5, 0.5, 0.0, 1.0) : vec4(altura + 0.5, actual.r + 0.5, 0.0, 1.0);
}
