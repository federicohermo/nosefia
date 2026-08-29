---
name: pr-review-batch
description: Revisa los PR abiertos de GitHub en paralelo —un agente por PR, cada uno en su worktree—, arregla lo que encuentra, verifica con verificar.py, commitea y pushea a la rama del PR, y si los PR están apilados cierra poniendo la pila al día. Usar al querer cerrar el review de uno o varios PR de este repo. Para revisar un spec que todavía es texto, spec-review-batch.
argument-hint: "<NN NN ...> | --abiertos [--comentar] [--dry]"
# Sin `allowed-tools`, o sea sin restricción, y por el mismo motivo que los demás skills de
# este repo: declarar una lista parcial le sacaría todo lo que no estuviera en ella —`Agent`,
# los `git worktree`, `verificar.py`, `gh`— y lo rompería en silencio a mitad de corrida.
#
# Tampoco hay inyección `!` de un script al cargar, a diferencia de los dos skills batch de
# spec: la matriz de este skill son los PR abiertos, y eso lo contesta GitHub, no el
# filesystem. Sale por `gh` en el Paso 0.
---

# pr-review-batch — No se fía

Un review de PR mira **un diff**. Este mira los N diffs abiertos, y su entregable propio es lo que
ninguno suelto puede ver: **si las ramas se apilan, un hallazgo del PR de arriba suele ser una
consecuencia del de abajo.**

Y no termina en el reporte. Encuentra, arregla, verifica, commitea y pushea a la rama del PR. El
reporte es lo que queda, no el producto.

---

## Lo que este repo cambia respecto del review de PR del que sale éste

Seis sustituciones. Las tres primeras son de herramienta; las tres últimas cambian el método.

| Un review genérico | Acá |
|---|---|
| Localiza el PR con las tools de Bitbucket, o con `mcp__github__*` porque `gh` no está | **`gh`, que sí está en el PATH** (medido: `gh 2.98.0`) y es lo que ya usa todo el harness — `lib/gh.py`, `deuda.py`, `publicar_spec.py` |
| Los AC salen de un ticket de Jira | **`specs/NNN-*/spec.md`**, con el `NNN` del nombre de la rama. **Hay que hidratarlo**: el worktree nace sin él |
| Cierra con `pnpm verify` | **`python .claude/scripts/verificar.py`**, y un nodo **salteado no es un nodo verde** |
| La cobertura la garantiza un umbral del 100 % | **Godot no mide cobertura.** El eje de cobertura pasa a ser del reviewer, entero |
| Un conflicto de merge se resuelve leyendo | **un `.tscn` no se mergea**: da una escena corrupta, no un conflicto. El Paso 6 no puede confiar en git |
| Eleva todo a comentarios del PR | **El chat y un issue** (`gh issue create`). El issue vive fuera del repo, así que **no viaja en el diff** — y a cambio no hereda el estado de nada. `--comentar` publica además un general por PR |

---

## Paso 0 — El mapa de PRs y la cadena de bases

`$ARGUMENTS`: números de PR sueltos (`6 7 8`), o `--abiertos` = todos los abiertos. **Sin
argumentos, preguntá**: no asumas.

```bash
gh pr list --repo federicohermo/nosefia --state open \
  --json number,headRefName,baseRefName,author,title
```

1. Por cada PR anotá: número, `headRefName`, **`baseRefName`** y autor.
2. **`baseRefName` es la base, nunca `staging` por default.** Si el lote está apilado, diffear el
   de arriba contra `staging` mete los commits del de abajo y el review se llena de hallazgos que
   son de otro PR. `diff_pr.py` recibe la base como argumento justamente para que ese error sea
   imposible.
3. **Dibujá la cadena** y pasásela a los agentes. Un agente que sabe que su base es otro PR
   abierto sabe además que un hallazgo suyo puede pertenecer al de abajo, y lo dice en vez de
   arreglarlo dos veces.
4. **Medí la lista caliente**, que es el insumo del paso que sigue. `diff_pr.py` acepta un tercer
   argumento —la cabeza— justamente para que el padre pueda medir **sin checkout**:
   ```bash
   for n in 6 7 8; do
     python .claude/skills/pr-review-batch/scripts/diff_pr.py <base> <dir>/$n origin/<head>
   done
   cat <dir>/*/pr.files | sort | uniq -c | sort -rn | awk '$1>1'
   ```
