## Las cinco quejas de cobro de la jornada 7: qué cobró cada comprador, qué respondió el jugador y
## si acertó en todas.
##
## **Los compradores, sus mensajes y sus compras viven en `FILAS`, y nada más.** El total correcto
## sale del `Catalogo`, y el valor cobrado de cada queja, de un sorteo con la semilla de la partida:
## con la misma semilla da los mismos cinco valores, así que retomar un guardado no sortea de nuevo.
class_name QuejasDeLaJornada
extends RefCounted

enum Respuesta { SIN_RESPONDER, DA_LA_RAZON, RECHAZA }

const JORNADA := ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA + 4
const MARCA_DEL_VALOR := "[VALOR]"
const ROL := "Comprador / reclamo de cobro"
const TEXTO_DE_DAR_LA_RAZON := (
	"Mil disculpas. Está claro que hubo un error de nuestra parte. "
	+ "Te descontamos la diferencia en tu próxima compra"
)
const TEXTO_DE_RECHAZAR := (
	"Perdón, pero no hubo ningún error. "
	+ "El valor que se cobró coincide con los precios de los productos. Buenas noches"
)
## De las cinco quejas, cuántas cobran de más o de menos.
const MINIMO_INCORRECTAS := 1
const MAXIMO_INCORRECTAS := 4
## Cuántos productos de la compra se reemplazan por otros en un valor incorrecto.
const MINIMO_REEMPLAZOS := 1
const MAXIMO_REEMPLAZOS := 2
const FOTO := "res://assets/ui/manada/fotos/transferencia-de-la-queja.png"
const DESTINO := "ENRIQUE PELDAÑO S.A. ****4689"
const ORIGEN := "Cuenta de ahorro ****"
const IDENTIDAD_DE_LA_QUEJA := "J7_QUEJA_%d"
const IDENTIDAD_DE_LA_RESPUESTA := "J7_QUEJA_%d_RESPUESTA"
## Cada fila es una queja. Los cuatro dígitos de la cuenta de origen son fijos y distintos.
const FILAS: Array[Dictionary] = [
	{
		"quien": Conversacion.Interlocutor.EL_SEBA,
		"nombre": "El Seba",
		"texto":
		(
			"Hola buenas tardes, te comento que ayer por la noche hice una compra de dos "
			+ "productos, un amargadito y un oremos por el valor de [VALOR] y me devolviste mal "
			+ "el vuelto. podrias chequearlo ?"
		),
		"productos": [Producto.Id.AMARGADITO, Producto.Id.OREMOS],
		"cuenta": "5173",
	},
	{
		"quien": Conversacion.Interlocutor.SUKO_YANEZ,
		"nombre": "Suko Yañez",
		"texto":
		(
			"hola no puede ser, un dia que decido pasarme por el local y me cobraron mal la "
			+ "pxxx mxxxx!!@1\n"
			+ "a ver si me devuelven la plata manga de forrxs\n"
			+ "pedi dos poetico, unas laysnnt y un zucaracha y me cobraron [VALOR]. no hacen "
			+ "nada bien, dediquense a otra cosa!!"
		),
		"productos":
		[Producto.Id.POETICO, Producto.Id.POETICO, Producto.Id.LAYSNNT, Producto.Id.ZUCARACHAS],
		"cuenta": "2208",
	},
	{
		"quien": Conversacion.Interlocutor.LUCAS_ORTEGA,
		"nombre": "Lucas Ortega",
		"texto":
		(
			"Hola buenas noches. El martes pase por el local y creo que me cobraron mal. Yo "
			+ "compré una lata de arvejas, una Pura-cola, y dos Durextra. Me cobraron [VALOR]."
		),
		"productos":
		[Producto.Id.PURA_COLA, Producto.Id.ARVECOR, Producto.Id.DUREXTRA, Producto.Id.DUREXTRA],
		"cuenta": "9046",
	},
	{
		"quien": Conversacion.Interlocutor.FLAVIO_BALBIN,
		"nombre": "Flavio Balbín",
		"texto":
		(
			"hola, estimado, ayer mi señora hizo una compra y me comento que le dieron mal el "
			+ "vuelto. mire le muestro.. Ella compró un fernet god, unos chicles burbaloo, unas "
			+ "papas progres y una cindolor"
		),
		"productos":
		[Producto.Id.FERNET_GOD, Producto.Id.BURBALOO, Producto.Id.PROGRES, Producto.Id.CINDOLOR],
		"cuenta": "3391",
	},
	{
		"quien": Conversacion.Interlocutor.MYRIAM_MELANO,
		"nombre": "Myriam Melano",
		"texto":
		(
			"qué onda, manadaaa, saben que.. la semana pasada me compre un terminator, un "
			+ "actroncito y una caja de marolini. cuando mire el ticket me di cuenta de que me "
			+ "cobraron mal, ¿puede ser?"
		),
		"productos": [Producto.Id.TERMINATOR, Producto.Id.ACTRONCITO, Producto.Id.MAROLINI],
		"cuenta": "7620",
	},
]

