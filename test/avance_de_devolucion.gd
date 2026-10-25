## Recorre los intervalos de los mensajes; un único cuadro largo no equivale a leerlos.
extends RefCounted


static func entregar(pantalla: PantallaDeDevolucion) -> void:
	centrar_celular(pantalla)
	for _mensaje: int in pantalla.get("_mensajes").size():
		if pantalla.opcion_a_la_vista():
			break
		pantalla.call("_process", DevolucionDelJefe.SEGUNDOS_ENTRE_MENSAJES)


static func centrar_celular(pantalla: PantallaDeDevolucion) -> void:
	esperar_el_celular(pantalla)
	var celular: PantallaDelCelular = pantalla.get("_pantalla_del_celular")
	if not celular.centrado():
		terminar_movimiento(pantalla)
	pantalla.call("_process", 0.0)


static func terminar_movimiento(pantalla: PantallaDeDevolucion) -> void:
	esperar_el_celular(pantalla)
	var celular: PantallaDelCelular = pantalla.get("_pantalla_del_celular")
	var lectura: Callable = celular.get("_ahora")
	var reloj := [maxi(int(lectura.call()), int(celular.get("_ultimo")))]
	celular.set("_ahora", func() -> int: return reloj[0])
	animar_celular(celular, reloj, int(PantallaDelCelular.RECORRIDO_COMPLETO * 1000000.0) + 25000)
	celular.set("_ahora", lectura)


## El celular sube dos segundos después de que la persiana termina de bajar: se termina la bajada,
## si sigue en curso, y se cuentan los dos segundos. Con el celular ya arriba, no hace nada.
static func esperar_el_celular(pantalla: PantallaDeDevolucion) -> void:
	if pantalla.visible:
		return
	var almacen := pantalla.get_parent().get_parent()
	var persiana: PersianaDeLaNoche = almacen.get_node("Interfaz/PersianaDeLaNoche")
	var subira := pantalla.devolucion_despachada.is_connected(
		Callable(almacen, "_al_despachar_la_devolucion")
	)
	if subira and persiana.get("_bajando"):
		terminar_la_bajada(persiana)
	if almacen.get("_devolucion_en_espera") != null:
		almacen.call("_process", DevolucionDelJefe.SEGUNDOS_DE_ESPERA_DEL_CELULAR)


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


## La persiana del cierre baja con su propio reloj: uno simulado la termina sin esperar.
static func terminar_la_bajada(persiana: PersianaDeLaNoche) -> void:
	var lectura: Callable = persiana.get("_ahora")
	var ahora := [int(persiana.get("_ultimo"))]
	persiana.set("_ahora", func() -> int: return ahora[0])
	ahora[0] += int(EntradaALaNoche.SUBIDA_DE_LA_PERSIANA * 1000000.0) + 1000
	persiana.call("_process", 0.0)
	persiana.set("_ahora", lectura)


## Una jornada con instrucciones abre con ellas: se leen hasta su «OK», que anuncia la noche.
static func leer_las_instrucciones(almacen: Node) -> void:
	var instrucciones: PantallaDeInstrucciones = almacen.get_node(
		"Interfaz/PantallaDeInstrucciones"
	)
	var siguiente: Button = instrucciones.get("_siguiente")
	if not instrucciones.visible:
		return
	while not (instrucciones.get("_instrucciones") as InstruccionesDelJefe).terminadas():
		siguiente.pressed.emit()
	terminar_instrucciones(instrucciones)


static func terminar_instrucciones(pantalla: PantallaDeInstrucciones) -> void:
	var lectura: Callable = pantalla.get("_ahora")
	var reloj: Array[int] = [int(lectura.call())]
	pantalla.set("_ahora", func() -> int: return reloj[0])
	for _cuadro in 30:
		if not pantalla.is_processing():
			break
		reloj[0] += 10000
		pantalla._process(0.0)
	pantalla.set("_ahora", lectura)
	pantalla.set("_ultimo", int(lectura.call()))


## La noche siguiente abre cuando termina la transición, que puede calentar útiles durante varios
## cuadros. Se espera la apertura, con un límite, en lugar de un cuadro.
static func esperar_la_noche_siguiente(almacen: Node, cuadros: int = 1200) -> bool:
	var partida: Partida = almacen.get("_partida")
	for _cuadro: int in cuadros:
		if partida.get("_jornada_abierta"):
			return true
		await almacen.get_tree().process_frame
	return partida.get("_jornada_abierta")