5. **Y medí aparte las escenas.** `cat <dir>/*/pr.escenas | sort | uniq -d` — un `.tscn` que
   aparece en dos PR **no es un conflicto barato**: es el único solapamiento del lote que git no
   sabe resolver. Va al preámbulo y al Paso 6.
6. **Comparalo contra `staging`.** El PR de más abajo puede estar detrás; si `staging` avanzó
   sobre archivos del lote, la puesta al día cuesta. Eso se dice en el reporte y **no** se hace
   desde acá.
7. **Autor distinto de `git config user.name` ⇒ ese PR es `--dry`**, él solo y no el lote: se
   revisa y se reporta, no se escribe ni se pushea. Pushear la rama de otro no es tuyo.

Con `--dry` no se escribe nada en ningún PR: se corre hasta el reporte y ahí termina.

## Paso 0 bis — El orden de merge, y por qué ningún agente lo puede verificar

Un batch que **escribe** sobre una cadena apilada tiene un modo de falla que el que sólo reporta
no tiene: el mismo arreglo aplicado en dos PR de la cadena se vuelve un conflicto de rebase, y el
arreglo aplicado en el PR equivocado obliga a rebasear todo lo que tiene encima. La cadena mergea
de **abajo hacia arriba**, siempre.

**Un agente no puede resolver esto solo, y no es por falta de criterio.** Está parado en su
cabeza, y `git log origin/staging..HEAD` —el rango natural para preguntar «¿quién más toca este
archivo?»— sólo ve **hacia abajo**: su propio PR y los que tiene de base. Los de arriba están
fuera del rango y no existen para él. Por eso la lista caliente la mide el padre en el Paso 0 y
**baja en el preámbulo**: no es un dato que el agente pueda ir a buscar.

Seis cláusulas, que van **literales** en el preámbulo del Paso 1:

1. **Un hallazgo es del PR más bajo de la cadena que lo introdujo.** Como la base de cada uno es
   la cabeza del de abajo, el código del inferior le llega al superior como **contexto** y no como
   diff: se ve nuevo y no es suyo. El test es mecánico — **si la línea no aparece como `+` en tu
   `pr.diff`, no es tuya**, aunque todavía no esté en `staging`. Se reporta como
   `PERTENECE-A-PR-<N>` con `archivo:línea` y evidencia, y no se toca.
2. **Pero la propiedad es de quien lo falsifica, no de quien toca la línea.** Un diff puede volver
   falsa una afirmación que **no contiene**: típicamente un conteo. Si tu diff mueve el número que
   una frase afirma, la frase es tuya aunque no la hayas escrito. Es la excepción que la cláusula 1
   necesita, porque sola crea un punto ciego — ver abajo.
3. **Un arreglo abajo cuesta un rebase en cada PR de arriba, y ese rebase lo paga el Paso 6.** Eso
   no cambia dónde va el fix —va donde se introdujo— ni lo achica. Lo que obliga es a que cada
   agente **liste los archivos que tocó**.
4. **Hunk chico y quieto** en todo archivo de la lista caliente: no re-justifiques un párrafo, no
   re-envuelvas líneas, no reordenes una tabla. Es **higiene y no un límite** — un conflicto de
   veinte líneas cuesta más que uno de una, pero los dos se resuelven, y desde que existe el Paso
   6 los resuelve el mismo pipeline que los creó. **No es motivo para achicar un fix, para elegir
   uno peor ni para no aplicarlo.** Un review que negocia con el conflicto deja bugs adentro.
5. **En una escena de la lista caliente, la cláusula 4 deja de ser higiene y pasa a ser un
   límite.** Un `.tscn` que dos PR del lote tocan **no se puede resolver en el Paso 6**: `git
   merge` sobre una escena no da un conflicto que alguien arregla, da una escena rota. Si tu fix
   necesita tocar una escena que el padre marcó como compartida, **no lo apliques**: reportalo con
   el cambio exacto y quién más la toca. Es la única clase de fix que se declara por el archivo y
   no por el hallazgo.
