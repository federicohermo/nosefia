# El contenedor de basura recibe con clic izquierdo lo que se lleva en la mano

Base de implementacion: `fe620b92a38b556f27fff721d162c466c1e784fb` (cabeza certificada de #309).

## Contexto

- **Objetivo:** tirar al contenedor con clic izquierdo saca de la jornada lo que se lleva en
  la mano. Una bolsa cuenta para sacar la basura; una caja del depósito se conserva en la mano.
- **Tipo:** `feature`
- **Spec:** modifica — `specs/store-cleanup/store-cleanup.md`,
  `specs/store-stock/store-stock.md` y `specs/player-actions/player-actions.md`.
- **Rama:** `feature/305-contenedor-de-basura`.
- **Depende de #298, #304 y #309:** la implementación parte de la cabeza que los contiene.
  La rama `improvement/fluidos-balde-y-mopa` ya es ancestro de `staging`.

**La base cambió.** `staging` f17948fe ya trae el contenedor artístico del depósito, con cuerpo,
ruedas, herrajes, bisagra, tapa y colisiones físicas. También trae `BR-CLN-025` y
`AC-CLN-034/035`: clic derecho sobre cuerpo o tapa alterna su apertura, el giro se puede invertir
y se detiene ante un objeto. Se conservan el modelo, su ubicación, sus materiales y sus
colisiones. No se crea otra caja verde ni se reemplaza el trabajo del artista.

**El usuario aclaró «Tirar es con click izquierdo».** Ése es el gesto del contenedor. El clic
derecho conserva el abrir/cerrar de la tapa. Sólo se puede tirar cuando la tapa está
completamente abierta: cerrarla corta el permiso desde el inicio del giro y volver a abrirla lo
recupera al llegar al tope. El clic izquierdo con la tapa cerrada o girando conserva lo sostenido
en la mano. Abrir la tapa no tira automáticamente nada.

**Hoy hay dos piezas para el descarte.** El contenedor físico está en la estructura y una
`ZonaDeDescarte` separada, de radio 1,5 m, cuenta cuerpos que entran. Esa esfera sale entera.
Desde este cambio, una bolsa cuenta por el clic izquierdo sobre el contenedor abierto; soltarla
en el piso o por su boca física no la deposita. El contenedor intercepta ese clic tanto en su
cuerpo como en su tapa, para que el soltar genérico no produzca un segundo efecto.

Lo tirado queda oculto, sin colisión y fuera de la mira durante esa jornada. Los objetos de
arranque vuelven al abrir la siguiente; las unidades de producto y los tickets siguen la limpieza
del puesto que los creó. #302 ya elimina todos los tickets al abrir otra noche. Este issue
conserva las tres bolsas de la obligatoria y sus identidades.

Quedan fuera los subtítulos de rechazo, el llamado por tirar algo útil (#308), los productos
vencidos y que una bolsa o un producto vencido tirados no vuelvan. Esas decisiones dependen de
las fichas que el lote ya declara abiertas. La aclaración del clic izquierdo se aplica a este
contenedor; no redefine el gesto del inodoro de #304.

## Criterios de aceptación

**Contenedor y gesto — `store-cleanup`:**

- [ ] Se agrega una regla: CUANDO el jugador hace clic izquierdo sobre el contenedor
  completamente abierto con un objeto que entra en la mano, el sistema DEBE retirarlo de la mano
  y de la jornada: no se ve, no choca y la mira no lo enfoca. SI es una caja del depósito,
  ENTONCES DEBE conservarla en la mano sin cambiar nada. Con la mano vacía no ocurre nada.
- [ ] Con la tapa cerrada o girando, el clic izquierdo DEBE conservar lo sostenido y el estado
  de la tarea. El clic derecho sobre cuerpo o tapa DEBE conservar el abrir/cerrar vigente, con
  la mano vacía o cargada. Abrirla no tira lo sostenido automáticamente.
- [ ] Con el jugador suspendido por examen, pausa o cierre, el clic izquierdo no llega al
  contenedor y no cambia las manos ni lo depositado.
- [ ] `BR-CLN-008` nombra el contenedor del depósito y conserva la separación funcional de
  6 m respecto de las tareas del local y del arranque de las bolsas; es mayor que el alcance de
  la mira. No incorpora una coordenada decorativa ni exige mover el modelo a una esquina.
- [ ] `BR-CLN-009` dice que la bolsa cuenta sólo tirada con clic izquierdo al contenedor
  completamente abierto. Soltada en el piso a menos de 1 m, o por la boca, no cuenta y se puede
  recoger. Sale el radio de 1,5 m.
- [ ] `BR-CLN-010` conserva dos rechazos de depositar, en orden: «no es basura» y «ya
  depositada». Sale «fuera de la zona».
- [ ] `BR-CLN-025` conserva la apertura de cada noche, el clic derecho, el giro, la inversión
  y el freno ante obstáculos. Su permiso pasa a recibir objetos; desaparece el sensor esférico.
- [ ] El lenguaje reemplaza «Descarte» por «Contenedor», el del depósito donde se tiran objetos
  y cuentan las bolsas. Los contratos y las señales nombran qué se tira. Sale el no objetivo
  «NO mide distancias: las recibe ya medidas».
- [ ] `to-spec` reescribe `AC-CLN-008`: dentro del depósito, no levantable, separado por al
  menos 6 m de las tareas del local y del arranque de las bolsas. La prueba deriva las posiciones
  de la escena vigente.
- [ ] `to-spec` reescribe `AC-CLN-009`: bolsa soltada cerca no depositada y recogible; después
  el clic izquierdo sobre contenedor abierto la deposita. Sale entero `AC-CLN-010`.
- [ ] `to-spec` reescribe `AC-CLN-011`: no bolsa rechazada por «no es basura», bolsa ya
  depositada por «ya depositada» y el segundo intento no aumenta lo depositado.
- [ ] `to-spec` actualiza `AC-CLN-034/035`: clic derecho conserva tapa y física; clic izquierdo
  tira sólo completamente abierta, conserva la carga durante cierre/apertura y abrir no produce
  un tiro automático.
- [ ] Criterio nuevo: por turno, bolsa, mopa, balde, jabón y unidad de producto tirados con clic
  izquierdo dejan mano vacía y cuerpo oculto, sin colisión ni foco. Sólo la bolsa suma depositada.
- [ ] Criterio nuevo: caja del depósito y tapa no abierta conservan lo sostenido; mano vacía
  no cambia nada. Cuerpo y tapa interceptan el gesto sin soltar genérico adicional.
- [ ] Criterio nuevo: mopa mojada, balde teñido y bolsa tirados vuelven al arranque al abrir
  otra noche, visibles, físicos y recogibles; mopa seca, balde vacío y bolsa sin depositar.
- [ ] Criterio nuevo: izquierda y derecha durante suspensión no tiran ni alternan tapa; al
  reanudar vuelven a producir sus efectos respectivos.

- [ ] El lector `tirados()` devuelve una copia independiente; modificarla no cambia los descartados. La siguiente noche vacía el registro. Una prueba restaura un útil móvil y comprueba caída de 0,5 m y apoyo físicos, además de padre, pose, visibilidad y colisiones.

**Unidad tirada — `store-stock`:**

- [ ] Regla nueva: tirar una unidad afuera la retira de afuera y descuenta una del depósito.
  La caja y la góndola siguen como estaban; esa unidad ya no se devuelve ni coloca. La siguiente
  noche abre con su inventario (`BR-STK-026`). «Unidad afuera» incluye hasta colocar, devolver o
  tirar.
- [ ] Criterio nuevo: caja de Actroncito en 8 y una unidad suya sostenida; al tirarla, caja
  sigue en 8, depósito tiene una menos y unidad no está afuera. Tirar una unidad sacada de un
  casillero conserva ese casillero vacío, no mueve la caja ni cumple reponer. Desechar una unidad
  no registrada afuera devuelve `false` y no cambia el inventario.

**Rescate — `player-actions`:**

- [ ] `AC-PLY-043` se reescribe: la bolsa tirada no se mueve ni aparece al rescatar; la bolsa
  no tirada superpuesta con un sólido se recupera y las depositadas no cambian. No nombra un área.

**Retiro y arquitectura:**

- [ ] Salen la escena, script y suite de zona, su radio, `Trayecto.dentro_del_descarte`,
  `pedir_depositar`, `deposito_rechazado`, «fuera de la zona» y el permiso `recibe_bolsas`.
  Todos los consumidores pasan antes a las puertas nuevas; la cobertura funcional acompana la migracion.
- [ ] `docs/architecture/capacidades.md`: `PLY → CLN` dice «qué se lleva y qué se tira»;
  entra `CLN → STK` con «la unidad tirada».

## Contrato

**`dominio/almacen`:**

- `ObjetoDelAlmacen.entra_en_el_contenedor: bool = true` exportado; el recurso común de caja
  de reposición declara `false`.
- `ReglasDeLaBasura`: sale `RADIO_DEL_DESCARTE`; `DISTANCIA_MINIMA_AL_DESCARTE` pasa a
  `DISTANCIA_MINIMA_AL_CONTENEDOR`, conservando 6,0. Entran
  `enum Tiro { TIRADO, MANO_VACIA, NO_ENTRA, TAPA_NO_ABIERTA }` y
  `static func tiro(sostenido: ObjetoDelAlmacen, recibe: bool) -> Tiro`: nulo → mano vacía;
  no entra → no entra; tapa no habilitada → tapa no abierta; lo restante → tirado. Los rechazos
  no modifican nada.
- `TapaDelContenedor.recibe_bolsas()` se renombra a `recibe_objetos() -> bool`; el estado y el
  giro conservan su implementación y sus bordes. El dominio sigue decidiendo el permiso.
- `TareaDeLaBasura.depositar(id: StringName) -> Resultado` pierde la distancia.
  `Resultado { DEPOSITADA, YA_DEPOSITADA, NO_ES_BASURA }` conserva orden e idempotencia.
- `Trayecto`: sale `dentro_del_descarte()`; `viajes()` conserva su contrato.
- `Inventario.desechar(unidad: UnidadDeProducto) -> bool`: si está registrada afuera, la
  retira y descuenta una del depósito; si no, `false` sin mutación. `Estante.desechar()` delega.

**`sistemas/tareas/RecolectorDeBasura`:**

- Exporta `agarre: Agarre` y `repositor: Repositor`, cableados por la raíz.
- `pedir_tirar(recibe: bool) -> ReglasDeLaBasura.Tiro` evalúa la regla pura sobre lo sostenido.
  Si se rechaza, devuelve el motivo sin entregar ni emitir. Ante `TIRADO`, una unidad pasa por
  `repositor.estante().desechar()`, el cuerpo sale por `agarre.entregar()` y se emite
  `objeto_tirado(nodo: Node3D)`. Se intenta depositar su `id`: sólo una bolsa aceptada emite
  `bolsa_depositada` y completa la obligatoria cuando corresponde. No bolsa no emite rechazo.
  Sin tarea, reloj, agarre o repositor cableados, `push_error` y ninguna mutación.
- Salen `pedir_depositar(id, distancia)` y `deposito_rechazado`.

**Escenas:**

- El contenedor expone `tirados() -> Array[Node3D]`, una copia de su lista propia. Consultarla no permite modificar el registro interno. Al abrir otra noche queda vacía, sin consultar cuerpos de tickets ya liberados. Los lectores posteriores del cierre usan esta puerta pública.

- El `contenedor_de_basura.gd` existente sigue en su cuerpo artístico. Exporta recolector,
  conserva tapa y mallas. `interactuar() -> ObjetoDelAlmacen` llama al recolector con el permiso
  de la tapa y devuelve `null`, consumiendo el clic izquierdo. `usar()` conserva alternar tapa.
  Su recepción de `objeto_tirado` esconde el cuerpo, lo congela, pone capa y máscara en 0 y lo
  cuelga del contenedor.
- `tapa_del_contenedor.gd` conserva toda la física de su giro. Exporta recolector y expone
  `recibe_objetos() -> bool` delegado al dominio. También intercepta `interactuar()` con el
  mismo recolector y `null`, para conservar la carga si la mira pega en la tapa cerrada.
  Desaparecen `zona`, `_actualizar_la_zona()` y sus llamadas.
- `almacen.gd` exporta el contenedor tipado por `preload`, cablea recolector, agarre,
  repositor y los dos puntos del clic; conecta una sola vez `objeto_tirado` a su receptor. La lista de tirados pertenece al contenedor: la raíz no mantiene otra copia mutable. Al abrir otra noche, el contenedor restaura los cuerpos persistentes y vacía su lista en el orden del ciclo heredado; la caja registradora sigue sólo lectura y conserva su limpieza de tickets de #302/#304. El caso funcional del ticket tirado deja completar esa limpieza y comprueba que la lista queda vacía sin leer un nodo liberado.
  `almacen.tscn` declara el nuevo `node_paths` y retira el cableado a la zona.
- #297 ya filtra el clic izquierdo durante `_control.esta_suspendido()`. La cabeza de #309
  debe heredarlo; al medirla se conserva ese guard y el ruteo por `interactuar()`. No se duplica
  implementación ni se agregan acciones/botones. El criterio integrado de suspensión permanece;
  `jugador.gd` pasa a sólo lectura si ese guard ya está presente según la medición de la base certificada.
- `objeto_agarrable.gd` guarda padre, pose, visibilidad, capa, máscara y estado `freeze` originales en `_ready()`.
  `volver_a_su_lugar()` restaura esos valores, incluido el estado físico original; la vuelta de útiles
  conserva sus reinicios de limpieza. Un objeto tirado con capa 0 no participa del rescate.

## Límites de archivos

| Categoría | Rutas |
|---|---|
| **Se escribe** | `specs/store-cleanup/store-cleanup.md`; `specs/store-stock/store-stock.md`; `specs/player-actions/player-actions.md`; `docs/architecture/capacidades.md`; `src/dominio/almacen/objeto_del_almacen.gd`; `src/dominio/almacen/caja_de_reposicion.tres`; `src/dominio/almacen/reglas_de_la_basura.gd`; `src/dominio/almacen/tarea_de_la_basura.gd`; `src/dominio/almacen/trayecto.gd`; `src/dominio/almacen/inventario.gd`; `src/dominio/almacen/estante.gd`; `src/dominio/almacen/tapa_del_contenedor.gd`; `src/dominio/almacen/rescate.gd`; `src/sistemas/tareas/recolector_de_basura.gd`; `src/escenas/objetos/objeto_agarrable.gd`; `src/escenas/almacen.gd`; `src/escenas/almacen.tscn`; `src/escenas/puestos/objetos_del_almacen.tscn`; `src/escenas/puestos/contenedor_de_basura.gd`; `src/escenas/puestos/tapa_del_contenedor.gd`; `test/dominio/almacen/reglas_de_la_basura_test.gd`; `test/dominio/almacen/tarea_de_la_basura_test.gd`; `test/dominio/almacen/trayecto_test.gd`; `test/dominio/almacen/objeto_del_almacen_test.gd`; `test/dominio/almacen/estante_test.gd`; `test/dominio/almacen/tapa_del_contenedor_test.gd`; `test/sistemas/tareas/recolector_de_basura_test.gd`; `test/escenas/puestos/contenedor_de_basura_test.gd`; `test/escenas/puestos/tapa_del_contenedor_test.gd`; `test/escenas/puestos/tapa_del_contenedor_test.gd.uid`; `test/escenas/puestos/tiro_al_contenedor_test.gd`; `test/escenas/puestos/tiro_al_contenedor_test.gd.uid`; `test/escenas/objetos/objeto_agarrable_test.gd`; `test/escenas/agarre_fisico_test.gd`; `test/escenas/jornada_integrada_test.gd`; `test/escenas/red_de_seguridad_integrada_test.gd`; `test/escenas/objetos/ubicacion_en_el_deposito_test.gd`; `test/escenas/objetos/mancha_en_el_piso_test.gd` |
| **Sólo lectura** | `src/escenas/jugador.gd`; `src/escenas/puestos/estructura_del_almacen.tscn`; `src/escenas/puestos/artefacto_del_bano.gd`; `src/escenas/puestos/limpieza_del_almacen.gd`; `src/escenas/puestos/reposicion_manual.gd`; `src/escenas/puestos/caja_registradora.gd`; `src/escenas/objetos/util_de_limpieza.gd`; `src/escenas/objetos/caja_de_productos.gd`; `src/sistemas/marco/agarre.gd`; `src/sistemas/marco/red_de_seguridad.gd`; `src/sistemas/tareas/repositor.gd`; `src/sistemas/tareas/caja_registradora.gd`; `src/dominio/almacen/manos.gd`; `src/dominio/almacen/unidad_de_producto.gd`; `src/dominio/almacen/ticket.gd`; `src/dominio/ambiente/tabla_de_sonidos.tres`; `src/dominio/ambiente/notificaciones.gd`; `src/ui/pila_de_notificaciones.gd`; `src/ui/pila_de_notificaciones.tscn`; `src/escenas/puestos/interfaz_del_almacen.tscn`; `src/sistemas/marco/control_de_pausa.gd`; `src/ui/interrupciones/menu_de_pausa.tscn`; `test/escenas/apoyos_del_modelo_test.gd`; `test/escenas/hoja_que_arrastra_test.gd`; `test/escenas/lo_soltado_fuera_de_los_solidos_test.gd`; `test/escenas/giro_parejo_test.gd`; `test/escenas/objetos/utiles_de_limpieza_test.gd`; `test/escenas/reposicion_manual_test.gd`; `test/escenas/modelo_integrado_test.gd`; `test/escenas/campo_de_interaccion_test.gd`; `test/sistemas/tareas/repositor_test.gd`; `test/dominio/almacen/inventario_test.gd`; `test/escenas/notificaciones_en_el_almacen_test.gd`; `test/ui/pila_de_notificaciones_test.gd`; `specs/shift-cycle/shift-cycle.md`; `specs/notifications/notifications.md` |
| **Se retira** | `src/escenas/puestos/zona_de_descarte.gd`; `src/escenas/puestos/zona_de_descarte.gd.uid`; `src/escenas/puestos/zona_de_descarte.tscn`; `test/escenas/puestos/zona_de_descarte_test.gd`; `test/escenas/puestos/zona_de_descarte_test.gd.uid` |
| **No se toca** | `src/escenas/jugador.tscn`; `src/escenas/puestos/servicios_del_almacen.tscn`; `src/escenas/puestos/limpieza_del_almacen.tscn`; `src/escenas/puestos/estructura_del_almacen.tscn`; `src/escenas/puestos/interfaz_del_almacen.tscn`; `src/escenas/almacen.lmbake`; `src/escenas/almacen.exr`; `src/ui/`; `src/dominio/ambiente/notificaciones.gd`; `assets/`; `project.godot`; `src/dominio/jornada/`; `specs/notifications/notifications.md` |

Las pruebas conservan las colisiones y el movimiento de tapa vigentes. Los casos que suponían
depósito automático por esfera se reescriben para el clic izquierdo y los bordes funcionales.
Los métodos públicos se cuentan sobre la cabeza final anterior antes de agregar casos: la suite
del estante tiene18 sobre c315ccd5/fe620b92, recibe a lo sumo dos; inventario21 con ignore basal y repositor no reciben casos. ReposicionManual20 permanece readonly. El espejo nuevo de tapa y la suite tematica de tiro separan los gestos sin ampliar esos limites.

## Verificación

1. `python .claude/scripts/verificar.py` — siete nodos en verde, sin salteos.
2. `python .claude/skills/implement-batch/scripts/conteo.py` inmediatamente después — suites
   corridas iguales a archivos `*_test.gd`.
3. `rg -n -i 'descarte' src test specs docs` — revisar y clasificar cada coincidencia. Salen
   lectores y textos del mecanismo retirado; vocabulario genérico legítimo del ticket u otra
   función se conserva. Guardar la lista y el motivo de cada coincidencia restante. Este comando
   es inventario semántico, no exige ausencia de una palabra ni un código de salida fijo.
4. `rg -n 'ZonaDeDescarte|zona_de_descarte|pedir_depositar|deposito_rechazado|FUERA_DE_LA_ZONA|dentro_del_descarte|RADIO_DEL_DESCARTE|DISTANCIA_MINIMA_AL_DESCARTE|recibe_bolsas' src test specs docs`
   debe devolver exit1, sin coincidencias de las APIs/sensor especificos retirados. Se migran todos sus consumidores sobre la base certificada, sin tests de ausencia del mecanismo ni renombrados de sustantivos ajenos.
5. `git diff --quiet fe620b92a38b556f27fff721d162c466c1e784fb -- src/escenas/jugador.tscn src/escenas/puestos/servicios_del_almacen.tscn src/escenas/puestos/limpieza_del_almacen.tscn project.godot src/escenas/almacen.lmbake src/escenas/almacen.exr src/escenas/puestos/interfaz_del_almacen.tscn src/ui/pila_de_notificaciones.gd src/ui/pila_de_notificaciones.tscn src/ui/interrupciones/menu_de_pausa.tscn src/dominio/ambiente/notificaciones.gd specs/notifications/notifications.md`.
   La comparacion usa la cabeza certificada de #309 y conserva los cambios heredados de #302/#304, no origin/staging.

6. Comparar geometría y arte contra ese mismo SHA certificado de #309: este issue no cambia modelo,
   materiales, ubicación ni colisiones de cuerpo/tapa. Las pruebas miden funcion y fronteras, derivando las posiciones de la escena.

## Bordes

- Mano vacía, clic izquierdo: sin efecto; clic derecho: alterna tapa.
- Caja en la mano, clic izquierdo: sigue sostenida, abierta o cerrada la tapa.
- Objeto aceptado, tapa cerrada o a mitad de cualquiera de los giros: sigue sostenido.
- Abrir completamente no tira automáticamente; un clic izquierdo posterior sí.
- Clic sobre cuerpo o sobre tapa produce un tiro a lo sumo; no añade soltar genérico.
- Bolsa soltada cerca o por la boca: no cuenta; se recoge y se tira después.
- La tercera bolsa tirada completa una sola vez; id repetido no aumenta depositadas.
- Tirar mopa, balde o jabón impide usarlos esa noche; vuelven con su estado nuevo al abrir otra.
- Una unidad tirada pierde su reserva afuera y una del depósito; la caja y la góndola no cambian.
- Examen, pausa o cierre bloquean ambos clics; no se modifica la lista de objetos ni las manos.
- Volver a abrir noche restaura padre, pose, visibilidad, colisiones y `freeze` originales, y tapa abierta. Un útil originalmente móvil vuelve a caer y apoyarse; no queda congelado por haber sido tirado.
- Ticket tirado se oculta esa noche y se elimina con los demás tickets al abrir la siguiente.

## Convivencia con la interfaz heredada de309

Al modificar almacen.gd se conservan las tres conexiones de PilaDeNotificaciones al comienzo de _ready: comprador_llegado, lectura_rechazada y turno_cerrado->vaciar.unbind(1). No se recrea ni reconecta Pila y no se usa como lector de manos o estado del contenedor. Interfaz/PilaDeNotificaciones sigue layer5/process_mode1; MenuDePausa sigue layer6. Interfaz/UI/Notificaciones y controles de pausa permanecen sin cambios.

Los casos integrados vuelven a ejercer aviso por llegada/lectorLLENO, cierre que vacia y pausa sobre Pila mediante las suites heredadas readonly, ademas del LEFT/RIGHT propio. El guard297 de jugador se conserva sin editar. Caja304 valida Ticket/inodoro; su signal ticket_desechado() es VOID y no se modifica en305. Entregar al contenedor no emite esa signal ni objeto_soltado: la referencia _papel de Caja queda inerte por comprobar la mano; su limpiar propio la reinicia y libera tickets en la siguiente noche. La lista propia del contenedor se vacia sin consultar cuerpos que Caja ya puso en cola de liberacion.

El espejo nuevo `test/escenas/puestos/tapa_del_contenedor_test.gd` y su UID cubren el gesto propio de la tapa. Inventario se prueba por la delegacion publica de Estante (dos plazas disponibles); no se agregan casos a Inventario21 ni ReposicionManual20. Las medidas geometricas se derivan de la base certificada, sin fijar coordenadas decorativas.
