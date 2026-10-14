// El material de un producto de la góndola, con su fila de atrás apagada.
//
// Reproduce lo que el `StandardMaterial3D` del modelo hace con los campos que los productos usan:
// la textura de color, la rugosidad, lo metálico y el especular, con el mismo filtro y los mismos
// modos de luz. Así la fila de adelante se ve como sin él. Las copias del dibujo con índice en
// [desde_atras, hasta_atras) son referencias fijas: menos saturación y suavizado, sin oscurecer.
//
// El rango sale de `INSTANCE_ID` y no de un dato por copia: el buffer queda en 12 flotantes por
// copia, y el corte entre filas es el mismo que ya usa el dibujo.
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(1.0);
uniform sampler2D textura : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D textura_desenfocada : source_color, filter_linear_mipmap, repeat_enable;
uniform float rugosidad : hint_range(0.0, 1.0) = 0.5;
uniform float metalico : hint_range(0.0, 1.0) = 0.0;
uniform float especular : hint_range(0.0, 1.0) = 0.5;
uniform int desde_atras = 0;
uniform int hasta_atras = 0;
uniform float saturacion_atras : hint_range(0.0, 1.0) = 1.0;

varying flat int apagada;
varying vec3 coordenadas;
varying flat vec3 silueta;

float es_silueta(vec4 plano, vec3 ojo) {
	if (length(plano.xyz) < 0.1) { return 1.0; }
	return dot(plano.xyz, ojo) <= plano.w ? 1.0 : 0.0;
}

void vertex() {
	apagada = INSTANCE_ID >= desde_atras && INSTANCE_ID < hasta_atras ? 1 : 0;
	coordenadas = CUSTOM0.xyz;
	vec3 ojo = (inverse(MODELVIEW_MATRIX) * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	silueta = vec3(es_silueta(CUSTOM1, ojo), es_silueta(CUSTOM2, ojo), es_silueta(CUSTOM3, ojo));
}

void fragment() {
	vec3 base = color.rgb * texture(textura, UV).rgb;
	float opacidad = 1.0;
	if (apagada == 1) {
		// El radio se mide en pantalla para que el desenfoque no desaparezca al acercarse.
		vec2 horizontal = dFdx(UV) * 2.5;
		vec2 vertical = dFdy(UV) * 2.5;
		vec3 suave = texture(textura_desenfocada, UV).rgb * 0.25;
		suave += texture(textura_desenfocada, UV + horizontal).rgb * 0.125;
		suave += texture(textura_desenfocada, UV - horizontal).rgb * 0.125;
		suave += texture(textura_desenfocada, UV + vertical).rgb * 0.125;
		suave += texture(textura_desenfocada, UV - vertical).rgb * 0.125;
		suave += texture(textura_desenfocada, UV + horizontal + vertical).rgb * 0.0625;
		suave += texture(textura_desenfocada, UV + horizontal - vertical).rgb * 0.0625;
		suave += texture(textura_desenfocada, UV - horizontal + vertical).rgb * 0.0625;
		suave += texture(textura_desenfocada, UV - horizontal - vertical).rgb * 0.0625;
		base = color.rgb * suave;
		float gris = dot(base, vec3(0.2126, 0.7152, 0.0722));
		base = mix(vec3(gris), base, saturacion_atras);
		vec3 distancia = coordenadas / max(fwidth(coordenadas), vec3(0.00001));
		float borde = 100000.0;
		if (silueta.x > 0.5) { borde = min(borde, distancia.x); }
		if (silueta.y > 0.5) { borde = min(borde, distancia.y); }
		if (silueta.z > 0.5) { borde = min(borde, distancia.z); }
		opacidad = smoothstep(0.0, 2.0, borde);
	}
	ALBEDO = base;
	METALLIC = metalico;
	ROUGHNESS = rugosidad;
	SPECULAR = especular;
	ALPHA = opacidad;
}
