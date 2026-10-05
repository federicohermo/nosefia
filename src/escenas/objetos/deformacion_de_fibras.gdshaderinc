uniform vec2 flexion = vec2(0.0);
uniform vec3 caida = vec3(0.0);
uniform float suelo_y = -1000.0;
uniform vec3 centro_balde = vec3(0.0);
uniform vec3 vertical_balde = vec3(0.0, 1.0, 0.0);
uniform float inmersion = 0.0;
uniform mat4 articulacion = mat4(1.0);

// Longitud local de las fibras del modelo: la punta conserva la flexión completa.
const float LONGITUD_DE_FIBRA = 0.077822447;

vec3 posicion_de_fibra(vec3 original, vec2 ancla) {
	vec3 vertice = original;
	float tramo = clamp((-0.774 - vertice.y) / LONGITUD_DE_FIBRA, 0.0, 1.0);
	float peso = tramo * tramo;
	float variacion = 0.85 + 0.15 * sin(vertice.x * 65.0 + vertice.z * 48.0);
	vec2 cambio = flexion * peso * variacion;
	vertice.xz += cambio;
	vertice += caida * peso;
	vec3 raiz = vec3(ancla.x, -0.774, ancla.y);
	vec3 hacia_punta = vertice - raiz;
	float largo_original = length(original - raiz);
	float largo = length(hacia_punta);
	if (largo > largo_original && largo > 0.000001) {
		vertice = raiz + hacia_punta * (largo_original / largo);
	}
	vec3 relativo = vertice - centro_balde;
	vec3 radial = relativo - vertical_balde * dot(relativo, vertical_balde);
	float radio = length(radial);
	if (radio > 0.145) {
		vertice -= radial * (1.0 - 0.145 / radio) * inmersion;
	}
	return vertice;
}


void deformar_fibras(inout vec3 vertice, inout vec3 normal, mat4 modelo, vec2 ancla) {
	// Las tangentes deformadas incluyen caída y límite de alcance, además de la flexión.
	vec3 eje = abs(normal.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	vec3 tangente = normalize(cross(normal, eje));
	vec3 bitangente = cross(normal, tangente);
	float paso = 0.0001;
	vec3 primera = posicion_de_fibra(vertice + tangente * paso, ancla)
		- posicion_de_fibra(vertice - tangente * paso, ancla);
	vec3 segunda = posicion_de_fibra(vertice + bitangente * paso, ancla)
		- posicion_de_fibra(vertice - bitangente * paso, ancla);
	vec3 perpendicular = cross(primera, segunda);
	if (dot(perpendicular, perpendicular) > 1e-16) {
		normal = normalize(perpendicular);
	}
	vertice = (articulacion * vec4(posicion_de_fibra(vertice, ancla), 1.0)).xyz;
	normal = normalize(mat3(articulacion) * normal);
	vec3 mundial = (modelo * vec4(vertice, 1.0)).xyz;
	if (inmersion <= 0.0 && mundial.y < suelo_y + 0.002) {
		vertice += (inverse(modelo) * vec4(0.0, suelo_y + 0.002 - mundial.y, 0.0, 0.0)).xyz;
	}
}
