# Al cerrar la noche, el desorden y lo que quedó afuera suman medio apercibimiento por motivo

## Contexto

- **Objetivo:** registrar llamados únicos por noche, conservar fracciones de medio apercibimiento en el legajo y anotar al cierre el desorden o un objeto que quedó afuera.
- **Tipo:** `feature`.
- **Spec:** modifica `employment-record` y `store-cleanup`; documenta representación del guardado según BR-SAV-006, sin cambiar política de checkpoint.
- **Rama:** `feature/306-llamados-de-atencion`.
- **Base y dependencias:** `11301e9df6fd2510b4fa2ff1c0fd6db9d25fe963`, cabeza certificada de #305 (PR355, FULL2 7/7 en 718,8 s, 208/208 suites, 1629 casos); hereda #295 (NINGUNA conserva deuda), #300 (estado actual de registrar), #297 (guard LEFT suspendido), #302/#304 (tickets), #309 y el arte nuevo del almacén. Escenas se editan en serie sobre esa cabeza, sin merge de tres vías.

Sale de las fichas verdes [Llamados de atención extras](https://app.notion.com/p/3e486efecd9d80078230fe988b0290d2) y [Ciclo de jornadas y sistema de puntos](https://app.notion.com/p/3cc86efecd9d81b2861ee59ab2fa4f2d). Cada motivo suma 0,5 al cierre, con cualquier banda; el corte sigue siendo 4 y el número permanece invisible. Lo declarado en las fichas decide los pesos.

La escena cambió desde la medición histórica `78f3faa2`. No valen sus habitaciones, alturas, origen de mopa ni posición de ventana. `exterior_del_almacen.gd` ya construye seis superficies de pavimento y la vereda; hoy esos Pavimento sólo tienen malla. Este issue agrega soporte físico a esas superficies existentes, conservando dibujo, shaders, ubicación y modelo; no duplica un piso dibujado. La altura medida del pavimento es -0,01776253 frente a superficie interior alrededor de 0,102237; no se fuerza al exterior a la altura del interior.

Los nombres históricos SueloSolido/Deposito y /Fondo no identifican por sí solos las habitaciones actuales. La medición nativa sobre 11301e9d leyó 242 cajas de colisión (25 deshabilitadas), 58 polígonos convexos, 31 cajas de productos, 5 útiles, 3 bolsas, pisos, techos, pasos y hueco. Se compusieron transforms locales de ancestros sin montar la escena; ambas sondas salieron 0, sin diagnósticos. El lector queda con transform identidad en Estructura. Los nombres históricos se usan sólo para localizar evidencia, no como contrato. La declaración normativa exige pertenencia funcional; las coordenadas quedan como evidencia de esa cabeza, no como valores decorativos de tests.

**Fuera de este issue:** papel al inodoro (#307), motivo del contenedor (#308), voz/chat del jefe y particulares de jornadas todavía 🟨 (producto sustituto J2 y vencidos J3). Las bolsas y los jabones ordinarios existentes conservan sus tipos actuales.

## Criterios de aceptación

- [ ] `to-spec` agrega BR-EMP-012 y AC-EMP-017–022, y BR-CLN-027–029 con AC-CLN-040–046. Se conservan los huecos de IDs retirados.
- [ ] `employment-record` declara que el cierre suma el peso de la banda y 0,5 por motivo distinto de esa noche, incluso con NINGUNA; la deuda previa se conserva.
- [ ] Un motivo repetido suma una vez. Distintos motivos se acumulan. Antes de abrir, después de cerrar y en partida terminada, anotar se ignora. La apertura siguiente vacía motivos pendientes.
- [ ] BR-EMP-003 compara el tope con medios: 7 medios no despide, 8 sí. BR-EMP-008 restaura exactamente medios. BR-EMP-009 elige comentario por lectura entera:7 medios dice lo mismo que6; no se muestra un contador nuevo.
- [ ] AC-EMP-017–022 cubren: limpio+impecable+un motivo=1 medio; dos motivos=2 medios; mismo repetido=1 medio; deuda 6+1=7sin despido; deuda 7+1=8con despido; restaurado7+impecable0conserva7; quinta impecablecon7sin motivo cumplecontrato; anotación durante placa no entra en noche siguiente; comentario7igual6.
- [ ] `store-cleanup` declara local, depósito y baño, y AFUERA si el punto no pertenece a ninguna. Cada habitación es una unión finita de volúmenes locales, desde el piso hasta su techo real, sin solaparse con otra habitación; cada paso estrecho pertenece a su habitación de destino. No se usa una envolvente que cubra el hueco junto a un paso o encima de un techo más bajo. La posición del cuerpo decide pertenencia.
- [ ] Desorden se anota si hay una unidad suelta en cualquiera de las tres habitaciones, una caja adentro fuera del depósito o un útil adentro fuera del baño. Mano y afuera se excluyen. Bolsas/tickets adentro no disparan desorden.
- [ ] Afuera se anota si hay al menos un objeto levantable fuera de las tres habitaciones al cierre. Mano y lo ya desechado se excluyen. Dos objetos afuera producen un motivo.
- [ ] AC-CLN-040–046 cubren estado inicial sin llamados; unidad suelta en local/depósito/baño; caja en local frente a depósito y paso; mopa en local frente a baño y paso; unidad colocada/devuelta excluida; caja/unidad/útil en mano excluidos; bolsa adentro sin desorden y afuera con motivo; examinado cuenta en posición del cuerpo; descarte excluye y apertura restaura lista.
- [ ] Dos cajas con el MISMO Resource de datos siguen siendo cuerpos distintos: sostener una excluye sólo esa, y la otra desordenada o afuera sigue generando su motivo. El getter público de Agarre conserva identidad al mover/devolver y devuelve null tras soltar/entregar/vaciar. Examen.iniciar real hace contar ese mismo cuerpo por su posición, aunque Agarre conserve su referencia; al terminar el examen vuelve la exclusión de mano.
- [ ] Una unidad apoyada sobre una caja/góndola sigue siendo suelta hasta colocarla/devolverla. El lector de sueltas no pierde las unidades cuya malla individual está oculta por agrupamiento ni incluye cuerpo de repuesto.
- [ ] Un objeto que se soltó por el hueco real de ventanilla se apoya físicamente sobre el pavimento existente y permanece en el mundo. Puede recogerse si está dentro del alcance vigente. Las pruebas derivan dos soltadas por ambos laterales físicamente libres del hueco, a partir del vidrio, las jambas y la forma real del objeto; afirman su premisa y verifican apoyo estable. No existe un paso superior: vidrio entre1,04y2,44m y dintel compuesto desde≈2,440001m dejan sólo holgura numérica. Se retira el tercer caso arriba del vidrio, sin sustituirlo por un tiro sobre el techo ni un punto artificial. No fijan distancias decorativas ni introducen un piso duplicado. El soporte exterior no habilita una soltada al otro lado de una pared: al buscar un apoyo cercano, se descartan los candidatos cuyo recorrido desde el centro de búsqueda queda bloqueado por un sólido con la máscara y exclusiones vigentes. Un caso geométrico con piso a ambos lados y una pared demuestra el rechazo; el mismo recorrido sin pared y los candidatos accesibles del lado actual se conservan. La prueba heredada de carga del contenedor mantiene veintiocho unidades reales y establece una pose inicial de caída libre sobre la boca, derivada de su geometría vigente y de la forma de cada unidad, comprobando volumen libre antes de avanzar física. Conserva más de seis cuerpos dentro antes de cerrar, el bloqueo de la tapa y la ausencia de penetración del cuerpo y de la tapa, sin desactivar colisiones, gravedad ni red de seguridad ni cambiar Jugador/Agarre.
- [ ] Recuperar un objeto antes de cerrar elimina Afuera. Si después queda como unidad suelta adentro, corresponde Desorden; para el caso sin motivos se devuelve/coloca o mantiene en mano.
- [ ] Un caso integrado con caja desordenada y unidad afuera entrega dos motivos; con GRAVE suma 6 medios desde 0. El cierre que determina motivos ocurre antes del registro del legajo y antes del checkpoint/parte.
- [ ] Reglas de pertenencia y cierre son puras y tienen test espejo. Una prueba con escena real comprueba que todas las cajas iniciales pertenecen al depósito, todos los útiles iniciales al baño y jugador al local; deriva cantidades de exports actuales. Las bolsas no se exigen en baño: la nueva base las ubica en depósito.
- [ ] El lector geométrico conserva pertenencia exacta con traslación y rotación: las uniones de cajas se declaran en coordenadas locales y el punto mundial se convierte con `to_local`. El test sintético verifica un punto dentro de cada parte de una habitación y puntos afuera que estarían dentro de la envolvente mundial de una caja rotada, un hueco de la unión, el lateral de un paso estrecho o el espacio encima de un techo más bajo. Una caja rotada no se agranda para clasificar. El caso sintético M2 gira 45° sobre Y y traslada el lector (también por un padre transformado), afirma la premisa de pertenencia local y el falso positivo de la envolvente mundial, y compara el resultado funcional sin exigir coordenadas decorativas.
- [ ] Guardado usa `medios:int`, defecto 0, VERSION 1. Guardado antiguo sin medios conserva jornada válida y restaura 0; int 7 se conserva, mal tipo vuelve 0, ambas claves usa medios. No hay migración de clave antigua.
- [ ] Las dos pruebas heredadas de Mancha y Almacen que prohíben todo if/elif/match en almacen.gd se reemplazan: se conservan y renombran la comprobación de espejos y la de una sola construcción del parte, y se retiran ambas prohibiciones lexicales. Las suites funcionales de cierre y el espejo puro verifican las decisiones; la revisión de capas/fuente confirma la delegación. No se agrega otra prueba textual de arquitectura.
- [ ] `docs/architecture/capacidades.md` agrega flechas `store-cleanup` → `employment-record` (motivos de noche) y `store-stock` → `store-cleanup` (sueltas).

## Contrato

- `Reglas.MEDIOS_POR_APERCIBIMIENTO:int=2`, `MEDIOS_POR_LLAMADO:int=1`. Pesos de banda y corte no cambian; se convierten a medios en un único lugar.
- `Legajo.con_medios(medios:int)->Legajo`, `medios()->int`; `registrar(cumplidas:int,obligatorias:int,llamados:int=0)->void`. `apercibimientos()->int` conserva lectura entera para comentario. Sale `con_apercibimientos`; se migran todos sus lectores, incluidos tests introducidos por #295.
- `Partida.Llamado{LOCAL_DESORDENADO,OBJETO_AFUERA}`, `anotar_llamado(llamado:Llamado)->void` con rechazo sin jornada abierta; `medios()->int` para persistencia. Apertura vacía motivos; cierre existente pasa cantidad única a Legajo. Cierre repetido permanece idempotente.
- `PartidaSerializada.Campo.MEDIOS`, clave `medios`, int con defecto 0; VERSION permanece 1. Política de guardado escribe `Partida.medios`; no serializa motivos.
- Nuevo puro `dominio/almacen/reglas_del_cierre.gd`: `enum Habitacion { LOCAL, DEPOSITO, BANO, AFUERA }`, `enum Clase { UNIDAD_SUELTA, CAJA, UTIL_DE_LIMPIEZA, OTRO }`; `habitacion_de(punto: Vector3, local: Array[AABB], deposito: Array[AABB], bano: Array[AABB]) -> Habitacion`; clase interna `Estado extends RefCounted` con `clase: Clase`, `habitacion: Habitacion`, `en_mano: bool` y constructor que recibe los tres valores. `hay_desorden(estados: Array[Estado]) -> bool` y `hay_objetos_afuera(estados: Array[Estado]) -> bool`. Lista vacía devuelve false. Las reglas reciben valores, sin nodos de escena ni arrays paralelos. El espejo verifica cada clase, habitación y condición de mano.
- Nuevo lector `src/escenas/puestos/habitaciones_del_almacen.gd`: `extends Node3D`, con `const ReglasDelCierre := preload("res://src/dominio/almacen/reglas_del_cierre.gd")`; exporta `local: Array[AABB]`, `deposito: Array[AABB]` y `bano: Array[AABB]`, declarados una sola vez en el espacio local del lector en `estructura_del_almacen.tscn`. `de(punto_mundial: Vector3) -> ReglasDelCierre.Habitacion` delega `ReglasDelCierre.habitacion_de(to_local(punto_mundial), local, deposito, bano)`. No transforma las cajas a envolventes AABB mundiales: eso agranda habitaciones rotadas. La raíz tipa su export mediante `preload` del lector, conservando el estilo del proyecto. El test temático verifica traslación, rotación y transformación de un padre con uniones de cajas sintéticas; la escena integrada comprueba cuerpos y pasos reales. La ampliación a uniones finitas fue autorizada al medir el techo escalonado y los pasos de #305; no cambia geometría, arte ni colisiones interiores. Se usan diez partes: 1 local, 3 depósito y 6 baño. El espejo puro recibe los arrays y comprueba pertenencia a cualquiera de sus partes, no a una caja envolvente; arrays vacíos dan AFUERA.
- `Agarre.cuerpo_sostenido() -> Node3D` devuelve el cuerpo EXACTO actual o null sin mutar estado. Soltar, entregar y vaciar dejan null; mover a examen y devolver conservan identidad. No se compara el Resource de datos: dos cajas comparten ese recurso y siguen siendo cuerpos distintos. El espejo pasa de 18 a 19 públicos, la fuente de 8 a 9, ambos dentro de 20. El rojo usa firma stub válida antes de implementar el lector.
- `CicloDeJornadas.signal turno_agotado(jornada:int)`: exactamente una vez al agotarse turno y ANTES de `Partida.cerrar_la_jornada`; `jornada_cerrada` sigue después. No introduce balance en sistemas.
- `almacen.gd` escucha turno_agotado, arma estados de cajas/útiles/bolsas/sueltas y registra lo que contesten las reglas. Los tickets se incorporan en #307. Consulta `Contenedor.tirados() -> Array[Node3D]`, copia independiente del registro cuyo único dueño es el contenedor; excluye esos cuerpos al clasificar. No mantiene una segunda lista mutable en la raíz ni lee `_tirados` privado. La foto local de candidatos incorpora además cuerpo_sostenido() sólo si sus datos son UnidadDeProducto y no está ya incluido por identidad: una unidad levantada sale de los grupos sueltos y debe volver a considerarse mientras se examina. Cajas, útiles y bolsas ya están en los arrays exportados. Ticket queda fuera de este candidato adicional y se incorpora en #307 con su lector activo. Esto no agrega ownership ni una lista persistente a la raíz. Se copian clase, habitación y condición de mano antes de aplicar las reglas. #305 vacía el registro al abrir otra noche, sin consultar tickets que su creador ya liberó. No filtra por visibilidad de malla individual. El estado en_mano usa identidad de cuerpo: `nodo == _agarre.cuerpo_sostenido() and not _jugador.examen.esta_examinando()`. Examen.iniciar sólo inicia sobre ese cuerpo y conserva la referencia del Agarre; durante el examen ese cuerpo cuenta por su posición física, frente a la cara. Se ejerce examen.iniciar real, no un flag fingido ni comparación por Resource.
- `ReposicionManual.unidades_sueltas()->Array[Node3D]` entrega copia de cuerpos de grupos sueltos, sin repuesto, colocados ni entregados. En305, objeto_agarrado retira el cuerpo de su grupo suelto; entregar no emite objeto_soltado. Se preserva ese flujo y no se finge una soltada para alimentar el lector.
- `exterior_del_almacen.gd` conserva la generación de pavimento y agrega colisión a sus mallas existentes. No agrega nuevas mallas/materiales/texturas ni horneado. Cada una de las seis mallas Pavimento existentes recibe soporte con sus mismos vértices y triángulos; las pruebas contrastan correspondencia y fronteras sin extender colisiones por huecos ajenos. El soporte comparte la geometría real y acepta objetos físicos; no se extiende un rectángulo arbitrario bajo toda la estación.

- `LugaresDelPiso.alrededor` conserva su firma, orden de candidatos, máscara y exclusiones. Tras comprobar el apoyo vertical, rechaza un candidato cuando el recorrido desde el centro de búsqueda hasta ese lateral está bloqueado; el recorrido se consulta a la altura de búsqueda vigente, sin confundir el propio piso de destino con una pared. El espejo geométrico deriva pisos y pared y afirma ambos lados, el obstáculo del segmento y el caso accesible. No cambia los gestos ni las reglas de Jugador o de reposición.

## Medición y declaración de habitaciones sobre #305

Estas cifras describen sólo la cabeza 11301e9d. Se declaran en el espacio local del lector,
cuya transformación es identidad. La pertenencia normativa depende del interior y sus fronteras,
no de un nombre antiguo de colisión. Las pruebas funcionales derivan los puntos de los arrays
exportados y de las caras vigentes, incluyendo un punto bajo y otro sobre cada techo distinto,
centros de ambos pasos y laterales que quedan afuera de las uniones. Los sintéticos ejercen
unión disjunta y rotación de 45° del lector y de un padre.

| Parte | X mínimo/máximo | Y piso/techo | Z mínimo/máximo |
|---|---|---|---|
| local 1 | [-2.480001, 7.870002] | [0.10223747, 4.370002] | [-7.870002, 6.280002] |
| deposito 1 | [-4.594377, 4.64691782] | [0.10273747, 4.86959791] | [-15.397972, -8.25329] |
| deposito 2 | [4.64691782, 7.925532] | [0.10273747, 4.872668] | [-15.397972, -8.25329] |
| deposito 3 | [5.882002, 7.606002] | [0.10223747, 2.886001] | [-8.25329, -7.870002] |
| bano 1 | [8.291861, 8.342008] | [0.10223747, 3.229942] | [-0.311377, 6.278322] |
| bano 2 | [8.342008, 13.43466] | [0.10223747, 4.724773] | [-0.311377, 3.753796] |
| bano 3 | [8.342008, 13.43466] | [0.10223747, 4.869401] | [3.753796, 3.795349] |
| bano 4 | [8.342008, 13.43466] | [0.10223747, 3.239967] | [3.795349, 6.278322] |
| bano 5 | [7.870002, 8.080002] | [0.10223747, 2.850001] | [-0.104, 1.576001] |
| bano 6 | [8.080002, 8.291861] | [0.10223747, 2.851981] | [-0.10535, 1.577521] |

Las dos primeras partes del depósito siguen el fondo y se separan donde cambia su techo;
la tercera es sólo el acceso del local. En baño, una franja oeste baja y tres sectores centrales
respetan las alturas existentes; las dos partes restantes siguen ambas mitades del acceso y sus
dinteles. No se extienden esos accesos a todo el ancho de la habitación. Se conserva el soporte
interior y sólo se agregan colisiones a las seis mallas de pavimento exterior existentes,
a y−0,01776253. No se tocan vereda, proyecciones, materiales ni texturas.

Evidencia externa: b-306-mediciones-305.json, b-306-convex-305.json y sus logs fusionados.
Los dos borradores de pruebas sintéticas adaptados a unión se aplican como tests primero y
se ejecutan en rojo sobre stubs; su gdformat/gdlint externo no se presenta como prueba de motor.

## Límites de archivos

| Categoría | Rutas |
|---|---|
| Se escribe | `specs/employment-record/employment-record.md`; `specs/store-cleanup/store-cleanup.md`; `docs/architecture/capacidades.md`; `src/dominio/reglas.gd`; `src/dominio/empleo/legajo.gd`; `src/dominio/empleo/partida.gd`; `src/dominio/empleo/partida_serializada.gd`; `src/dominio/empleo/politica_de_guardado.gd`; `src/dominio/almacen/reglas_del_cierre.gd`; `src/dominio/almacen/reglas_del_cierre.gd.uid`; `src/escenas/puestos/habitaciones_del_almacen.gd`; `src/escenas/puestos/habitaciones_del_almacen.gd.uid`; `src/sistemas/marco/ciclo_de_jornadas.gd`; `src/sistemas/marco/agarre.gd`; `src/escenas/almacen.gd`; `src/escenas/almacen.tscn`; `src/escenas/puestos/estructura_del_almacen.tscn`; `src/escenas/puestos/exterior_del_almacen.gd`; `src/escenas/puestos/reposicion_manual.gd`; `test/dominio/reglas_test.gd`; `test/dominio/empleo/legajo_test.gd`; `test/dominio/empleo/partida_test.gd`; `test/dominio/empleo/partida_serializada_test.gd`; `test/dominio/empleo/parte_de_cierre_test.gd`; `test/dominio/empleo/politica_de_guardado_test.gd`; `test/sistemas/marco/ciclo_de_jornadas_test.gd`; `test/sistemas/marco/agarre_test.gd`; `test/sistemas/marco/guardado_test.gd`; `test/sistemas/marco/enlace_de_guardado_test.gd`; `test/escenas/almacen_test.gd`; `test/escenas/objetos/mancha_en_el_piso_test.gd`; `test/dominio/almacen/reglas_del_cierre_test.gd`; `test/dominio/almacen/reglas_del_cierre_test.gd.uid`; `test/escenas/puestos/habitaciones_del_almacen_test.gd`; `test/escenas/puestos/habitaciones_del_almacen_test.gd.uid`; `test/dominio/empleo/llamados_de_la_partida_test.gd`; `test/dominio/empleo/llamados_de_la_partida_test.gd.uid`; `test/escenas/cierre_del_almacen_test.gd`; `test/escenas/cierre_del_almacen_test.gd.uid`; `test/escenas/unidades_sueltas_del_cierre_test.gd`; `test/escenas/unidades_sueltas_del_cierre_test.gd.uid`; `test/escenas/soporte_del_exterior_test.gd`; `test/escenas/soporte_del_exterior_test.gd.uid`; `src/sistemas/marco/lugares_del_piso.gd`; `test/sistemas/marco/lugares_del_piso_test.gd`; `test/escenas/puestos/notas_del_almacen_test.gd`; `test/escenas/objetos/caja_que_se_lleva_test.gd`; `test/escenas/puestos/contenedor_de_basura_test.gd` |
| Sólo lectura | `src/sistemas/tareas/recolector_de_basura.gd`; `src/escenas/puestos/contenedor_de_basura.gd`; `src/escenas/puestos/tapa_del_contenedor.gd`; `src/escenas/jugador.gd`; `src/escenas/objetos/objeto_agarrable.gd`; `src/escenas/objetos/caja_de_productos.gd`; `src/escenas/objetos/util_de_limpieza.gd`; `src/escenas/objetos/grupo_del_piso.gd`; `src/escenas/objetos/ticket.tscn`; `src/escenas/puestos/ventanilla.gd`; `src/escenas/puestos/caja_registradora.gd`; `src/sistemas/investigacion/examen.gd`; `src/sistemas/marco/red_de_seguridad.gd`; `src/sistemas/marco/enlace_de_guardado.gd`; `src/sistemas/marco/guardado.gd`; `src/dominio/empleo/parte_de_cierre.gd`; `src/dominio/empleo/catalogo_de_reacciones.gd`; `src/dominio/empleo/consecuencia.gd`; `src/dominio/empleo/reaccion.gd`; `specs/save-and-resume/save-and-resume.md`; `specs/store-stock/store-stock.md`; `specs/player-actions/player-actions.md`; `specs/notifications/notifications.md`; `test/escenas/reposicion_manual_test.gd`; `test/escenas/modelo_integrado_test.gd`; `test/escenas/agarre_fisico_test.gd`; `test/escenas/notificaciones_en_el_almacen_test.gd`; `test/ui/pila_de_notificaciones_test.gd` |
| No se toca | `src/escenas/almacen.lmbake`; `src/escenas/almacen.exr`; `assets/`; `project.godot`; `src/escenas/jugador.tscn`; `src/escenas/puestos/objetos_del_almacen.tscn`; `src/escenas/puestos/limpieza_del_almacen.tscn`; `src/escenas/puestos/servicios_del_almacen.tscn`; `src/escenas/puestos/interfaz_del_almacen.tscn`; `src/ui/`; `.claude/skills/` |

Los archivos nuevos son ocho GDScript con sus UID: dos fuentes y seis suites temáticas. No se agregan casos a Almacen30 (excepción heredada), ReposicionManual20 ni Inventario21; los casos nuevos se separan por función. Legajo15 admite hasta cinco, Partida17 hasta tres, Agarre18 hasta dos (se agrega uno), Serializada5, Parte9, Politica3, Ciclo5, Guardado10 y Enlace5 permanecen dentro de 20. Los tests actuales de enteros conservan sus valores de apercibimientos al migrar a medios: se multiplica por dos, no se reinterpretan3 como1,5. El espejo de Agarre y el test funcional de dos cuerpos con datos compartidos cubren ownership de identidad.

## Verificación

1. `python .claude/scripts/verificar.py`, por FIFO compartida con árbol congelado desde encolar hasta resultado. Requiere 7/7, cero salteos.
2. Conteo inmediato: `python .claude/skills/implement-batch/scripts/conteo.py`; suitesXML igual suitesen test, casos sin failure/error/skip.
3. `python .claude/scripts/verificar.py --solo specs`.
4. Barrido de API retirada: `rg -n 'con_apercibimientos|Campo\.APERCIBIMIENTOS|\x22apercibimientos\x22' src test specs docs .claude` debe retirar todos los lectores de API. La clave `apercibimientos` sólo puede permanecer como dato del caso funcional de guardado antiguo; comprobar sus coincidencias exactas y registrar esa excepción, aprobada por el padre el 2026-10-09. No escribir tests de ausencia del nombre. Medición readonly de30511301e9d:20 coincidencias precisas en10 archivos (`b-306-readers-305.json`); el enum sin prefijo se migra también. No se barre el sustantivo legítimo apercibimientos ni sus constantes de puntos enteros. El comando de verificación final distinguirá el archivo/caso funcional del uso vigente sin ocultar coincidencias imprevistas.
5. Primer commitnormativo; skeletonfirmasnuevas, rojo deaserción; implementaciónverde; push antes del full; guardar logs y corrida; PR propio apilado sobre #305.

## Bordes

- NINGUNA con deuda suma sólo llamados; conserva el legajo. GRAVE con dos motivos suma tres
  apercibimientos; NINGUNA con dos motivos suma uno.
- Tres medios y medio más medio llegan a cuatro y despiden. La quinta impecable con3,5sin
  motivos cumple el contrato; el comentario usa la lectura entera3.
- Una caja en el paso del depósito pertenece al depósito; un útil en el paso del baño pertenece
  al baño. Los laterales de esos pasos y el espacio sobre un techo más bajo quedan fuera.
- Una bolsa adentro no produce desorden; afuera produce OBJETO_AFUERA. Los tickets se incorporan
  al inventario de cuerpos del cierre en #307.
- Lo tirado se excluye por Contenedor.tirados. Al abrir, los persistentes vuelven a su lugar;
  las unidades se limpian y se recrean según reposición, y los tickets se liberan según su puesto.
- El cuerpo sostenido exacto se excluye. Examen.iniciar real conserva ese cuerpo en Agarre,
  pero mientras se examina cuenta por su posición física. Terminar vuelve la exclusión de mano.
- Recuperar algo de afuera cambia la foto al cierre. Una unidad devuelta, colocada o sostenida
  no es desorden; recuperada y suelta adentro sí puede serlo.
- Anotar sin jornada abierta no acumula deuda para una noche futura. Una partida terminada
  rechaza llamados y cierres adicionales.
- El guardado viejo restaura 0medios sin migración. El entero7 conserva3,5apercibimientos y la
  jornada. Un float7,0 vuelve al defecto: no se convierte a entero para eludir el tipo.

## Interfaz309 preservada

Base inmediata11301e9d, que hereda309fe620b92. Se conservan en almacen.gd las conexiones comprador_llegado->avisar_llegada, lectura_rechazada->avisar_lectura_rechazada y turno_cerrado->vaciar.unbind(1), sin alterar su orden o crear doble conexion. Pila CanvasLayer5/process_mode1 y MenuDePausa layer6 no se modifican. Permanecen fuera del alcance src/ui/, src/dominio/ambiente/notificaciones.gd, src/escenas/puestos/interfaz_del_almacen.tscn y specs/notifications/notifications.md. Las suites heredadas test/escenas/notificaciones_en_el_almacen_test.gd y test/ui/pila_de_notificaciones_test.gd se ejercen readonly en los full. Jugador/guard297 y gesto/caja304 se conservan. Agarre sólo agrega el lector readonly aprobado; no altera movimientos, señales ni física. Las rutas y cantidades anteriores se midieron contra la dependencia inmediata certificada.

## Corrección de la premisa del hueco vigente

La lectura sobre11301e9d de Ventanilla/Vidrio y almacen/Volumen/local_ventanilla_alto compone sus transforms y verifica vidrio[1,04;2,44] y cara inferior del dintel≈2,440001. Esa holgura numérica no deja pasar ningún cuerpo. Se conserva el arte y se prueban únicamente los dos laterales libres; el comentario heredado que citaba2,84m se corrige como premisa histórica obsoleta. El contrato originalSPECfirst3a0c3b9b permanece en la historia; este ajuste normativo precede tests y fuente de soporte.

## Primer full y segundo control heredado

La convergencia formal sobre2390328d ejecutó las214 suites y1670 casos, con12 aserciones fallidas y0 errores. Entre ellas apareció un segundo control lexical en Almacen: además del de Mancha ya declarado, prohibía cualquier condición en la raíz. Su sustitución conserva la comprobación de un solo ParteDeCierre y reutiliza las pruebas funcionales de cierre. La fixture de guardado conserva su apercibimiento entero escribiendo dos medios, como ya exige la migración de lectores. Ambas rutas ya están en Se escribe; no se agrega ningún archivo ni se cambia una regla normativa. Cuatro fallos físicos se diagnostican por separado sobre el árbol congelado antes de decidir correcciones; el primer full permanece fallido en la evidencia.

## Regresión del recorrido al agregar soporte exterior

El contraste sobre2390328d y su base11301e9d reprodujo las tres regresiones de balde, caja y notas; el caso del contenedor pasó en ambas corridas focales y conserva su fallo del primer full como antecedente. Una copia instrumentada del caso original del balde confirmó que el primer candidato exterior de LugaresDelPiso cruzaba la fachada: el segmento desde el jugador hasta ese lateral impacta la pared real. La corrección del recorrido y su espejo, junto con las dos correcciones de premisa física descritas abajo, son cuatro rutas adicionales autorizadas antes de escribirlas: Se escribe pasa de43a47 rutas. Las copias diagnósticas y sus filtros no cuentan como convergencia ni sustituyen los casos originales. Desactivar únicamente la capa física de los seis soportes nuevos, conservando su creación, corrige el balde pero reproduce los mismos fallos de notas y caja. No se atribuyen esos dos fallos a un orden de IDs sin evidencia. Las copias con premisas físicas válidas pasan ambos casos, conservando las comprobaciones de lectura y apoyo. No cambia una regla normativa del juego, ni se altera geometría interior, arte, Jugador o reposición.

## Premisas físicas de las pruebas heredadas

La prueba de notas rechazaba treinta posiciones cuyo rayo impacta la cara superior real del piso interior duplicado del modelo, sólo porque el dueño de esa colisión no se llama SueloSolido. La corrección compara el punto y la normal del impacto con las caras superiores y los límites locales derivados de los BoxShape de los pisos interiores existentes, incluido el baño; no admite cualquier superficie horizontal. Conserva y ejerce la cápsula libre, la visibilidad hasta la hoja, el alcance, el foco calculado por el juego y la lectura real de cada hoja. No cambia la ubicación de las hojas ni la colisión de la escena.

La prueba de caja calculaba los pies a partir de la altura de la mancha, incluso para una mancha vertical del depósito, y avanzaba un solo cuadro desde esa posición inválida. La fixture obtiene la altura del piso de su BoxShape vigente y deja acomodarse físicamente al jugador; antes de apuntar afirma apoyo cercano con normal superior y cápsula libre. Conserva todas las manchas visibles, el foco real de la mancha, el gesto, el rechazo de la caja en mano tras soltar, el apoyo de sus cuatro esquinas y la ausencia de penetración. Para acceder a la mancha del baño se abren las puertas de las cabinas mediante su API pública real y se espera de forma acotada a que terminen su movimiento, afirmando ese estado. Es una precondición de acceso: el caso no exige cabinas cerradas. No se desactivan colisiones ni se simula un foco a través de la puerta; las posiciones siguen exigiendo cápsula libre, visibilidad y alcance antes del gesto. No se cambian umbrales de apoyo ni las reglas de colocación, ni se omiten casos. Estas dos rutas corrigen las premisas de notas y caja; sus versiones instrumentadas son diagnósticas y los casos originales corregidos deben pasar en las suites y la convergencia formal.


La segunda convergencia formal sobre `01bda52fac0e92b191e7c367086c9a7798e0d895` ejecutó
214/214 suites y 1671 casos: quedó una aserción fallida, cero errores y cero salteos, en la
carga del contenedor. FULL1 y FULL2 permanecen fallidos y preservados. El caso había pasado
en los focales completos A/B y GREEN3; eso no certifica la segunda convergencia ni permite
atribuirlo a IDs o declararlo inestable sin evidencia.

Una copia instrumentada del caso completo, con originales y aserciones intactos, mostró que
el rayo del jugador apunta al borde delantero del contenedor y que 27 de las 28 unidades son
recolocadas por el flujo normal de soltado antes de comenzar la caída. El primer punto pedido
(2.93, 1.452238, -14.94747) se convierte en (3.0, 1.446469, -14.55757); el rayo alcanza el
borde en (3.0, 1.177237, -14.55757). Sólo siete cuerpos quedan dentro en ese diagnóstico:
el marcador solicitado no acredita una carga física sobre la boca.

Se autoriza una quinta ruta adicional, `test/escenas/puestos/contenedor_de_basura_test.gd`:
Se escribe pasa de 47 a 48 rutas. El archivo real está en puestos, no en objetos. Su prueba
de contención y cierre conserva las veintiocho unidades reales retiradas por la reposición,
sus formas, materiales, máscaras, grupos y seguridad. Después de retirar y soltar mediante
las APIs vigentes, establece explícitamente la pose de arranque de la caída sobre la boca.
El alto se deriva del límite mundial de la malla del cuerpo del contenedor, del límite de
los cuerpos ya cargados y del mínimo vertical de la forma real de la nueva unidad, más el
roce vigente. Se conserva la orientación de cada unidad. Las posiciones XZ se derivan de la boca real: rayos horizontales hacia sus cuatro paredes a una altura interior verifican sus límites; ese rectángulo se reduce por el AABB mundial de la forma de la unidad. Se buscan candidatos finitos dentro del espacio restante. Antes de avanzar física, cada punto debe tener forma inicialmente libre y un recorrido vertical libre, comprobado con cast_motion hasta encima de la carga existente y del borde. Ambas consultas conservan la máscara original y excluyen sólo el RID propio: no se omiten la tapa ni otros cuerpos. La distribución XZ histórica no es contrato; se corrige porque cinco formas orientadas intersectaban la tapa abierta al comenzar. El primer intento de fixture corregido (GREEN4, once casos, seis aserciones fallidas y cero errores) permanece preservado; no cuenta como convergencia formal.
La unidad parte sin velocidad lineal ni angular, con gravedad y colisión activas; no se
desactiva la red de seguridad ni se fuerza el cuerpo a través de paredes o tapa. El caso
verifica contención física, mientras los gestos de #305 permanecen cubiertos por sus suites.
Conserva la caída/espera física, más de seis unidades dentro antes de cerrar, el bloqueo por
la carga y todas las aserciones de penetración. No hay umbral relajado, nuevo caso ni cambio
normativo. El espejo mantiene sus once tests públicos; los ayudantes nuevos son privados.
La suite original completa debe pasar antes del FULL3 formal sobre commit y push exactos.

La lectura viva para esta ampliación está congelada en `01bda52fac0e92b191e7c367086c9a7798e0d895`,
tracked limpio. El original del fixture tiene SHA256
`0bd174cd4dab7671dcf332fb6f837344aaa211fdb83f3a7b6703f36aed23be8e`; manifest, diff,
28 poses pedidas/soltadas y 28 poses estables se conservan fuera de fuente. La copia filtrada
es diagnóstico con tiempo perturbado por prints, no un rojo, un verde final ni convergencia.
