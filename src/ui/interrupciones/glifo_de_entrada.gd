## El dibujo de una entrada de la pantalla de controles. No es un texto: una tecla es una tecla con
## borde, un clic también y lo dice con letras, una ranura libre es un recuadro punteado, y un botón
## del joystick es su glifo de PlayStation. Cada uno mide su ancho natural, y quien lo pone en una
## columna le da el ancho de la tecla más ancha: la tecla, la píldora y la ranura llenan ese ancho.
## El botón de una celda va `en_tecla`: dentro del rectángulo de una tecla, que llena el ancho de la
## columna, con su glifo centrado. Se dibuja con formas y no con imágenes, así que escala con el
## lienzo.
##
## Qué forma lleva cada entrada lo contesta `forma_de`. El nombre que se lee en la forma lo trae
## quien lo crea: este script no sabe nombrar una entrada.
class_name GlifoDeEntrada
extends Control

enum Forma { TECLA, CRUZ, CIRCULO, CUADRADO, TRIANGULO, PILDORA, PALANCA, CRUCETA, RANURA_LIBRE }

const TEMA := preload("res://assets/ui/manada/tema.tres")
## El tipo del tema con que Configuraciones escribe sus nombres: de ahí sale el tamaño de la letra.
const TIPO_DEL_TEXTO := &"TextoDelMenu"
## Lo que mide una tecla de alto, y con ella el círculo más grande que entra en una celda.
const ALTO := 58.0
const MARGEN_DEL_TEXTO := 22.0
## Lo que separa el borde de un círculo o de una píldora de la tinta de su texto: el texto no se
## achica, el contorno crece hasta dejar este aire.
const AIRE_DEL_TEXTO := 5.0
const GROSOR_DEL_BORDE := 2
## El motor dibuja la tinta de la fuente a esta fracción de píxel más abajo que su contorno, medido
## sobre la captura: se resta para que el texto no quede bajo.
const BAJADA_DE_LA_TINTA := 0.4
const FORMAS_QUE_LLENAN: Array[Forma] = [Forma.TECLA, Forma.PILDORA, Forma.RANURA_LIBRE]
## Cuánto del alto de la tecla ocupa un glifo que va dentro de ella.
const ESCALA_EN_LA_TECLA := 0.76
const COLOR_DEL_BORDE := Color("f4e6b5")
const COLOR_DEL_FONDO := Color(0.04, 0.1, 0.12, 0.9)
const COLOR_DE_LA_RANURA_LIBRE := Color("f4e6b599")
## Las flechas se dibujan: la fuente no trae sus glifos.
const FLECHAS: Dictionary = {
	KEY_UP: Vector2.UP,
	KEY_DOWN: Vector2.DOWN,
	KEY_LEFT: Vector2.LEFT,
	KEY_RIGHT: Vector2.RIGHT,
}
const COLOR_DE_LA_CRUZ := Color("6fa8ff")
const COLOR_DEL_CIRCULO := Color("ff5a64")
const COLOR_DEL_CUADRADO := Color("f08fd0")
const COLOR_DEL_TRIANGULO := Color("4fd8a0")

var forma: Forma = Forma.TECLA
## Lo que se lee: el nombre de la tecla, de la píldora o la letra de la palanca. Vacío en un
## glifo que se entiende sin nombre.
var texto: String = ""
## Hacia dónde apunta una tecla de flecha, o cero si no lo es. Se dibuja su punta, no su nombre.
var flecha: Vector2 = Vector2.ZERO
## Si va dentro del rectángulo de una tecla. Una píldora dibuja entonces sólo su texto.
var en_tecla: bool = false


## Qué forma lleva una entrada.
static func forma_de(tipo: int, codigo: int) -> Forma:
	if tipo != AsignacionDeControles.TipoDeEntrada.BOTON_DEL_JOYSTICK:
		return Forma.TECLA
	match codigo:
		JOY_BUTTON_A:
			return Forma.CRUZ
		JOY_BUTTON_B:
			return Forma.CIRCULO
		JOY_BUTTON_X:
			return Forma.CUADRADO
		JOY_BUTTON_Y:
			return Forma.TRIANGULO
		JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK:
			return Forma.PALANCA
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT:
			return Forma.CRUCETA
	return Forma.PILDORA


## El glifo de una entrada de la asignación, con su nombre ya leído.
static func de_la_entrada(entrada: Vector2i, leida: String) -> GlifoDeEntrada:
	var glifo := GlifoDeEntrada.new()
	glifo.forma = forma_de(entrada.x, entrada.y)
	glifo.texto = leida
	if glifo.forma == Forma.TECLA:
		glifo.flecha = FLECHAS.get(entrada.y, Vector2.ZERO)
	else:
		glifo.en_tecla = true
	glifo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glifo


## Una tecla que no es de la asignación, como ENTER o las flechas de las ayudas.
static func de_una_tecla(leida: String) -> GlifoDeEntrada:
	return _de(Forma.TECLA, leida)


## Una secundaria sin entrada, que se lee como un lugar libre donde asignar.
static func de_una_ranura_libre() -> GlifoDeEntrada:
	return _de(Forma.RANURA_LIBRE, "")


