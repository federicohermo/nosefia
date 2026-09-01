---
name: spec-review-batch
description: Revisa N specs de specs/ en paralelo —un agente por spec— más un carril de coherencia que caza las contradicciones ENTRE specs mientras todavía son texto editable, y cierra devolviendo las ediciones a los issues. Usar al revisar dos o más specs de una. Para uno solo, spec-review.
argument-hint: "<NNN NNN ...> | <NNN-MMM> | --propuestos [--dry]"
# Sin `allowed-tools`, igual que `spec-implement` y `spec-review`. Este skill abanica N+1
# agentes, corre el harness en Python, habla con GitHub por `gh` y escribe adentro de
# `specs/`: declarar una lista parcial le sacaría todo lo que no estuviera en ella y lo
# rompería en silencio a mitad de corrida, que es el modo de falla que este repo persigue.
---

# spec-review-batch — No se fía

## Matriz del lote

<!-- Inyección dinámica: el comando corre ANTES de que el modelo procese este archivo, así que
     la matriz llega con el skill ya cargado en vez de costar un turno de tool (la llamada más
     su resultado). `lote.py` entiende las tres formas del `argument-hint`, que es lo que deja
     pasarle `$ARGUMENTS` crudo sin un caso especial, e ignora `--dry` porque ése es un flag
     del skill y no suyo.

     La ruta sale de `${CLAUDE_SKILL_DIR}` y no está escrita a mano: es lo que deja mover,
     renombrar o empaquetar el skill sin editar su propio contenido. Y va con `python`
     adelante porque en Windows un `.py` no es ejecutable por sí solo. -->

!`python "${CLAUDE_SKILL_DIR}/scripts/lote.py" $ARGUMENTS`

---

Un review de spec audita **uno** contra el repo. Este audita **N contra el repo y entre sí**.

Lo segundo es el entregable: una contradicción entre dos specs del lote no la ve ningún review
suelto, porque cada uno mira una carpeta. Y acá sale barata — arreglarla es un párrafo. La misma
contradicción sobrevive intacta hasta que dos ramas del lote se pisan, y ahí ya cuesta un rebase.
Si las dos tocan la misma escena, no cuesta un rebase: cuesta la escena.

**Y se arregla, no se anota.** Las cinco descargas de
[`sin-deuda.md`](sin-deuda.md) valen enteras acá, con una ventaja que ningún otro
skill tiene: **el trabajo todavía es texto**, así que hasta el hallazgo que excede al lote se
descarga barato — es un spec más, y este skill está parado justo en el momento de escribirlo.

## Por qué no hay worktrees

Revisar el lote y **implementarlo** se abanican distinto, y confundirlos es el error caro:

|  | implementar el lote | revisarlo (acá) |
|---|---|---|
| Qué se abanica | una cadena de specs entera | **un spec** |
| Ancho | tantas cadenas como haya | **N, siempre** |
| Aislamiento | un worktree por cadena | ninguno: `specs/NNN-*/` ya es disjunta |
| Convergencia | merge de ramas, resuelve texto | el padre escribe lo compartido, resuelve semántica |
| Qué arregla un choque | una resolución de merge | **nada**: la última escritura gana en silencio |

Un review no compila, no corre `verificar.py` y no toca `src/`: lee el árbol y escribe adentro de
la carpeta de su spec. Esa disyunción es lo único que hace segura la concurrencia, y por eso la
regla del Paso 3 no es una precaución sino la condición.

**Una cadena de anclaje no serializa.** Implementar el 002 necesita el 001 *en el árbol*;
revisarlo necesita el 001 *escrito*, y ya lo está. Por eso el ancho es N aunque los specs se
citen en fila.

**Y el gate del hook no frena nada de esto**: `.claude/` y `specs/` no están entre las rutas
protegidas, a propósito. Este skill no necesita rama de feature ni la abre.

---

## Paso 0 — Resolver el lote y los gates

