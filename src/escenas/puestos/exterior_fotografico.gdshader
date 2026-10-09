shader_type spatial;
render_mode unshaded, cull_disabled;

#include "exterior_proyeccion.gdshaderinc"

uniform bool fondo_continuo = false;
uniform bool fundir_cielo = false;
uniform bool fundir_suelo = false;
uniform bool fundir_apoyo = false;
uniform float altura_del_suelo = -0.01776253;
uniform bool quitar_lampara = false;
uniform sampler2D marquesina_sin_lampara : source_color, filter_linear_mipmap, repeat_disable;

vec2 proyectar_fondo(vec3 punto) {
	vec3 q = punto - origen;
	float angulo = atan(q.z, -q.x);
	float limite = 0.70;
	float desplazamiento = focal.x * tan(min(abs(angulo), limite));
	desplazamiento += max(abs(angulo) - limite, 0.0)
		* (1.0 - focal.x * tan(limite)) / (PI - limite);
	float u = 0.5 - sign(angulo) * desplazamiento;
	// La extensión reflejada cierra la vuelta sin reiniciar la imagen en cada pared.
	u = 1.0 - abs(fract(u * 0.5) * 2.0 - 1.0);
	float profundidad = length(q.xz) * max(cos(angulo), cos(limite));
	return vec2(u, horizonte - focal.y * q.y / max(profundidad, 0.001));
}

void vertex() {
	punto_mundial = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = proyectar(punto_mundial);
	if (fondo_continuo) {
		uv = proyectar_fondo(punto_mundial);
	}
	vec2 muestra = uv;
	if (fundir_cielo && uv.y < 0.12) {
		// Redondear el retorno evita que las nubes y la lluvia formen una costura al reflejarse.
		float distancia = sqrt(uv.y * uv.y + 0.0036) - 0.06;
		float continuacion = 0.06 + 0.12 * (1.0 - exp(-distancia / 0.12));
		muestra.y = mix(continuacion, uv.y, smoothstep(0.0, 0.12, uv.y));
	}
	vec3 foto = texture(fotografia, clamp(muestra, vec2(0.001), vec2(0.999))).rgb;
	if (quitar_lampara) {
		// El parche sólo reemplaza la lámpara lejana y su halo; el resto conserva la foto.
		vec2 pixel = uv * vec2(2912.0, 1440.0);
		vec2 parche = (pixel - vec2(1190.0, 550.0)) / vec2(200.0, 110.0);
		float distancia = length((pixel - vec2(1293.0, 593.0)) / vec2(45.0, 30.0));
		float peso = 1.0 - smoothstep(0.60, 1.0, distancia);
		foto = mix(foto, texture(marquesina_sin_lampara, clamp(parche, vec2(0.0), vec2(1.0))).rgb, peso);
	}
	if (fundir_suelo) {
		foto = mix(foto, vegetacion_baja(punto_mundial.xz), smoothstep(0.525, 0.54, uv.y));
	}
	if (fundir_apoyo) {
		// Sólo los últimos centímetros del recorte se integran con su sombra de contacto.
		float apoyo = smoothstep(0.0, 0.025, punto_mundial.y - altura_del_suelo);
		foto = mix(asfalto(punto_mundial.xz) * 0.60, foto, apoyo);
	}
	ALBEDO = foto;
}
