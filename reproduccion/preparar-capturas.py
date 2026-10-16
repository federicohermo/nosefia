import hashlib
import json
from pathlib import Path


origen = Path("C:/Users/fede_/AppData/Local/Temp/nosefia-batch-425-435/430")
destino = Path(__file__).parent
huellas = {}
helper = '''

func _burbuja(lista: VBoxContainer, indice: int) -> PanelContainer:
	for hijo: Node in lista.get_children():
		if hijo.has_meta("indice_de_mensaje") and int(hijo.get_meta("indice_de_mensaje")) == indice:
			return hijo as PanelContainer
	return null


func _rotulos(lista: VBoxContainer) -> Array[String]:
	var rotulos: Array[String] = []
	for hijo: Node in lista.get_children():
		if hijo is Label:
			rotulos.append(hijo.text)
	return rotulos
'''
for anterior, nuevo in [
    ("capturar_nativo430.gd", "capturar_nativo431.gd"),
    ("paquete430.gd", "paquete431.gd"),
    ("exportar_paquete430.py", "exportar_paquete431.py"),
    ("servir430.py", "servir431.py"),
]:
    datos = (origen / anterior).read_bytes()
    huellas[anterior] = hashlib.sha256(datos).hexdigest()
    texto = datos.decode("utf-8").replace("\r\n", "\n").replace("430", "431")
    if nuevo.endswith(".gd"):
        texto += helper
        texto = texto.replace("lista.get_child(5).find_children", "_burbuja(lista, 5).find_children")
        texto = texto.replace("lista.get_child(21).find_children", "_burbuja(lista, 21).find_children")
        texto = texto.replace("lista.get_child(caso.x).find_children", "_burbuja(lista, caso.x).find_children")
    if nuevo == "capturar_nativo431.gd":
        texto = texto.replace('await _foto("yasmin-final")', '_exigir(_rotulos(lista) == ["HOY"], "Yasmín no tiene un bloque HOY")\n\tawait _foto("yasmin-final")')
        texto = texto.replace('await _foto("enrique")', '_exigir(_rotulos(lista) == ["AYER", "HOY"], "Enrique no separa J1/J2")\n\tawait _foto("enrique")')
        texto = texto.replace('await _foto("contenedor")', '''await _foto("contenedor")
	var foto_abierta: TextureRect = _pantalla.get("_imagen")
	var textura_anterior := foto_abierta.texture
	var clase_devolucion: Script = load("res://src/dominio/empleo/devolucion_del_jefe.gd")
	var intercalado: Resource = clase_devolucion.call("mensaje", "Llegada anterior intercalada", 1, 99)
	_celular.call("recibir", 0, intercalado)
	await _cuadros()
	_exigir(foto_abierta.texture == textura_anterior, "la llegada reemplazó la foto ampliada")
	_exigir(scroll.scroll_vertical == posicion, "la llegada con foto alteró scroll")
	_exigir(_burbuja(lista, 22).find_children("*", "TextureButton", true, false)[0] == foto, "la llegada reconstruyó la foto")
	await _foto("foto-intercalada")''')
        texto = texto.replace('var informe := FileAccess.open', '''var partida_actual: RefCounted = _local.get("_partida")
	var reloj_actual: Node = _local.get("_reloj")
	var reglas: Script = load("res://src/dominio/reglas.gd")
	var ritmo: Script = load("res://src/dominio/jornada/ritmo.gd")
	reloj_actual.call("avanzar", float(reglas.get_script_constant_map()["DURACION_DEL_TURNO"]) / float(ritmo.get_script_constant_map()["SEGUNDOS_DE_TURNO_POR_SEGUNDO_REAL"]))
	await _cuadros(60)
	_exigir(partida_actual.call("jornada") == 3, "el cierre no dejó J3 pendiente")
	_exigir(_rotulos(lista) == ["AYER", "HOY"], "el cierre de J2 cambió a referencia futura")
	var devolucion: Node = _local.get("_pantalla")
	for _paso: int in 30:
		if devolucion.call("opcion_a_la_vista"):
			break
		devolucion.call("_process", 1.0)
		await _cuadros()
	_exigir(devolucion.call("opcion_a_la_vista"), "faltó Continuar al terminar la devolución")
	await _foto("cierre-jornada-2-hoy")
	partida_actual = null
	var informe := FileAccess.open''')
    if nuevo == "paquete431.gd":
        texto = texto.replace('celular.call("pedir_chat", 3)', 'celular.call("pedir_chat", 3)\n\t_exigir(_rotulos(lista) == ["HOY"], "Yasmín exportada no tiene HOY")')
        texto = texto.replace('celular.call("pedir_chat", 0)', 'celular.call("pedir_chat", 0)\n\t_exigir(_rotulos(lista) == ["AYER", "HOY"], "Enrique exportado no separa J1/J2")')
    if nuevo == "exportar_paquete431.py":
        texto = texto.replace("godot=os.environ['GODOT_BIN']", '''sys.path.insert(0, str(root / '.claude/scripts'))
from lib.godot import resolver
godot, procedencia = resolver(dict(os.environ))
if not godot: raise SystemExit('Godot no declarado')
print('GODOT431', procedencia, godot, flush=True)''')
    (destino / nuevo).write_text(texto, encoding="utf-8")
(destino / "fuentes-capturas.json").write_text(json.dumps({"origen": str(origen), "sha256": huellas, "nota": "Copias adaptadas en scratch propio; originales de430 intactos. Cargar únicamente cabeza431 actual y su paquete nuevo."}, ensure_ascii=False, indent=2), encoding="utf-8")