6. **Un 🟡 que no se aplica se abre como issue con `gh issue create`, y su `Detectado en #N` es el
   issue del spec propio.** El `#N` sale de `specs/mapa.json`, no del `NNN` —el spec 001 es el
   issue #3—: un `#N` equivocado cuelga el hallazgo del spec que no es **sin que ningún diff lo
   delate**. Un 🟡 que pertenece a otro PR del lote **no** se abre: se reporta como
   `PERTENECE-A-PR-<N>`. Y el precio de que el destino esté fuera del repo se paga acá: **el
   reviewer del PR no ve el issue en el diff**, así que el Paso 8 es el único canal.

Nadie rebasea y nadie usa `--force`. Y **ningún agente de PR mergea**: poner la pila al día es del
padre y es el Paso 6, después de que todos los fixes estén adentro. El push de cada agente es
`git push origin HEAD:refs/heads/<headRefName>`.

### El punto ciego que la cláusula 2 existe para tapar

**Una afirmación numérica monótona sobre el árbol, corregida en un PR de la pila, queda vieja en
cada PR de arriba — y la cláusula 1 garantiza que ningún agente la vea.** El agente que la corrige
la deja exacta para **su** cabeza; los de arriba no pueden cazarla por dos motivos que se suman:
la frase no está en su diff, y el arreglo del de abajo **todavía no existe** cuando corren.

Pero si el diff de arriba **mueve el número que la frase afirma** —agrega un `.gd`, un test, una
capa—, entonces es suyo por la cláusula 2. Se despacha desde el Paso 5, con el número medido al
lado y la orden de remedirlo.

El corolario operativo: **todo conteo que el lote mueva es del padre.** Es la única clase de
hallazgo que no se delega, porque requiere ver la cadena entera a la vez. En este repo los
candidatos están servidos: `docs/architecture/directory-structure.md` enumera y cuenta, y
`CLAUDE.md` afirma «los seis nodos» y «las cuatro capas».

## Paso 1 — El preámbulo, destilado una vez

Es el ahorro propio del batch: sin esto, N agentes lo re-derivan N veces desde frío. Cinco
insumos, y los cinco van **destilados**, no como rutas a leer:

- **Las convenciones verificables, ≤40 líneas**, con la línea de [`hallazgos.md`](./hallazgos.md)
  marcada: qué verifica ya una herramienta y qué no. `CLAUDE.md` **ya la dibujó** —tiene una lista
  «verificadas por una herramienta» y otra «prosa»— así que acá se copia, no se deriva.
- **El mapa síntoma → deuda**: `python .claude/scripts/deuda.py`.
- **Lo que ya se probó y no funcionó** para el área del lote. Vive como comentarios en el issue de
  cada spec: `gh issue view <N> --repo federicohermo/nosefia --json comments`.
- **La cadena de bases del Paso 0**, con **las seis cláusulas del Paso 0 bis literales**, **la
  lista caliente medida** y **las escenas compartidas**. Las cuatro cosas son del padre y ninguna
  la puede derivar el agente.
- **Las cuatro trampas de `CLAUDE.md`**, y de ésas dos son operativas acá: la salida en cp1252 y
  que **`Grep` no ve `specs/`**.

Escribilo **a un archivo** y pasá la ruta absoluta, en vez de inlinearlo N veces: los worktrees no
lo comparten pero sí leen rutas absolutas. Y **escribilo con `Write`, nunca con un heredoc** — los
backticks y los `$` del contenido rompen el heredoc con un `unexpected EOF` que cuesta más
diagnosticar que reescribirlo. Está medido en esta máquina.

## Paso 2 — Un worktree por PR

Lanzá los N en **un solo mensaje**, un `Agent` por PR con `isolation: "worktree"`.

**Por qué un worktree y no ramas en el árbol principal:** los agentes corren `verificar.py` a la
vez, dos checkouts de la misma rama no pueden coexistir, y cada uno hace `git add`. Compartir
árbol significa que el primero que commitea se lleva puesto el trabajo de los otros.

**El ancho lo manda `verificar.py`, no el review.** Son seis nodos concurrentes cada uno, y el de
`tests` levanta Godot headless. N PRs son 6N procesos, N de ellos un motor entero. Hasta cuatro es
razonable; más que eso, tandas. **No hay medición propia todavía**: es una cota prudente, y la
primera corrida que la contradiga la mueve.

## Paso 3 — El contrato de cada agente

