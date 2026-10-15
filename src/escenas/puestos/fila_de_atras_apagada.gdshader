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
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(1.0);
uniform sampler2D textura : source_color, filter_nearest_mipmap, repeat_enable;
uniform float rugosidad : hint_range(0.0, 1.0) = 0.5;
uniform float metalico : hint_range(0.0, 1.0) = 0.0;
uniform float especular : hint_range(0.0, 1.0) = 0.5;
uniform int desde_atras = 0;
uniform int hasta_atras = 0;
uniform float saturacion_atras : hint_range(0.0, 1.0) = 1.0;

varying flat int apagada;

void vertex() {
	apagada = INSTANCE_ID >= desde_atras && INSTANCE_ID < hasta_atras ? 1 : 0;
}

void fragment() {
	vec3 base = color.rgb * texture(textura, UV).rgb;
	if (apagada == 1) {

		float gris = dot(base, vec3(0.2126, 0.7152, 0.0722));
		base = mix(vec3(gris), base, saturacion_atras);
	}
	ALBEDO = base;
	METALLIC = metalico;
	ROUGHNESS = rugosidad;
	SPECULAR = especular;
}
