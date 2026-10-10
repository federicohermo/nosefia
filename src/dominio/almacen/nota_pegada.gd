## Lo que dice una nota pegada. Las imágenes del baño las conserva su soporte.
class_name NotaPegada
extends RefCounted

enum Id {
	TAREAS_A_REALIZAR, LOCAL_ORDENADO, JABONES_Y_MANCHAS, INSTRUCCIONES_DE_LIMPIEZA, NO_TIRAR_PAPEL
}

const TAREAS_EN_ORDEN := [
	Tarea.Tipo.CAJA,
	Tarea.Tipo.REGISTRAR,
	Tarea.Tipo.LIMPIAR,
	Tarea.Tipo.REPONER,
	Tarea.Tipo.SACAR_LA_BASURA,
	Tarea.Tipo.ORDENAR_LAS_CAJAS,
]
const NOMBRES_DE_LAS_TAREAS := {
	Tarea.Tipo.CAJA: "Atención al cliente",
	Tarea.Tipo.REGISTRAR: "Registro de productos vendidos",
	Tarea.Tipo.LIMPIAR: "Limpieza",
	Tarea.Tipo.REPONER: "Reposición",
	Tarea.Tipo.SACAR_LA_BASURA: "Sacar la basura",
	Tarea.Tipo.ORDENAR_LAS_CAJAS: "Ordenar cajas en el depósito",
}

var _titulo: String
var _renglones: Array[String]
var _numerada: bool


func _init(titulo_de_la_nota: String, filas: Array[String], es_numerada: bool = false) -> void:
	_titulo = titulo_de_la_nota
	_renglones = filas.duplicate()
	_numerada = es_numerada


static func de(id: Id) -> NotaPegada:
	match id:
		Id.TAREAS_A_REALIZAR:
			return tareas_a_realizar([])
		Id.LOCAL_ORDENADO:
			return (
				NotaPegada
				. new(
					"MANTENER EL LOCAL ORDENADO",
					[
						"No dejar productos tirados.",
						"Dejar las cajas en el depósito.",
						"Dejar los elementos de limpieza en el baño.",
					]
				)
			)
		Id.JABONES_Y_MANCHAS:
			return NotaPegada.new("JABONES Y MANCHAS", [])
		Id.INSTRUCCIONES_DE_LIMPIEZA:
			return NotaPegada.new("INSTRUCCIONES DE LIMPIEZA", [])
		Id.NO_TIRAR_PAPEL:
			return NotaPegada.new("NO TIRAR PAPEL", [])
	return null


static func tareas_a_realizar(obligatorias: Array[Tarea]) -> NotaPegada:
	var filas: Array[String] = []
	for tipo: Tarea.Tipo in TAREAS_EN_ORDEN:
		for tarea in obligatorias:
			if tarea.tipo() == tipo:
				filas.append(NOMBRES_DE_LAS_TAREAS[tipo])
	return NotaPegada.new("TAREAS A REALIZAR", filas, true)


func titulo() -> String:
	return _titulo


func renglones() -> Array[String]:
	return _renglones.duplicate()


func numerada() -> bool:
	return _numerada
