---
name: to-issue
description: "Escribe y publica un issue de No se fía, o varios de una, con formato task-brief — el plan chico y descartable de un cambio puntual — y decide si cada cambio toca un spec. Usar apenas llega un pedido, un bug o una idea que se va a hacer, antes de abrir la rama; también con «abrí un issue», «armá el ticket» o la salida de shape en modo issue. Si el issue cambia lo que el juego tiene que hacer, después va to-spec. No escribe código ni specs."
argument-hint: "[pedido | bug | idea]"
---

# to-issue — el plan de un cambio

**Un issue y un spec son cosas distintas.** El issue es un plan chico: resuelve un problema
puntual, tiene límites y criterios propios, y se descarta al cerrar su PR. El spec es el contrato
durable de una funcionalidad. Un issue toca un spec sólo cuando cambia lo que el juego tiene que
hacer. Muchos issues no tocan ninguno.

**No deja deuda**, y eso está en [`sin-deuda.md`](sin-deuda.md).

## Cuándo vale un issue

Casi siempre, y nunca a la fuerza. Un issue deja escrito qué se hace y cómo se sabe que está.
Si el usuario pide un arreglo para ahora y no quiere issue, se hace sin issue: un `bugfix/` o un
`improvement/` no lo exigen. Ofrecelo una vez y seguí.

## Paso 1 — Qué clase de cambio es

| Tipo | Qué es | Etiqueta | ¿Toca un spec? |
|---|---|---|---|
| `feature` | una funcionalidad nueva, cambiada o que se quita | `enhancement` | **siempre**: crea, modifica o borra |
| `bugfix` | el juego no hace lo que ya tiene que hacer | `bug` | casi nunca |
| `refactor` | el mismo comportamiento con otra forma | `refactor` | nunca |
| `improvement` | todo lo demás que no cambia ninguna regla: UI, arte, sonido, rendimiento, documentación, accesibilidad | `improvement`, más `documentation` o `accessibility` cuando aplica | nunca |

La etiqueta la pone `gh issue create --label`. Las de gestión —`duplicate`, `invalid`,
`wontfix`, `question`, `good first issue`, `help wanted`— no dicen de qué tipo es el cambio:
dicen en qué estado está el issue, y van sobre cualquier tipo.

**La prueba para el spec es una sola: ¿cambia lo que el juego tiene que hacer?** Una regla
nueva, un valor de balance, un comportamiento que el GDD fija, una funcionalidad que se quita.
Si la respuesta es sí, el tipo es `feature`.

**Un hotfix no es un tipo de issue.** Es un commit directo sobre `staging`, con el mensaje
empezando por `hotfix:`. No lleva issue, rama ni PR.

Un `bugfix` toca un spec en un solo caso: el bug era una regla que nadie había escrito. Ahí la
regla se escribe con el arreglo.

Si el tipo no está claro, preguntá. Es la decisión que define la rama y el resto del flujo.

## Paso 2 — Medir antes de escribir

**Los límites de archivo y los criterios salen del árbol de hoy, no de la memoria.**

```bash
rg -n "<lo que el issue va a tocar>" src/ test/ docs/   # una guía también describe la regla
gh issue list --state open --limit 50      # si ya hay uno igual, no se abre otro
```

Consultá `nosefia-index` para saber quién usa lo que vas a tocar. Lo que aparece ahí entra en
«Sólo lectura» o en «No se toca».

## Paso 3 — Escribir el issue

**El borrador sale del template, nunca de memoria.** Arrancalo con el script y llená el archivo
que deja:

```bash
python .claude/skills/to-issue/scripts/borrador.py nuevo <archivo del scratchpad>
```

Copia el [task-brief](../../../.github/ISSUE_TEMPLATE/task-brief.md) sin su encabezado. Se llenan
los huecos y no se agregan ni se sacan secciones. Los comentarios quedan: GitHub no los muestra.
Lo que más se rompe:

- **Un issue, un problema.** Completá esta frase: «después de este issue, <algo observable>». Si
  no se completa, el corte está mal. Si se completa con dos cosas sin relación, son dos issues.
- **Los criterios son del issue**, binarios y con los valores que deciden. Si el issue toca un
  spec, los `AC-<COD>-###` nuevos o cambiados van también acá, y **los escribe `to-spec`**, no
  este skill. Acá se nombran por lo que tienen que decir.
