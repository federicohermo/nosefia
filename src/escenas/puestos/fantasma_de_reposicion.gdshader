// Dónde va la próxima unidad: el producto mismo, transparente y titilando despacio.
//
// **Muestra el producto y no una marca abstracta.** Antes era un rectángulo con el borde
// amarillo del foco dibujado en el piso, y con la iluminación de la noche ese amarillo se
// perdía contra el estante: la marca estaba y no se leía. Un fantasma del envase dice dos cosas
// a la vez —dónde va y qué va— sin ningún cartel.
//
// **El envase con su color de siempre, y nada más que la transparencia.** Teñirlo de rojo lo
// hacía leer como otro producto puesto en el lugar equivocado en vez de como una marca, y el
// titileo ya alcanza para que no se confunda con mercadería.
//
// `unshaded` porque es una indicación y no un objeto: tiene que verse igual con luz o sin ella.
// `depth_draw_never` para que no tape lo que hay atrás, y `cull_disabled` para que se lea
// también desde adentro del mueble.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D textura : source_color, filter_nearest;

uniform float opacidad_minima = 0.04;
uniform float opacidad_maxima = 0.18;

// Cuánto tarda un ciclo completo, en segundos. **Lento a propósito**: un titileo rápido se lee
// como un error del juego y no como una indicación.
uniform float periodo = 2.2;

const float VUELTA = 6.28318530718;

void fragment() {
	ALBEDO = texture(textura, UV).rgb;
	float pulso = 0.5 + 0.5 * sin(TIME * VUELTA / periodo);
	ALPHA = mix(opacidad_minima, opacidad_maxima, pulso);
}
