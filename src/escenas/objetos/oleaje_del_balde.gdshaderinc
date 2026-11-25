// Las formas de `ondas_del_balde.gd`, en el mismo orden. Un cambio allá va también acá.
uniform bool ondas_en_vertices = false;
uniform vec4 modos_a = vec4(0.0);
uniform vec4 modos_b = vec4(0.0);
uniform vec2 inclinacion = vec2(0.0);
uniform float nivel = 1.0;
uniform float descenso = 0.0;
uniform float fondo = -1.0;
uniform float limite = 1.0;
uniform float borde = 1.0;
uniform float radio_del_disco = 0.6;
uniform float relieve_de_las_ondas = 1.8;

const float MEDIA_DEL_MODO_AXIAL = 0.405;

float ondas_en(vec2 punto) {
	float radio = min(length(punto), 1.0);
	vec2 direccion = radio > 0.00001 ? punto / length(punto) : vec2(1.0, 0.0);
	float c1 = direccion.x;
	float s1 = direccion.y;
	float c2 = c1 * c1 - s1 * s1;
	float s2 = 2.0 * c1 * s1;
	float c3 = c2 * c1 - s2 * s1;
	float s3 = s2 * c1 + c2 * s1;
	float sr = sin(radio * PI * 0.5);
	float cr = cos(radio * PI * 0.5);
	float sr2 = sr * sr;
	float sr10 = 2.0 * sr * cr;
	float cr10 = cr * cr - sr2;
	float sr15 = sr10 * cr + cr10 * sr;
	float cr20 = cr10 * cr10 - sr10 * sr10;
	return dot(modos_a, vec4(cr10 + MEDIA_DEL_MODO_AXIAL, sr15 * c1, sr15 * s1, sr2 * c2))
		+ dot(modos_b, vec4(sr2 * s2, sr2 * sr * c3, sr2 * sr * s3, cr20));
}

// Evalúa ondas_en(p) y su gradiente exacto (do/dpx, do/dpz) en una sola pasada con un solo par
// sin/cos radial, evitando 6 evaluaciones por diferencias finitas en cada píxel.
vec3 ondas_y_gradiente(vec2 p) {
	float r_raw = length(p);
	float r = min(r_raw, 1.0);
	float en_disco = step(r_raw, 1.0);
	vec2 u = r_raw > 0.00001 ? p / r_raw : vec2(1.0, 0.0);
	vec2 t = vec2(-u.y, u.x);
	float c1 = u.x;
	float s1 = u.y;
	float c2 = c1 * c1 - s1 * s1;
	float s2 = 2.0 * c1 * s1;
	float c3 = c2 * c1 - s2 * s1;
	float s3 = s2 * c1 + c2 * s1;
	float sr = sin(r * PI * 0.5);
	float cr = cos(r * PI * 0.5);
	float sr2 = sr * sr;
	float sr3 = sr2 * sr;
	float sr10 = 2.0 * sr * cr;
	float cr10 = cr * cr - sr2;
	float sr15 = sr10 * cr + cr10 * sr;
	float cr15 = cr10 * cr - sr10 * sr;
	float sr20 = 2.0 * sr10 * cr10;
	float cr20 = cr10 * cr10 - sr10 * sr10;
	float o = dot(modos_a, vec4(cr10 + MEDIA_DEL_MODO_AXIAL, sr15 * c1, sr15 * s1, sr2 * c2))
		+ dot(modos_b, vec4(sr2 * s2, sr3 * c3, sr3 * s3, cr20));
	float do_dr = en_disco * (
		-PI * sr10 * modos_a.x
		+ 1.5 * PI * cr15 * (modos_a.y * c1 + modos_a.z * s1)
		+ 0.5 * PI * sr10 * (modos_a.w * c2 + modos_b.x * s2)
		+ 1.5 * PI * sr2 * cr * (modos_b.y * c3 + modos_b.z * s3)
		- 2.0 * PI * sr20 * modos_b.w
	);
	float f1_r = r_raw > 0.0001 ? sr15 / r_raw : 1.5 * PI;
	float f2_r = r_raw > 0.0001 ? sr2 / r_raw : 0.0;
	float f3_r = r_raw > 0.0001 ? sr3 / r_raw : 0.0;
	float do_dt = f1_r * (-modos_a.y * s1 + modos_a.z * c1)
		+ 2.0 * f2_r * (-modos_a.w * s2 + modos_b.x * c2)
		+ 3.0 * f3_r * (-modos_b.y * s3 + modos_b.z * c3);
	return vec3(o, do_dr * u + do_dt * t);
}

