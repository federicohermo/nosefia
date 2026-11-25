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
uniform bool usar_silueta = false;
uniform int cantidad_capsulas = 0;
uniform vec4 capsulas[8];
uniform float radios_capsulas[8];
// `(centro_x, centro_z, radio_mayor, radio_tubo)`. Con `radio_mayor <= 0.0` no se dibuja aro.
uniform vec4 aro_silueta = vec4(0.0);
// Unión de hasta 8 rectángulos en el plano de la mancha para bases compuestas o en L.
uniform bool usar_cajas = false;
uniform int cantidad_cajas = 0;
// `(centro_x, centro_z, mitad_x, mitad_z)` en metros respecto del centro del plano.
uniform vec4 cajas[8];
// Si es cierto, cada instancia del `MultiMesh` define su propia mancha rectangular:
// el tamaño sale de `MODEL_MATRIX`. Sin `recorte_por_instancia`, `INSTANCE_CUSTOM` trae
// `(suavidad, esquinas, intensidad, 0)`. Con `recorte_por_instancia`, `INSTANCE_CUSTOM` trae el
// recorte `(min_x, min_z, max_x, max_z)`, `length(MODEL_MATRIX[1].xyz) - 1.0` trae `esquinas`
// (el plano vive en `y = 0`), y `suavidad`/`intensidad` salen de los uniformes compartidos.
uniform bool parametros_por_instancia = false;

varying vec2 plano;
varying vec3 en_el_apoyo;
varying vec4 recorte_instancia;
varying vec4 datos_instancia;

void vertex() {
	if (parametros_por_instancia) {
		vec2 tamano_inst = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[2].xyz));
		plano = VERTEX.xz * tamano_inst;
		en_el_apoyo = vec3(0.0);
		recorte_instancia = INSTANCE_CUSTOM;
		float suav_inst = recorte_por_instancia ? suavidad : INSTANCE_CUSTOM.x;
		float esq_inst = recorte_por_instancia
			? clamp(length(MODEL_MATRIX[1].xyz) - 1.0, 0.0, 1.0)
			: INSTANCE_CUSTOM.y;
		float int_inst = recorte_por_instancia ? intensidad : INSTANCE_CUSTOM.z;
		datos_instancia = vec4(
			max(vec2(0.001), 0.5 * tamano_inst - vec2(suav_inst)),
			esq_inst,
			int_inst
		);
	} else {
		plano = VERTEX.xz * tamano;
		en_el_apoyo = (al_apoyo * vec4(plano.x, 0.0, plano.y, 1.0)).xyz;
		recorte_instancia = INSTANCE_CUSTOM;
		datos_instancia = vec4(0.0);
	}
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
	if (parametros_por_instancia) {
		vec2 huella_inst = datos_instancia.xy;
		float radio_inst = datos_instancia.z * min(huella_inst.x, huella_inst.y);
		float dist_inst = distancia_al_rectangulo(plano, huella_inst, radio_inst);
		float suav_inst = recorte_por_instancia ? suavidad : recorte_instancia.x;
		float borde_inst = 1.0 - smoothstep(0.0, suav_inst, dist_inst);
		float dentro_inst = 1.0;
		if (recorte_por_instancia) {
			vec2 desde = smoothstep(recorte_instancia.xy, recorte_instancia.xy + 0.01, plano);
			vec2 hasta = 1.0 - smoothstep(recorte_instancia.zw - 0.01, recorte_instancia.zw, plano);
			dentro_inst = desde.x * desde.y * hasta.x * hasta.y;
		}
		ALBEDO = vec3(0.0);
		ALPHA = datos_instancia.w * borde_inst * dentro_inst;
	} else {
		float distancia = 0.0;
		if (usar_silueta) {
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
		} else if (usar_cajas) {
			distancia = 1000.0;
			for (int i = 0; i < 8; i++) {
				if (i >= cantidad_cajas) {
					break;
				}
				vec2 mitad_caja = cajas[i].zw;
				float radio_caja = esquinas * min(mitad_caja.x, mitad_caja.y);
				distancia = min(
					distancia,
					distancia_al_rectangulo(plano - cajas[i].xy, mitad_caja, radio_caja)
				);
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
}
