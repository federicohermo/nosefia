## La caja del depósito de un producto, como la ve la noche: cuántas unidades tiene, qué hace el
## clic sobre ella y qué dice al examinarla.
##
## **No lleva un número propio, y es la decisión.** Lo que tiene la caja es el depósito de su
## producto menos lo que salió de ella y todavía no se colocó, y las dos cosas ya las cuenta el
## inventario, que el estante le pregunta. Un contador acá diría otra cosa apenas la ventanilla
## vendiera una unidad, que sale del mismo depósito, y ningún error lo avisaría.
##
## **Por eso se arma en cada pregunta y no se guarda en la caja del local.** Cada jornada abre
## con un estante nuevo, y una guardada seguiría contestando por el estante de la noche en que se
## armó.
##
## Qué hace el clic, qué entra y qué dice el texto se decide acá, donde tiene test. La escena sólo
## busca la acción del gesto que esto contesta.
class_name ContenidoDeLaCaja
extends RefCounted

## Lo que hace el clic sobre la caja según lo que haya en la mano. La ficha nombra dos gestos, y
## para cualquier otra cosa en la mano no inventa un efecto: por eso existe `NADA`.
enum Gesto { SACAR, METER, NADA }


## Los datos que cambian al examinar una caja, separados de las palabras que los presentan.
class DatosDelExamen:
	var producto: Producto.Id
	var unidades: int
	var entran: int
	var familia: EntradaSonora.Sonoridad

	func _init(un_producto: Producto, cuantas: int) -> void:
		producto = un_producto.id
		unidades = cuantas
		entran = ReglasDelEstante.UNIDADES_POR_CAJA - cuantas
		familia = Catalogo.sonoridad_de(producto)


## El texto al examinar la caja: cuántas tiene, cómo se llaman y de qué producto. Lo que entra va
## en otra frase porque con la caja llena no se dice, y porque una sola unidad va en singular.
const TEXTO_DEL_EXAMEN := "Una caja con %d %s de %s."
const TEXTO_DE_UNA_MAS := " Entra %d más."
const TEXTO_DE_VARIAS_MAS := " Entran %d más."

## Cómo se nombra la unidad en el texto, en singular y en plural, según la familia sonora de su
## producto.
##
## **Sale de la familia sonora y no de lo que el producto es.** Actroncito es una caja de
## medicamentos y Malbardo un paquete de cigarrillos, y la ficha cuenta a los dos en cajitas. Una
## caja se cuenta en cartones y no en cajas: el texto diría «una caja con 8 cajas».
##
## **No hay una palabra de repuesto.** Una familia sin fila deja el texto sin palabra, y el caso
## que recorre el catálogo nombra el producto y la familia que la necesitan.
const NOMBRES_DE_LA_UNIDAD := {
	EntradaSonora.Sonoridad.CAJITA: ["cajita", "cajitas"],
	EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO: ["paquete", "paquetes"],
	EntradaSonora.Sonoridad.LATA: ["lata", "latas"],
	EntradaSonora.Sonoridad.CAJA: ["cartón", "cartones"],
	EntradaSonora.Sonoridad.BOTELLA_PLASTICA: ["botella", "botellas"],
	EntradaSonora.Sonoridad.BOTELLA_VIDRIO: ["botella", "botellas"],
	EntradaSonora.Sonoridad.CAJA_CEREALES: ["cajita", "cajitas"],
}

## El producto que trae, que es el de su etiqueta salvo en la última noche (BR-ANO-004).
var producto: Producto

## El estante de la noche: el que cuenta el depósito y lo que salió de cada caja.
var _estante: Estante


func _init(la_etiqueta: Producto, un_estante: Estante) -> void:
	_estante = un_estante
	producto = la_etiqueta
	if la_etiqueta != null and _estante.contenidos.has(la_etiqueta.id):
		producto = Catalogo.de(_estante.contenidos[la_etiqueta.id])