- **La fila «No se toca» es una lista cerrada que prohíbe.** Ahí van los `.tscn` que otro issue
  en vuelo edita: una escena no se mergea. Si dos issues tocan la misma escena, el segundo dice
  `Depende de #N`.
- **El primer comando de verificación es siempre `python .claude/scripts/verificar.py`.** El
  veredicto sale del código de salida, nunca de un grep.
- **Un comando que prueba una ausencia se corre hoy, y devuelve todo lo que el criterio saca.**
  Si deja casos afuera, se amplía. Si no se puede, el criterio nombra el test que los cubre. En
  el #140, el `rg` de la verificación no veía los productos de la raíz del modelo.
- **Un valor de balance no se inventa.** Un costo, un tiempo o un umbral sale del GDD o del
  dominio. Si ninguno lo fija, el criterio lo nombra como pregunta abierta y `to-spec` lo
  registra. Un número propuesto por el agente se lee como decidido.
- **Un síntoma medido se reproduce en las condiciones del criterio antes de pedir su rojo.** Si
  el criterio excluye un caso —un obstáculo, un cuadro de transición—, la medición también lo
  excluye. En el #187, los saltos de lo que se lleva se midieron en el local, y eran del brazo
  rozando un mueble: en un piso libre no había rojo que pedir.
- **Los bordes van escritos.** El caso feliz lo cubre cualquier implementación.
- **Un criterio de rendimiento dice desde dónde se mide, y desde ahí se ve lo que el cambio
  agrega.** Lo que no está en pantalla puede no costar nada. En el #181, el p95 se medía desde
  donde arranca el jugador, el agua del baño no se veía desde ahí, y su simulación estaba en
  pausa: el criterio salía verde sin medir el agua.
- **Una tabla de ejemplos cierra consigo misma.** Cada fila se recalcula desde la regla antes de
  escribirla, y una hora de cierre es apertura más duración, no un número copiado de la ficha.
- **Un objetivo numérico se mide con la propuesta del issue antes de publicarlo**, y un criterio
  que agrupa archivos se corre contra el árbol. En el #267, productos a 512 y el resto a 1024
  daban 30,9 MB contra un tope de 30, y agrupar por carpeta dejaba cinco etiquetas afuera: 31,3.
  El carril tuvo que sumar una recompresión que el issue no traía.
- **Un criterio que depende del modelo se mide sobre el modelo, o se escribe como pregunta.** En
  el #262, «umbral 8 de frente» y «los estantes se achican» salieron sin medir: 10 de los 31
  productos no entraban ocho de frente donde el issue los ponía, y el umbral lo decidió el
  usuario mirando las capturas del PR.
- **Una textura sobre una malla que ya existe se cruza con sus UV y con la cara que ve el
  jugador.** En el #264, la etiqueta de cada caja caía en las caras ±X, y la fila del fondo del
  depósito le mostraba al cuarto la +Z: desde ahí no se leía ningún nombre. En el #262, los
  laterales de Actroncito caían en una zona lisa del atlas.
- **Un valor nuevo en un enum del dominio lleva a «Se escribe» todo lo que se indexa con él.** No
  sólo el catálogo: la escena que declara uno por valor, las miniaturas, las tablas. El `rg` del
  enum corre sobre `src/`, `test/` y `assets/`. En el #262, las 23 cajas del depósito vivían en
  `objetos_del_almacen.tscn` y la planilla pedía una miniatura por producto: ninguna de las dos
  estaba en los límites.
- **Cada suite de «Se escribe» se cuenta contra el tope de 20 métodos públicos de `gdlint`**, con
  `rg -c '^func [a-z]'`: cuentan también `before_test` y cualquier ayudante sin `_`. En el #277,
  `repositor_test.gd` tenía 19 casos y 20 métodos, y el issue le pedía uno más. Si una ya está
  en el tope, el issue dice adónde van los casos nuevos. En el #176, `reposicion_manual_test.gd`
  estaba en 20 y `caja_que_se_lleva_test.gd` en 19, y la suite nueva no estaba en los límites.
- **Un issue que suma cuerpos al grupo `interactuable` mide lo que cuesta la mira.** Se mide
  `_leer_la_mira` en el pasillo más cargado, con la mano vacía y con algo en la mano. En el
  #265, pasar de una zona por producto a una por casillero multiplicó por 60 lo enfocable, y la
  lectura pasó de 30 µs a 2 ms por paso de física.
