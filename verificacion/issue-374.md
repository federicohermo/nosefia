<!-- Un issue es un plan chico y descartable: resuelve un problema puntual, con límites y
     criterios propios. Un spec es otra cosa: el contrato durable de una funcionalidad.
     Un issue cambia un spec sólo si cambia lo que el juego tiene que hacer. -->

# Un juego nuevo arranca con las instrucciones de Enrique sobre la persiana baja, y «comenzar» abre la noche 1

## Contexto

**Dependencias:** Depende de #373, #364, #369.

- **Objetivo:** que «nuevo juego» muestre los catorce mensajes introductorios de Enrique, uno a uno, antes de la primera noche, y que «continuar» no pase por ellos.
- **Tipo:** `feature`
- **Spec:** modifica — `specs/employment-record/employment-record.md` y `specs/save-and-resume/save-and-resume.md`
- **Rama:** `feature/374-instrucciones-de-enrique`
- **Diseño:** el frame en [Manada — UI](https://www.figma.com/design/SQEAfczyRvyOHokmzPOee7/Manada---UI?node-id=511-302), `node-id` `511:302` («Chat del jefe incio de jornada 1»). La silueta de Enrique es la capa `511:317`. Diferencias con la ficha, donde manda la ficha: el frame pone «Volver» y «Siguiente» al pie del panel, y la ficha los pone abajo del último mensaje; el frame cuenta «1/12», y los mensajes son catorce. Se conservan la silueta, el nombre, el rol y la nota al pie del frame, que la ficha no contradice.

Depende de #373 («El celular se abre con Q, y los chats pasan de la computadora a él»): el chat de
Enrique, con sus fotos, vive en el celular. Depende del issue de la placa «NOCHE N» y la
persiana (#364): «comenzar» termina en su entrada. Depende de
#369 («La quinta tarea cambia cada noche, y en la primera es ordenar las cajas del depósito»): Intro 13 pide ordenar las cajas del depósito, y su foto muestra las
cajas en el piso que ese issue deja en la jornada 1.

Fuentes: la ficha «Pantalla entre jornadas», sección «Pantalla de inicio de la partida», y la
ficha «Chat con el jefe», tabla «Mensajes introductorios» (Intro 1 a 14). La ficha «Interfaces
virtuales» dice que el chat de Enrique incluye los mensajes de la introducción: los catorce pasos de contenido quedan en el celular desde la noche 1. Son 21 entradas de chat: 14 de texto y 7 de foto. Cada foto es una entrada sin texto inmediatamente anterior al texto de su Intro. Así `Bandeja.adjunto_de()` de #373 encuentra el texto correcto al ampliar, sin mostrar la Intro siguiente.

Hoy «nuevo juego» confirma si hay guardado, lo borra, pasa por la pantalla de carga y entra al
almacén con la noche 1 corriendo (#226, `BR-SAV-012`, `BR-SAV-015`). «Continuar» hace lo mismo
con la jornada guardada.

**El flujo nuevo:** «nuevo juego» funde el menú a negro. La pantalla de carga sigue como hoy. Con
el almacén listo, la persiana baja aparece con un fade in desde negro. Desde el borde inferior
sube la interfaz de instrucciones. Los mensajes se ven uno a uno. «Comenzar» saca la interfaz y
da paso a la entrada de #364: la placa `NOCHE 1`, la persiana sube y empieza el turno. El turno no
corre y el jugador no se mueve hasta entonces.

**Las fotos se capturan del modelo del juego.** Lo hace un generador nuevo,
`assets/models/generar_fotos_del_jefe.gd`, con la forma de `generar_miniaturas.gd`: levanta
`almacen.tscn` en la jornada 1, oculta la interfaz, pone una cámara por foto y guarda un PNG de
960 × 540. La pose de cada cámara es una constante del generador. Para Intro 9 prepara una estantería con cajas sólo en su fixture de captura y restaura las poses de la jornada 1 antes de Intro 13; no cambia la disposición jugable de T1. Antes de guardar, comprueba que
el rayo del centro de la cámara pega en el cuerpo de su tema. Necesita pantalla, como el de las
miniaturas. Las siete fotos y sus temas:

| Mensaje | Tema |
|---|---|
| Intro 4 | la nota de tareas del corcho |
| Intro 6 | la ventanilla |
| Intro 7 | el lector y la caja registradora |
| Intro 8 | la computadora |
| Intro 9 | una estantería del depósito con cajas |
| Intro 11 | los útiles de limpieza y las notas del baño |
| Intro 13 | el depósito con las cajas en el piso, como lo deja la jornada 1 de la quinta tarea |

**Los textos van literales**, con las negritas de la ficha. Se corrigen sólo estas erratas:

- Intro 6: «atende los pedidos  y» pasa a «Atendé los pedidos y»: falta la mayúscula después del punto, la tilde del voseo, y sobra un espacio.
- Intro 7: sobra el espacio final.
- Intro 8: «Bastante simple.z» pasa a «Bastante simple.».
- Intro 12: «instruccciones» pasa a «instrucciones».

No se agregan los signos de apertura que faltan («entendido?», «Estamos?»): es el registro del
chat, y las devoluciones de la misma ficha los omiten igual.

Las fichas no fijaban los tiempos. El usuario decidió el 2026-10-10: fundido a negro del menú
de 0,3 s, fade in de la persiana baja de 0,3 s y subida de la interfaz de instrucciones de
0,3 s, todos reales. `to-spec` cierra las tres preguntas con esta decisión.

**Base para verificar el alcance.** Esta revisión leyó `110206dd30feebd25cfe1fdc2f58db297b975595` en `federicohermo/features-to-issues-notion-2`. La base de implementación se mide después de integrar las dependencias: al abrir su rama y antes del primer cambio, ejecutar `git update-ref refs/nosefia/base-374 HEAD` y guardar el SHA de `git rev-parse refs/nosefia/base-374` en el PR. Ese ref local queda fijo aunque se integren otros cambios. Los comandos de alcance comparan contra ese arranque y no cobran cambios heredados.

La dependencia #364 entrega un test de menú que comprueba la placa tanto para una
partida nueva como para una guardada. Este issue adapta ese fixture: el camino nuevo
recorre las instrucciones y emite «comenzar» antes de comprobar `NOCHE 1`; el camino
guardado comprueba su placa directamente. Conserva `AC-SHF-025`, la jornada correcta
y el control suspendido durante la entrada.

Al compartir los fundidos reales, PersianaDeLaNoche usa una fuente monotónica también
para la entrada de #364. Se adapta además sólo la fuente de tiempo del caso
	est_esc_congela_entrada_y_turno_y_reanudar_continua: inyecta _ahora y avanza
1 250 000 / 250 000 microsegundos en lugar de simular esos intervalos con el delta de
_process. Conserva todas sus comprobaciones de opacidad (0,5 → 0), pausa, posición
y presupuesto del turno, y su cita AC-SHF-026. Los tiempos decididos no cambian.

**Cierre cruzado del contrato compartido.** La auditoría del lote encontró que
`AC-EMP-050`, añadido al contrato previo por la distribución de #369, todavía no tiene
cita: su caso heredado de `partida_test.gd` comprueba sólo el cierre con cuatro cumplidas.
Este issue extiende únicamente ese caso para abrir una jornada 3 real, con cuatro
obligatorias declaradas, y cerrar instancias independientes con 4, 3 y 2 cumplidas:
bandas `NINGUNA`, `AVISO` y `GRAVE`, y sus medios correspondientes en el legajo. Conserva
`AC-SHF-027`, suma `AC-EMP-050` en la declaración del test y no cambia el dominio ni sus
cortes. Así la ratificación de `employment-record` cierra también la regla compartida
del lote, sin atribuirla al flujo de instrucciones.

La verificación completa también adapta el fixture heredado de carga del almacén: sus tres
casos de nuevo juego esperaban la pantalla de carga antes del fundido nuevo. Se modifica sólo
su helper de elegir nuevo juego para inyectar el reloj monotónico, conservar la carga oculta
durante el fundido y completar los 300 000 microsegundos antes de las aserciones existentes.
Conserva los seis casos y todas sus aserciones, incluido doble clic, almacén ya leído y fallo
con reintento; no deja correr cuadros ni cambia el código de producción o los tiempos.

## Criterios de aceptación

- [ ] `to-spec` agrega a `employment-record` una regla: una partida nueva empieza con las instrucciones de Enrique, los catorce mensajes de la ficha en orden, antes de abrir el turno de la jornada 1.
- [ ] Un criterio nuevo de `employment-record`, con su test de dominio: DADO las instrucciones recién abiertas ENTONCES se ve 1 mensaje y no se puede volver. CUANDO se avanza 13 veces ENTONCES se ven 14 y el botón de avanzar dice «comenzar». CUANDO se vuelve ENTONCES se ven 13 y dice «siguiente». CUANDO se avanza desde el mensaje 14 ENTONCES las instrucciones terminan.
- [ ] `to-spec` cambia `BR-SAV-015`: retomar NO DEBE mostrar las instrucciones; abre directo la entrada de la jornada guardada. Un criterio lo verifica en escena: después de `anunciar_la_noche()` la interfaz de instrucciones no está en pantalla.
- [ ] Un criterio nuevo de `employment-record`, con su test de escena: DADO el almacén recién instanciado CUANDO se llama `empezar_partida_nueva()` ENTONCES la persiana está baja, la interfaz muestra Intro 1, «volver» no se ve, el control del jugador está suspendido y el turno no descuenta con los cuadros. CUANDO se llega al mensaje 14 y se elige «comenzar» ENTONCES la interfaz deja la pantalla y la persiana muestra `NOCHE 1`.
- [ ] «Volver» saca el último mensaje a la vista. No aparece con un solo mensaje a la vista, igual que «anterior» en la pantalla de hipótesis de la misma ficha.
- [ ] Los botones van abajo del último mensaje a la vista, y siguen ahí al avanzar y al volver.
- [ ] Los tests de escena miden el fundido del menú a negro en 0,3 s, el fade in de la persiana baja en 0,3 s y la subida de las instrucciones en 0,3 s, todos reales.
- [ ] Cada una de las siete fotos va en una entrada `Mensaje` sin texto inmediatamente seguida del texto de su Intro. Las instrucciones agrupan esa pareja como un único paso, con la foto arriba; avanzar por las 21 entradas requiere 14 pasos. El chat mantiene sus 21 entradas y al ampliar cada foto muestra el texto de esa misma Intro, nunca el de la siguiente. Los casos de agrupación y adjuntos ejercen las siete parejas.
- [ ] En el celular, desde la noche 1, el chat de Enrique empieza con Intro 1 a 14, en ese orden y con sus siete fotos como entradas separadas antes del texto correspondiente (21 entradas en total). Los tres mensajes de prueba de hoy («Che, hoy te toca solo…», «Y no toques la puerta del fondo…», «Cualquier cosa me escribís mañana…») salen del juego.
- [ ] Las siete fotos existen en `assets/ui/manada/fotos/`, salen del generador sin editar, y el PR las adjunta. El padre abre cada PNG y confirma que muestra su tema.
- [ ] El menú conecta «nuevo juego» con la entrada con instrucciones y «continuar» con la entrada directa. Lo afirma un caso de `menu_de_inicio_test.gd`.

## Contrato

- **Dominio** — `src/dominio/empleo/instrucciones_del_jefe.gd`, `class_name InstruccionesDelJefe extends RefCounted`:
  - Clase interna `Paso`: `foto: Mensaje` y `texto: Mensaje`; la foto puede ser `null`.
  - `static func pasos_de(mensajes: Array[Mensaje]) -> Array[Paso]`: agrupa una foto sin texto con el texto sin foto que le sigue; un texto solo forma su propio paso. No altera las entradas ni su orden. Las 21 entradas de las instrucciones forman 14 pasos.
  - `_init(cantidad: int) -> void` — recibe la cantidad de pasos, no la cantidad de entradas del chat.
  - `a_la_vista() -> int` — arranca en 1.
  - `avanzar() -> void` — en el último, termina.
  - `volver() -> bool` — `false` con 1 a la vista, sin cambiar nada.
  - `se_puede_volver() -> bool`
  - `en_el_ultimo() -> bool`
  - `terminadas() -> bool`
- **Datos** — `src/dominio/investigacion/conversacion_con_el_jefe.tres` lleva 21 recursos `Mensaje`: los 14 textos Intro 1 a 14 y las siete fotos sin texto, cada una inmediatamente anterior al texto de su Intro. Usa el formato de #373 sin modificar su contrato de adjunto siguiente.
- **UI** — `src/ui/interrupciones/pantalla_de_instrucciones.gd` y `.tscn`, `class_name PantallaDeInstrucciones extends CanvasLayer`, capa 4, declarada después de `PersianaDeLaNoche` en `interfaz_del_almacen.tscn` para dibujarse encima:
  - `mostrar(mensajes: Array[Mensaje]) -> void` — recibe las 21 entradas, obtiene los 14 pasos de `InstruccionesDelJefe.pasos_de()` y sube desde el borde inferior durante 0,3 s reales. Los botones avanzan o vuelven por pasos.
  - `signal comenzar_pedido` — una vez.
  - Las palabras de los botones viven acá: «siguiente», «volver» y «comenzar».
- **UI** — `PersianaDeLaNoche` suma `mostrar_baja() -> void`: la persiana baja, sin placa, con un fade in desde negro de 0,3 s reales.
- **Escena** — `almacen.gd` suma `empezar_partida_nueva() -> void`: retiene el reloj, suspende al jugador, muestra la persiana baja y la interfaz con los mensajes de Enrique. `comenzar_pedido` llama a `anunciar_la_noche()`.
- **Menú** — `menu_de_inicio.gd` suma `empezar_partida_nueva() -> void`: funde a negro durante 0,3 s reales y entra al almacén con instrucciones. `nuevo_juego_pedido` se conecta acá. `continuar_pedido` sigue en `entrar_al_almacen()`. `_entrar()` llama a `empezar_partida_nueva()` o a `anunciar_la_noche()` del almacén según por dónde se entró. El fundido es un nodo que arma el script, como la capa de la carga: `menu_de_inicio.tscn` no cambia.

## Límites de archivos

| Categoría | Rutas |
|---|---|
| **Se escribe** | `specs/employment-record/employment-record.md` y `specs/save-and-resume/save-and-resume.md` (primer commit); `src/dominio/empleo/instrucciones_del_jefe.gd` y su `.uid` (nuevos); `test/dominio/empleo/instrucciones_del_jefe_test.gd` y su `.uid` (nuevos: contador de pasos, agrupación de las siete parejas y correspondencia de adjuntos); `test/ui/interrupciones/pantalla_de_instrucciones_test.gd` y su `.uid` (nuevos: 21 entradas muestran 14 pasos); `src/dominio/investigacion/conversacion_con_el_jefe.tres`; `src/ui/interrupciones/pantalla_de_instrucciones.gd`, `pantalla_de_instrucciones.tscn` y el `.uid` (nuevos); `src/ui/interrupciones/persiana_de_la_noche.gd`; `src/escenas/puestos/interfaz_del_almacen.tscn` (un nodo `PantallaDeInstrucciones`); `src/escenas/almacen.gd`; `src/escenas/menu_de_inicio.gd`; `test/escenas/menu_de_inicio_test.gd` (10 métodos públicos: entra uno); `test/escenas/entrada_a_la_noche_en_el_almacen_test.gd` (adaptar el fixture del menú a nuevo → instrucciones → comenzar → placa, conservando AC-SHF-025 y el camino directo de continuar; adaptar sólo la fuente de tiempo de test_esc_congela_entrada_y_turno_y_reanudar_continua a _ahora monotónico, conservando todas las aserciones y AC-SHF-026); `test/escenas/instrucciones_en_el_almacen_test.gd` y su `.uid` (nuevos); `assets/models/generar_fotos_del_jefe.gd` y su `.uid` (nuevos); `assets/ui/manada/fotos/` con las siete fotos y sus `.import` (nuevos); `assets/ui/manada/enrique.png` y su `.import` (nuevos, la capa `511:317`); `assets/ui/manada/README.md` |
| **Se escribe: cierre cruzado** | `test/dominio/empleo/partida_test.gd`: sólo extender `test_la_tercera_noche_con_cuatro_cumplidas_cierra_sin_banda` a los tres cierres 4/3/2 de una jornada 3 real y añadir la cita `AC-EMP-050`, conservando `AC-SHF-027`, la comprobación de cuatro obligatorias y las aserciones del caso original. Se puede acortar su nombre para conservar el límite de 100 caracteres con ambas citas. No cambiar ningún otro caso ni código de producción. |
| **Se escribe: fixture de carga** | `test/escenas/carga_del_almacen_test.gd`: sólo adaptar `_elegir_nuevo_juego()` para completar el fundido monotónico real de 0,3 s en el fixture, conservando los seis casos y todas sus aserciones. No simular cuadros ni cambiar el comportamiento de carga. |
| **Sólo lectura** | `src/dominio/investigacion/mensaje.gd`, `conversacion.gd` y `bandeja.gd` (el formato con foto y el adjunto siguiente son de #373); `src/dominio/investigacion/celular.gd`; `src/sistemas/investigacion/celular_del_empleado.gd`; `src/ui/diegetica/pantalla_del_celular.gd` y `pantalla_del_celular.tscn`; `src/dominio/jornada/entrada_a_la_noche.gd`; `src/sistemas/marco/reloj_del_turno.gd`; `src/sistemas/marco/pedidos_del_menu.gd` y `test/sistemas/marco/pedidos_del_menu_test.gd` (las señales no cambian); `src/dominio/empleo/menu_de_inicio.gd`; `src/ui/interrupciones/pantalla_de_carga.gd`; `assets/models/generar_miniaturas.gd`; `test/dominio/investigacion/conversacion_test.gd` (cada mensaje en disco dice algo: los catorce lo cumplen); `test/escenas/notificaciones_en_el_almacen_test.gd` (la capa 4 queda debajo de la pila) |
| **No se toca** | `src/escenas/almacen.tscn`; `src/escenas/menu_de_inicio.tscn`; `src/ui/interrupciones/pantalla_de_carga.tscn`; `src/dominio/empleo/partida.gd` y el guardado; `src/ui/interrupciones/pantalla_de_cierre.gd` y `.tscn`; `project.godot`; el modelo y el horneado |

## Verificación

1. `python .claude/scripts/verificar.py`
2. `Executed test suites: (N/N)` de la salida cruda, con N igual a la cantidad de `*_test.gd`.
3. `! rg -n "hoy te toca solo|no toques la puerta del fondo|no tengo señal" src test` sale con 0.
4. `! rg -n "simple\.z|instruccciones|atende los" src` sale con 0.
5. `"$GODOT_BIN" --path . --rendering-driver opengl3 --script assets/models/generar_fotos_del_jefe.gd -- assets/ui/manada/fotos` sale con 0, con pantalla, y deja las siete fotos.
6. `git diff --quiet refs/nosefia/base-374 -- src/escenas/almacen.tscn src/escenas/menu_de_inicio.tscn project.godot` sale con 0.

## Bordes

- «Volver» con un solo mensaje a la vista no existe; «siguiente» en el 14 dice «comenzar».
- Avanzar y volver varias veces deja el mismo mensaje a la vista que la cuenta: avanzar 3 y volver 3 deja 1.
- Esc durante las instrucciones pausa. «Volver al menú» desde la pausa no guarda nada: «nuevo juego» ya borró el guardado, y «continuar» queda deshabilitado.
- Elegir «comenzar» dos veces no anuncia dos noches.
- «Nuevo juego» sobre un guardado sigue pidiendo confirmación (`BR-SAV-012`). Cancelar no funde a negro.
- Una carga que falla vuelve al menú como hoy, sin quedar en negro.
- El turno no descuenta durante las instrucciones, aunque el jugador tarde minutos en leerlas.
- Instanciar `almacen.tscn` sin el menú no muestra las instrucciones.
- Un rayo de una foto que no pega en su tema hace salir al generador con error, sin escribir ese PNG.



