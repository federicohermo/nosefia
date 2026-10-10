<!-- Un issue es un plan chico y descartable: resuelve un problema puntual, con límites y
     criterios propios. Un spec es otra cosa: el contrato durable de una funcionalidad.
     Un issue cambia un spec sólo si cambia lo que el juego tiene que hacer. -->

# La quinta tarea cambia cada noche, y en la primera es ordenar las cajas del depósito

## Contexto

- **Objetivo:** que cada noche pida cuatro tareas fijas más la tarea particular de esa jornada, y que la de la jornada 1 sea dejar todas las cajas del depósito en sus estanterías.
- **Tipo:** `feature`
- **Spec:** modifica — `specs/shift-cycle/shift-cycle.md`, `specs/store-stock/store-stock.md` y `specs/player-actions/player-actions.md`
- **Rama:** `feature/369-quinta-tarea-por-jornada`
- **Diseño:** sin pantalla. Fichas: [Particulares de cada jornada](https://app.notion.com/p/3d286efecd9d805fa314caa6345c84a3) (Jornada 1), [Ciclo de jornadas](https://app.notion.com/p/3cc86efecd9d81b2861ee59ab2fa4f2d), [Notas](https://app.notion.com/p/3e486efecd9d80caa50dc8dfec402093) («Tareas a realizar»), [Reposición](https://app.notion.com/p/3cc86efecd9d81968a25c7cffca4b0dd) (cajas contenedoras) y [Chat con el jefe](https://app.notion.com/p/3ea86efecd9d8013a7f7f50db70e3861) («Tarea 5»).

<!-- `feature` es el único tipo que siempre toca un spec. Un `bugfix` toca uno sólo si el bug
     era una regla que nadie había escrito. La etiqueta sale del tipo: `enhancement`, `bug`,
     `refactor` o `improvement`, y `documentation` o `accessibility` cuando aplica. -->

**Qué hay hoy.** `BR-SHF-005` pide las cinco obligatorias iguales todas las noches: cobrar,
reponer, registrar, limpiar y sacar la basura. `Apertura.obligatorias()` recorre `Tarea.Tipo`
entero y no recibe la jornada. La nota del corcho la arma `notas_del_almacen.gd` una sola vez,
en `_ready()`, con esa lista. Las 31 cajas arrancan todas las noches apoyadas en los pallets de
las tres estanterías del depósito (`test_las_cajas_de_reposicion_estan_apoyadas_en_el_deposito`).

**Qué pide la ficha.** Cinco tareas: cuatro fijas y una particular de cada jornada. La de la
jornada 1 es «Ordenar cajas en el depósito»: al abrir, todas las cajas contenedoras están
apiladas en el fondo del depósito, frente al portón. Se cumple si al final todas están apoyadas
en las estanterías del depósito. Una caja apilada sobre otra que está en una estantería cuenta.
La caja que el jugador tiene en la mano al terminar cuenta como apoyada. La imagen de la ficha
muestra las cajas en columnas de dos a cuatro, contra la pared. La ficha de Reposición confirma
que las demás noches arrancan con las cajas en las estanterías.

**Qué hace cada jornada después de este issue.** La jornada 1 pide ordenar las cajas. La 2 pide
sacar la basura, con las tres bolsas sueltas de hoy: el cambio a los tachos lo hace el issue «J2:
tirar la basura sacando bolsas de los 3 tachos», que depende de éste. Las jornadas 3 a 5 no
tienen diseño cerrado: la 3 queda fuera de esta tanda, la 4 está vacía en la ficha y la 5 está
incompleta. **Hasta que cada una tenga su issue, declaran sólo las cuatro fijas**, confirmado por el usuario. No se inventa
una quinta. El árbol lo admite sin reglas nuevas: `BR-SHF-008` cuenta sólo las declaradas,
`BR-EMP-001` mide «todas» contra las declaradas, y la nota enumera lo que recibe. `to-spec` lo
registra como una `OQ-SHF` nueva: «¿qué tarea particular piden las jornadas 3, 4 y 5?».

**Medido en el modelo.** El portón (`porton-col`) está en la pared oeste del depósito, centrado
en z −11,5, con unos 4,3 m de ancho. Entre el portón y la estantería central izquierda
(`deposito_pallet_central_izquierdo_*`) hay unos 3,7 m libres. Las tres bolsas de hoy arrancan
ahí mismo, en x −3,7 a −3,1 y z −12,1 a −11,5: la pila las tiene que dejar libres y alcanzables
hasta que el issue de J2 las saque. El pallet del piso (`deposito_pallet_piso`) no es una
estantería: el test de hoy ya lo excluye. Las cajas grandes miden 0,61 m de lado.

**Lo que sale del árbol para la línea del parte.** `CatalogoDeReacciones` pide una línea por
tipo, cumplida y sin cumplir. Sin cumplir, la ficha del chat trae el texto de «Tarea 5 — Falla la
tarea de la jornada 1». Cumplida, la ficha no trae texto. El usuario pidió uno **provisorio**, en
el registro del jefe, que vale hasta que el issue del cierre por chat reemplace la placa.

**Cruce de fixtures sobre la implementación del lote.** El focal de 127 suites
conservado en `369-regresion-focal-godot.log` encontró premisas del reparto anterior:
el último recurso de rescate esperaba un origen de estantería y dos gestos de apilar
caminaban hacia la caja en su pose inicial. Se adapta sólo ese rescate a la jornada 2
y esos dos gestos a una caja grande apoyada explícitamente en piso libre. Los casos
nuevos conservan la pila de jornada 1 y prueban su rescate real; no se cambia el
comportamiento ni las tolerancias de la red, el apilado o la física.

El detector de cifras de balance también separaba los decimales geométricos `2.0`
y `0.02` como enteros. Se corrige su tokenización y se agrega un testigo rojo/verde
de decimales: sigue rechazando enteros desde 2, incluida una copia `JORNADAS := 5`,
en los mismos tres archivos. No se mueve código sólo para eludir el detector ni
se cambia ningún valor de balance.

**Auditoría heredada de apoyos.** La primera noche incorpora apoyos entre cajas, cubiertos por las pruebas nuevas de la pila. La auditoría existente que exige que cada objeto se apoye directamente sobre la estructura se ejerce en la jornada 2, donde las cajas vuelven a su pose de estantería. Se parametriza sólo ese fixture, sin cambiar sus rayos, umbrales ni aserciones. Las demás pruebas de esa suite conservan su jornada inicial.

La auditoría de soltado sobre una estantería también abre sólo ese caso en la jornada 2, para conservar el hueco de UAKAS que su fixture usa como destino. El resto de la matriz de soltado mantiene jornada 1 y sus tolerancias.

**Enlaces de escena y servicios creados al arrancar.** La auditoría de enlaces antes de `_ready()` comprueba las propiedades de script serializadas, no las variables de ejecución que todavía no se construyeron. Se conserva el chequeo de enlaces no nulos y de roles/cajas/bolsas, y se afirma que el filtro encontró propiedades para que no pueda pasar sin verificar ninguna. El acomodador se sigue creando en el cableado y su funcionamiento lo ejercen los casos nuevos.

## Criterios de aceptación

<!-- Los de este issue: binarios y con los valores que deciden. Mueren con el issue.
     Si el issue toca un spec, acá van también los `AC-<COD>-###` que agrega o cambia: ésos
     sí duran, y un test los cita. -->

**Las obligatorias de cada noche (`specs/shift-cycle`)**

- [ ] `BR-SHF-005` se reescribe: cada jornada pide las cuatro fijas —cobrar en la caja,
  registrar, limpiar y reponer— más la particular que esa jornada declara. La jornada 1 declara
  ordenar las cajas; la 2, sacar la basura; la 3, la 4 y la 5, ninguna, con la `OQ-SHF` nueva.
- [ ] `AC-SHF-005` se reescribe: DADO las jornadas 1 a 5, CUANDO cada una pide sus obligatorias,
  ENTONCES la 1 recibe 5 con ordenar las cajas, la 2 recibe 5 con sacar la basura, y la 3, la 4 y
  la 5 reciben 4. Dos jornadas seguidas reciben instancias nuevas, todas sin cumplir.
- [ ] `AC-SHF-007` y `AC-SHF-018` dicen «las declaradas» donde hoy dicen «las cinco», sin cambiar
  sus valores.
- [ ] El HUD de cada jornada cuenta contra sus obligatorias: abre la 1 con `0/5` y la 3 con `0/4`.
- [ ] Una noche de la jornada 3 con las cuatro cumplidas cierra en banda `NINGUNA`.

**La pila de la jornada 1 (`specs/store-stock`)**

- [ ] Una regla nueva de `store-stock`: CUANDO abre una jornada que declara ordenar las cajas, el
  sistema DEBE dejar todas las cajas del depósito apiladas en el fondo del depósito, frente al
  portón, sin ninguna sobre una estantería. Las demás jornadas DEBEN arrancar con cada caja en su
  lugar de las estanterías, como hoy.
- [ ] Un `AC-STK` nuevo lo verifica en la escena: DADO la jornada 1 abierta, ENTONCES las 31
  cajas están dentro del depósito, ninguna se apoya en un pallet de las tres estanterías, ningún
  cuerpo de la pila se superpone con otro cuerpo, y la mira enfoca cada caja desde un punto libre
  del piso a no más de `ReglasDelJugador.ALCANCE_DE_LA_MIRA`. DADO la jornada 2 abierta después,
  ENTONCES cada caja vuelve a apoyarse en su pallet, como afirma hoy
  `test_las_cajas_de_reposicion_estan_apoyadas_en_el_deposito`.
- [ ] La pila queda quieta: ninguna caja se mueve más de 1 cm en los 120 cuadros de física
  posteriores a abrir la jornada 1, sin que el jugador la toque.
- [ ] Las tres bolsas siguen alcanzables desde la puerta del depósito con la pila puesta:
  `test_las_tres_bolsas_arrancan_en_el_deposito_y_lejos_del_contenedor` sigue verde sin cambios.
- [ ] El PR trae una captura de la pila tomada desde la puerta del depósito. La ubicación
  «frente al portón» se revisa mirándola: ningún test fija coordenadas de la pila
  (`.claude/rules/tests.md`).

**Ordenar las cajas (`specs/store-stock`)**

- [ ] Otra regla nueva de `store-stock`: MIENTRAS queda turno, ordenar las cajas DEBE contar
  como cumplida si cada caja del depósito está en la mano del jugador, o se apoya en un pallet de
  una de las tres estanterías del depósito, o se apoya sobre otra caja que cumple esto mismo.
  DEBE dejar de contar en cuanto una caja deja de cumplirlo (`BR-SHF-007`).
- [ ] Un `AC-STK` nuevo, en el dominio y sin escena, con la tabla:

  | Estado de las cajas | Ordenar |
  |---|---|
  | todas sobre un pallet de estantería | cumplida |
  | todas sobre un pallet, salvo una en el piso | sin cumplir |
  | una sobre otra caja que está sobre un pallet; el resto, sobre pallets | cumplida |
  | una sobre otra caja que está en el piso | sin cumplir |
  | todas sobre pallets salvo una, que está en la mano | cumplida |
  | la misma, soltada en el piso | sin cumplir |
  | una sobre el pallet del piso del depósito | sin cumplir |
  | dos cajas que se declaran apoyadas una sobre la otra | sin cumplir |

- [ ] Un `AC-STK` nuevo en la escena: DADO la jornada 1, CUANDO se llevan las 31 cajas a las
  estanterías, ENTONCES la obligatoria de ordenar queda cumplida y el HUD sube en 1. CUANDO
  después se baja una caja al piso y queda en reposo, ENTONCES la obligatoria se descumple y el
  HUD baja en 1.
- [ ] Con el turno cerrado, mover una caja no cumple ni descumple ordenar: cuenta el estado del
  cierre (`AC-SHF-007`, `AC-SHF-019`).

**La nota del corcho y el parte (`specs/player-actions`, `CatalogoDeReacciones`)**

- [ ] `BR-PLY-030` se reescribe: la nota de tareas enumera las obligatorias de la jornada en el
  orden atención al cliente, registro de productos vendidos, limpieza, reposición y, al final, la
  particular de esa jornada. `AC-PLY-069` conserva su ejemplo de dos renglones.
- [ ] La nota de la jornada 1 dice, en este orden: «Atención al cliente», «Registro de productos
  vendidos», «Limpieza», «Reposición» y «Ordenar cajas en el depósito». La de la jornada 3 tiene
  los cuatro primeros y nada más.
- [ ] La nota se arma de nuevo al abrir cada jornada: después de despachar la placa de la 1, la
  nota de la 2 dice «Sacar la basura» en el quinto renglón, sin recargar la escena.
- [ ] El parte de cierre de la jornada 1 lleva la línea de ordenar las cajas. Sin cumplir, dice el
  texto de la ficha del chat: «Cuando te pedí que ordenaras las cajas en las estanterías del
  depósito, lo que quería decir es que pongas TODAS y cada una de las CAJAS de cartón con
  productos ARRIBA de las ESTANTERÍAS del DEPÓSITO. Ahí se entendió?». Cumplida, dice el texto
  provisorio «Las cajas quedaron arriba de las estanterías. Así me gusta.», que vale hasta que el
  cierre por chat reemplace la placa.

## Contrato

<!-- Sólo si aparecen firmas, señales o datos nuevos. Cada uno con su capa y su tipo de
     retorno. El caso de falla va junto al de éxito. -->

- **`dominio/jornada/tarea.gd`:** `Tarea.Tipo` suma `ORDENAR_LAS_CAJAS` al final del `enum`. Los
  valores que ya existen no cambian de número.
- **`dominio/jornada/apertura.gd`:**
  - `Apertura.obligatorias(jornada: int) -> Array[Tarea]`: las cuatro fijas más la particular de
    esa jornada, instancias nuevas en cada llamada. Una jornada sin particular devuelve las
    cuatro. Reemplaza a la versión sin argumento: no queda una función que recorra `Tarea.Tipo`
    entero.
  - `Apertura.cantidad_de_obligatorias(jornada: int) -> int`.
  - `Apertura.cajas_apiladas(jornada: int) -> bool`: `true` si la jornada declara
    `ORDENAR_LAS_CAJAS`. No es una tabla aparte: sale de la misma particular.
- **`dominio/empleo/partida.gd`:** `abrir_la_jornada()` pide `Apertura.obligatorias(_jornada)`.
- **`dominio/almacen/orden_del_deposito.gd` (nuevo):** `class_name OrdenDelDeposito`.
  - `enum Apoyo { ESTANTERIA, CAJA, OTRO }`.
  - Clase interna `Estado`: `producto: Producto.Id`, `en_mano: bool`, `apoyo: Apoyo` y
    `sobre: Producto.Id` (sólo vale con `Apoyo.CAJA`).
  - `static func ordenadas(estados: Array[Estado]) -> bool`. Una cadena de cajas que no termina
    en `ESTANTERIA` —porque termina en `OTRO`, en una caja que no está en la lista o en un ciclo—
    da `false`. Una lista vacía da `true`.
- **`sistemas/tareas/acomodador_del_deposito.gd` (nuevo):** `class_name AcomodadorDelDeposito`,
  `extends Node`. `func revisar(estados: Array[OrdenDelDeposito.Estado]) -> void` le pide a
  `OrdenDelDeposito.ordenadas()` la respuesta y completa o descumple
  `reloj.obligatoria(Tarea.Tipo.ORDENAR_LAS_CAJAS)`. Si la jornada no la declaró, `obligatoria()`
  devuelve `null` y el reloj ya lo ignora. Lo crea `almacen.gd` con `add_child()`, como hoy a
  `MarcoDelObjetivo`: `almacen.tscn` no cambia.
- **`escenas/almacen.gd`:** mide de qué se apoya cada caja con un rayo hacia abajo desde su
  centro, sin contarla a ella. Un pallet `deposito_pallet_*` que no es `deposito_pallet_piso` es
  `ESTANTERIA`; otra caja es `CAJA`; lo demás es `OTRO`. La caja sostenida sin examen y la que se
  examina desde la mano son `en_mano`. Revisa al abrir la jornada, cuando una caja cambia de
  reposo y cuando el agarre toma o suelta una caja.
- **`escenas/puestos/pila_del_deposito.gd` (nuevo):** calcula la pose de cada caja en la pila a
  partir de los nodos del modelo —el portón y la estantería central izquierda— y del tamaño de
  cada caja. No escribe coordenadas sueltas.
- **`escenas/objetos/caja_de_productos.gd`:** la caja recibe la pose con que arranca la noche.
  `volver_a_su_lugar()` y `lugar_de_origen()` usan esa pose: en la jornada 1, la de la pila.
- **`escenas/puestos/notas_del_almacen.gd`:** `func declarar_tareas(obligatorias: Array[Tarea])
  -> void`. Lo llama `almacen.gd` al abrir cada jornada, en vez de armar la nota en `_ready()`.
- **`assets/reactions/cajas_pendiente.tres` y `cajas_cumplida.tres` (nuevos):** las dos líneas de
  `ORDENAR_LAS_CAJAS` en `CatalogoDeReacciones`.

## Límites de archivos

| Categoría | Rutas |
|---|---|
| **Se escribe** | `specs/shift-cycle/shift-cycle.md`; `specs/store-stock/store-stock.md`; `specs/player-actions/player-actions.md`; `src/dominio/jornada/tarea.gd`; `src/dominio/jornada/apertura.gd` (salvo `FALTANTES_POR_JORNADA` y `faltantes_de_la_jornada()`); `src/dominio/empleo/partida.gd`; `src/dominio/empleo/catalogo_de_reacciones.gd`; `src/dominio/almacen/nota_pegada.gd`; `src/dominio/almacen/orden_del_deposito.gd` y su `.uid` (nuevos); `src/sistemas/tareas/acomodador_del_deposito.gd` y su `.uid` (nuevos); `src/escenas/almacen.gd`; `src/escenas/puestos/notas_del_almacen.gd`; `src/escenas/puestos/pila_del_deposito.gd` y su `.uid` (nuevos); `src/escenas/objetos/caja_de_productos.gd`; `assets/reactions/cajas_pendiente.tres` y `assets/reactions/cajas_cumplida.tres` (nuevos); `test/dominio/jornada/apertura_test.gd` (17 métodos públicos: suma 3 como máximo); `test/dominio/jornada/tarea_test.gd`; `test/dominio/jornada/turno_test.gd`; `test/dominio/reglas_test.gd`; `test/dominio/almacen/nota_pegada_test.gd`; `test/dominio/almacen/orden_del_deposito_test.gd` y su `.uid` (nuevos); `test/dominio/empleo/catalogo_de_reacciones_test.gd`; `test/dominio/empleo/partida_test.gd`; `test/dominio/empleo/parte_de_cierre_test.gd`; `test/dominio/empleo/legajo_test.gd`; `test/ui/interrupciones/pantalla_de_cierre_test.gd`; `test/sistemas/tareas/acomodador_del_deposito_test.gd` y su `.uid` (nuevos); `test/sistemas/tareas/ventanilla_test.gd`; `test/sistemas/tareas/repositor_test.gd` (20 métodos públicos: sólo cambia la llamada, no suma casos); `test/sistemas/tareas/recolector_de_basura_test.gd`; `test/sistemas/tareas/limpiador_test.gd`; `test/sistemas/marco/reloj_del_turno_test.gd`; `test/sistemas/marco/ciclo_de_jornadas_test.gd`; `test/sistemas/marco/enlace_de_guardado_test.gd`; `test/sistemas/investigacion/computadora_de_escritorio_test.gd` (19 métodos públicos: sólo cambia la llamada); `test/escenas/puestos/escritorio_test.gd`; `test/escenas/almacen_test.gd`; `test/escenas/jornada_integrada_test.gd`; `test/escenas/puestos/notas_del_almacen_test.gd`; `test/escenas/objetos/ubicacion_en_el_deposito_test.gd`; `test/escenas/lo_soltado_fuera_de_los_solidos_test.gd` (sólo parametrizar `_almacen` y abrir jornada 2 en `test_la_caja_se_sigue_apoyando_en_un_estante_del_deposito`, conservando AC-PLY-021, rayos, aserciones y tolerancias; demás casos jornada 1); `test/escenas/modelo_integrado_test.gd` (sólo acotar `test_la_raiz_agrupa_por_rol_y_conserva_sus_enlaces` a propiedades de script serializadas con `PROPERTY_USAGE_STORAGE`, afirmar que el filtro no quedó vacío y conservar las aserciones de enlaces, roles, cajas y bolsas); `test/escenas/apoyos_del_modelo_test.gd` (sólo parametrizar `_abrir` y abrir jornada 2 en `test_los_objetos_y_manchas_quedan_sobre_el_modelo`, conservando rayos, tolerancias y aserciones; demás casos conservan jornada 1); `test/escenas/deposito_ordenado_test.gd` y su `.uid` (nuevos: los casos de escena de la pila y de ordenar); `test/escenas/red_de_seguridad_integrada_test.gd` (sólo parametrizar el fixture y abrir la jornada 2 en el caso del último recurso, conservando AC-PLY-028 y sus aserciones); `test/escenas/objetos/caja_que_se_lleva_test.gd` (sólo preparar SALADIK en PISO_LIBRE_DEL_DEPOSITO en los dos casos de soltar sobre tapa/costado, sin cambiar aserciones ni tolerancias); `test/dominio/empleo/reglas_de_la_partida_test.gd` (sólo corregir la tokenización de literales numéricos completos y agregar testigos de decimales/exponentes, conservando los archivos vigilados, enteros >=2 y la detección de JORNADAS := 5) |
| **Sólo lectura** | `src/dominio/jornada/turno.gd`; `src/dominio/empleo/consecuencia.gd`; `src/dominio/empleo/legajo.gd`; `src/dominio/empleo/parte_de_cierre.gd`; `src/dominio/almacen/reglas_del_cierre.gd`; `src/sistemas/marco/reloj_del_turno.gd`; `src/sistemas/marco/ciclo_de_jornadas.gd`; `src/sistemas/marco/red_de_seguridad.gd`; `src/sistemas/marco/agarre.gd`; `src/sistemas/tareas/recolector_de_basura.gd`; `src/escenas/puestos/reposicion_manual.gd`; `src/ui/hud.gd`; `test/escenas/apertura_con_lugar.gd`; `test/escenas/cierre_del_almacen_test.gd`; `test/escenas/tickets_del_cierre_test.gd`; `test/escenas/consecuencias_del_contenedor_test.gd`; `test/escenas/salida_de_compradores_test.gd` |
| **No se toca** | `src/escenas/almacen.tscn`; `src/escenas/puestos/objetos_del_almacen.tscn`; `src/escenas/puestos/estructura_del_almacen.tscn`; `src/escenas/puestos/notas_del_almacen.tscn`; `src/escenas/puestos/limpieza_del_almacen.tscn`; `src/escenas/objetos/caja_de_productos.tscn`; `assets/models/`; `src/dominio/almacen/tarea_de_la_basura.gd`; `src/dominio/almacen/reglas_de_la_basura.gd`; `specs/store-cleanup/store-cleanup.md`; `specs/employment-record/employment-record.md`; en `src/dominio/jornada/apertura.gd`, `FALTANTES_POR_JORNADA` y `faltantes_de_la_jornada()` |

<!-- La tercera fila es una lista negativa y cerrada. Un `.tscn` que otro issue en vuelo edita
     va siempre acá: un merge de tres vías sobre una escena da una escena corrupta. -->

## Verificación

<!-- Comandos que devuelven código de salida 0. El veredicto sale del código de salida,
     nunca de un grep de la salida. -->

1. `python .claude/scripts/verificar.py`
2. `! rg -n "Apertura\.obligatorias\(\)|cantidad_de_obligatorias\(\)" src test` — no queda una llamada sin jornada.
3. `! rg -n -i "las cinco obligatorias|cinco tareas" src test specs/shift-cycle` — la prosa vieja de la regla salió.
4. `rg -n "AC-SHF-005" test` y `rg -n "ORDENAR_LAS_CAJAS" test/dominio/almacen/orden_del_deposito_test.gd test/escenas/deposito_ordenado_test.gd` encuentran sus casos.
5. La captura de la pila desde la puerta del depósito está en el PR, y el padre abre el PNG.

## Bordes

<!-- El caso feliz lo cubre cualquier implementación. Acá van los límites: cero, uno, el
     máximo, el valor justo antes del corte, el que llega dos veces. -->

- **La jornada 1 sin tocar una caja:** ordenar no está cumplida al abrir. Las cajas de la pila
  están en el depósito, así que no hay desorden por cajas (`BR-CLN-028`, `AC-CLN-040`).
- **La última caja en la mano al cerrar:** cuenta como apoyada, y ordenar cierra cumplida.
  Examinarla desde la mano también cuenta como en la mano.
- **Una caja apilada sobre la que está en la mano:** el juego no la deja ahí. Si el rayo devuelve
  la caja sostenida, cuenta como `CAJA` sobre una caja `en_mano`, y la cadena termina en la mano.
- **Sacar una caja de abajo de una columna:** las de arriba caen (`reposicion_manual.gd`) y se
  vuelven a medir al quedar en reposo. Si caen al piso, ordenar se descumple.
- **Una caja rescatada por la red de seguridad en la jornada 1:** vuelve a su pose de la pila, no
  a la estantería. Si volviera a la estantería, ordenar se cumpliría sin que el jugador la lleve.
- **Una partida continuada desde el guardado:** arranca en la jornada 2 o más, y abre con las cajas
  en las estanterías. Una partida nueva arranca en la 1, con la pila.
- **La jornada 1 en esta tanda todavía tiene las tres bolsas sueltas:** tirarlas no cumple ninguna
  obligatoria, porque la 1 no declara sacar la basura, y no anota un llamado (`BR-CLN-031`).
  Depositar la tercera no llama a `completar()` con algo que no es `null`.
- **Las jornadas 3, 4 y 5:** el parte trae cuatro líneas y la nota cuatro renglones. Cumplir las
  cuatro es «todas».
- **Lo que no cambia:** el texto de las demás líneas del parte, la tapa del contenedor y lo que
  cuenta como desorden.