- **Si el issue cambia cuántos nodos crea un puesto, el `rg` busca los tests que filtran sus
  hijos por tipo.** Un `is StaticBody3D` no nombra lo que cambia. En el #265,
  `estante_test.gd` contaba un cuerpo por producto, y costó una corrida entera.
- **Un gesto que deshace la condición de una obligatoria dice qué pasa con ella.** En el #265,
  agarrar una unidad colocada descumplía reponer, y el issue no lo decía (`BR-SHF-007`).
- **Una lista que reparte un conjunto suma el total.** Si el issue divide los productos en dos
  grupos, los dos grupos se cuentan contra el catálogo. En el #264, las cajas con textura y sin
  textura eran 19 y 11 de 31: Malbardo no estaba en ninguna.
- **Si el issue deja renombrar algo, el `rg` de los límites se corre también sobre los
  comentarios.** Un archivo en «Sólo lectura» que nombra por ruta lo que se renombra queda
  mintiendo, y el implementador no lo puede tocar.
- **Si el issue borra un nombre, «Verificación» lleva el `rg` que lo prueba**: `rg -i <nombre>
  src test specs docs .claude` da cero. El carril lo corre también después de mergear otra
  rama, porque un carril en vuelo puede sumarle un lector. En el #266, un caso de #176, escrito
  en otro carril, cargaba `trapeador.tres`, y la corrida entera salió 6/7.
- **Si el issue cambia una regla, el `rg` de los límites busca también la regla vieja en
  palabras.** Un símbolo no encuentra el comentario que explica la regla con otras palabras, ni
  el test que arma el estado que la regla lee. En el #166 quedaron fuera de «Se escribe» cinco
  archivos con comentarios y un test.
- **Y busca a cada lector del valor que se mueve, en `src/` y en `test/`.** El contrato sigue a
  todos, no al primero. En el #263 el cupo dejaba de ser `.umbral`, pero `faltantes()` y
  `vendibles()` también lo leían. Además, 20 tests armaban con `retirar(` la góndola vacía que el
  issue llenaba. La primera corrida dio 37 casos rojos en 11 archivos fuera de «Se escribe».
- **Un criterio que conserva un enunciado se lee contra lo que el issue retira.** En el #263,
  «`BR-STK-013` sin cambiar su enunciado» nombraba el umbral que el mismo issue sacaba.
- **Si el issue saca una regla, busca qué otra contaba con ella sin decirlo.** Un corte suele
  sostener un invariante que ninguna regla escribe. En el #276, sacar el corte de `BR-STK-017`
  dejaba que la venta alcanzara las unidades en la mano: `BR-STK-018` contaba con que nunca
  pasaran de los casilleros vacíos. Lo encontró el padre al escribir el issue, preguntando qué
  dejaba de ser cierto sin el corte.
- **Si el issue escribe a disco, dice cómo lo aíslan los tests.** Toda suite que levanta la
  escena lee y escribe la ruta real del usuario, y ningún gate lo ve. En el #23 una partida
  guardada cambiaba en qué noche arrancaban unas 28 suites.
- **Un criterio del issue no contradice un criterio `ratified` de otra capacidad.** El `rg` de
  los límites busca la regla también en los specs vecinos. En el #179 la puerta «no se abre»
  chocaba con `AC-PLY-040`, y la puerta ya existía en el modelo.
- **Un borde tampoco, y vale igual contra un spec `draft`.** Un borde que describe un gesto que
  el juego no tiene se implementa inventando la regla que falta. En el #263, «vender una unidad
  de la góndola» chocaba con `BR-CTR-014` —la venta sale del depósito—, y «una partida guardada
  a mitad de noche» describía un guardado que no existe (`AC-SAV-020`).
- **Si el issue cambia un recurso generado, lo que lo genera está en el repo o entra en «Se
  escribe».** Un recurso sin su generador sólo se edita a mano. En el #262, la disposición de la
  góndola salía de un acomodador que vivió en el scratch de una sesión y nunca se commiteó.
- **Un dato nuevo en una clase base entra con sus herederas.** Si cada una lo declara, cada una
  va en «Se escribe». En el #197 faltó `unidad_de_producto.gd`, que hereda de
  `ObjetoDelAlmacen`.
