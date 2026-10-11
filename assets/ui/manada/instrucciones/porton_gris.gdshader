shader_type canvas_item;

void fragment() {
	vec2 p = vec2(0.055, 0.08) + UV * vec2(0.89, 0.84);
	vec3 c = texture(TEXTURE, p).rgb;
	float g = dot(c, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(vec3(g * 0.48), 1.0);
}
