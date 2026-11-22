// La mancha difusa que un objeto deja sobre la superficie que tiene debajo.
//
// Es un plano negro con alfa: oscurece lo que cae atrás y no pone luz. Sobre una imagen casi
// negra no se ve. Los valores son uniformes del material, y cada mancha lleva el suyo: en la
// web los uniformes por instancia llegan en cero.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// Tamaño del plano, en metros.
uniform vec2 tamano = vec2(1.0);
// Mitad de la huella del objeto, en metros.
uniform vec2 huella = vec2(0.2);
// De 0 (esquinas vivas) a 1 (círculo).
uniform float esquinas = 0.0;
// Ancho del borde difuso, en metros.
uniform float suavidad = 0.06;
uniform float intensidad = 0.0;
// Del plano de la mancha, en metros, al espacio de la forma que la sostiene.
uniform mat4 al_apoyo = mat4(1.0);
// Hasta dónde llega esa forma: mínimo y máximo, en su espacio.
uniform vec3 apoyo_minimo = vec3(-1000.0);
uniform vec3 apoyo_maximo = vec3(1000.0);
// Si es cierto, cada instancia del `MultiMesh` trae su recorte en `INSTANCE_CUSTOM`:
// `(min_x, min_z, max_x, max_z)` en metros sobre el plano de la mancha.
uniform bool recorte_por_instancia = false;
// Silueta analítica 2D para objetos cóncavos (palanca, llave): hasta 8 cápsulas y 1 aro opcional.
uniform int cantidad_capsulas = 0;
uniform vec4 capsulas[8];
uniform float radios_capsulas[8];
// `(centro_x, centro_z, radio_mayor, radio_tubo)`. Con `radio_mayor <= 0.0` no se dibuja aro.
uniform vec4 aro_silueta = vec4(0.0);

varying vec2 plano;
varying vec3 en_el_apoyo;
varying vec4 recorte_instancia;

void vertex() {
	plano = VERTEX.xz * tamano;
	en_el_apoyo = (al_apoyo * vec4(plano.x, 0.0, plano.y, 1.0)).xyz;
	recorte_instancia = INSTANCE_CUSTOM;
}

float distancia_al_rectangulo(vec2 punto, vec2 mitad, float radio) {
	vec2 q = abs(punto) - mitad + radio;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radio;
}

float distancia_a_la_capsula(vec2 punto, vec2 a, vec2 b, float radio) {
	vec2 pa = punto - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.000001), 0.0, 1.0);
	return length(pa - ba * h) - radio;
}

void fragment() {
	float distancia = 0.0;
	if (cantidad_capsulas > 0 || aro_silueta.z > 0.0) {
		distancia = 1000.0;
		for (int i = 0; i < 8; i++) {
			if (i >= cantidad_capsulas) {
				break;
			}
			distancia = min(
				distancia,
				distancia_a_la_capsula(plano, capsulas[i].xy, capsulas[i].zw, radios_capsulas[i])
			);
		}
		if (aro_silueta.z > 0.0) {
			float d_aro = abs(length(plano - aro_silueta.xy) - aro_silueta.z) - aro_silueta.w;
			distancia = min(distancia, d_aro);
		}
	} else {
		float radio = esquinas * min(huella.x, huella.y);
		distancia = distancia_al_rectangulo(plano, huella, radio);
	}
	float borde = 1.0 - smoothstep(0.0, suavidad, distancia);
	// Sin esto la mancha sigue en el aire más allá del borde de lo que la sostiene.
	float dentro = 1.0;
	if (recorte_por_instancia) {
		vec2 desde = smoothstep(recorte_instancia.xy, recorte_instancia.xy + 0.01, plano);
		vec2 hasta = 1.0 - smoothstep(recorte_instancia.zw - 0.01, recorte_instancia.zw, plano);
		dentro = desde.x * desde.y * hasta.x * hasta.y;
	} else {
		vec3 desde = smoothstep(apoyo_minimo, apoyo_minimo + 0.01, en_el_apoyo);
		vec3 hasta = 1.0 - smoothstep(apoyo_maximo - 0.01, apoyo_maximo, en_el_apoyo);
		dentro = desde.x * desde.y * desde.z * hasta.x * hasta.y * hasta.z;
	}
	ALBEDO = vec3(0.0);
	ALPHA = intensidad * borde * dentro;
}
