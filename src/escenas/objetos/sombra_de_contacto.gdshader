// La mancha difusa que un objeto deja sobre la superficie que tiene debajo.
//
// Es un plano negro con alfa: oscurece lo que cae atrás y no pone luz. Sobre una imagen casi
// negra no se ve. Los valores son uniformes del material, y cada mancha lleva el suyo: en la
// web los uniformes por instancia llegan en cero.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Tamaño del plano, en metros.
uniform vec2 tamano = vec2(1.0);
// Mitad de la huella del objeto, en metros.
uniform vec2 huella = vec2(0.2);
// De 0 (esquinas vivas) a 1 (círculo).
uniform float esquinas = 0.0;
// Ancho del borde difuso, en metros.
uniform float suavidad = 0.06;
uniform float intensidad = 0.0;
// Del plano de la mancha, en metros, al espacio de la forma que la sostiene.
uniform mat4 al_apoyo = mat4(1.0);
// Hasta dónde llega esa forma: mínimo y máximo, en su espacio.
uniform vec3 apoyo_minimo = vec3(-1000.0);
uniform vec3 apoyo_maximo = vec3(1000.0);

varying vec2 plano;
varying vec3 en_el_apoyo;

void vertex() {
	plano = VERTEX.xz * tamano;
	en_el_apoyo = (al_apoyo * vec4(plano.x, 0.0, plano.y, 1.0)).xyz;
}

float distancia_al_rectangulo(vec2 punto, vec2 mitad, float radio) {
	vec2 q = abs(punto) - mitad + radio;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radio;
}

void fragment() {
	float radio = esquinas * min(huella.x, huella.y);
	float borde = 1.0 - smoothstep(0.0, suavidad, distancia_al_rectangulo(plano, huella, radio));
	// Sin esto la mancha sigue en el aire más allá del borde de lo que la sostiene.
	vec3 desde = smoothstep(apoyo_minimo, apoyo_minimo + 0.01, en_el_apoyo);
	vec3 hasta = 1.0 - smoothstep(apoyo_maximo - 0.01, apoyo_maximo, en_el_apoyo);
	ALBEDO = vec3(0.0);
	ALPHA = intensidad * borde * desde.x * desde.y * desde.z * hasta.x * hasta.y * hasta.z;
}
