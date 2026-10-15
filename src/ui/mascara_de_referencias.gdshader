shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

void fragment() {
	// Tres dígitos de base 32 conservan pasos de 4 mm hasta 128 m. Las bandas medias evitan
	// que la conversión de color del framebuffer pierda los dígitos más oscuros.
	float distancia = clamp(floor(-VERTEX.z * 256.0), 1.0, 32767.0);
	vec3 digitos = vec3(floor(distancia / 1024.0), mod(floor(distancia / 32.0), 32.0), mod(distancia, 32.0));
	ALBEDO = vec3(0.2) + digitos * 0.02;
}