`$ARGUMENTS`: números sueltos (`001 002 003`), un rango (`001-003`), o `--propuestos` = todos los
`Propuesto` de `specs/mapa.json`. **Sin argumentos, preguntá**: no asumas los últimos.

- **Sacá los terminales.** `Descartado` y `Superado` no se revisan: son historia, y corregir
  historia es inventarla. Decí cuáles sacaste.
- **Hidratá, y hidratá TODO, no sólo el lote.**

  ```bash
  python .claude/scripts/hidratar_specs.py            # los que están en vuelo y falten
  python .claude/scripts/hidratar_specs.py --todos    # si el lote cita specs ya cerrados
  ```

  `specs/[0-9]*/` está en el `.gitignore`, así que el directorio es una **caché** que puede no
  estar. Sin esto los agentes revisan un directorio vacío y **no falla**: revisan un spec que no
  leyeron, y reportan igual.

  **Y hay un segundo motivo, que es el que muerde al cerrar.** El Paso 5 sube las ediciones con
  `publicar_spec.py publicar`, y esa fase **recorre todas las carpetas que haya en disco**, no
  las del lote: sobreescribe el issue de cada una con lo que el disco diga. Una carpeta vieja que
  quedó de otra corrida se sube encima de un issue que ya era más nuevo, y se lleva puesto lo que
  el issue tenía. Con el árbol hidratado antes de empezar, esas carpetas son idénticas al issue y
  subirlas es un no-op.
- **Buscar adentro de los specs necesita `--no-ignore`.** `Grep` es ripgrep y respeta el
  `.gitignore`, así que contesta **cero sin decir que no miró** — que es la peor respuesta
  posible. Va en el preámbulo del Paso 1, literal, porque cada agente lo va a necesitar:

  ```bash
  rg --no-ignore "lo que sea" specs/
  ```
- **Loop activo.** `git worktree list` y `git branch --list "feature/*"`: el spec que ya tenga
  rama o worktree abierto está **en implementación**, y cae a `--dry` **él solo**, no el lote.
  Revisarlo sirve igual; editarle el `tasks.md` por debajo a quien lo está marcando, no. Al resto
  del lote no se le mueve el piso por un vecino.

Con `--dry` no se escribe nada: ni ediciones, ni issues, ni `publicar`. Se corre hasta el reporte
y ahí termina.

## Paso 1 — El preámbulo, destilado una vez

Es el ahorro propio del batch: sin esto, N reviews lo re-derivan N veces desde frío. Cinco
insumos, y los cinco se pasan **destilados**, no como rutas a leer:

