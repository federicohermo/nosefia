<!-- Un issue es un plan chico y descartable: resuelve un problema puntual, con límites y
     criterios propios. Un spec es otra cosa: el contrato durable de una funcionalidad.
     Un issue cambia un spec sólo si cambia lo que el juego tiene que hacer. -->

# En la jornada 2, la basura se saca de los tres tachos con clic derecho

## Contexto

**Dependencias:** Depende de #369, #301.

- **Objetivo:** que las tres bolsas de la jornada 2 salgan de los tres tachos del local —el de compradores, el del escritorio y el del baño— con clic derecho, y que ninguna otra noche tenga bolsas.
- **Tipo:** `feature`
- **Spec:** modifica — `specs/store-cleanup/store-cleanup.md` y `specs/player-actions/player-actions.md`
- **Rama:** `feature/370-basura-de-los-tachos`
- **Diseño:** sin pantalla. Fichas: [Particulares de cada jornada](https://app.notion.com/p/3d286efecd9d805fa314caa6345c84a3) (Jornada 2), [Contenedor de basura](https://app.notion.com/p/3dc86efecd9d80f6a6cfc9e9cf068ce7), [Notas](https://app.notion.com/p/3e486efecd9d80caa50dc8dfec402093) y [Chat con el jefe](https://app.notion.com/p/3ea86efecd9d8013a7f7f50db70e3861) («Tarea 5 — Falla la tarea de la jornada 2»).
- **Depende de** el issue #369 («La quinta tarea cambia cada noche, y en la primera es ordenar las cajas del depósito»): ése deja la basura como particular de la jornada 2 sola, con las bolsas sueltas de hoy. Éste cambia de dónde salen.
- **Depende de #301:** #301 mueve el tacho grande del local en el modelo y actualiza el horneado; conserva las escenas sin editar. Este issue lee la ubicación final del tacho y agrega su interacción en `estructura_del_almacen.tscn`.

<!-- `feature` es el único tipo que siempre toca un spec. Un `bugfix` toca uno sólo si el bug
     era una regla que nadie había escrito. La etiqueta sale del tipo: `enhancement`, `bug`,
     `refactor` o `improvement`, y `documentation` o `accessibility` cuando aplica. -->

**Qué hay hoy.** `BR-CLN-007` pone tres bolsas sueltas cada noche, en el piso del depósito,
frente al portón (`objetos_del_almacen.tscn`, nodos `BolsaDeBasura1` a `3`). Se cuentan al
tirarlas con clic izquierdo al contenedor con la tapa abierta (`BR-CLN-009`, #305). Eso no cambia.

**Qué pide la ficha.** En la jornada 2, el jugador saca una bolsa de cada uno de los tres tachos:
el de compradores cerca de la entrada del local, el tachito abajo del escritorio y el del baño.
Mirando un tacho, el clic derecho le pone una bolsa en la mano. El tacho pasa de «con basura» a
«sin basura». Las bolsas sólo se pueden sacar en la jornada 2; las demás noches los tachos se ven
«sin basura». La tarea se cumple tirando las tres al contenedor.

**Medido en el modelo y la escena.**

- Los tres tachos son mallas del modelo con un cuerpo estático importado, sin script ni grupo
  `interactuable`: `tachitobasura` (local, en (7,27; 5,25) antes de #301), `tachitobasura_001`
  (escritorio, en (0,70; 4,30)) y `tachitobasura_002` (baño, en (9,14; 5,46)).
- **No hay arte «con basura» ni «sin basura».** Cada tacho es una sola malla con un solo
  material (`Material.004`). La bolsa de hoy tampoco tiene modelo: es la caja genérica de
  `objeto_agarrable.tscn`, de 12 × 16 × 12 cm. Este issue no pide arte. Decidido por el usuario:
  «con basura» es la bolsa de hoy, visible en la boca de su tacho; «sin basura» es el tacho sin
  ella.
- El contenedor está en (3,00; −14,91). Los tres tachos quedan a más de 19 m, y el destino de #301
  no los acerca a menos de 6 m (`BR-CLN-008`).
- Unas 20 suites de escena usan una bolsa como «algo que se agarra» en la jornada 1. Con este
  issue, en la jornada 1 las bolsas no están en el mundo. La lista sale de
  `rg "_bolsas|BolsaDeBasura|bolsa_de_basura" test/escenas`; la sonda de la inversión no se
  corrió. El carril corre primero esas suites y las que salen rojas pasan a abrir la jornada 2 y
  sacar la bolsa del tacho con un ayudante nuevo.
- `test/escenas/giro_parejo_test.gd` conserva un comentario que sitúa las bolsas en el
  depósito, en el camino a la pared. Esta apertura lo vuelve falso: se corrige sólo ese
  comentario. El código del test, su fixture y sus umbrales permanecen de sólo lectura.
- La base integrada de #369 agrega una expectativa del nombre de la quinta tarea en
  `test/escenas/deposito_ordenado_test.gd`. Se actualiza sólo ese texto a «Tirar la basura»,
  conservando la auditoría de cajas, el recorrido de jornadas y sus umbrales.

- La inspección de las matrices de lector, notas, caja registradora, puertas y paneles, y
  del caso de mezcla de útiles, encontró otra premisa: toman directamente `BolsaDeBasura1`.
  Pueden pasar incluso con una bolsa oculta y sin cuerpo en jornada 1. En los casos precisos
  declarados abajo se prepara jornada 2 y se extrae la bolsa por
  `RecolectorDeBasura.sacar_bolsa`, aun si la primera sonda da verde. El ayudante conserva el
  mismo nodo, datos e identidad y lo suelta por `Agarre`; no activa visibilidad ni colisiones
  a mano. La apertura ocurre antes de crear tickets, preparar puertas o cargar y mezclar agua,
  para conservar la premisa original del gesto. Todas las aserciones actuales se conservan.

## Criterios de aceptación

<!-- Los de este issue: binarios y con los valores que deciden. Mueren con el issue.
     Si el issue toca un spec, acá van también los `AC-<COD>-###` que agrega o cambia: ésos
     sí duran, y un test los cita. -->

**Las bolsas salen de los tachos (`specs/store-cleanup`)**

- [ ] `BR-CLN-007` se reescribe: CUANDO abre una jornada que declara sacar la basura, el sistema
  DEBE poner una bolsa en cada uno de los tres tachos —el de compradores del local, el del
  escritorio y el del baño—. Las demás jornadas DEBEN abrir con los tres tachos sin bolsa. Tres
  bolsas siguen siendo más que las manos disponibles.
- [ ] Una regla nueva: CUANDO el jugador usa —clic derecho— un tacho con bolsa y la mano vacía,
  el sistema DEBE ponerle la bolsa de ese tacho en la mano y dejar el tacho sin bolsa. SI el
  tacho no tiene bolsa, o la mano no está vacía, ENTONCES NO DEBE cambiar nada.
- [ ] `AC-CLN-007` se reescribe: DADO la jornada 2 abierta, ENTONCES hay 3 tachos con bolsa, con
  identidades distintas, y son más que las manos. DADO las jornadas 1, 3, 4 y 5 abiertas,
  ENTONCES los tres tachos están sin bolsa y ninguna bolsa está en el mundo.
- [ ] Un `AC-CLN` nuevo, en el dominio: DADO un tacho con bolsa y la mano vacía, CUANDO se lo usa,
  ENTONCES la bolsa queda en la mano y el tacho sin bolsa. CUANDO se lo usa otra vez con la mano
  vacía, ENTONCES no pasa nada. DADO un tacho con bolsa y la mano ocupada, ENTONCES no pasa nada
  y el tacho conserva su bolsa.
- [ ] Un `AC-CLN` nuevo en la escena: DADO la jornada 2, CUANDO se enfoca cada tacho y se hace clic
  derecho con la mano vacía, ENTONCES la mano lleva una bolsa y la boca de ese tacho deja de
  mostrarla. CUANDO se tiran las tres al contenedor con la tapa abierta, ENTONCES sacar la basura
  queda cumplida y el HUD sube en 1.
- [ ] `BR-CLN-008` y `AC-CLN-008` miden desde los tres tachos, y no desde un arranque en el
  depósito: el contenedor queda a 6 m o más de cada tacho y de las tareas del local.
- [ ] `AC-CLN-012` dice «las tres bolsas de la jornada 2» y conserva su borde de una pendiente.
- [ ] `AC-CLN-038` se reescribe para la bolsa: DADO una bolsa tirada en la jornada 2, CUANDO abre
  otra noche, ENTONCES no está en el mundo. La mopa y el balde conservan su vuelta de hoy.
- [ ] Los tres tachos son enfocables y su contorno aparece al mirarlos desde un punto libre del
  piso a no más de `ReglasDelJugador.ALCANCE_DE_LA_MIRA`.

**El nombre en la nota (`specs/player-actions`)**

- [ ] `BR-PLY-030` y `AC-PLY-069` dicen «Tirar la basura», que es el título de la jornada 2 en la
  ficha, en lugar de «Sacar la basura». La nota de la jornada 2 lo dice en el quinto renglón.

## Contrato

<!-- Sólo si aparecen firmas, señales o datos nuevos. Cada uno con su capa y su tipo de
     retorno. El caso de falla va junto al de éxito. -->

- **`dominio/almacen/tarea_de_la_basura.gd`:**
  - `enum Tacho { LOCAL, ESCRITORIO, BANO }`.
  - `static func de_la_jornada(jornada: int) -> TareaDeLaBasura`: con `Apertura` declarando
    `SACAR_LA_BASURA` para esa jornada, una bolsa por tacho; si no, ninguna. Reemplaza a la
    versión sin argumento.
  - `func tiene_bolsa(tacho: Tacho) -> bool`.
  - `func sacar(tacho: Tacho, mano_vacia: bool) -> StringName`: el `id` de la bolsa que sale, o
    `ObjetoDelAlmacen.SIN_ID` si el tacho no tiene bolsa o la mano no está vacía. Sin efecto en
    ese caso.
  - `depositar()`, `bolsas()`, `depositadas()` y `completada()` siguen como hoy. Los `id` siguen
    siendo `bolsa_de_basura_1` a `3`, uno por tacho en el orden del `enum`.
- **`dominio/almacen/reglas_de_la_basura.gd`:** `BOLSAS_DE_LA_JORNADA` pasa a contar las bolsas de
  la jornada que declara la basura, una por tacho.
- **`sistemas/tareas/recolector_de_basura.gd`:** `func sacar_bolsa(tacho: TareaDeLaBasura.Tacho)
  -> bool` le pide al dominio el `id`, y con uno válido le pide al `Agarre` que tome el cuerpo de
  esa bolsa. Emite `bolsa_sacada(tacho)`.
- **`escenas/puestos/tacho_de_basura.gd` (nuevo):** el script de cada cuerpo de tacho en
  `estructura_del_almacen.tscn`, con `@export var tacho: TareaDeLaBasura.Tacho` y el grupo
  `interactuable`. Dibuja «con bolsa» o «sin bolsa». No decide nada.
- **`escenas/almacen.gd`:** conecta `jugador.uso_pedido` con el tacho enfocado y el recolector.
  Al abrir cada noche ubica cada bolsa en la boca de su tacho, congelada y sin colisión, si el
  dominio dice que tiene bolsa; si no, la deja fuera del mundo, oculta y sin colisión.
- **Ayudante de tests (nuevo):** `test/escenas/bolsa_en_la_mano.gd`, que abre la jornada 2 y saca
  una bolsa de un tacho, para las suites que usan una bolsa como objeto agarrable.

## Límites de archivos

| Categoría | Rutas |
|---|---|
| **Se escribe** | `specs/store-cleanup/store-cleanup.md`; `specs/player-actions/player-actions.md`; `src/dominio/almacen/tarea_de_la_basura.gd`; `src/dominio/almacen/reglas_de_la_basura.gd`; `src/dominio/almacen/nota_pegada.gd` (sólo el nombre de `SACAR_LA_BASURA`); `src/sistemas/tareas/recolector_de_basura.gd`; `src/escenas/puestos/tacho_de_basura.gd` y su `.uid` (nuevos); `src/escenas/puestos/estructura_del_almacen.tscn` (el script y el grupo de los tres cuerpos de tacho); `src/escenas/puestos/objetos_del_almacen.tscn` (los tres nodos `BolsaDeBasura`); `src/escenas/almacen.gd`; `test/dominio/almacen/tarea_de_la_basura_test.gd`; `test/dominio/almacen/reglas_de_la_basura_test.gd`; `test/dominio/almacen/nota_pegada_test.gd`; `test/escenas/objetos/nota_pegada_test.gd` (afirma el nombre visible de la basura); `test/sistemas/tareas/recolector_de_basura_test.gd`; `test/escenas/bolsa_en_la_mano.gd` y su `.uid` (nuevos); `test/escenas/puestos/tachos_de_basura_test.gd` y su `.uid` (nuevos); `test/escenas/objetos/ubicacion_en_el_deposito_test.gd` (`test_las_tres_bolsas_arrancan_en_el_deposito_y_lejos_del_contenedor` pasa a los tachos); `test/escenas/puestos/contenedor_de_basura_test.gd`; `test/escenas/jornada_integrada_test.gd`; `test/escenas/deposito_ordenado_test.gd` (sólo la expectativa del nombre «Tirar la basura» de la quinta tarea de jornada 2); `test/escenas/puestos/tiro_al_contenedor_test.gd`; `test/escenas/consecuencias_del_contenedor_test.gd`; `test/escenas/cierre_del_almacen_test.gd`; `test/escenas/giro_parejo_test.gd` (sólo corregir el comentario que sitúa las bolsas en el depósito; sin cambiar código, fixture ni umbrales); `test/escenas/puestos/lector_test.gd` (sólo preparar una bolsa real en `test_los_seis_objetos_se_rechazan_y_siguen_en_la_mano`); `test/escenas/puestos/notas_del_almacen_test.gd` (sólo esa precondición en `test_cada_objeto_sigue_en_la_mano_al_leer_y_salir`); `test/escenas/puestos/caja_registradora_test.gd` (sólo esa precondición en `test_el_derecho_abre_y_cierra_con_los_ocho_estados_de_la_mano` y `test_lavatorios_otros_objetos_y_papel_ajeno_no_se_desechan`, con apertura de jornada antes de tickets y puertas); `test/escenas/uso_en_el_almacen_test.gd` (sólo esa precondición en `test_el_derecho_abre_las_dos_puertas_con_cualquier_mano` y `test_el_derecho_abre_y_cierra_paneles_con_cualquier_mano`, mediante su ayudante `_cosas_de_la_mano`); `test/escenas/objetos/utiles_de_limpieza_test.gd` (sólo esa precondición en `test_la_mezcla_espera_aunque_se_suelten_los_utiles_en_otro_cuarto`, abriendo jornada 2 antes de cargar y mezclar agua; sin cambiar las aserciones). Estas correcciones puntuales de premisa se permiten aunque la sonda inicial dé verde; no trasladan suites enteras a jornada 2; y, de las que salgan rojas en la primera corrida, `test/escenas/agarre_fisico_test.gd`, `test/escenas/campo_de_interaccion_test.gd`, `test/escenas/hoja_que_arrastra_test.gd`, `test/escenas/lo_soltado_fuera_de_los_solidos_test.gd`, `test/escenas/objetos/utiles_de_limpieza_test.gd`, `test/escenas/puestos/caja_registradora_test.gd`, `test/escenas/puestos/lector_test.gd`, `test/escenas/puestos/notas_del_almacen_test.gd`, `test/escenas/puestos/tapa_del_contenedor_test.gd`, `test/escenas/red_de_seguridad_integrada_test.gd`, `test/escenas/reposicion_completa_test.gd`, `test/escenas/reposicion_manual_test.gd`, `test/escenas/uso_en_el_almacen_test.gd` |
| **Sólo lectura** | `src/dominio/jornada/apertura.gd`; `src/dominio/almacen/reglas_del_cierre.gd`; `src/dominio/almacen/objeto_del_almacen.gd`; `src/dominio/almacen/bolsa_de_basura_1.tres`, `_2.tres` y `_3.tres`; `src/sistemas/marco/agarre.gd`; `src/sistemas/marco/reloj_del_turno.gd`; `src/escenas/jugador.gd`; `src/escenas/objetos/objeto_agarrable.gd`; `src/escenas/objetos/objeto_agarrable.tscn`; `src/escenas/puestos/contenedor_de_basura.gd`; `src/escenas/puestos/tapa_del_contenedor.gd`; `test/escenas/giro_parejo_test.gd` (código, fixture y umbrales; se exceptúa sólo el comentario autorizado en «Se escribe»); `test/escenas/modelo_integrado_test.gd` |
| **No se toca** | `assets/models/`; `src/escenas/almacen.tscn`; `src/escenas/almacen.lmbake` y `src/escenas/almacen.exr`; `src/escenas/puestos/limpieza_del_almacen.tscn`; `src/escenas/puestos/notas_del_almacen.tscn`; `src/escenas/objetos/caja_de_productos.gd`; `src/escenas/puestos/notas_del_almacen.gd`; `specs/shift-cycle/shift-cycle.md`; `specs/store-stock/store-stock.md` |

<!-- La tercera fila es una lista negativa y cerrada. Un `.tscn` que otro issue en vuelo edita
     va siempre acá: un merge de tres vías sobre una escena da una escena corrupta. -->

## Verificación

<!-- Comandos que devuelven código de salida 0. El veredicto sale del código de salida,
     nunca de un grep de la salida. -->

1. `python .claude/scripts/verificar.py`
2. `! rg -n "TareaDeLaBasura\.de_la_jornada\(\)" src test` — no queda la versión sin jornada.
3. `! rg -n "Sacar la basura" src test specs/player-actions` — el nombre viejo de la nota salió. Se conserva el título histórico «Sacar la basura» en la procedencia de `specs/store-cleanup/store-cleanup.md`.
4. `rg -n "AC-CLN-007" test/escenas/puestos/tachos_de_basura_test.gd test/dominio/almacen/tarea_de_la_basura_test.gd` encuentra sus casos.
5. El PR trae una captura de cada tacho de la jornada 2 antes y después de sacar su bolsa, tomada desde donde el jugador lo enfoca, y el padre abre los PNG.

## Bordes

<!-- El caso feliz lo cubre cualquier implementación. Acá van los límites: cero, uno, el
     máximo, el valor justo antes del corte, el que llega dos veces. -->

- **Clic derecho en un tacho en la jornada 1, 3, 4 o 5:** no pasa nada y la mano no cambia.
- **Dos clics derechos seguidos en el mismo tacho de la jornada 2:** el primero da la bolsa; el
  segundo, con la bolsa en la mano, no hace nada.
- **Clic derecho con una bolsa en la mano sobre otro tacho con bolsa:** no pasa nada. La bolsa no
  vuelve a un tacho: ningún gesto la devuelve.
- **Clic izquierdo sobre un tacho:** no tira ni agarra nada. Tirar sigue siendo sólo al
  contenedor (#305).
- **Una bolsa sacada y soltada en el piso del local al cerrar la jornada 2:** no produce desorden
  (`BR-CLN-028`). Si quedó afuera por la ventanilla, produce el llamado por objeto afuera
  (`BR-CLN-029`).
- **Una bolsa en la mano al cerrar la jornada 2:** sacar la basura queda sin cumplir; la mano
  queda vacía al abrir la 3, y la bolsa no está en el mundo.
- **Tirar una bolsa al contenedor:** no anota el llamado por objeto importante (`BR-CLN-031`).
- **La red de seguridad rescata una bolsa ya sacada:** vuelve a su lugar de origen como cuerpo
  libre y se recoge con clic izquierdo. El tacho no vuelve a tener bolsa para el dominio, y la
  bolsa conserva su `id`: tirarla sigue contando una sola vez.
- **La mira sobre la bolsa en la boca del tacho:** enfoca el tacho, no la bolsa. La bolsa en el
  tacho no tiene cuerpo hasta que sale.
