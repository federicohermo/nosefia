## El dibujo de una entrada de la pantalla de controles. No es un texto: una tecla es una tecla con
## borde, un clic también y lo dice con letras, una ranura libre es un recuadro punteado del tamaño
## de una tecla de una letra, y un botón del joystick es su glifo de PlayStation. Cada uno mide su
## ancho natural y se dibuja pegado a la izquierda de donde está. Se dibuja con formas y no con
## imágenes, así que escala con el lienzo.
##
## Qué forma lleva cada entrada lo contesta `forma_de`. El nombre que se lee en la forma lo trae
## quien lo crea: este script no sabe nombrar una entrada.
class_name GlifoDeEntrada
extends Control

enum Forma { TECLA, CRUZ, CIRCULO, CUADRADO, TRIANGULO, PILDORA, PALANCA, CRUCETA, RANURA_LIBRE }

const TEMA := preload("res://assets/ui/manada/tema.tres")
## El tipo del tema con que Configuraciones escribe sus nombres: de ahí sale el tamaño de la letra.
const TIPO_DEL_TEXTO := &"TextoDelMenu"
const ALTO := 46.0
const MARGEN_DEL_TEXTO := 22.0
## La letra que mide una ranura libre: la más ancha del teclado.
const LETRA_DE_LA_RANURA := "W"
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


## El rectángulo que dibuja la forma: su tamaño natural, a la izquierda y centrado en el alto.
func marco_dibujado() -> Rect2:
	var natural := _tamano_natural()
	return Rect2(Vector2(0.0, (size.y - natural.y) / 2.0), natural)


func _draw() -> void:
	var marco := marco_dibujado()
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
			return Vector2(maxf(ALTO, _ancho_del_texto(texto) + MARGEN_DEL_TEXTO), ALTO)
		Forma.RANURA_LIBRE:
			return Vector2(
				maxf(ALTO, _ancho_del_texto(LETRA_DE_LA_RANURA) + MARGEN_DEL_TEXTO), ALTO
			)
	return Vector2(ALTO, ALTO)


func _ancho_del_texto(lo_escrito: String) -> float:
	return (
		get_theme_default_font()
		. get_string_size(lo_escrito, HORIZONTAL_ALIGNMENT_LEFT, -1.0, _tamano_de_la_letra())
		. x
	)


## El tamaño de todo el texto de la pantalla de controles, el de las teclas también: el del texto
## de Configuraciones.
static func tamano_de_la_letra() -> int:
	return TEMA.get_font_size(&"font_size", TIPO_DEL_TEXTO)


func _tamano_de_la_letra() -> int:
	return tamano_de_la_letra()


func _caja(radio: int) -> StyleBoxFlat:
	var caja := StyleBoxFlat.new()
	caja.bg_color = COLOR_DEL_FONDO
	caja.border_color = COLOR_DEL_BORDE
	caja.set_border_width_all(2)
	caja.set_corner_radius_all(radio)
	return caja


func _escribir(marco: Rect2, lo_escrito: String) -> void:
	var fuente := get_theme_default_font()
	var tamano_de_la_letra := _tamano_de_la_letra()
	var medida := fuente.get_string_size(
		lo_escrito, HORIZONTAL_ALIGNMENT_LEFT, -1.0, tamano_de_la_letra
	)
	var base := Vector2(
		marco.position.x + (marco.size.x - medida.x) / 2.0,
		marco.position.y + (marco.size.y + fuente.get_ascent(tamano_de_la_letra)) / 2.0 - 2.0
	)
	draw_string(
		fuente,
		base,
		lo_escrito,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		tamano_de_la_letra,
		COLOR_DEL_BORDE
	)


func _dibujar_tecla(marco: Rect2) -> void:
	draw_style_box(_caja(4), marco)
	if flecha == Vector2.ZERO:
		_escribir(marco, texto)
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
	_escribir(marco, texto)


func _dibujar_palanca(marco: Rect2) -> void:
	var centro := marco.get_center()
	draw_circle(centro, marco.size.y / 2.0, COLOR_DEL_FONDO)
	draw_arc(centro, marco.size.y / 2.0 - 1.0, 0.0, TAU, 32, COLOR_DEL_BORDE, 2.0)
	_escribir(marco, texto)


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
					c + Vector2(0.0, -lado * 1.2),
					c + Vector2(lado * 1.2, lado * 0.9),
					c + Vector2(-lado * 1.2, lado * 0.9),
					c + Vector2(0.0, -lado * 1.2),
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
