## Abre la noche del almacén con los faltantes que un caso necesita, en vez de los de la jornada.
##
## La noche abre con la góndola llena salvo lo que falta, y colocar pide un casillero vacío. Los
## casos que colocan una unidad le hacen lugar antes: el inventario de `Apertura` con los
## casilleros que mide el puesto, y el puesto redibujado sobre él. **No declara qué casilleros
## abren vacíos**, así que el hueco queda al final de la fila de cada producto, y no donde lo
## sortea la apertura del juego: esa noche la abre `abrir_con_semilla()`.
##
## Sacar no pide lugar: la caja entrega con la fila completa (BR-STK-017). Los casos que sólo
## sacan unidades para usarlas de objeto abren igual con lugar, que es la noche contra la que se
## midieron.
##
## La venta sigue mirando el inventario que armó la jornada: un caso que cobra en la ventanilla
## abre con la de verdad.
extends RefCounted


## El acceso a los productos refrigerados requiere abrir sus hojas físicas.
static func abrir_heladeras(almacen: Node3D) -> void:
	for numero in 2:
		var mueble: String = ["heladeranueva", "heladeranueva_001"][numero]
		var ruta := "Estructura/%s/puerta_heladera_%d/CuerpoDeLaHoja" % [mueble, numero]
		almacen.get_node(ruta).call("alternar")
	for cuadro in 60:
		await almacen.get_tree().physics_frame


## La noche con esos faltantes: cada caja llena, y la góndola completa salvo lo que falta.
static func abrir_con_faltantes(almacen: Node3D, faltantes: Dictionary[Producto.Id, int]) -> void:
	_completar_catalogo(almacen)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var casilleros: Dictionary[Producto.Id, int] = puesto.call("casilleros")
	var inventario := Apertura.inventario_con_faltantes(faltantes, casilleros, Catalogo.todos())
	var repositor: Repositor = almacen.get("_repositor")
	repositor.arrancar(Estante.new(inventario, Catalogo.todos()))
	puesto.call("limpiar")


## La noche con todo el lugar que una caja puede reponer: a cada producto le faltan tantas como
## su caja trae, o su fila entera si es más corta. Es la capacidad que reserva este fixture.
static func abrir_con_todo_el_lugar(almacen: Node3D) -> void:
	_completar_catalogo(almacen)
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var casilleros: Dictionary[Producto.Id, int] = puesto.call("casilleros")
	var faltantes: Dictionary[Producto.Id, int] = {}
	for id: Producto.Id in casilleros:
		faltantes[id] = mini(casilleros[id], ReglasDelEstante.UNIDADES_POR_CAJA)
	abrir_con_faltantes(almacen, faltantes)


## Reabre con una fuente reproducible sin cambiar el cableado compartido de la venta.
static func abrir_con_semilla(
	almacen: Node3D, jornada: int = ReglasDeLaPartida.PRIMERA_JORNADA_COMPLETA, semilla: int = 17
) -> void:
	var azar: RandomNumberGenerator = almacen.get("azar_de_la_apertura")
	azar.seed = semilla
	almacen.call("_al_abrir_la_jornada", jornada)


static func _completar_catalogo(almacen: Node3D) -> void:
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var cupos: Dictionary = puesto.call("casilleros")
	if cupos.values().has(0):
		abrir_con_semilla(almacen)
