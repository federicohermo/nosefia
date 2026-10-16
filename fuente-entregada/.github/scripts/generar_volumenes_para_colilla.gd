## Deriva sólidos de las cinco mallas que admite ahora el agarrable más pequeño.
## Escribe únicamente la propuesta absoluta indicada por el operador.
extends SceneTree

const RUTAS: Array[String] = [
	"board tareas",
	"tableroluz",
	"tachitobasura/tachitobasura-col_bisagra_001/tachitobasura-col_tapa_001",
	"tachitobasura_001/tachitobasura-col_001_bisagra/tachitobasura-col_001_tapa",
	"tachitobasura_002/tachitobasura-col_002_bisagra_001/tachitobasura-col_002_tapa_001"
]


func _initialize() -> void:
	_generar.call_deferred()


func _generar() -> void:
	var argumentos := OS.get_cmdline_user_args()
	if argumentos.size() != 1 or not argumentos[0].is_absolute_path():
		push_error("Indicar una salida JSON absoluta fuera del repositorio.")
		quit(2)
		return
	var destino := argumentos[0].replace("\\", "/").simplify_path().to_lower()
	var repositorio := ProjectSettings.globalize_path("res://").simplify_path().to_lower()
	if destino.begins_with(repositorio):
		push_error("La propuesta debe quedar fuera del repositorio.")
		quit(2)
		return
	var escena := load("res://src/escenas/puestos/estructura_del_almacen.tscn") as PackedScene
	var estructura := escena.instantiate() as Node3D
	var resultado: Dictionary = {}
	for ruta: String in RUTAS:
		var malla := estructura.get_node(ruta) as MeshInstance3D
		var formas: Array[Array] = []
		for puntos: PackedVector3Array in _formas(malla):
			var datos: Array[Array] = []
			for punto: Vector3 in puntos:
				datos.append([punto.x, punto.y, punto.z])
			formas.append(datos)
		resultado[ruta] = formas
	var archivo := FileAccess.open(argumentos[0], FileAccess.WRITE)
	archivo.store_string(JSON.stringify(resultado, "\t"))
	archivo.close()
	estructura.free()
	_salir.call_deferred()


func _salir() -> void:
	quit()


static func _formas(malla: MeshInstance3D) -> Array[PackedVector3Array]:
	var salida: Array[PackedVector3Array] = []
	for pieza: PackedVector3Array in _piezas(malla.mesh.get_faces()):
		var puntos := PackedVector3Array()
		for punto: Vector3 in pieza:
			if not puntos.has(punto):
				puntos.append(punto)
		if str(malla.name) == "tableroluz":
			salida.append_array(_paredes(puntos))
		else:
			salida.append(puntos)
	return salida


static func _piezas(caras: PackedVector3Array) -> Array[PackedVector3Array]:
	var grupos: Array[PackedVector3Array] = []
	for indice: int in range(0, caras.size(), 3):
		var pieza := PackedVector3Array([caras[indice], caras[indice + 1], caras[indice + 2]])
		var unir: Array[int] = []
		for grupo: int in grupos.size():
			for punto: Vector3 in pieza:
				if grupos[grupo].has(punto):
					unir.append(grupo)
					break
		unir.reverse()
		for grupo: int in unir:
			pieza.append_array(grupos[grupo])
			grupos.remove_at(grupo)
		grupos.append(pieza)
	return grupos


## Cada caja hueca tiene cuatro anillos: fondo y boca, por dentro y por fuera.
## Cinco convexos conservan sus cuatro paredes y fondo sin rellenar el hueco.
static func _paredes(puntos: PackedVector3Array) -> Array[PackedVector3Array]:
	var eje := -1
	var niveles: Array[float] = []
	for candidato: int in 3:
		var actuales: Array[float] = []
		for punto: Vector3 in puntos:
			var valor := snappedf(punto[candidato], 0.00001)
			if not actuales.has(valor):
				actuales.append(valor)
		if actuales.size() == 3:
			eje = candidato
			niveles = actuales
			break
	assert(eje >= 0 and puntos.size() == 16, "Cambió la topología del tablero; medir nuevamente.")
	var anillos: Array[PackedVector3Array] = []
	var frente := PackedVector3Array()
	for nivel: float in niveles:
		var anillo := PackedVector3Array()
		for punto: Vector3 in puntos:
			if absf(punto[eje] - nivel) < 0.00001:
				anillo.append(punto)
		if anillo.size() == 8:
			frente = anillo
		else:
			anillos.append(anillo)
	assert(frente.size() == 8 and anillos.size() == 2)
	if absf(anillos[0][0][eje] - frente[0][eje]) < absf(anillos[1][0][eje] - frente[0][eje]):
		anillos.reverse()
	var centro := Vector3.ZERO
	for punto: Vector3 in frente:
		centro += punto / 8.0
	var ordenados: Array[Vector3] = []
	ordenados.assign(frente)
	ordenados.sort_custom(
		func(a: Vector3, b: Vector3) -> bool:
			return a.distance_squared_to(centro) < b.distance_squared_to(centro)
	)
	anillos.append(PackedVector3Array(ordenados.slice(0, 4)))
	anillos.append(PackedVector3Array(ordenados.slice(4, 8)))
	var u := (eje + 1) % 3
	var v := (eje + 2) % 3
	for indice: int in anillos.size():
		var orden: Array[Vector3] = []
		orden.assign(anillos[indice])
		orden.sort_custom(
			func(a: Vector3, b: Vector3) -> bool:
				return (
					atan2(a[v] - centro[v], a[u] - centro[u])
					< atan2(b[v] - centro[v], b[u] - centro[u])
				)
		)
		anillos[indice] = PackedVector3Array(orden)
	var base := anillos[0].duplicate()
	base.append_array(anillos[1])
	var salida: Array[PackedVector3Array] = [base]
	for lado: int in 4:
		var pared := PackedVector3Array()
		for anillo: PackedVector3Array in anillos:
			pared.append(anillo[lado])
			pared.append(anillo[(lado + 1) % 4])
		salida.append(pared)
	return salida
