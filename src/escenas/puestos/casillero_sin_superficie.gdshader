// Conserva la profundidad del envase sin dibujar otra superficie. Así las aristas de atrás
// quedan ocultas en un casillero vacío y el hover no cambia la iluminación del producto puesto.
shader_type spatial;
render_mode unshaded, depth_draw_always, shadows_disabled;

void fragment() {
	ALPHA = 0.0;
}