var _cobrados: Array[Array] = []
var _respuestas: Array[Respuesta] = []
var _mensajes: Dictionary[int, Array] = {}


## Las quejas de una partida: la semilla y la jornada fijan el sorteo.
static func de_la_partida(semilla: int) -> QuejasDeLaJornada:
	var azar := RandomNumberGenerator.new()
	azar.seed = hash([semilla, JORNADA])
	return sortear(azar)


## Entre `MINIMO_INCORRECTAS` y `MAXIMO_INCORRECTAS` quejas cobran distinto del total; las otras,
## justo el total.
static func sortear(azar: RandomNumberGenerator) -> QuejasDeLaJornada:
	var quejas := QuejasDeLaJornada.new()
	var sin_elegir: Array[int] = []
	for indice in cantidad():
		sin_elegir.append(indice)
	var incorrectas: Array[int] = []
	for _n in azar.randi_range(MINIMO_INCORRECTAS, MAXIMO_INCORRECTAS):
		incorrectas.append(sin_elegir.pop_at(azar.randi_range(0, sin_elegir.size() - 1)))
	for indice in cantidad():
		var productos := productos_de(indice)
		if incorrectas.has(indice):
			productos = _con_reemplazos(productos, azar)
		quejas._cobrados.append(productos)
		quejas._respuestas.append(Respuesta.SIN_RESPONDER)
	return quejas


static func cantidad() -> int:
	return FILAS.size()


static func indice_de(quien: Conversacion.Interlocutor) -> int:
	for indice in cantidad():
		if FILAS[indice]["quien"] == quien:
			return indice
	return -1


static func nombre_de(indice: int) -> String:
	return FILAS[indice]["nombre"]


## Los cuatro dígitos de la cuenta de origen de ese comprador.
static func cuenta_de(indice: int) -> String:
	return FILAS[indice]["cuenta"]


static func productos_de(indice: int) -> Array[Producto.Id]:
	var productos: Array[Producto.Id] = []
	productos.assign(FILAS[indice]["productos"])
	return productos


## Lo que valen los productos de la compra de esa queja, con los precios del catálogo.
static func total_correcto(indice: int) -> int:
	return _total(productos_de(indice))


## El valor con la forma de la captura: `$ 4.200`.
static func formato_del_importe(valor: int) -> String:
	var digitos := str(valor)
	var puntos := ""
	while digitos.length() > 3:
		puntos = "." + digitos.right(3) + puntos
		digitos = digitos.left(-3)
	return "$ " + digitos + puntos


## Un chat por comprador, vacío: sus mensajes salen de las quejas de la noche.
static func conversaciones() -> Array[Conversacion]:
	var chats: Array[Conversacion] = []
	for fila in FILAS:
		var chat := Conversacion.new()
		chat.interlocutor = fila["quien"]
		chat.nombre = fila["nombre"]
		chat.rol = ROL
		chat.jornada_de_menu = JORNADA
		chats.append(chat)
	return chats


## Lo que cobró esa queja.
func cobrado(indice: int) -> int:
	return _total(productos_cobrados(indice))


## Los productos que el comprador dice que le cobraron. Con el valor correcto son los de su compra.
func productos_cobrados(indice: int) -> Array[Producto.Id]:
	var productos: Array[Producto.Id] = []
	if indice >= 0 and indice < _cobrados.size():
		productos.assign(_cobrados[indice])
	return productos


## Si lo cobrado es lo que valen sus productos.
func es_correcto(indice: int) -> bool:
	return cobrado(indice) == total_correcto(indice)


