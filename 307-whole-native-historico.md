# Tirar un ticket al inodoro suma un llamado; un ticket afuera cuenta al cierre

## Contexto

- **Objetivo:** tirar al menos un ticket al inodoro durante una noche suma0,5 al cierre; un ticket que sigue afuera de las tres habitaciones anota el motivo de afuera.
- **Tipo:** `feature`.
- **Spec:** modifica `specs/store-cleanup/store-cleanup.md`.
- **Rama:** `feature/307-llamado-del-inodoro`.
- **Base y dependencias:** `789ce08184f9bbf7ba5df765a2cffe72609d0070`, PR certificado de306. Hereda305 (contenedor y registro propietario),304 (ticket al inodoro y signal VOID),309 (notificaciones),297 (suspension) y302/303 (programa manual).

Sale de la ficha verde [Llamados de atencion extras](https://app.notion.com/p/3e486efecd9d80078230fe988b0290d2). Cada motivo suma medio apercibimiento al cierre, incluso con banda NINGUNA. Tirar al menos un ticket al inodoro dispara un motivo unico. Los tickets adentro no producen desorden; afuera participan como cuerpos levantables. La voz/chat del jefe queda fuera de alcance.

306 ya implementa medios enteros, unicidad por noche, rechazo de anotacion sin jornada abierta y foto anterior al registro/parte/checkpoint. Las tres habitaciones son uniones finitas `Array[AABB]` locales, consultadas mediante `to_local`, sin envolventes ni geometria nueva. Este issue consume esos contratos y no los recalcula.

## Criterios de aceptacion

- [ ] `store-cleanup` agrega una regla de papel en el inodoro y aclara que los tickets adentro no producen desorden y afuera si participan. Se mantienen los contratos de304 y306; los nuevos criterios tienen tests funcionales citados.
- [ ] Durante una jornada abierta, el evento VOID `ticket_desechado()` anota `PAPEL_EN_EL_INODORO` una vez por noche. Uno o dos tickets propios aceptados dan un medio con noche impecable; vaciar un balde o enjuagar mopa no anota este motivo.
- [ ] El puesto de caja devuelve una copia tipada de tickets propios activos. Excluye referencias invalidas y cuerpos queued_for_deletion; modificar el array devuelto no modifica el registro ni otra consulta. El lector conserva tickets validos en ranura, mundo, mano, examen y contenedor, sin interpretar freeze/capa/visibilidad como estado de descarte.
- [ ] La foto del cierre incorpora esos tickets como clase OTRO. Uno afuera anota `OBJETO_AFUERA`; varios afuera anotan uno. En local, deposito o bano no producen desorden. La misma pertenencia a uniones y pasos exactos de306 se conserva.
- [ ] Mano se excluye por identidad de cuerpo y solo sin examen: `nodo == agarre.cuerpo_sostenido() and not examen.esta_examinando()`. Un examen real conserva ese cuerpo y lo hace contar por su posicion fisica; al terminar vuelve la exclusion de mano. Recuperarlo elimina Afuera si queda adentro o sostenido sin examen; examinarlo fisicamente afuera conserva el motivo.
- [ ] Un papel aceptado por el inodoro se retira del registro del puesto y se libera. El callback del motivo no recibe ni consulta un cuerpo; tras free, cierre y apertura siguen funcionando sin acceso al papel. Un ticket tirado al contenedor sigue vivo y puede seguir en el lector del puesto, pero la foto lo excluye por `Contenedor.tirados()`; no anota papel en el inodoro ni Afuera por su posicion escondida.
- [ ] Un caso con almacen entero desecha un ticket propio al inodoro, deja una caja desordenada y una unidad afuera. Con GRAVE produce tres motivos, suma7 medios desde0 y no despide. La noche siguiente impecable sin motivos conserva7; no borra la deuda.
- [ ] Al abrir otra noche se vacian motivos pendientes y la caja limpia sus papeles como304. Un evento antes de abrir, despues del cierre, durante placa o con partida terminada no suma deuda ni contamina la siguiente noche. El cierre repetido sigue siendo idempotente.

## Contrato

- `Partida.Llamado` agrega `PAPEL_EN_EL_INODORO`; no agrega un lector de listas ni cambia `Legajo`, bandas, guardado o umbral. Se reutilizan `anotar_llamado()` y `medios()` existentes. La unicidad y rechazo pertenecen al dominio306.
- `src/sistemas/tareas/caja_registradora.gd` permanece sololectura: su `signal ticket_desechado` no tiene argumentos. `pedir_desechar()` valida Ticket/destino y emite al aceptar;304 conserva el gesto propio, la entrega de manos y el free posterior.
- `almacen.gd` conecta ese VOID una sola vez a un callback privado que llama `Partida.anotar_llamado(PAPEL_EN_EL_INODORO)`. No agrega payload, no obtiene un nodo del evento ni copia la politica al callback.
- `src/escenas/puestos/caja_registradora.gd` agrega `tickets_en_el_mundo() -> Array[Node3D]`. Construye un array tipado nuevo recorriendo `_tickets: Array[ObjetoAgarrable]`, incluyendo solo `is_instance_valid(papel) and not papel.is_queued_for_deletion()`. No retorna el array interno ni asume covarianza de `duplicate()` entre tipos de array. No muta el registro al consultar.
- `almacen.gd` agrega la copia del lector a los candidatos locales de `_estados_del_cierre()`. Conserva la toma unica de `cuerpo_sostenido()`, la exclusion por copia publica de `Contenedor.tirados()`, el filtro invalid/queued, la clase OTRO y la bandera de mano exacta de306. Copia clase, pertenencia por posicion y condicion de mano a Estado antes de aplicar reglas; no conserva candidatos entre cierres ni lee `_tickets`/`_tirados` privados de otros nodos.
- Inodoro y contenedor son destinos distintos. Inodoro libera el papel; contenedor conserva el cuerpo oculto sin colision. La raiz no agrega otra lista persistente ni transfiere el ownership del descarte. La apertura305/304 conserva el orden que limpia cuerpos creados y vacia el registro del contenedor sin leer referencias liberadas.
- Las uniones de `HabitacionesDelAlmacen` y el dominio `ReglasDelCierre` quedan sololectura. No se agrega una clasificacion especial de desorden para Ticket ni una segunda conversion geometrica.

## IDs normativos

Historia CLN medida sobre `789ce08184f9bbf7ba5df765a2cffe72609d0070`: 18 revisiones, 18 blobs distintos; máximos BR029/AC046/OQ003. La continuación normativa es BR030 y AC047–049.

| Contrato | ID | Verificacion |
|---|---|---|
| Papel en el inodoro como motivo unico | BR-CLN-030 | VOID aceptado, dominio306 conserva unicidad/guardas |
| Un/dos tickets, balde y anotacion fuera de noche | AC-CLN-047 | Flujo de ticket aceptado y cierre real de la noche |
| Tickets activos, mano/examen, destinos y Afuera | AC-CLN-048 | Lector COPY y snapshot integrado |
| Tres motivos mas GRAVE, orden/reset/deuda | AC-CLN-049 | Almacen entero,7medios sin despido y noche siguiente |

BR-CLN-028 aclara la excepcion de ticket adentro; BR-CLN-029 conserva la regla generica de afuera, ahora ejercida tambien con tickets. AC-CLN-043 conserva identidad/examen. No se reescriben criterios heredados para que acepten un resultado distinto.

## Limites de archivos

La escritura queda cerrada a estas seis rutas. El primer commit es normativo; la suite nueva obtiene UID mediante importacion FIFO, no uno inventado.

| Categoria | Rutas |
|---|---|
| Se escribe | `specs/store-cleanup/store-cleanup.md`; `src/dominio/empleo/partida.gd`; `src/escenas/almacen.gd`; `src/escenas/puestos/caja_registradora.gd`; `test/escenas/tickets_del_cierre_test.gd`; `test/escenas/tickets_del_cierre_test.gd.uid` |
| Sololectura | `src/sistemas/tareas/caja_registradora.gd`; `src/dominio/almacen/ticket.gd`; `src/sistemas/tareas/limpiador.gd`; `src/sistemas/marco/agarre.gd`; `src/sistemas/investigacion/examen.gd`; `src/escenas/puestos/contenedor_de_basura.gd`; `src/escenas/puestos/tapa_del_contenedor.gd`; `src/sistemas/tareas/recolector_de_basura.gd`; `src/dominio/almacen/reglas_del_cierre.gd`; `src/escenas/puestos/habitaciones_del_almacen.gd`; `src/escenas/puestos/reposicion_manual.gd`; `src/sistemas/marco/ciclo_de_jornadas.gd`; espejos y suites heredadas de304/305/306/309, sin modificar esas suites |
| No se toca | Todos los `.tscn`; `assets/`; `src/ui/`; `src/dominio/ambiente/notificaciones.gd`; `src/dominio/reglas.gd`; `src/dominio/empleo/legajo.gd`; guardado/politica de checkpoint; limpieza_del_almacen.gd; uso.gd; `project.godot`; export_presets.cfg; EXR/LMBake; specs fuera de store-cleanup; addons; harness, reglas, AGENTS y skills |

## Pruebas funcionales

Por instrucción del usuario, se agrega una sola suite de integración funcional. No se agregan
pruebas de coordenadas, flags internos ni estados intermedios. Las posiciones se usan únicamente
para montar las situaciones de juego. Los resultados son los llamados al cierre, el despido,
la deuda guardada y la posibilidad de continuar la noche siguiente.

Los siete casos cubren uno o dos tickets al inodoro, balde/mopa sin llamado, tickets dentro,
afuera y recuperados, mano/examen con cuerpos que comparten datos, descarte al contenedor,
tres motivos más GRAVE con guardado de siete medios y eventos durante la placa. La consulta
pública de tickets se ejerce en esos flujos, incluida su copia independiente y su limpieza al
abrir otra noche. Los tests heredados de304 siguen comprobando el gesto y la aceptación.

El registro de motivos y sus guardas ya tienen las pruebas funcionales de306 y se reutilizan.
El cambio de307 agrega un valor al enum, sin duplicar aquellos casos en el espejo de Partida.
Se descartan los casos que sólo inspeccionaban estados intermedios del lector.
La suite nueva tiene siete casos y after_test; los ayudantes son privados. El gate conserva
el límite de veinte métodos públicos y los espejos existentes.

## Verificacion y entrega

1. Publicar y leer el cuerpo entero con esta base certificada, historia de IDs y premisas medidas antes del primer commit normativo. Aplicar CLAUDE/AGENTS/reglas scoped vigentes. Registrar publicación y readback exactos.
2. Primer commit normativo de CLN; lector con firma/skeleton valido y tests primero. Capturar RED por asercion, no por firma ausente/parse. Implementar lo minimo y conservar GREEN focal. No aflojar contratos304/305/306 ni umbrales.
3. Todas las llamadas motor/import/captura/verificacion usan `turno.py` y entorno del preambulo. Push seguro antes del full; congelar el arbol desde encolar hasta resultado. Ejecutar `python .claude/scripts/verificar.py` sin filtros y exigir7/7 sin salteos, preservando RAW completo mediante el wrapper externo.
4. Inmediatamente despues del full ejecutar `python .claude/skills/implement-batch/scripts/conteo.py`; conservar XML, suites descubiertas/ejecutadas, casos, cero failure/error/skip y hashes. Clasificar diagnosticos heredados/propios leyendo RAW; XML0 no autoriza afirmar RAW limpio.
5. Comparar `git diff --name-only 789ce08184f9bbf7ba5df765a2cffe72609d0070` con las seis rutas autorizadas y recontar publicos. La verificacion de specs debe pasar sin cambiar contratos ajenos. Registrar toda corrida real con numero y evidencia, incluyendo intentos no verdes.
6. PR propio contra la rama306 con `Closes #307`, base/head completos, tabla AC->caso->resultado y enlace a RAW/XML/conteo; mantener metadatos/CI terminales actualizados. Evidencia fuera de fuente publicada con el mecanismo del lote. No declarar listo con criterio pendiente ni sin PR.

## Bordes y compatibilidad

- Sin ticket aceptado no hay papel en el inodoro. Vaciado del balde/enjuague de mopa y ticket ajeno rechazado conservan sus contratos304.
- Dos tickets al inodoro suman1medio; un ticket al inodoro y otro afuera producen dos motivos distintos. Tickets adentro no producen desorden.
- Impreso en ranura puede estar congelado y seguir activo. Contenedor puede estar oculto y seguir vivo. Visibilidad/freeze/capa no reemplazan identidad ni ownership.
- El snapshot consulta la copia de tirados antes de leer posicion de un cuerpo descartado; no lee un papel liberado por inodoro o apertura. Las copias son locales de consulta, no registros persistentes nuevos.
- Cerrar mientras se examina acredita la posicion fisica antes del cierre; terminar examen devuelve el mismo cuerpo a mano. Una referencia igual de datos no excluye otro cuerpo.
- Recuperacion al interior/mano sin examen elimina Afuera. Un examen que conserva el cuerpo afuera no lo elimina.
- Tres motivos mas GRAVE son7medios: no despido. Cuatro mas GRAVE seran8 al agregar308; este issue no agrega ese motivo anticipadamente.
- Para medir1medio, controlar/completar las demas obligatorias: una banda GRAVE accidental no debe mezclarse con el motivo probado. Derivar el total obligatorio de la Partida/Apertura real, no otro balance.
- Apertura limpia papeles creados; motivos reinician, medios quedan. El mismo motivo puede anotarse en otra noche. Evento fuera de noche y doble cierre no suman ni contaminan la siguiente.
- Notificaciones309, Pila.layer5/Pausa.layer6, programa manual/popup303, suspension297 y gestos304/305 quedan intactos. Sus suites se ejecutan sololectura en el full.
