shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

uniform bool es_referencia = true;
uniform int desde = -1;
varying flat int indice;

void vertex() {
	indice = INSTANCE_ID;
}

void fragment() {
	if (indice < desde) { discard; }
	// La conversión de color del framebuffer pierde los valores muy oscuros. Tres dígitos
	// en una banda de grises medios conservan 4 mm de precisión hasta los 16 metros.
	float distancia = clamp(floor(-VERTEX.z * 256.0), 1.0, 4095.0);
	vec3 digitos = vec3(floor(distancia / 256.0), mod(floor(distancia / 16.0), 16.0), mod(distancia, 16.0));
	// La clasificación va en rojo: un framebuffer opaco puede devolver alfa 1 también
	// para los oclusores. Mantener todo opaco conserva la profundidad de esta máscara.
	ALBEDO = vec3((es_referencia ? 0.6 : 0.1) + digitos.x * 0.02, 0.2 + digitos.yz * 0.04);
}
