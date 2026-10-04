uniform vec2 flexion = vec2(0.0);
uniform vec3 caida = vec3(0.0);
uniform float suelo_y = -1000.0;
uniform vec3 centro_balde = vec3(0.0);
uniform vec3 vertical_balde = vec3(0.0, 1.0, 0.0);
uniform float inmersion = 0.0;
uniform mat4 articulacion = mat4(1.0);


void deformar_fibras(inout vec3 vertice, inout vec3 normal, mat4 modelo) {
	float tramo = clamp((-0.774 - vertice.y) / 0.104, 0.0, 1.0);
	float peso = tramo * tramo;
	float variacion = 0.85 + 0.15 * sin(vertice.x * 65.0 + vertice.z * 48.0);
	vec2 cambio = flexion * peso * variacion;
	vertice.xz += cambio;
	vertice += caida * peso;
	vec3 relativo = vertice - centro_balde;
	vec3 radial = relativo - vertical_balde * dot(relativo, vertical_balde);
	float radio = length(radial);
	if (radio > 0.145) {
		vertice -= radial * (1.0 - 0.145 / radio) * inmersion;
	}
	// La inversa transpuesta del gradiente mantiene la iluminación al curvar la fibra.
	float derivada = -2.0 * tramo / 0.104;
	normal.y -= dot(normal.xz, flexion * derivada * variacion);
	normal = normalize(normal);
	vertice = (articulacion * vec4(vertice, 1.0)).xyz;
	normal = normalize(mat3(articulacion) * normal);
	vec3 mundial = (modelo * vec4(vertice, 1.0)).xyz;
	if (inmersion <= 0.0 && mundial.y < suelo_y + 0.002) {
		vertice += (inverse(modelo) * vec4(0.0, suelo_y + 0.002 - mundial.y, 0.0, 0.0)).xyz;
	}
}
