## Recorre los intervalos de los mensajes; un único cuadro largo no equivale a leerlos.
extends RefCounted


static func entregar(pantalla: PantallaDeDevolucion) -> void:
	centrar_celular(pantalla)
	for _mensaje: int in pantalla.get("_mensajes").size():
		if pantalla.opcion_a_la_vista():
			break
		pantalla.call("_process", DevolucionDelJefe.SEGUNDOS_ENTRE_MENSAJES)


static func centrar_celular(pantalla: PantallaDeDevolucion) -> void:
	var celular: PantallaDelCelular = pantalla.get("_pantalla_del_celular")
	if not celular.centrado():
		terminar_movimiento(pantalla)
	pantalla.call("_process", 0.0)


static func terminar_movimiento(pantalla: PantallaDeDevolucion) -> void:
	var celular: PantallaDelCelular = pantalla.get("_pantalla_del_celular")
	var lectura: Callable = celular.get("_ahora")
	var reloj := [maxi(int(lectura.call()), int(celular.get("_ultimo")))]
	celular.set("_ahora", func() -> int: return reloj[0])
	animar_celular(celular, reloj, int(PantallaDelCelular.RECORRIDO_COMPLETO * 1000000.0) + 25000)
	celular.set("_ahora", lectura)


## El reloj simulado avanza en cuadros normales; los saltos se prueban por separado.
static func animar_celular(pantalla: PantallaDelCelular, reloj: Array, microsegundos: int) -> void:
	var restantes := microsegundos
	while restantes > 0:
		var paso := mini(restantes, 25000)
		reloj[0] += paso
		pantalla.call("_process", 0.0)
		restantes -= paso


## Después de elegir «continuar»: el celular llega a las notas y se pulsa la acción del recuadro
## hasta terminar la reflexión, espera incluida. Lo deja bajando, como sin reflexión.
static func pasar_la_reflexion(pantalla: PantallaDeDevolucion) -> void:
	var almacen := pantalla.get_parent().get_parent()
	var partida: Partida = almacen.get("_partida")
	var reflexion := partida.reflexion
	if reflexion == null:
		return
	terminar_movimiento(pantalla)
	var recuadro: PantallaDeHipotesis = almacen.get("_hipotesis")
	for _gesto: int in ReflexionDeCierre.TEXTOS_DE_LA_PRIMERA.size():
		if reflexion.etapa() in [ReflexionDeCierre.Etapa.TEXTOS, ReflexionDeCierre.Etapa.ELEGIR]:
			recuadro.botones().back().pressed.emit()
	if reflexion.etapa() == ReflexionDeCierre.Etapa.ESPERA:
		almacen.call("_process", ReflexionDeCierre.ESPERA_ANTES_DE_LA_NOCHE)
