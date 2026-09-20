// Dónde va la próxima unidad: el producto mismo, transparente y titilando despacio.
//
// **Muestra el producto y no una marca abstracta.** Antes era un rectángulo con el borde
// amarillo del foco dibujado en el piso, y con la iluminación de la noche ese amarillo se
// perdía contra el estante: la marca estaba y no se leía. Un fantasma del envase dice dos cosas
// a la vez —dónde va y qué va— sin ningún cartel.
//
// **El envase sin color mientras es una marca, y con su color al quedar puesto.** Teñirlo de
// rojo lo hacía leer como otro producto puesto en el lugar equivocado; dejarle su color, con
// tan poca opacidad, lo hacía perderse entre la mercadería de al lado. En blanco y negro la
// marca se distingue de todo lo que ya está en el estante, y el color que aparece al colocar
// la unidad es el aviso de que quedó puesta.
//
// `unshaded` porque es una indicación y no un objeto: tiene que verse igual con luz o sin ella.
// `depth_draw_never` para que no tape lo que hay atrás, y `cull_disabled` para que se lea
// también desde adentro del mueble.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D textura : source_color, filter_nearest;

uniform float opacidad_minima = 0.0;
uniform float opacidad_maxima = 1.0;

// Cuánto tarda un ciclo completo, en segundos. El titileo recorre la opacidad entera, de nada a
// todo: es lo único que distingue la marca de la mercadería, así que tiene que alcanzar a
// leerse mientras el jugador mira el estante. Más rápido que esto se lee como un parpadeo roto.
uniform float periodo = 1.2;

const float VUELTA = 6.28318530718;

// Cuánto aporta cada canal al gris. Son los pesos de luminancia de Rec. 709: un promedio simple
// apaga el rojo y enciende el azul, y los envases quedan todos del mismo gris medio.
const vec3 LUMINANCIA = vec3(0.2126, 0.7152, 0.0722);

void fragment() {
	ALBEDO = vec3(dot(texture(textura, UV).rgb, LUMINANCIA));
	float pulso = 0.5 + 0.5 * sin(TIME * VUELTA / periodo);
	ALPHA = mix(opacidad_minima, opacidad_maxima, pulso);
}