## Un botón del joystick que no es de la asignación, como START o una palanca.
static func de_un_boton(forma_del_boton: Forma, leida: String = "") -> GlifoDeEntrada:
	return _de(forma_del_boton, leida)


static func _de(la_forma: Forma, leida: String) -> GlifoDeEntrada:
	var glifo := GlifoDeEntrada.new()
	glifo.forma = la_forma
	glifo.texto = leida
	glifo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return glifo


func _get_minimum_size() -> Vector2:
	return _tamano_natural()


## El rectángulo que dibuja la forma, centrado en el alto y pegado a la izquierda. Una tecla, una
## píldora, una ranura libre y todo lo que va en una tecla llenan el ancho que les dan: es el de la
## tecla más ancha. Las demás formas son redondas y miden su tamaño natural.
func marco_dibujado() -> Rect2:
	var natural := _tamano_natural()
	var ancho := maxf(size.x, natural.x) if en_tecla or forma in FORMAS_QUE_LLENAN else natural.x
	return Rect2(Vector2(0.0, (size.y - natural.y) / 2.0), Vector2(ancho, natural.y))


func _draw() -> void:
	var marco := marco_dibujado()
	if en_tecla:
		draw_style_box(_caja(4), marco)
		if forma == Forma.PILDORA:
			_escribir(texto)
			return
	marco = contorno_dibujado()
	match forma:
		Forma.TECLA:
			_dibujar_tecla(marco)
		Forma.PILDORA:
			_dibujar_pildora(marco)
		Forma.RANURA_LIBRE:
			_dibujar_ranura_libre(marco)
		Forma.PALANCA:
			_dibujar_palanca(marco)
		Forma.CRUCETA:
			_dibujar_cruceta(marco)
		_:
			_dibujar_simbolo(marco)


func _tamano_natural() -> Vector2:
	match forma:
		Forma.TECLA, Forma.PILDORA:
			if flecha != Vector2.ZERO:
				return Vector2(ALTO, ALTO)
			var margen := ALTO if forma == Forma.PILDORA and not en_tecla else MARGEN_DEL_TEXTO
			return Vector2(maxf(ALTO, _tinta_del_texto().size.x + margen), ALTO)
	return Vector2(ALTO, ALTO)


## El tamaño de todo el texto de la pantalla de controles, el de las teclas también: el del texto
## de Configuraciones.
static func tamano_de_la_letra() -> int:
	return TEMA.get_font_size(&"font_size", TIPO_DEL_TEXTO)


## El rectángulo de la forma redonda o de la píldora: el que su borde recorre. El círculo de una
## palanca crece con el texto hasta dejarle `AIRE_DEL_TEXTO`, y queda centrado en su marco.
func contorno_dibujado() -> Rect2:
	var marco := marco_dibujado()
	if forma == Forma.PALANCA:
		var diametro := maxf(
			ALTO * ESCALA_EN_LA_TECLA, 2.0 * (_esquina_del_texto() + AIRE_DEL_TEXTO)
		)
		return Rect2(marco.get_center() - Vector2.ONE * diametro / 2.0, Vector2.ONE * diametro)
	if not en_tecla or forma == Forma.PILDORA:
		return marco
	return Rect2(
		marco.get_center() - Vector2.ONE * ALTO * ESCALA_EN_LA_TECLA / 2.0,
		Vector2.ONE * ALTO * ESCALA_EN_LA_TECLA
	)


## La distancia del centro del texto a su esquina más lejana.
func _esquina_del_texto() -> float:
	return (_tinta_del_texto().size / 2.0).length()


## Dónde cae la tinta de `texto` en el glifo: centrada en su contorno, en los dos ejes. Es la caja
## de lo que se ve, no la de la línea de la fuente, que deja más aire arriba que abajo.
func rect_del_texto() -> Rect2:
	var tinta := _tinta_del_texto()
	var centro := _marco_del_texto().get_center()
	var esquina := centro - tinta.size / 2.0 - Vector2(0.0, BAJADA_DE_LA_TINTA)
	return Rect2(esquina.round(), tinta.size)


## El marco en que se centra el texto: el contorno, o el rectángulo de la tecla.
func _marco_del_texto() -> Rect2:
	if en_tecla and forma != Forma.PALANCA:
		return marco_dibujado()
	return contorno_dibujado()


## La caja de los trazos de `texto` con el origen en el inicio de su línea de base: lo que se ve,
## sin el aire que la fuente deja arriba, abajo y a los lados de cada letra.
func _tinta_del_texto() -> Rect2:
	var fuente := get_theme_default_font()
	var servidor := TextServerManager.get_primary_interface()
	var tamano := tamano_de_la_letra()
	var tinta := Rect2()
	var hay_tinta := false
	var avance := 0.0
	for letra: String in texto:
		var codigo := letra.unicode_at(0)
		var rid: RID = fuente.get_rids()[0]
		var trazo: Dictionary = servidor.font_get_glyph_contours(
			rid, tamano, servidor.font_get_glyph_index(rid, tamano, codigo, 0)
		)
		for punto: Vector3 in trazo.get("points", PackedVector3Array()):
			var en_la_linea := Vector2(avance + punto.x, punto.y)
			tinta = tinta.expand(en_la_linea) if hay_tinta else Rect2(en_la_linea, Vector2.ZERO)
			hay_tinta = true
		avance += fuente.get_char_size(codigo, tamano).x
	return tinta