- **«Se escribe» nombra también lo nuevo que el contrato implica**, archivo o carpeta. Si no, el
  implementador lo declara en el PR como un desvío. En el #266 el contrato pedía el balde y la
  mopa en `dominio/`, y quedaron sin nombrar sus scripts, sus `.tres`, los de los tres jabones
  y dos scripts de escena.
- **Un nodo nuevo en una escena se mide contra los tests de esa escena.** En el #192, la red no
  tenía lugar en ningún `.tscn` de «Se escribe». Los tests de cada escena de «Se escribe» se
  buscan con `tests_de` y `quien_instancia` de `nosefia-index`, y cada uno entra a «Se escribe»
  o queda descartado con una línea. En el #266 quedaron afuera cuatro que afirmaban sobre una
  escena entera, y los cuatro salieron rojos recién en la corrida.
- **Un archivo en «Sólo lectura» se lee antes de ponerlo ahí.** En el #201, el enlace de audio
  ataba una sola fuente por señal, y con cinco puertas sonaba una. Tuvo que pasar a «Se
  escribe».
- **Una regla de `.claude/rules/` que cambia pone en «Se escribe» sus copias `AGENTS.md`.**
  `test_copias_de_agents_md.py` da rojo si una copia difiere de su regla. Si una copia vive en
  `src/`, la rama lleva un prefijo del producto, porque `docs/` no escribe en `src/`. En el #231
  faltaron esas copias, y la rama pasó de `docs/` a `improvement/` a mitad del carril.

## Paso 4 — Mostrar y publicar

Primero, el script revisa el borrador contra el template:

```bash
python .claude/skills/to-issue/scripts/borrador.py revisar <archivo del scratchpad>
```

Si sale con 1, nombra lo que falta: una sección que no está o sobra, un hueco sin llenar, un
campo copiado tal cual. Se arregla y se vuelve a correr. **Con un 1 no se muestra ni se publica.**
El único hueco que deja pasar es `<issue>` en la rama: el número no existe hasta publicar.

Mostrá el issue **entero, como va a quedar publicado**, y no un resumen. Esperá la
confirmación. Después:

```bash
gh issue create --title "<qué cambia>" --label <etiqueta> --body-file <archivo del scratchpad>
python .claude/skills/to-issue/scripts/borrador.py numerar <archivo del scratchpad> <N>
gh issue edit <N> --body-file <archivo del scratchpad>
```

`numerar` escribe el número en la rama y revisa sin dejar pasar nada. El cuerpo no se commitea:
el issue es la fuente.

## Varios de una

Con varios issues de una, antes de mostrar nada:

1. **Cruzá las filas «Se escribe» de todos los borradores.** Si dos comparten un archivo,
   elegí cuál va primero y publicalo primero. El otro dice `Depende de #N`, con el número ya
   publicado. Hasta entonces nombra al primero por su título: `<issue>` no sirve, porque
   `numerar` lo reemplaza por el número propio. Sin un archivo en común, el orden da igual.
   Un `.gd` o un spec con cambios chicos en zonas distintas no lleva `Depende de #N`: lo
   resuelve el merge.
2. **Dos issues que se bloquean entre sí son un solo cambio mal cortado.** Cortalo de nuevo antes
   de publicar.
3. **Cruzá también lo que cada uno da por hecho.** Un dato que un issue lee lo entrega él o uno
   anterior, y una regla que un issue escribe no la reescribe el siguiente. Cruzalos además con
   los issues abiertos que tocan el mismo spec: no van en el lote, pero parten de sus reglas. En
   el lote del #262, #263 tomaba el cupo de una fila que ningún issue declaraba, #262 la fijaba en
   8 y #263 la hacía variable, y #176, abierto, suponía un depósito que #263 cambiaba.
4. **Mostrá todos los borradores enteros, cada uno con `revisar` en 0, y esperá un solo sí
   sobre el lote.** Si el usuario aprueba una parte, publicá sólo esa parte. Los demás
   borradores quedan en el scratchpad.

## Al cerrar

Reportá el número del issue, el tipo, y el paso siguiente:

- **Spec: crea, modifica o borra** → `to-spec`, con el issue como entrada, en la rama
  `<tipo>/<N>-<kebab>`: `feature/`, o `bugfix/` si el bug era una regla sin escribir.
- **Spec: ninguno** → `implement-feature`, en la rama `<tipo>/<N>-<kebab>`. Un issue que no toca
  `src/` se nombra por lo que toca: `harness/<N>-<kebab>` o `docs/<N>-<kebab>`.