func respuesta_de(indice: int) -> Respuesta:
	if indice < 0 or indice >= _respuestas.size():
		return Respuesta.SIN_RESPONDER
	return _respuestas[indice]


func respondida(indice: int) -> bool:
	return respuesta_de(indice) != Respuesta.SIN_RESPONDER


## Devuelve `true` sólo si la respondió ahora: una queja respondida no se responde otra vez.
func responder(indice: int, da_la_razon: bool) -> bool:
	if indice < 0 or indice >= _respuestas.size() or respondida(indice):
		return false
	_respuestas[indice] = Respuesta.DA_LA_RAZON if da_la_razon else Respuesta.RECHAZA
	_mensajes.erase(indice)
	return true


## Darle la razón a un valor incorrecto, o rechazar uno correcto.
func acerto(indice: int) -> bool:
	if not respondida(indice):
		return false
	return (respuesta_de(indice) == Respuesta.DA_LA_RAZON) != es_correcto(indice)


## Las cinco respondidas, y todas bien.
func cumplida() -> bool:
	for indice in cantidad():
		if not acerto(indice):
			return false
	return true


## El mensaje del comprador y, si ya se respondió, la respuesta del jugador.
func mensajes_de(quien: Conversacion.Interlocutor) -> Array[Mensaje]:
	var indice := indice_de(quien)
	var mensajes: Array[Mensaje] = []
	if indice < 0 or indice >= _cobrados.size():
		return mensajes
	if not _mensajes.has(indice):
		_mensajes[indice] = _armar_los_mensajes(indice)
	mensajes.assign(_mensajes[indice])
	return mensajes


func _armar_los_mensajes(indice: int) -> Array[Mensaje]:
	var importe := formato_del_importe(cobrado(indice))
	var queja := Mensaje.new()
	queja.identidad = IDENTIDAD_DE_LA_QUEJA % (indice + 1)
	queja.jornada = JORNADA
	queja.orden = 0
	queja.de_quien = nombre_de(indice)
	queja.texto = String(FILAS[indice]["texto"]).replace(MARCA_DEL_VALOR, importe)
	queja.foto = load(FOTO) as Texture2D
	queja.importe_de_la_captura = importe
	queja.origen_de_la_captura = cuenta_de(indice)
	var mensajes: Array[Mensaje] = [queja]
	if respondida(indice):
		var respuesta := Mensaje.new()
		respuesta.identidad = IDENTIDAD_DE_LA_RESPUESTA % (indice + 1)
		respuesta.jornada = JORNADA
		respuesta.orden = 1
		respuesta.propio = true
		respuesta.texto = (
			TEXTO_DE_DAR_LA_RAZON
			if respuesta_de(indice) == Respuesta.DA_LA_RAZON
			else TEXTO_DE_RECHAZAR
		)
		mensajes.append(respuesta)
	return mensajes


static func _total(productos: Array[Producto.Id]) -> int:
	var total := 0
	for id in productos:
		total += Catalogo.de(id).precio
	return total


## Uno o dos productos de la compra cambian por otros del catálogo de la noche, hasta que el total
## ya no sea el correcto.
static func _con_reemplazos(
	productos: Array[Producto.Id], azar: RandomNumberGenerator
) -> Array[Producto.Id]:
	var correcto := _total(productos)
	var cambiados := _reemplazar(productos, azar)
	while _total(cambiados) == correcto:
		cambiados = _reemplazar(productos, azar)
	return cambiados


static func _reemplazar(
	productos: Array[Producto.Id], azar: RandomNumberGenerator
) -> Array[Producto.Id]:
	var cambiados: Array[Producto.Id] = productos.duplicate()
	var posiciones: Array[int] = []
	for posicion in cambiados.size():
		posiciones.append(posicion)
	var catalogo := Catalogo.de_la_jornada(JORNADA)
	var cuantos := azar.randi_range(MINIMO_REEMPLAZOS, mini(MAXIMO_REEMPLAZOS, cambiados.size()))
	for _n in cuantos:
		var posicion: int = posiciones.pop_at(azar.randi_range(0, posiciones.size() - 1))
		var otros: Array[Producto.Id] = []
		for producto in catalogo:
			if producto.id != cambiados[posicion]:
				otros.append(producto.id)
		cambiados[posicion] = otros[azar.randi_range(0, otros.size() - 1)]
	return cambiados
