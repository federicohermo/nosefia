// Dónde va la próxima unidad: el producto mismo, transparente y titilando despacio.
//
// **Muestra el producto y no una marca abstracta.** Antes era un rectángulo con el borde
// amarillo del foco dibujado en el piso, y con la iluminación de la noche ese amarillo se
// perdía contra el estante: la marca estaba y no se leía. Un fantasma del envase dice dos cosas
// a la vez —dónde va y qué va— sin ningún cartel.
//
// `unshaded` porque es una indicación y no un objeto: tiene que verse igual con luz o sin ella.
// `depth_draw_never` para que no tape lo que hay atrás, y `cull_disabled` para que se lea
// también desde adentro del mueble.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D textura : source_color, filter_nearest;

// Con qué se tiñe el envase. En blanco se ve su color real; en rojo, que es lo que usa el foco,
// grita sin dejar de ser reconocible.
uniform vec4 tinte : source_color = vec4(1.0);

uniform float opacidad_minima = 0.08;
uniform float opacidad_maxima = 0.30;

// Cuánto tarda un ciclo completo, en segundos. **Lento a propósito**: un titileo rápido se lee
// como un error del juego y no como una indicación.
uniform float periodo = 2.2;

const float VUELTA = 6.28318530718;

void fragment() {
	vec4 base = texture(textura, UV);
	ALBEDO = base.rgb * tinte.rgb;
	float pulso = 0.5 + 0.5 * sin(TIME * VUELTA / periodo);
	ALPHA = mix(opacidad_minima, opacidad_maxima, pulso);
}
