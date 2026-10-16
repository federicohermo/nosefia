class_name Expediente
extends RefCounted

signal pista_nueva(pista: Pista)
signal desenlace_alcanzado(desenlace: Desenlace)

enum Resultado { ANOTADA, REPETIDA, DESCONOCIDA }

var _caso: CasoDeInvestigacion
var _consistente: bool = false
var _identidades: PackedStringArray = PackedStringArray()
var _notas: Array[Mensaje] = []
var _avisados: Array[Desenlace] = []


func _init(caso: CasoDeInvestigacion) -> void:
	_caso = caso
	_consistente = caso != null and caso.consistencia() == CasoDeInvestigacion.Consistencia.VALIDO
	_avisados = desenlaces_alcanzados()


func registrar(identidad: String) -> Resultado:
	if not _consistente:
		return Resultado.DESCONOCIDA
	var pista := _caso.pista_de(identidad)
	if pista == null:
		return Resultado.DESCONOCIDA
	if _identidades.has(identidad):
		return Resultado.REPETIDA
	for exigida: String in pista.exigencias:
		if not _identidades.has(exigida):
			return Resultado.DESCONOCIDA
	_identidades.append(identidad)
	_agregar_notas(pista)
	pista_nueva.emit(pista)
	for desenlace: Desenlace in desenlaces_alcanzados():
		if not _avisados.has(desenlace):
			_avisados.append(desenlace)
			desenlace_alcanzado.emit(desenlace)
	return Resultado.ANOTADA


func registrar_por_canal(origen: StringName, canal: Pista.Canal, jornada: int) -> Resultado:
	if not _consistente:
		return Resultado.DESCONOCIDA
	for pista: Pista in _caso.pistas:
		if pista.se_dispara_con(origen, canal, jornada):
			return registrar(pista.identidad)
	return Resultado.DESCONOCIDA


func identidades() -> PackedStringArray:
	return _identidades.duplicate()


func mensajes_de_notas() -> Array[Mensaje]:
	var copia: Array[Mensaje] = []
	for mensaje: Mensaje in _notas:
		copia.append(mensaje.duplicate() as Mensaje)
	return copia


func reconstruir(identidades_conocidas: PackedStringArray, mensajes: Array[Mensaje] = []) -> void:
	if not _consistente:
		return
	_identidades.clear()
	for identidad: String in identidades_conocidas:
		if _caso.pista_de(identidad) != null and not _identidades.has(identidad):
			_identidades.append(identidad)
	var anteriores: Array[Mensaje] = _notas.duplicate()
	anteriores.append_array(mensajes)
	_notas.clear()
	var recibidos := PackedStringArray()
	for mensaje: Mensaje in anteriores:
		if mensaje != null and not recibidos.has(mensaje.identidad) and _es_nota_conocida(mensaje):
			recibidos.append(mensaje.identidad)
			_notas.append(mensaje.duplicate() as Mensaje)
	_avisados = desenlaces_alcanzados()


func hipotesis_para(jornada: int) -> Array[Hipotesis]:
	return _caso.hipotesis_para(jornada, _identidades) if _consistente else []


func desenlaces_alcanzados() -> Array[Desenlace]:
	var alcanzados: Array[Desenlace] = []
	if _consistente:
		for desenlace: Desenlace in _caso.desenlaces:
			if desenlace.alcanzado_por(_identidades):
				alcanzados.append(desenlace)
	return alcanzados


func _agregar_notas(pista: Pista) -> void:
	if pista.foto == null or pista.texto.is_empty():
		return
	for es_foto: bool in [true, false]:
		var mensaje := Mensaje.new()
		mensaje.identidad = _identidad_de_nota(pista.identidad, es_foto)
		mensaje.jornada = pista.jornada
		mensaje.momento = Mensaje.Momento.CIERRE
		mensaje.orden = _notas.size()
		mensaje.foto = pista.foto if es_foto else null
		mensaje.texto = "" if es_foto else pista.texto
		_notas.append(mensaje)


func _es_nota_conocida(mensaje: Mensaje) -> bool:
	for identidad: String in _identidades:
		var pista := _caso.pista_de(identidad)
		if mensaje.jornada != pista.jornada:
			continue
		if mensaje.identidad == _identidad_de_nota(identidad, true):
			return mensaje.foto != null
		if mensaje.identidad == _identidad_de_nota(identidad, false):
			return mensaje.foto == null and mensaje.dice_algo()
	return false


static func _identidad_de_nota(identidad: String, es_foto: bool) -> String:
	return "NOTA_%s_%s" % [identidad, "FOTO" if es_foto else "TEXTO"]
