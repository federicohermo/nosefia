## Abre la noche del almacén con los faltantes que un caso necesita, en vez de los de la jornada.
##
## La noche abre con la góndola llena salvo lo que falta, y colocar pide un casillero vacío. Los
## casos que colocan una unidad le hacen lugar antes, con la misma apertura que el juego: el
## inventario de `Apertura` con los casilleros que mide el puesto, y el puesto redibujado sobre
## él. No es un atajo por dentro del dominio: es otra noche, con otros datos.
##
## Sacar no pide lugar: la caja entrega con la fila completa (BR-STK-017). Los casos que sólo
## sacan unidades para usarlas de objeto abren igual con lugar, que es la noche contra la que se
## midieron.
##
## La venta sigue mirando el inventario que armó la jornada: un caso que cobra en la ventanilla
## abre con la de verdad.
extends RefCounted


## La noche con esos faltantes: cada caja llena, y la góndola completa salvo lo que falta.
static func abrir_con_faltantes(almacen: Node3D, faltantes: Dictionary[Producto.Id, int]) -> void:
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var casilleros: Dictionary[Producto.Id, int] = puesto.call("casilleros")
	var inventario := Apertura.inventario_con_faltantes(faltantes, casilleros)
	var repositor: Repositor = almacen.get("_repositor")
	repositor.arrancar(Estante.new(inventario, Catalogo.todos()))
	puesto.call("limpiar")


## La noche con todo el lugar que una caja puede reponer: a cada producto le faltan tantas como
## su caja trae, o su fila entera si es más corta. Es lo más que el juego deja faltar.
static func abrir_con_todo_el_lugar(almacen: Node3D) -> void:
	var puesto: Node3D = almacen.get("_reposicion_manual")
	var casilleros: Dictionary[Producto.Id, int] = puesto.call("casilleros")
	var faltantes: Dictionary[Producto.Id, int] = {}
	for id: Producto.Id in casilleros:
		faltantes[id] = mini(casilleros[id], ReglasDelEstante.UNIDADES_POR_CAJA)
	abrir_con_faltantes(almacen, faltantes)
