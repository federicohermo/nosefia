// La referencia de un casillero vacío tiene ruido gris y deja ver lo que hay detrás.
// No lleva la etiqueta del producto: el color identifica las unidades que ya están puestas.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_back, shadows_disabled;

uniform float opacidad : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 punto = floor(UV * 256.0);
	float ruido = fract(sin(dot(punto, vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = vec3(mix(0.3, 0.7, ruido));
	ALPHA = opacidad;
}