## Cuántas unidades tiene: el depósito de su producto menos las que salieron y no se colocaron.
##
## Una unidad colocada ya había salido, así que colocarla no le cambia nada. Una vendida sale del
## depósito, así que le resta una.
func unidades() -> int:
	return maxi(0, _estante.unidades_en_deposito(producto) - _estante.reservadas(producto))


## Saca una unidad para la mano, o devuelve `null` si no la da.
##
## Vacía no da nada aunque la góndola tenga lugar, y con unidades da una aunque la góndola esté
## llena (BR-STK-017). La que sale la anota afuera el estante.
func sacar() -> UnidadDeProducto:
	if unidades() <= 0:
		return null
	return _estante.retirar(producto)


## Mete de vuelta una unidad que salió de ella, y devuelve si entró.
##
## El tope es el de las reglas del estante y no otro: la caja no pasa nunca de lo que trae al
## abrir la noche. Lo que no entra no cambia nada, y la unidad sigue donde estaba.
func meter(unidad: UnidadDeProducto) -> bool:
	if not _puede_volver(unidad) or unidades() >= ReglasDelEstante.UNIDADES_POR_CAJA:
		return false
	return _estante.devolver(unidad)


## El secundario saca con mano vacía; el primario devuelve una unidad coincidente.
##
## Cualquier otra cosa incluye otra caja. Todas las cajas comparten el mismo objeto, y llevar una
## es lo que impide sacarle a la que se lleva.
func uso(sostenido: ObjetoDelAlmacen, primario: bool) -> Gesto:
	if not primario and sostenido == null:
		return Gesto.SACAR
	if primario and _puede_volver(sostenido as UnidadDeProducto):
		return Gesto.METER
	return Gesto.NADA


## Qué haría el gesto sobre la caja, sin hacerlo: como `uso()`, pero sin nada que sacar no saca, y
## llena no mete. Lo pregunta la referencia de controles, y no cambia nada.
func gesto_posible(sostenido: ObjetoDelAlmacen, primario: bool) -> Gesto:
	var gesto := uso(sostenido, primario)
	if gesto == Gesto.SACAR and unidades() <= 0:
		return Gesto.NADA
	if gesto == Gesto.METER and unidades() >= ReglasDelEstante.UNIDADES_POR_CAJA:
		return Gesto.NADA
	return gesto


func datos_del_examen() -> DatosDelExamen:
	return DatosDelExamen.new(producto, unidades()) if producto != null else null


## Lo que dice la caja al examinarla: cuántas tiene y, si no está llena, cuántas le entran.
##
## No dice la pista de la caja. Esa se registra en la investigación, y el texto dice sólo la
## cuenta.
func texto_del_examen() -> String:
	var datos := datos_del_examen()
	if datos == null:
		return ""
	var nombres: Array = NOMBRES_DE_LA_UNIDAD.get(datos.familia, ["", ""])
	var nombre: String = nombres[0] if datos.unidades == 1 else nombres[1]
	var texto := TEXTO_DEL_EXAMEN % [datos.unidades, nombre, producto.nombre]
	if datos.entran == 1:
		texto += TEXTO_DE_UNA_MAS % datos.entran
	elif datos.entran > 1:
		texto += TEXTO_DE_VARIAS_MAS % datos.entran
	return texto


## Si la caja la recibiría: es de su producto y no está vencida, porque una vencida que vuelve a
## la caja saldría después como sana (BR-STK-052).
func _puede_volver(unidad: UnidadDeProducto) -> bool:
	return _es_de_su_producto(unidad) and not unidad.vencido


## Si la unidad es de su producto. Compara por `id` y no por instancia: el catálogo arma un
## producto nuevo en cada llamada.
func _es_de_su_producto(unidad: UnidadDeProducto) -> bool:
	return (
		unidad != null
		and unidad.producto != null
		and producto != null
		and unidad.producto.id == producto.id
	)