Cada uno recibe el preámbulo del Paso 1, su número de PR, su `headRefName`, su `baseRefName` y la
ruta a [`hallazgos.md`](./hallazgos.md), que es el método y va **literal**: un agente aislado
necesita la rúbrica de confianza más que vos, porque no tiene el contexto que te deja descartar un
hallazgo de un vistazo.

Y este contrato, en este orden:

1. **Parate en la cabeza del PR sin robarle la rama a nadie.**
   ```bash
   git fetch origin
   git checkout -B feature/<NNN>-rev-pr-<N> origin/<headRefName>
   ```
   Una rama de andamio propia: `git checkout <headRefName>` a secas falla si esa rama ya está
   tomada por otro worktree.

   **El nombre no es libre, y el `NNN` del spec del PR va adelante a propósito.**
   `gate_de_spec.py` corre como hook sobre `Edit|Write|MultiEdit|Bash|PowerShell` y **bloquea toda
   escritura a `src/` y `docs/` desde una rama que no matchee `^feature/(\d{3})-` con ese número
   en `specs/mapa.json`**. Un nombre tipo `rev-pr-<N>` no matchea, así que el review de cualquier
   PR que toque esas dos carpetas se quedaría sin poder arreglar nada. Como el spec del PR ya está
   en el mapa por construcción, ponerlo adelante alcanza. El nombre de la rama de andamio **no
   afecta el push**, que sigue siendo a `refs/heads/<headRefName>`.

   **Si el PR no tiene spec** —una rama `fix/` o `chore/`, que este repo permite para lo que no
   toca rutas protegidas— entonces por construcción **no hay nada que arreglar en `src/` ni en
   `docs/`**, y la rama de andamio se llama como quieras. Si igual hiciera falta tocarlas, eso
   **es un hallazgo sobre el PR**: le falta el spec.
2. **Hidratá el spec. No es opcional y no falla solo.**
   ```bash
   python .claude/scripts/hidratar_specs.py <NNN>
   ```
   `specs/[0-9]*/` está en el `.gitignore` y `git worktree add` hace checkout de lo **trackeado**,
   así que al worktree llegan dos archivos de `specs/` y ningún spec. Sin esto el Paso 4 lee un
   directorio vacío, no encuentra los AC y **revisa sin criterios de aceptación** — que es la peor
   forma de este bug, porque el review igual termina y reporta.

   **No hay `install` que correr**: el proyecto es Godot y `addons/` está vendorizado.
3. **Materializá el diff una sola vez**, con la base del PR y no con `staging`:
   ```bash
   python .claude/skills/pr-review-batch/scripts/diff_pr.py <baseRefName> <dir-temporal>
   ```
   Emite el diff, el `--stat`, las listas de código, prosa y **escenas** por separado, el gate de
   ejes y las afirmaciones numéricas que el diff agrega. **Si `diff_size=grande`, no leas el diff
   entero**: triageá con el `--stat` y leé por archivo.
4. **Leé los AC del spec del PR** y contrastá cada uno contra el diff. Un AC sin contraparte
   verificable en el diff es hallazgo aunque el código esté bien.
5. **Encontrá con el método de `hallazgos.md`**, y sólo en los ejes que el gate abrió.
6. **Arreglá con la política de triage de `hallazgos.md`**, y con las seis cláusulas del Paso 0
   bis encima.
7. **`verificar.py` en verde**, con el Paso 4 de este archivo adelante.
8. **Commit y push**, sin `--force`:
   ```bash
   git push origin HEAD:refs/heads/<headRefName>
   ```
   **El mensaje de commit se escribe con `Write` a un archivo y se pasa con `-F`, nunca con
   heredoc.**
9. **Devolvé un reporte de 30–50 líneas**: veredicto en la primera, los bloqueantes con
   `archivo:línea` y evidencia, lo aplicado a conteos, lo **no** aplicado con motivo, lo
   `BLOQUEADO` con quién lo bloqueó, los `PERTENECE-A-PR-<N>`, **la lista exacta de archivos
   tocados** —es lo único con lo que el padre calcula el costo de rebase—, **si algún nodo se
   salteó y cuál**, y el SHA. Sin el SHA el padre no puede verificar que el push llegó.

   **Cada 🟡 no aplicado lleva su motivo, y el motivo tiene que ser uno de los tres de
   `hallazgos.md`.** Cualquier otra cosa significa que el fix se aplica, o que va como `BLOQUEADO`
   y **no** como decisión de triage. El padre lo va a cruzar contra esa lista.

   Y **pedile que no afirme qué otros PR tocan sus archivos.** No lo puede saber.

