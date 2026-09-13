## La obligatoria de sacar la basura: qué bolsas hay y cuáles llegaron al descarte.
##
## **La posición decide.** Una bolsa soltada a mitad de camino no cuenta y **tampoco se quema**:
## el mismo `id` adentro de la zona sí deposita. Sin eso, un tropiezo en el pasillo dejaría la
## obligatoria imposible de cerrar esa noche y el jugador sin saber por qué.
##
## **A qué distancia se soltó entra como parámetro**, igual que el tiempo en el 001: el dominio no
## puede saber de física. Quien mide es la escena.
##
## Es la mitad de la tarea que se ejerce sin levantar una escena: acá no hay un solo `Node3D`.
class_name TareaDeLaBasura
extends RefCounted

## Cómo salió el intento de depositar. Es un conjunto cerrado y por eso es un `enum`: los tres
## rechazos se leen distinto adelante del jugador y aplanarlos daría un cartel para tres cosas.
enum Resultado { DEPOSITADA, FUERA_DE_LA_ZONA, YA_DEPOSITADA, NO_ES_BASURA }

## Los `id` de las bolsas de la noche, en orden. Sin repetidos: uno duplicado daría una tarea que
## se cumple depositando menos bolsas de las que hay en el local.
var _ids: Array[StringName] = []

var _depositadas: Array[StringName] = []


func _init(ids: Array[StringName]) -> void:
	for id in ids:
		if id == ObjetoDelAlmacen.SIN_ID or _ids.has(id):
			continue
		_ids.append(id)


## La tarea de una noche, con las bolsas que declara el balance.
##
## Instancias nuevas en cada llamada: con una compartida, lo depositado anoche llegaría depositado
## esta noche y la obligatoria se cumpliría sola a partir de la segunda jornada.
static func de_la_jornada() -> TareaDeLaBasura:
	return TareaDeLaBasura.new(ReglasDeLaBasura.ids_de_las_bolsas())


func bolsas() -> int:
	return _ids.size()


func depositadas() -> int:
	return _depositadas.size()


func esta_depositada(id: StringName) -> bool:
	return _depositadas.has(id)


## Si no quedó una sola bolsa adentro.
##
## Se compara contra la lista que se recibió y nunca contra un número escrito acá: subir las
## bolsas es tocar el balance, no este archivo.
func completada() -> bool:
	return depositadas() == bolsas()


## Deja una bolsa en el descarte, y devuelve cómo salió.
##
## El orden de los rechazos importa: «eso no es basura» es una propiedad de la cosa y vale
## siempre; «ésa ya la trajiste» es del estado; y «esto no es el fondo» es lo único que depende
## de dónde está parado el jugador — y es el que **no** cambia nada, para que dejarla a mitad de
## camino no la queme.
func depositar(id: StringName, distancia_al_descarte: float) -> Resultado:
	if not _ids.has(id):
		return Resultado.NO_ES_BASURA
	if esta_depositada(id):
		return Resultado.YA_DEPOSITADA
	if not Trayecto.dentro_del_descarte(distancia_al_descarte, ReglasDeLaBasura.RADIO_DEL_DESCARTE):
		return Resultado.FUERA_DE_LA_ZONA
	_depositadas.append(id)
	return Resultado.DEPOSITADA
