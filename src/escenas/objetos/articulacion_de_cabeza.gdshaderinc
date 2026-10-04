uniform mat4 articulacion = mat4(1.0);

void articular_cabeza(inout vec3 vertice, inout vec3 normal) {
	if (vertice.y < -0.748) {
		vertice = (articulacion * vec4(vertice, 1.0)).xyz;
		normal = normalize(mat3(articulacion) * normal);
	}
}