**No commitea el árbol rojo.** Si `verificar.py` queda rojo después del Paso 4, revertí lo que lo
rompió, no pushees, y decilo. Un pipeline que pushea para completarse no sirve.

## Paso 4 — El protocolo de contención

**Acá el rojo casi nunca es del PR, y el modo de falla propio de este repo no es un rojo: es un
salteado.**

`verificar.py` saltea el nodo `tests` si no encuentra `GODOT_BIN`, y **lo declara** — pero un
reporte que dice «6/6» sin leer los salteados es un review que dio por corrida una suite que no
corrió. Medido en esta máquina: `GODOT_BIN` **no está en el entorno de la terminal**, se lee del
registro de Windows, y una terminal anterior a la variable le pasa el entorno viejo a todo lo que
lance.

El protocolo, y no hay que improvisarlo:

1. **Leé los salteados antes que los rojos.** `tests` salteado **es un rojo del review**: la suite
   no corrió, así que no sabés si el fix rompió algo.
2. Si el salteo es por `GODOT_BIN`, no lo declares como pasado: exportalo en el worktree y volvé a
   correr. Si no se puede, **es un bloqueante del lote y no del PR**.
3. ¿El test que falló está en un archivo que el PR toca? **Si sí, es tuyo** — arreglalo.
4. Si no, y huele a contención —N motores a la vez—, **corré `verificar.py --solo tests`** solo.
5. **Verde ⇒ seguí, y declaralo en el reporte** con las dos corridas. No lo escondas: el usuario
   tiene que poder distinguir «pasó» de «pasó en la segunda».
6. **Rojo de nuevo ⇒ no pushees.** Reportalo como bloqueante del lote.

**Y ojo con OneDrive:** si Godot está adentro y el archivo no está descargado, Windows contesta
«el proveedor de archivos de nube no se está ejecutando», que no nombra ni a Godot ni a los tests.

## Paso 5 — Converger

El padre no re-audita: cruza.

- **Verificá que cada push llegó.** `git fetch origin` y comparar el head remoto contra el SHA que
  devolvió cada agente. Un agente que dice «pusheado» y un remoto que no se movió es el único modo
  de falla silencioso que queda.
- **Un hallazgo del PR de arriba que en realidad es del de abajo se arregla una sola vez**, en el
  de abajo. Ruteá cada `PERTENECE-A-PR-<N>` **antes** de darlo por perdido: el agente destino sigue
  vivo y se resume con `SendMessage`, con su worktree y su contexto puestos — sale mucho más barato
  que una pasada nueva.
- **Recalculá la lista caliente con lo que el review escribió, no con lo que el diff traía.** El
  propio review crea solapamiento nuevo: es habitual que varios agentes terminen tocando el mismo
  doc, que ningún diff original incluía.
- **Los conteos que el lote mueve son tuyos** (cláusula 2). Barré las afirmaciones numéricas sobre
  el árbol —cuántos archivos, cuántos nodos, cuántas capas— **cabeza por cabeza**, y despachá el
  número medido. Y medilo con el pathspec acotado.
- **Verificá los descartes, no sólo los hallazgos.** El caso caro es el que se lee como un hallazgo
  bueno: un 🟡 **que no era cierto**. Corregilo antes de que salga, y si el issue ya está abierto,
  editalo: escrito como estaba, el próximo que pase lo «arregla» a algo peor.
- **El lote no está cerrado mientras quede un fix conocido sin aplicar** —salvo con `--dry`—. Es el
  único paso que puede cerrarlos, porque el padre corre en el checkout principal:
  - Cada `BLOQUEADO` **lo aplicás vos**. Y si el bloqueo fue el hook, mirá el nombre de la rama
    antes de nada.
  - Cada 🟡 cuyo motivo no sea uno de los tres **vuelve**: o lo aplicás, o lo despachás con
    `SendMessage`.
  - Un fix que el propio review destapó **sobre el skill o sobre el repo** —no sobre un PR—
    también se aplica: el padre es el único que corre el pipeline entero y a la vez lee su propia
    prescripción.