// La altura sin recortar del agua en un punto de la malla quieta, en metros locales.
float altura_en_escala(vec2 punto, float escala) {
	return (dot(inclinacion, punto * escala)
		+ ondas_en(punto / radio_del_disco) * relieve_de_las_ondas) * nivel - descenso;
}

float altura_libre(vec2 punto) {
	return altura_en_escala(punto, borde);
}

// La normal analítica por píxel, más la altura libre y la agitación calculadas en la misma pasada.
vec3 normal_del_balde(vec2 punto, out float altura, out float agitacion) {
	float suma_modos = dot(abs(modos_a), vec4(1.0)) + dot(abs(modos_b), vec4(1.0));
	agitacion = smoothstep(0.0, 0.05, suma_modos);
	float inv_radio = 1.0 / max(radio_del_disco, 0.0001);
	vec2 p = punto * inv_radio;
	float o = 0.0;
	vec2 grad_o = vec2(0.0);
	if (suma_modos > 0.00001) {
		vec3 og = ondas_y_gradiente(p);
		o = og.x;
		grad_o = og.yz * inv_radio;
	}
	float h = (dot(inclinacion, punto * borde) + o * relieve_de_las_ondas) * nivel - descenso;
	altura = h;
	float libre = smoothstep(fondo, fondo + 0.004, h)
		* (1.0 - smoothstep(limite - 0.004, limite, h));
	// El borde se escala en xz; la pendiente se mide sobre el punto ya escalado.
	vec2 grad_h = (inclinacion * borde + grad_o * relieve_de_las_ondas) * nivel;
	vec3 normal = normalize(
		mix(vec3(0.0, 1.0, 0.0), normalize(vec3(-grad_h.x, borde, -grad_h.y)), libre)
	);
	float radio = length(p);
	vec2 radial = p / max(radio, 0.0001);
	float empuje = clamp(length(inclinacion) * 5.0, 0.0, 1.0);
	vec2 rizo = vec2(0.0);
	if (agitacion > 0.001 || empuje > 0.001) {
		// Los rizos capilares rebotan hacia adentro desde la pared y se cruzan con el empujón.
		vec2 hacia = empuje > 0.0 ? normalize(inclinacion) : vec2(1.0, 0.0);
		vec2 tangencial = vec2(-radial.y, radial.x);
		float centro_suave = smoothstep(0.0, 0.14, radio);
		float deformacion = o * 40.0;
		vec2 desde_la_pared = p - hacia;
		float distancia = length(desde_la_pared);
		vec2 cruzado = vec2(-hacia.y, hacia.x);
		rizo = radial * cos((1.0 - radio) * 22.0 + deformacion - TIME * 6.0)
				* centro_suave * agitacion
			+ desde_la_pared / max(distancia, 0.0001)
				* cos(distancia * 18.0 - TIME * 5.5) * empuje * max(1.0 - distancia * 0.4, 0.0)
			+ tangencial * sin(dot(p, hacia) * 16.0 - dot(p, cruzado) * 12.0 - TIME * 4.5)
				* centro_suave * agitacion * 0.35;
	}
	// Menisco contra la pared interior: se marca más donde la ola trepa por el plástico.
	float cresta_borde = clamp(h * 10.0, 0.0, 0.6);
	vec2 menisco = radial * smoothstep(0.91, 1.0, radio) * nivel * (0.14 + 0.08 * cresta_borde);
	return normalize(normal - vec3(rizo.x * 0.11 * libre + menisco.x, 0.0,
		rizo.y * 0.11 * libre + menisco.y));
}
