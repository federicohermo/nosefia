// La mancha difusa que un objeto deja sobre la superficie que tiene debajo.
//
// Es un plano negro con alfa: oscurece lo que cae atrás y no pone luz. Sobre una imagen casi
// negra no se ve. Todos los valores son por instancia, así que lo comparte un solo material.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Tamaño del plano, en metros.
instance uniform vec2 tamano = vec2(1.0);
// Mitad de la huella del objeto, en metros.
instance uniform vec2 huella = vec2(0.2);
// De 0 (esquinas vivas) a 1 (círculo).
instance uniform float esquinas = 0.0;
// Ancho del borde difuso, en metros.
instance uniform float suavidad = 0.06;
instance uniform float intensidad = 0.0;
// Hasta dónde llega la superficie de apoyo: mínimo y máximo, en el plano.
instance uniform vec4 recorte = vec4(-100.0, -100.0, 100.0, 100.0);

varying vec2 plano;

void vertex() {
	plano = VERTEX.xz * tamano;
}

float distancia_al_rectangulo(vec2 punto, vec2 mitad, float radio) {
	vec2 q = abs(punto) - mitad + radio;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radio;
}

void fragment() {
	float radio = esquinas * min(huella.x, huella.y);
	float borde = 1.0 - smoothstep(0.0, suavidad, distancia_al_rectangulo(plano, huella, radio));
	// Sin esto la mancha sigue en el aire más allá del borde de lo que la sostiene.
	vec2 desde = smoothstep(recorte.xy, recorte.xy + 0.01, plano);
	vec2 hasta = 1.0 - smoothstep(recorte.zw - 0.01, recorte.zw, plano);
	ALBEDO = vec3(0.0);
	ALPHA = intensidad * borde * desde.x * desde.y * hasta.x * hasta.y;
}