- **Con `--comentar`**, un general por PR encabezado por el SHA, con las cuatro secciones:
  bloqueantes resueltos, mejoras aplicadas, **no aplicado con motivo**, y lo que sigue abierto. La
  tercera es la que le da valor. **No abras inline sobre tu propio PR ya arreglado**: es ruido con
  costo.

**El reporte no se escribe acá.** Es el Paso 8, y va último porque tiene que contar cómo quedó la
pila después del Paso 6.

## Paso 6 — Poner la pila al día

**Un review de una pila no termina cuando cada PR está verde: termina cuando la pila entera se
puede mergear.** Aprobar cinco PR que no entran uno detrás del otro no le sirve a nadie.

Va **al final, después de todos los fixes**, y no es orden sino calidad: mientras el conflicto sea
algo que hay que evitar, el review negocia con él y deja bugs adentro para no tocar una rama. Con
el conflicto pagado acá, el Paso 3 arregla como si la pila no existiera.

Si el lote no está apilado —todos los `baseRefName` son `staging`— este paso no tiene nada que
hacer y se saltea **declarándolo en el reporte**. Con `--dry` tampoco corre.

### Primero medir, sin checkout

```bash
git fetch origin
git merge-tree --write-tree --name-only origin/<de-arriba> origin/<de-abajo>
```

Contesta qué archivos chocan **sin tocar el árbol y sin worktree**, así que el padre mide las N
uniones de un saque. Y es lo que le deja **escribirle a cada agente la resolución ya redactada**:
el mismo comando sin `--name-only` devuelve el árbol mergeado, y `git show <tree>:<archivo>`
muestra el conflicto con sus marcadores.

Medí también el resultado **semántico**, no sólo si hubo conflicto: un automerge limpio puede
quedar mal —dos cadenas que mueven el mismo conteo mergean sin chocar y dejan un número viejo—.

### La excepción que este repo agrega: la escena

**Si el archivo que choca es un `.tscn` o un `.tres`, este paso NO lo resuelve y no lo intenta.**
Un merge de tres vías sobre una escena no produce un conflicto que alguien arregla: produce una
escena corrupta que Godot abre a medias, y `git merge-tree` la va a mergear **sin marcar nada**.

Y no hay red debajo: `.gitattributes` marca `binary` los `.png` y los `.ogg` **con ese mismo
argumento escrito**, pero **no marca los `.tscn`** — medido el 2026-08-28. O sea que git los trata
como texto y los va a mergear alegremente.

Lo que se hace en su lugar: **se para la cadena en esa unión**, se reporta con los dos PR y la
escena, y se dice cuál de las dos versiones sobrevive y qué hay que rehacer a mano en el editor.
Dos PR sobre la misma escena se ordenan, no se mergean.

### Un carril por cadena, no por unión

Las uniones de una misma cadena son **secuenciales**, así que van todas en el mismo agente, en
orden y de abajo hacia arriba. Cadenas independientes sí van en paralelo.

Cada agente recibe: su cadena con los SHA, **cada conflicto medido con su resolución textual**, y
el contrato:

1. **Rama de andamio propia por unión**, con el `NNN` del PR de destino adelante —el hook la exige
   igual que en el Paso 3—.
2. **`git merge`, nunca `git rebase` y nunca `--force`.** Un rebase reescribe los commits del
   review que el usuario acaba de leer, y encima los hace resolver de nuevo uno por uno.
3. **Resolver con la resolución que bajó el padre**, y parar y reportar si el conflicto no es el
   que el prompt describe: significa que algo se movió entre la medición y el merge.
4. **Editar con una herramienta que respete el fin de línea.** `.gitattributes` fuerza `eol=lf`
   pero el árbol de trabajo en Windows puede tener CRLF, y `sed -i` en Git Bash convierte el
   archivo entero: el diff pasa de tres líneas al archivo completo. `git diff --stat` después de
   resolver lo atrapa, y `git checkout --merge <archivo>` devuelve el conflicto sin perder nada.
5. **`verificar.py` después de cada unión**, con el veredicto del exit code y el Paso 4 adelante.
   **Y con los specs hidratados**: sin eso los gates del registro se saltean declarándolo, y el
   merge se da por verde sin haberlos corrido.
6. **Push sólo a la ref que ya existe**, confirmada antes con `git ls-remote --heads origin <rama>`.
   La rama de andamio muere con el worktree y **no se pushea con su nombre**. Este paso no abre
   ramas remotas ni PR.

