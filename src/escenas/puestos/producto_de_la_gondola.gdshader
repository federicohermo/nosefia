// El material de un producto de la góndola.
//
// Reproduce lo que el `StandardMaterial3D` del modelo hace con los campos que los productos usan:
// la textura de color con su escala y su desplazamiento de UV, la rugosidad, lo metálico y el
// especular, con el mismo filtro y los mismos modos de luz.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 color : source_color = vec4(1.0);
uniform sampler2D textura : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 escala_uv = vec3(1.0);
uniform vec3 desplazamiento_uv = vec3(0.0);
uniform float rugosidad : hint_range(0.0, 1.0) = 0.5;
uniform float metalico : hint_range(0.0, 1.0) = 0.0;
uniform float especular : hint_range(0.0, 1.0) = 0.5;

// Los valores de la oclusión de contacto. Sin ellos vale 0 y no cambia nada.
#include "res://src/escenas/objetos/oclusion_de_contacto.gdshaderinc"

void vertex() {
	contacto = contacto_del_vertice(MODEL_MATRIX, VERTEX, NORMAL);
}

void fragment() {
	ALBEDO = oscurecer_por_contacto(
			color.rgb * texture(textura, UV * escala_uv.xy + desplazamiento_uv.xy).rgb);
	METALLIC = metalico;
	ROUGHNESS = rugosidad;
	SPECULAR = especular;
}
