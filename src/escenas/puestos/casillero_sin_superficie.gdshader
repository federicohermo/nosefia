// La superficie de un casillero vacío: tapa sin verse.
//
// El contorno del foco dibuja las caras de atrás de la malla inflada, y queda en un borde porque
// la superficie del objeto tapa el resto. Un casillero vacío no tiene superficie que mostrar, y
// sin ninguna la silueta entera sale rellena del color del contorno. Ésta escribe su profundidad
// y ningún color: tapa el relleno, y por adentro del borde se ve lo que hay detrás.
//
// Sin color quiere decir transparente del todo, y eso la manda a dibujarse con lo transparente,
// igual que el contorno. Quién de los dos va primero lo dice la prioridad del material.
shader_type spatial;
render_mode unshaded, depth_draw_always, shadows_disabled;

void fragment() {
	ALPHA = 0.0;
}