### Lo que este paso NO puede resolver, y por eso va al reporte

**Dos cadenas independientes que tocan el mismo archivo.** Ese conflicto no existe todavía:
aparece recién cuando la segunda entra a `staging`, y resolverlo desde acá pediría mergear a
`staging` —que no es de este skill— o enredar dos PR que no dependen entre sí. Va al reporte **con
el texto final ya redactado**, no con una descripción de qué habría que elegir.

## Paso 7 — Destruir los worktrees

```bash
python .claude/skills/pr-review-batch/scripts/limpiar_worktrees.py --todos
```

**No lo hagas a mano, y no uses `git worktree remove` solo: va a fallar.** Borra lo trackeado y el
`.git`, pero `.godot/` y `reportes/` están en el `.gitignore`, así que el directorio no queda
vacío y el borrado final tira `Directory not empty`. `--force` no ayuda —no es un problema de
cambios sin commitear— y le pasa a **todo worktree que haya corrido `verificar.py`**, o sea a
todos: el nodo `tests` abre el proyecto en Godot y Godot escribe su caché de importación.

El script hace las tres cosas en orden —desregistrar, matar lo que haya adentro por **ruta del
worktree**, borrar— y se lleva también el directorio padre vacío.

**Si imprime `ANOMALIA`, va al reporte:** `verificar.py` levanta Godot pero tendría que haber
terminado, así que un proceso vivo adentro de un worktree es **un Godot colgado**, y el reporte
tiene que decir con qué test se colgó. Si dice `SIGUE AHI`, el handle es de afuera —el editor o el
IDE con la carpeta abierta— y eso lo cierra el usuario, no vos.

Después borrá las ramas de andamio, **pero recién después de verificar que cada una es idéntica a
su `origin/<headRefName>`**. Si difieren, algo no se pusheó y la rama es lo único que lo tiene.

---

## Paso 8 — El reporte

En este orden y en ~40 líneas más la tabla:

1. **Una tabla, una fila por PR:** número, rama, hallazgos por severidad, el SHA del review, el
   SHA del merge si el Paso 6 lo tocó, y **si `verificar.py` pasó a la primera, a la segunda, o
   con algún nodo salteado**. La tercera columna no se omite: un salteado no es un verde.
2. **Lo que apareció en más de un PR** — el patrón transversal es el entregable propio del batch.
3. **Lo no aplicado**, con el número del issue que quedó abierto y el `Detectado en #N` que lleva.
   **No es redundante con el PR**: el issue no está en el diff, así que quien mergea sólo lo ve
   acá.
4. **Cómo quedó la pila después del Paso 6**: qué cadena está al día contra qué, con qué SHA, y
   cada conflicto resuelto **con el criterio que lo resolvió**. La verificación va escrita al lado:
   que cada cadena contenga entera a la de abajo —`git log <abajo>..<arriba>` vacío— y que no haya
   aparecido ninguna ref remota nueva.
5. **Las escenas compartidas que quedaron sin mergear**, con qué hay que rehacer a mano. Es lo que
   este repo agrega y lo que ningún merge va a resolver después.
6. **Lo que queda entre cadenas independientes, con la resolución textual.** Y el orden de merge,
   de abajo hacia arriba, más el aviso de que un squash obliga a rebasear el PR de arriba.

La pregunta que el reporte tiene que dejar contestada es **«¿puedo mergear esto ya?»**. Si la
respuesta es «sí, salvo un conflicto», el conflicto va con su texto final resuelto adentro del
reporte, no como una advertencia.

---

## Lo que no hace

- **No mergea a `staging`, y no mueve estados en `specs/mapa.json`** — los mueve ese merge y la
  Action, que son del usuario. Sí mergea **hacia arriba dentro de la pila**, en el Paso 6.
- **No revisa specs que todavía son texto.** Eso es `spec-review-batch`, corre antes, y sale mucho
  más barato: un cruce detectado como texto cuesta un párrafo y detectado en dos ramas cuesta un
  rebase.
- **No abre PRs ni ramas de feature.** Trabaja sobre lo que ya está abierto.
- **No abre el juego.** Corre la suite en headless, que es otra cosa. Si un fix toca algo que se
  ve, la verificación en pantalla la pide el spec: acá queda **declarada en el reporte** como
  pendiente, con qué habría que medir.