- **El registro**: las filas del lote en `specs/mapa.json` —`issue`, `estado`, `origen`—. El
  `#N` del issue **no se deduce del `NNN`**: son dos numeraciones y en este repo ya divergen (el
  spec 001 es el issue #3). Todo lo que un agente escriba citando un issue sale de acá.
- **El mapa síntoma → deuda**, que es el eje D entero:
  ```bash
  python .claude/scripts/deuda.py     # los issues abiertos que ningún spec reclama
  ```
  Un spec nunca dice *replico la deuda #7*: eso lo traduce el review, y sólo puede hacerlo con la
  lista adelante.
- **Lo que ya se probó y no funcionó**, que en este repo vive como **comentarios en el issue de
  cada spec** y no en ningún archivo: `gh issue view <N> --repo federicohermo/nosefia --json
  comments`.
- **Las convenciones verificables, ≤40 líneas**: `CLAUDE.md`, más los `.claude/rules/` de las
  capas que el lote toca, más **quién verifica cada una** — que es el dato que cambia el
  hallazgo. Una regla que verifica `gate_de_capas.py` no necesita hallazgo de review: la va a
  frenar sola. Una que es prosa, sí.
- **Las trampas del repo**, las cuatro de `CLAUDE.md`, y de ellas la que decide reparto: **un
  `.tscn` no se mergea**.

## Paso 2 — El orden del lote es la base de anclaje

El eje A del review suelto pregunta *¿el spec describe el repo que existe?*. En un lote encadenado
esa pregunta está mal formulada para todos menos el primero: el 002 cita cosas que el 001 crea.

**La base de cada spec es `staging` + los specs del lote que lo preceden.** Derivá el orden y
pasáselo a cada agente, o el lote devuelve una avalancha de citas rotas falsas.

1. **La matriz ya está arriba**, inyectada por [`scripts/lote.py`](./scripts/lote.py) al cargar
   este archivo. No la vuelvas a pedir por Bash — ya la tenés. Si arriba salió un mensaje de uso
   en vez de la matriz, el lote está mal escrito y eso se resuelve en el Paso 0.
2. **Leé la matriz con este descuento, que está medido acá el 2026-08-28** sobre el lote
   001 002 003: `verificar.py` sale compartido por los tres y `specs/mapa.json` por dos, y
   **ninguno de los dos es una arista**. Los cita el ritual de cierre que todo `tasks.md` de este
   repo tiene —correr los seis nodos, y no tocar el mapa dentro del PR—, así que van a aparecer en
   **todos** los lotes. `lote.py` no los filtra a propósito: filtrar por el verbo de la tarea es
   adivinar, y un script que adivina se equivoca en silencio. El que descuenta sos vos, y lo
   decís.
3. **La marca que sí es una conclusión es `<- ESCENA COMPARTIDA`.** Para todo lo demás, compartir
   un archivo dice *dónde mirar*; para un `.tscn` dice *qué hacer*: se ordena, no se paraleliza.
   Un `[P]` entre dos tareas que tocan la misma escena es bloqueante en los dos specs.
4. **La matriz sale de los `tasks.md` y de ningún otro archivo** —`lote.py` los lee y nada
   más—, así que **un archivo que un spec edita sin darle tarea propia es invisible acá**. El
   caso está medido: en el lote 004–010, el 2026-08-30, `src/escenas/almacen.gd` lo escriben el
   007, el 008 y el 009, y sólo aparece en los `plan.md` de los dos últimos. La matriz no lo
   listó, y con él se perdía que el AC22 del 007 —que prohíbe ramas en ese archivo— lo verifica
   una tarea del 007 que corre **antes** de que los otros dos escriban sus líneas.

   No se arregla haciendo que `lote.py` lea los cuatro archivos: los `research.md` citan medio
   repo y la matriz se volvería ruido. **Se arregla acá**, con un barrido propio: `rg --no-ignore`
   sobre los `plan.md` del lote buscando rutas de `src/`, y todo lo que aparezca en dos specs y
   no esté en la matriz es una arista que el Paso 2 no vio.

4. **Los pares `X -> Y`** del tercer bloque son la arista que ningún `preload` ni ningún
   `class_name` delata. Salen de la **línea** de la tarea y no de su prosa, y vienen como texto y
   no como número: hay pares con coma decimal que un `float()` convierte en un error.
5. **Contrastá el grafo contra lo que los specs declaran.** Eso dice qué quiso el autor; la
   matriz dice qué archivos se pisan. **Si difieren, ése es el hallazgo**, y se corrige en el
   `tasks.md` que lo declara.
6. Un spec que **declara tolerar** llegar antes que su dependencia sale de la cadena: es permiso
   escrito, no un olvido.

Con el orden en mano, el eje A cambia de forma para todo spec que no sea el primero:

- Una cita a algo que **no existe hoy** no es cita rota si un spec anterior del lote lo crea. El
  hallazgo es el inverso: que el anterior **no** lo cree.
- Una cita con número de línea a un archivo que un spec anterior reescribe **está podrida por
  construcción**. Se re-ancla a un símbolo, o el enunciado declara contra qué base vale.
- Un número que aparece como `X -> Y`: el `X` de abajo tiene que ser el `Y` de arriba, no el de
  `staging`.

## Paso 3 — N agentes de spec, más el de coherencia

Lanzá los **N+1 en un solo mensaje**. Más de ~6 specs conviene en tandas: el cuello no es el
reloj, es que el padre tiene que sostener los reportes para el Paso 4.

### El carril de coherencia

Su unidad de análisis es **el lote**, no el spec. Existe porque el padre no puede hacer ese
trabajo: converge sobre los N reportes, que están comprimidos a 40 líneas cada uno, y un cruce
vive justo en el detalle que ningún reporte comprimido menciona.

- **Corre en paralelo con los demás**, no después: su insumo son los specs, que ya están
  escritos. No espera a que los reviews terminen, así que no cuesta reloj.
- **Es uno solo, y no se reparte por clase de cruce.** Lo único que lo hace funcionar es que hay
  una sola cabeza con los N specs enteros adelante; partirlo re-fragmenta exactamente eso.
- **Lee los specs crudos**, los N enteros —`spec.md`, `research.md`, `plan.md` y `tasks.md`—, más
  la matriz de arriba y el orden derivado en el Paso 2.
- **No edita nada, ni siquiera dentro de una carpeta.** Cada hallazgo suyo abarca dos specs o
  más, y esas carpetas las están escribiendo los agentes de spec en este momento.
- **Su brief son las nueve clases de [`cruces.md`](./cruces.md)**, y las recorre todas: devuelve
  también las que dieron que no, porque un cruce ausente es información y un cruce no mirado no.
- **Devuelve, por hallazgo:** la clase, los dos `path:línea`, **qué AC queda infalsificable** si
  nadie lo toca, y **en qué spec va la edición**. Sin ese último dato el padre no puede aplicar
  nada.

### Los agentes de spec

Uno por spec, cada uno con el preámbulo del Paso 1 y su base del Paso 2. Los seis ejes, y los dos
últimos son los que este motor agrega:

- **Anclaje** — cada ruta, `class_name`, firma y cita con número de línea existe hoy y dice lo
  que el spec afirma. Es el eje que más rinde y el que el Paso 2 reencuadra.
- **Superficie** — todo lo que cita lo que el spec modifica está en el alcance o explícitamente
  fuera. En Godot eso incluye **nombrar un `class_name`**, que es la forma normal de escribir
  código y no deja rastro en ningún `preload`: la búsqueda es por identificador, no por import.
- **Convenciones** — los snippets del spec se leen como el diff que se va a mergear. Si `gdlint`,
  `gdformat` o los dos gates lo rechazarían, el spec ya está mal: tipado en toda firma con
  `-> void` incluido, español, cero `print`, y un valor fijo una sola vez.
- **Deuda** — traducir lo que el spec propone al mapa síntoma → deuda del preámbulo, y verificar
  que su `**Origen:**` **salda** lo que dice saldar y no sólo lo cita.
- **Capas** — la pregunta que decide si el spec es implementable acá: ¿en qué capa cae cada
  regla? Un spec que ubica una regla del juego en un `Node` de `sistemas/` o en una escena la
  hace **nacer sin test**, porque `gate_de_tests.py` no mira `ui/` ni `escenas/`. La corrección
  es bajarla a `dominio/`, y el spec tiene que decirlo. Y `dominio/` es puro: nada de `Node`,
  `get_tree()`, `_process` ni `await` de un timer.
- **Criterios de aceptación** — cada uno **falsable**: «el HUD muestra el tiempo» no lo es; «con
  3 minutos restantes, `tiempo_restante()` devuelve 180.0» sí. Si un AC no se puede ver fallar,
  no verifica nada. Más el AC mecánico y el de no-regresión si hubo superficie compartida.
- **Estructura** — los cuatro archivos, los `T0NN` sin renumerar —renumerar rompe toda referencia
  que otra tarea le hiciera—, `[P]` que no miente, ninguna tarea que se cierre **mirando o
  escuchando**, **ninguna sección que aplace** (`## Seguimiento` y sus alias) y **ninguna tarea
  que aplace** (`TODO`, «por ahora», «más adelante»). Lo verifica `test_convencion_de_specs.py`.
  **Una tarea nueva va con el número libre siguiente y se escribe donde corre**, porque el ID
  no es el orden. El sufijo de letra —`T001a`— **es rojo**: el gate exige tres dígitos exactos
  (`TAREA = ^- \[[ x]\] (T\d{3})( \[P\])? \S`). Medido en el lote 001–002 el 2026-08-30, donde
  los dos agentes lo pisaron el mismo día.
- **Completitud** — la pregunta que ningún gate contesta: **¿las tareas que hay alcanzan para
  cumplir los AC?** Una tarea faltante no rompe nada, no aparece en ningún diff y no se hace
  nunca. Si falta, se escribe acá.

Y este contrato, que es lo propio del batch:

> **No escribís fuera de `specs/<NNN>-*/`.** Ni `docs/`, ni `.claude/rules/`, ni `CLAUDE.md`, ni
> `specs/mapa.json`, ni el issue de ningún spec. Los tocan los N a la vez y no hay merge que lo
> arregle: el `git diff` ni siquiera los ve, porque `specs/[0-9]*/` está ignorado. Devolvelos
> como **edición propuesta**, con `path:línea` y el texto exacto.
>
> **Tampoco abrís ni cerrás issues, ni corrés `publicar_spec.py`.** Esa fase sube **todo el
> árbol**, así que un agente que la corra publica también los specs que los otros están
> escribiendo a medias. La corre el padre, una vez, en el Paso 5.
>
> **Y esta barrera es sólo una línea escrita, que es lo que la vuelve frágil.** Cuando el spec
> del vecino era un archivo suyo, respetar la carpeta propia alcanzaba para no pisarlo. Desde que
> el registro es un issue, nada en la forma de la operación delata que estás escribiendo afuera.

Y devuelve dos cosas: su reporte, comprimido a **40–60 líneas** —veredicto en la primera, después
los bloqueantes con evidencia, y lo editado a conteos—, y esa lista de ediciones propuestas
afuera. Sin la lista, el Paso 5 no tiene qué aplicar.

## Paso 4 — Converger las dos vistas

Vuelven N reportes de spec y uno de coherencia, y **miran cosas distintas a propósito**. El padre
no re-audita: cruza.

- **En cualquier hallazgo que abarque dos specs, manda el de coherencia** — es el único que vio
  los dos lados. Un «cita rota» de un agente que el de coherencia explica como *«eso lo crea el
  001»* no es hallazgo: es la base del Paso 2 funcionando.
- **Al revés también:** si el de coherencia apunta a una línea que el agente de ese spec ya
  editó, el cruce se re-escribe contra el texto nuevo antes de aplicarlo.
- **Si los dos contradicen al orden que derivaste en el Paso 2, gana la evidencia y decilo**: un
  orden mal derivado es un hallazgo sobre el spec que lo declara, no un detalle de proceso.
- **Agrupá las ediciones propuestas por spec DESTINO antes de aplicar ninguna, y contá.** Dos
  agentes que piden lo mismo al mismo spec es la señal más fuerte que devuelve este skill: son
  dos lectores independientes que llegaron a la misma conclusión sin verse. **Medido en el lote
  004–010 el 2026-08-30:** el 006 y el 009 pidieron cada uno, por su cuenta, que el 004 expusiera
  `suspender()` / `reanudar()` en `src/escenas/jugador.gd`, y el carril de coherencia lo levantó
  como tercero. Tres pedidos, una edición.

  Y por qué se pierde si no se agrupa: **cada spec escribe ese pedido adentro de su propio**
  **`research.md`, que es el único lugar donde el agente del spec destino no va a mirar.** El
  agente del 004 corrió sin enterarse de que se lo pedían dos veces. Aplicar la edición una vez
  por pedido deja el spec destino con la misma cosa escrita dos veces; aplicarla una sola vez
  pero sin ver que eran dos pierde la evidencia de que es dura.

- **Verificá los descartes, no sólo los hallazgos.** Un agente que descarta algo como
  «preexistente» con una medición propia puede estar descartando bien por el motivo equivocado —
  o mal. Y el caso caro es el que se lee como un hallazgo bueno: uno **que no era cierto**.
  Corregilo antes de que salga, porque el próximo que pase lo «arregla» a algo peor.

La asimetría del review vale igual acá: **endurecer se aplica** —un AC que falta se corrige en el
spec al que le falta—; **aflojar se propone**. Si el cruce obliga a elegir entre dos diseños,
frená con `AskUserQuestion`: un párrafo ahora contra dos ramas rebaseadas después. Es la descarga
4 de [`sin-deuda.md`](sin-deuda.md), y es la única forma legítima de que algo
salga de esta corrida sin estar hecho.

### Un hallazgo que excede al lote no se anota: se le abre un spec

Es la tentación fuerte de este paso, porque el cruce **es** el entregable y suena razonable
dejarlo escrito. No lo es: un cruce anotado en un issue es un hallazgo que entendiste, mediste y
decidiste no arreglar.

Lo que sí hay que ver es que **acá el trabajo todavía es texto**, así que la descarga sale mucho
más barata que en un review de PR: el hallazgo que excede al lote es **un spec más**, y este skill
está parado justo en el momento de escribirlo. Con `spec-create`, o sumándolo al lote si el
`numeros.py` del `spec-create-batch` todavía tiene números sin repartir.

Y **el spec nuevo se publica en la misma corrida del Paso 5**, con los del lote: `crear` para
todos antes de `publicar` para uno, o su cita cruzada queda como enlace muerto.

**Si el hallazgo era del método y no del spec, corregí el `SKILL.md`.** Un `[P]` falso que llegó
al review es una regla que `spec-create` no atajó; una escena compartida que la matriz no marcó es
una regla de este archivo. Ver «el lazo» en [`sin-deuda.md`](sin-deuda.md), y va
al reporte como sección propia.

> **Y por eso este skill no corre forkeado.** Sacaría de esta conversación los N+1 reportes y la
> convergencia entera, que es su gasto de contexto más grande — es tentador. Pero
> `AskUserQuestion` no existe en un subagente, así que el fork no rechazaría la línea de arriba:
> la ejecutaría eligiendo solo, en silencio, exactamente en el punto donde el skill decidió no
> elegir. El gate del Paso 0 —«sin argumentos, preguntá»— cae por lo mismo.

## Paso 5 — Aplicar lo compartido, devolver las ediciones y reportar

En este orden, y el segundo es el que se saltea:

1. **Las ediciones fuera-de-carpeta**, una por hallazgo y en serie, para que el diff se lea. Y
   **los specs nuevos** que salieron de los cruces que exceden al lote: se escriben acá, con sus
   cuatro archivos, y entran a la corrida de `crear` del punto 3. **Ninguno queda como issue
   suelto** — ver [`sin-deuda.md`](sin-deuda.md).
2. **Devolvé las ediciones a los issues. No es opcional y no lo hace nadie más:**

   ```bash
   python .claude/scripts/publicar_spec.py publicar
   ```

   El árbol de `specs/` es **caché**. Un review que edita el `spec.md` en disco y no publica dejó
   el trabajo en un archivo ignorado por git, que la próxima hidratación **sobreescribe sin
   avisar**. Es la forma más cara de perder una corrida entera de este skill: no falla, no
   aparece en ningún `git status`, y el spec vuelve a decir lo que decía.

   Corré la fase con `--dry` primero si el lote fue grande: imprime qué issue va a tocar sin
   tocarlo.
3. **Commiteá `specs/mapa.json` si cambió** — cambia si el punto 1 escribió un spec nuevo. Ahí
   corré `publicar_spec.py crear` **antes** que el `publicar` del punto 2, porque `traducir()`
   deja verbatim la cita a un spec que todavía no está en el mapa: enlace muerto en el issue, sin
   error y sin aviso. **El `estado` no se toca acá**: lo deriva la Action en el push a `staging`,
   y el gate da rojo si alguien lo escribe a mano.
4. **`python .claude/scripts/verificar.py --solo harness`**, que es donde corre
   `test_convencion_de_specs.py` sobre lo hidratado: sección que aplaza, tarea que aplaza,
   medición declarada como no hecha. Un lote que se publica sin esto sube specs que el gate va a
   rechazar después, cuando ya son N issues.
5. **El reporte**, en este orden:
   - **Una tabla, una fila por spec:** veredicto (`listo` · `N advertencias` · `no implementar`),
     bloqueantes, y las ediciones comprimidas a conteos.
   - **Los cruces y qué se decidió** — el entregable propio de este skill, y casi todo el
     presupuesto del reporte.
   - **El orden que salió**, cuántas de las aristas declaradas resultaron falsas, y **qué pares
     de specs no se pueden paralelizar por escena compartida**. Eso último es lo que va a leer
     `spec-implement-batch` para repartir carriles.
   - **Qué se publicó**: los issues que el paso 2 tocó, para que se pueda verificar.
   - **Los specs nuevos** que abrieron los cruces que excedían al lote, con su `NNN` y su issue.
   - **Si esta corrida corrigió un `SKILL.md`**, cuál y qué regla se le agregó. Es el entregable
     del lazo, y el único que impide que el mismo cruce vuelva en el lote siguiente.
   - Una línea de lo que no tuvo nada.

## El reporte se escribe para decidir, no para demostrar que trabajaste

**Techo duro: 25 líneas más la tabla**, y la tabla no pasa de una fila por spec. Medido acá el
2026-08-30: la primera versión del reporte de este lote salió en ~60 líneas de prosa densa y el
usuario la rechazó entera —«esto es una ensalada total de palabras»— y hubo que rehacerla. **El
reporte largo no es más completo: es ilegible, que es lo mismo que vacío.**

Las tres secciones que van, y ninguna más:

1. **Qué hice** — dos o tres líneas. Cuántos bloqueantes, qué se publicó.
2. **Qué necesito que definas** — lo que está esperando una decisión del usuario, numerado.
3. **Qué huecos quedaron** — lo que nadie está cubriendo hoy.

Todo lo demás —los cruces uno por uno, el orden derivado, las aristas, las mediciones, el porqué
de cada decisión— **va a los specs y a sus issues, que es donde queda**. El chat se pierde. Si
un cruce sólo existe en el reporte, no se descargó.

Las reglas de escritura, que son las que se rompen primero:

- **Nada de negritas por énfasis.** Sólo para lo que hay que poder saltear leyendo en diagonal.
- **Ningún término del harness sin traducir.** Quien lee decide sobre el juego, no sobre el
  skill: «clase 3», «eje anclaje», «carril de coherencia» y «`--solo harness`» no significan nada
  afuera de este archivo.
- **Un hallazgo se dice por su consecuencia, no por su mecanismo.** «Jugar perfecto tres días
  seguidos te hacía echar» se entiende; «la tabla del 002 está en absolutos contra un supuesto de
  cinco» hay que descifrarlo.
- **No repitas lo que ya está en la tabla.**
- **Si no requiere acción del usuario y no es un hueco, no va.**

**Y el reporte no puede decir «queda pendiente».** Si aparece esa frase, el hallazgo no se
descargó.

---

## Lo que no hace

- **No revisa código.** Si el lote ya tiene implementación, eso es un review de PR.
- **No implementa, y no reparte el lote en carriles de trabajo.** Corre antes de eso, y su salida
  —el orden corregido y los cruces resueltos— es el insumo de `spec-implement-batch`.
- **No crea specs.** Eso es `spec-create-batch`, y corre antes.
- **No abre ramas ni PRs, no corre `verificar.py` y no mueve estados en `specs/mapa.json`.**
- **No es un barrido de staleness.** Si lo único que querés es saber qué specs quedaron viejos
  respecto del código de hoy, alcanza con anclaje y deuda sobre cada uno, sin editar y sin
  coherencia: sale mucho más barato que esto.
