uniform float angulo = 1.570796327;

void girar_manija(inout vec3 vertice, inout vec3 normal, vec2 parte) {
	if (parte.x < 0.5) {
		return;
	}
	vec3 bisagra = vec3(0.0, 0.134, 0.0);
	float seno = sin(angulo);
	float coseno = cos(angulo);
	// El arco se abre al salvar el borde; bisagras y agarre conservan su forma.
	float paso = sin(2.0 * angulo);
	float apertura = abs(seno) * 0.003 + 0.04 * paso * paso;
	float altura = abs(seno) * 0.015;
	float tx = clamp((abs(vertice.x) - 0.06) / 0.08, 0.0, 1.0);
	float ty = clamp((vertice.y - 0.1445) / 0.0105, 0.0, 1.0);
	float ta = clamp((vertice.y - 0.18) / 0.07, 0.0, 1.0);
	float wx = smoothstep(0.0, 1.0, tx);
	float wy = smoothstep(0.0, 1.0, ty);
	float wa = smoothstep(0.0, 1.0, ta);
	float xx = 1.0 + apertura * 6.0 * tx * (1.0 - tx) / 0.08 * wy;
	float xy = sign(vertice.x) * apertura * wx * 6.0 * ty * (1.0 - ty) / 0.0105;
	float yy = 1.0 + altura * 6.0 * ta * (1.0 - ta) / 0.07;
	normal.x /= xx;
	normal.y = (normal.y - xy * normal.x) / yy;
	normal = normalize(normal);
	vertice.x += sign(vertice.x) * apertura * wx * wy;
	vertice.y += altura * wa;
	mat3 giro = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, coseno, seno), vec3(0.0, -seno, coseno));
	vertice = bisagra + giro * (vertice - bisagra);
	normal = giro * normal;
}
