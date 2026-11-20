## Mezcla el atlas de un horneado con el de otro horneado del mismo local.
##
## **Los dos horneados no ubican las piezas igual.** Cada uno acomoda las mallas en el atlas a su
## manera: con unos obstáculos de más, 92 de las 146 piezas del local quedaron en otro lugar. Una
## mezcla texel a texel mezclaría piezas distintas. Por eso cada pieza se lee del rectángulo que
## tiene en el atlas de cada horneado, y se escribe en el que tiene en la base.
##
## La base es lo que queda: sus piezas, su disposición y su `.lmbake`. Del otro horneado sólo salen
## las luces de cada pieza.
extends RefCounted

## Cada pieza de `user_data` ocupa cuatro lugares: la ruta de la malla, su rectángulo en el
## atlas (de 0 a 1), la rebanada del atlas y el índice de su instancia.
const CAMPOS_POR_PIEZA := 4
const CAMPO_RUTA := 0
const CAMPO_RECTANGULO := 1
const CAMPO_REBANADA := 2
const CAMPO_INSTANCIA := 3
## Texeles de más alrededor de cada pieza: el filtrado del mapa de luz los lee.
const MARGEN := 1
const CANALES := 4


## Lo que dejó la mezcla.
class Resultado:
	var imagen: Image
	## Las piezas de la base que el otro horneado no trae igual: quedan como estaban.
	var sin_par: int = 0


## Un atlas es una pila de capas cuadradas, una sobre otra: la luz y, de a tres, su dirección.
## `piezas_base` y `piezas_otro` son el `user_data` de cada `LightmapGIData`.
## Con `nivel` 0 el resultado es la base, y con 1 es la base con la luz del otro entera.
static func mezclar(
	base: Image, otro: Image, piezas_base: Array, piezas_otro: Array, nivel: float
) -> Resultado:
	var resultado := Resultado.new()
	var formato := base.get_format()
	var a := Image.create_from_data(
		base.get_width(), base.get_height(), false, base.get_format(), base.get_data()
	)
	var b := Image.create_from_data(
		otro.get_width(), otro.get_height(), false, otro.get_format(), otro.get_data()
	)
	a.convert(Image.FORMAT_RGBAF)
	b.convert(Image.FORMAT_RGBAF)
	var ancho := a.get_width()
	@warning_ignore("integer_division")
	var capas := a.get_height() / ancho
	var rebanadas := maxi(_rebanadas(piezas_base), _rebanadas(piezas_otro))
	@warning_ignore("integer_division")
	var capas_por_rebanada := capas / rebanadas
	var luz_base := a.get_data().to_float32_array()
	var luz_otro := b.get_data().to_float32_array()
	var salida := luz_base.duplicate()
	var del_otro := _por_clave(piezas_otro)
	# Primero los bordes de todas las piezas y después sus interiores: un borde puede caer sobre
	# el interior de otra pieza, y el interior tiene que ganar.
	for margen: int in [MARGEN, 0]:
		for i: int in range(0, piezas_base.size(), CAMPOS_POR_PIEZA):
			var clave := _clave(piezas_base, i)
			if not del_otro.has(clave):
				if margen == MARGEN:
					resultado.sin_par += 1
				continue
			var j: int = del_otro[clave]
			var rect_base: Rect2 = piezas_base[i + CAMPO_RECTANGULO]
			var rect_otro: Rect2 = piezas_otro[j + CAMPO_RECTANGULO]
			var tamano := Vector2i(
				roundi(rect_base.size.x * ancho), roundi(rect_base.size.y * ancho)
			)
			if (
				tamano
				!= Vector2i(roundi(rect_otro.size.x * ancho), roundi(rect_otro.size.y * ancho))
			):
				if margen == MARGEN:
					resultado.sin_par += 1
				continue
			_mezclar_pieza(
				salida,
				luz_base,
				luz_otro,
				ancho,
				capas_por_rebanada,
				[piezas_base[i + CAMPO_REBANADA], piezas_otro[j + CAMPO_REBANADA]],
				[_esquina(rect_base, ancho), _esquina(rect_otro, ancho)],
				tamano,
				margen,
				nivel
			)
	var imagen := Image.create_from_data(
		ancho, a.get_height(), false, Image.FORMAT_RGBAF, salida.to_byte_array()
	)
	imagen.convert(formato)
	resultado.imagen = imagen
	return resultado


static func _mezclar_pieza(
	salida: PackedFloat32Array,
	luz_base: PackedFloat32Array,
	luz_otro: PackedFloat32Array,
	ancho: int,
	capas_por_rebanada: int,
	rebanadas: Array[int],
	esquinas: Array[Vector2i],
	tamano: Vector2i,
	margen: int,
	nivel: float
) -> void:
	var desde_x := esquinas[0].x - margen
	var largo := (tamano.x + 2 * margen) * CANALES
	if (
		desde_x < 0
		or esquinas[1].x - margen < 0
		or esquinas[0].x + tamano.x + margen > ancho
		or esquinas[1].x + tamano.x + margen > ancho
	):
		return
	for capa: int in capas_por_rebanada:
		var fila_base := (rebanadas[0] * capas_por_rebanada + capa) * ancho
		var fila_otro := (rebanadas[1] * capas_por_rebanada + capa) * ancho
		for y: int in range(-margen, tamano.y + margen):
			var yb := esquinas[0].y + y
			var yo := esquinas[1].y + y
			if yb < 0 or yb >= ancho or yo < 0 or yo >= ancho:
				continue
			var inicio_base := ((fila_base + yb) * ancho + desde_x) * CANALES
			var inicio_otro := ((fila_otro + yo) * ancho + esquinas[1].x - margen) * CANALES
			for k: int in largo:
				var valor := luz_base[inicio_base + k]
				salida[inicio_base + k] = valor + (luz_otro[inicio_otro + k] - valor) * nivel


static func _esquina(rect: Rect2, ancho: int) -> Vector2i:
	return Vector2i(roundi(rect.position.x * ancho), roundi(rect.position.y * ancho))


static func _clave(piezas: Array, i: int) -> String:
	return "%s#%s" % [piezas[i + CAMPO_RUTA], piezas[i + CAMPO_INSTANCIA]]


static func _por_clave(piezas: Array) -> Dictionary:
	var indices := {}
	for i: int in range(0, piezas.size(), CAMPOS_POR_PIEZA):
		indices[_clave(piezas, i)] = i
	return indices


static func _rebanadas(piezas: Array) -> int:
	var cuantas := 1
	for i: int in range(0, piezas.size(), CAMPOS_POR_PIEZA):
		cuantas = maxi(cuantas, int(piezas[i + CAMPO_REBANADA]) + 1)
	return cuantas
