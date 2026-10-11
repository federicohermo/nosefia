shader_type canvas_item;

uniform sampler2D mascara;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	color.a *= texture(mascara, UV).a;
	COLOR = color;
}