func _caja(radio: int) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = COLOR_DEL_FONDO
	caja.border_color = COLOR_DEL_BORDE
	caja.set_border_width_all(GROSOR_DEL_BORDE)
	caja.set_corner_radius_all(radio)
	return caja


func _escribir(lo_escrito: String) -> void:
	var tinta := _tinta_del_texto()
	draw_string(
		get_theme_default_font(),
		rect_del_texto().position - tinta.position,
		lo_escrito,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		tamano_de_la_letra(),
		COLOR_DEL_BORDE
	)


func _dibujar_tecla(marco: Rect2) -> void:
	draw_style_box(_caja(4), marco)
	if flecha == Vector2.ZERO:
		_escribir(texto)
		return
	var c := marco.get_center()
	var largo := marco.size.y * 0.22
	var de_lado := Vector2(-flecha.y, flecha.x)
	draw_colored_polygon(
		PackedVector2Array(
			[
				c + flecha * largo,
				c - flecha * largo * 0.8 + de_lado * largo,
				c - flecha * largo * 0.8 - de_lado * largo,
			]
		),
		COLOR_DEL_BORDE
	)


func _dibujar_pildora(marco: Rect2) -> void:
	draw_style_box(_caja(int(marco.size.y / 2.0)), marco)
	_escribir(texto)


func _dibujar_palanca(marco: Rect2) -> void:
	var centro := marco.get_center()
	draw_circle(centro, marco.size.y / 2.0, COLOR_DEL_FONDO)
	draw_arc(centro, marco.size.y / 2.0 - 1.0, 0.0, TAU, 32, COLOR_DEL_BORDE, 2.0)
	_escribir(texto)


func _dibujar_cruceta(marco: Rect2) -> void:
	var c := marco.get_center()
	var largo := marco.size.y / 2.0 - 2.0
	var ancho := largo / 2.6
	var puntos := PackedVector2Array(
		[
			c + Vector2(-ancho, -largo),
			c + Vector2(ancho, -largo),
			c + Vector2(ancho, -ancho),
			c + Vector2(largo, -ancho),
			c + Vector2(largo, ancho),
			c + Vector2(ancho, ancho),
			c + Vector2(ancho, largo),
			c + Vector2(-ancho, largo),
			c + Vector2(-ancho, ancho),
			c + Vector2(-largo, ancho),
			c + Vector2(-largo, -ancho),
			c + Vector2(-ancho, -ancho),
		]
	)
	draw_colored_polygon(puntos, COLOR_DEL_FONDO)
	var contorno := puntos.duplicate()
	contorno.append(puntos[0])
	draw_polyline(contorno, COLOR_DEL_BORDE, 2.0)


func _dibujar_simbolo(marco: Rect2) -> void:
	var c := marco.get_center()
	var radio := marco.size.y / 2.0 - 1.0
	var lado := radio * 0.5
	draw_circle(c, radio, COLOR_DEL_FONDO)
	draw_arc(c, radio - 1.0, 0.0, TAU, 32, COLOR_DEL_BORDE, 2.0)
	match forma:
		Forma.CRUZ:
			draw_line(
				c + Vector2(-lado, -lado), c + Vector2(lado, lado), COLOR_DE_LA_CRUZ, 3.0, true
			)
			draw_line(
				c + Vector2(lado, -lado), c + Vector2(-lado, lado), COLOR_DE_LA_CRUZ, 3.0, true
			)
		Forma.CIRCULO:
			draw_arc(c, lado * 1.1, 0.0, TAU, 24, COLOR_DEL_CIRCULO, 3.0, true)
		Forma.CUADRADO:
			draw_rect(
				Rect2(c - Vector2(lado, lado), Vector2(lado, lado) * 2.0),
				COLOR_DEL_CUADRADO,
				false,
				3.0
			)
		Forma.TRIANGULO:
			var vertices := PackedVector2Array(
				[
					c + Vector2(0.0, -lado * 1.05),
					c + Vector2(lado * 1.2, lado * 1.05),
					c + Vector2(-lado * 1.2, lado * 1.05),
					c + Vector2(0.0, -lado * 1.05),
				]
			)
			draw_polyline(vertices, COLOR_DEL_TRIANGULO, 3.0, true)


func _dibujar_ranura_libre(marco: Rect2) -> void:
	var caja := marco.grow(-1.0)
	var esquinas: Array[Vector2] = [
		caja.position,
		Vector2(caja.end.x, caja.position.y),
		caja.end,
		Vector2(caja.position.x, caja.end.y),
	]
	for i: int in esquinas.size():
		draw_dashed_line(
			esquinas[i], esquinas[(i + 1) % esquinas.size()], COLOR_DE_LA_RANURA_LIBRE, 2.0, 5.0
		)
