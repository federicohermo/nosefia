// El envase de un casillero vacío: el producto mismo, transparente, quieto o titilando.
//
// **Muestra el producto y no una marca abstracta.** Antes era un rectángulo con el borde
// amarillo del foco dibujado en el piso, y con la iluminación de la noche ese amarillo se
// perdía contra el estante: la marca estaba y no se leía. Un fantasma del envase dice dos cosas
// a la vez —dónde va y qué va— sin ningún cartel.
//
// **En blanco y negro mientras espera, y en color con emisión cuando la mira lo enfoca.** El gris
// lo separa de la mercadería ya puesta, que tiene su color entero; el color y el brillo de más
// del apuntado dicen cuál de todos los que esperan es el que va a recibir el clic, y qué producto
// va ahí. Cuánto gris, cuánto brillo, qué opacidades y qué ritmo los pone la escena, que los lee
// de las reglas del estante: acá ninguno trae un valor propio, porque un número escrito acá sería
// el mismo valor en dos lugares, y el que se ajusta jugando no sería éste.
//
// `unshaded` porque es una indicación y no un objeto: tiene que verse igual con luz o sin ella,
// y `depth_draw_never` para que no tape lo que hay atrás. Por lo mismo, la emisión no es luz: es
// el color por encima del suyo, que el tonemap del entorno lleva hacia el blanco.
//
// **Las caras de atrás no se dibujan.** Con `cull_disabled` el fantasma mostraba su propio
// reverso a través del frente: en una lata se veía la tapa de abajo como una mancha negra, y en
// una bolsa la tabla nutricional del dorso encima del logo. Un envase es un cuerpo cerrado, así
// que la cara que mira para el otro lado no aporta nada, y sumada en transparencia sobre la de
// adelante ensucia las dos. Lo que se pierde es verlo desde adentro del mueble, que es una
// posición desde la que el jugador no mira.
shader_type spatial;
render_mode unshaded, depth_draw_never;


uniform sampler2D textura : source_color, filter_nearest;

// Entre qué opacidades titila. Iguales, el envase queda quieto.
uniform float opacidad_minima;
uniform float opacidad_maxima;

// Cuánto tarda un ciclo completo del titileo, en segundos.
uniform float periodo;

// Cuánto color le queda al envase: 0 es blanco y negro y 1 es el envase tal cual.
uniform float saturacion;

// Cuánto brilla de más sobre su propio color: 0 es su color, sin nada encima.
uniform float emision;

const float VUELTA = 6.28318530718;

// Cuánto aporta cada canal al gris. Son los pesos de luminancia de Rec. 709: un promedio simple
// apaga el rojo y enciende el azul, y los envases quedan todos del mismo gris medio.
const vec3 LUMINANCIA = vec3(0.2126, 0.7152, 0.0722);

// Un ciclo nunca dura cero: sin ritmo, el titileo se queda en su punto medio en vez de dividir
// por cero.
const float PERIODO_MINIMO = 0.001;


void fragment() {
	vec3 color = texture(textura, UV).rgb;
	vec3 tenido = mix(vec3(dot(color, LUMINANCIA)), color, saturacion);
	ALBEDO = tenido * (1.0 + emision);

	float pulso = 0.5 + 0.5 * sin(TIME * VUELTA / max(periodo, PERIODO_MINIMO));
	ALPHA = mix(opacidad_minima, opacidad_maxima, pulso);
}
