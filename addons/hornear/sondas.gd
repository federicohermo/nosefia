## Rellena las sondas de afuera del local con la luz de sus vecinas de adentro.
##
## **El horneador reparte las sondas por los bordes de las mallas**, y buena parte cae adentro de
## una pared, del techo o de un mueble, o afuera: abajo del piso, arriba del techo. Un objeto que
## toma la luz de las sondas —los productos, las cajas— la interpola entre las cuatro del
## tetraedro que lo contiene, y ese tetraedro cruza la pared. Adentro de una pared la sonda sale
## negra y apaga lo que está cerca. Afuera ve el cielo del horneado: en la noche del corte,
## abajo del piso valía lo mismo que al lado del ventanal, y alumbraba todo lo que está cerca del
## piso.
##
## Por eso cada sonda que no está adentro de un ambiente se reescribe con el promedio, pesado por
## cercanía, de sus vecinas de adentro. Una sonda de adentro no se toca aunque esté negra: es la
## luz de un ambiente oscuro, y rellenarla traía la de otro a través de la pared. El relleno no
## toca la malla de tétrades.
extends RefCounted

const VECINAS := 6
const ALCANCE := 2.5
const COEFICIENTES := 9


## Qué cierra los ambientes del local: las mallas del modelo, vistas desde el horneado.
class Cascara:
	const DIRECCIONES: Array[Vector3] = [
		Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK
	]

	var _malla := TriangleMesh.new()
	var _caras := PackedVector3Array()
	var _de_dos_lados := PackedByteArray()

	## `marco` lleva del mundo al espacio de las sondas.
	func _init(raiz: Node, marco: Transform3D) -> void:
		for nodo: Node in raiz.find_children("*", "MeshInstance3D", true, false):
			var malla := nodo as MeshInstance3D
			if malla.mesh == null or not malla.is_visible_in_tree():
				continue
			var al_horno := marco * malla.global_transform
			var propias := malla.mesh.get_faces()
			for vertice in propias:
				_caras.append(al_horno * vertice)
			var de_dos_lados := malla.gi_mode != GeometryInstance3D.GI_MODE_STATIC
			@warning_ignore("integer_division")
			for cara in propias.size() / 3:
				_de_dos_lados.append(1 if de_dos_lados else 0)
		_malla.create_from_faces(_caras)

	## Adentro de un ambiente, lo primero que se ve hacia cualquier lado es el frente de una
	## superficie horneada. Abajo del piso, un rayo se escapa; adentro de una pared, choca contra
	## una cara de espaldas. Un vidrio o una hoja que abre no se hornean y cierran de los dos lados.
	func encierra(punto: Vector3) -> bool:
		for direccion in DIRECCIONES:
			var choque := _malla.intersect_ray(punto, direccion)
			if choque.is_empty():
				return false
			var cara: int = choque.face_index
			if _de_dos_lados[cara] == 1:
				continue
			# El choque da la normal vuelta hacia el rayo: el frente sale del orden de la cara.
			var frente := Plane(_caras[cara * 3], _caras[cara * 3 + 1], _caras[cara * 3 + 2])
			if frente.normal.dot(direccion) > 0.0:
				return false
		return true


static func rellenar(datos: LightmapGIData, cascara: Cascara) -> Dictionary:
	var sondas: Dictionary = datos.get("probe_data")
	var puntos: PackedVector3Array = sondas["points"]
	var adentro: Array[bool] = []
	for punto in puntos:
		adentro.append(cascara.encierra(punto))
	var resultado := rellenar_coeficientes(puntos, sondas["sh"], adentro)
	sondas["sh"] = resultado["sh"]
	datos.set("probe_data", sondas)
	return {"total": puntos.size(), "rellenadas": resultado["rellenadas"]}


## Se repite mientras quede una sonda de afuera con una vecina con luz que darle: una rellenada
## en una pasada es vecina en la siguiente. Aplicarlo sobre un horneado ya rellenado da lo mismo.
static func rellenar_coeficientes(
	puntos: PackedVector3Array, sh: PackedColorArray, adentro: Array[bool]
) -> Dictionary:
	var nuevo := sh.duplicate()
	var con_luz: Array[int] = []
	var afuera: Array[int] = []
	for i in puntos.size():
		if adentro[i]:
			con_luz.append(i)
		else:
			afuera.append(i)
	var rellenadas := 0
	while true:
		var pasada := _una_pasada(puntos, nuevo, con_luz, afuera)
		if pasada.is_empty():
			break
		rellenadas += pasada.size()
		con_luz.append_array(pasada)
		var quedan: Array[int] = []
		for i in afuera:
			if not pasada.has(i):
				quedan.append(i)
		afuera = quedan
	return {"sh": nuevo, "rellenadas": rellenadas}


static func _una_pasada(
	puntos: PackedVector3Array, sh: PackedColorArray, con_luz: Array[int], afuera: Array[int]
) -> Array[int]:
	var nuevos := {}
	for i in afuera:
		var vecinas := _vecinas(puntos, con_luz, puntos[i])
		if vecinas.is_empty():
			continue
		var peso_total := 0.0
		var suma: Array[Color] = []
		suma.resize(COEFICIENTES)
		suma.fill(Color(0, 0, 0, 0))
		for vecina in vecinas:
			var peso: float = 1.0 / maxf(vecina[0], 0.1)
			peso_total += peso
			for k in COEFICIENTES:
				suma[k] += sh[vecina[1] * COEFICIENTES + k] * peso
		for k in COEFICIENTES:
			suma[k] /= peso_total
		nuevos[i] = suma
	# Se escriben al final: una sonda rellenada en esta pasada no presta luz hasta la siguiente.
	var rellenadas: Array[int] = []
	for i: int in nuevos:
		for k in COEFICIENTES:
			sh[i * COEFICIENTES + k] = nuevos[i][k]
		rellenadas.append(i)
	return rellenadas


static func _vecinas(puntos: PackedVector3Array, con_luz: Array[int], desde: Vector3) -> Array:
	var cerca := []
	for j in con_luz:
		var distancia := puntos[j].distance_to(desde)
		if distancia <= ALCANCE:
			cerca.append([distancia, j])
	cerca.sort()
	return cerca.slice(0, VECINAS)
