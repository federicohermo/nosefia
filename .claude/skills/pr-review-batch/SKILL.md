---
name: pr-review-batch
description: Revisa los PR abiertos de GitHub en paralelo —un agente por PR, cada uno en su worktree—, arregla lo que encuentra, verifica con verificar.py, commitea y pushea a la rama del PR, y si los PR están apilados cierra poniendo la pila al día. Usar al querer cerrar el review de dos o más PR de este repo. Para uno solo, pr-review. Para revisar un spec que todavía es texto, spec-revise-batch.
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

**No deja deuda, y en un lote eso tiene una vuelta más.** Las cinco descargas están en
[`sin-deuda.md`](sin-deuda.md) y valen para cada agente. Lo propio del batch es
que acá hay un destino que allá no existe —`PERTENECE-A-PR-<N>`, el hallazgo que es de otro PR de la
cadena— y
**ése no es una descarga: es un ruteo.** Queda descargado cuando alguien lo aplica, y el
responsable de que eso pase es el padre (Paso 7). Un `PERTENECE-A-PR-<N>` que llega al reporte sin
haberse aplicado es deuda con nombre de tránsito.

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
| Eleva todo a comentarios del PR, y lo de afuera del alcance a un issue | **Nada queda anotado.** Lo del alcance entra al PR; lo de afuera sale en **su propio PR** en esta corrida; lo del planteo se corrige en el `spec.md`. Los issues acá son **entrada**, no salida — ver [`sin-deuda.md`](sin-deuda.md). `--comentar` publica además un general por PR |

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
   cat <dir>/*/pr.files | sort | uniq -cd | sort -rn
   ```
   **`uniq -cd` y no un `awk` sobre la primera columna**, y no es estilo: un `$1` escrito acá
   **no le llega al agente**. El harness de slash-command sustituye los posicionales del cuerpo
   del skill por los argumentos de la invocación, así que `awk '$1>1'` viaja como `awk '025>1'`
   —una constante no nula, o sea **verdadera para toda línea**— y la lista caliente sale con el
   lote entero en vez de con los archivos compartidos. **No falla: contesta de más, y en
   silencio.** Las variables con nombre (`$n`, `$GODOT_BIN`) viajan intactas; los dígitos no.
   Medido el 2026-09-01 en la corrida sobre el lote 024/025.
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
6. **Todo hallazgo se descarga, y ninguna descarga es un issue.** Las cinco están en
   [`sin-deuda.md`](sin-deuda.md). Lo del alcance de tu spec entra a tu PR; lo de
   afuera
   **sale en su propio PR desde `staging`**, abierto por vos en esta corrida —no desde tu rama, o
   arrastra tus commits—; lo que pelea con un AC se descarga **corrigiendo el AC** en el `spec.md`
   y devolviéndolo al issue. «Es preexistente» y «es de otro spec» deciden **dónde aterriza**, no
   si se hace.

   **Las dos únicas cosas que devolvés sin aplicar** son las que no podés aplicar desde tu
   worktree: un `PERTENECE-A-PR-<N>` (cláusula 1) y un fix sobre una escena compartida
   (cláusula 5). Las dos las aplica el padre, **y las dos son ruteo y no descarga**: no las
   escribas como si el hallazgo estuviera cerrado.

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

- - **Las convenciones verificables, ≤40 líneas**, con la línea de
  [`hallazgos.md`](hallazgos.md) marcada: qué verifica ya una herramienta y qué no.
  `CLAUDE.md` **ya la dibujó** —tiene una lista «verificadas por una herramienta» y otra «prosa»—
  así que acá se copia, no se deriva.
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

**El método de búsqueda de cada agente es [`hallazgos.md`](hallazgos.md), que este skill trae
adentro.** Los ejes, el filtro de confianza y la política de triage son los mismos que usa
`pr-review` para un PR solo —los Pasos 1 a 7: pararse en la rama del PR, hidratar, diff, AC,
encontrar, arreglar, verificar, pushear— y este archivo agrega **lo único que un PR solo no tiene:
la cadena**.

**Y la copia es deliberada, no un descuido.** Un skill es la unidad que se instala y se distribuye,
así que tiene que traer su implementación completa: uno que salga a buscar el archivo al skill de
al lado deja de funcionar apenas viaja sin su hermano. Lo que un `../` ahorraba —que no se separen— lo compra más
barato un gate: `test_copias_de_skills.py` da rojo si dos copias difieren en un byte.

Cada agente recibe el preámbulo del Paso 1, su número de PR, su `headRefName`, su `baseRefName` y la
ruta a [`hallazgos.md`](hallazgos.md), que va **literal**:
un agente aislado necesita la rúbrica de confianza más que vos, porque no tiene el contexto que te
deja descartar un hallazgo de un vistazo.

Y estas diferencias respecto de `pr-review`, que son las que lo vuelven un carril del lote:

1. **Corre adentro de su worktree, no en el checkout principal.** Por eso `pr-review` pide el árbol
   limpio y acá no hace falta: el worktree nace limpio por construcción. **La rama sigue siendo la
   del PR** —`git worktree add <dir> <headRefName>`—, y no hace falta inventarle otro nombre para
   que los carriles no se pisen: cada PR tiene su propia `headRefName`, así que ya son disjuntas.
   El único caso que falla es que **el checkout principal esté parado en una de ellas**; ahí se
   mueve el principal a otra rama antes de lanzar, no se le cambia el nombre al carril.
2. **Hidratá el spec, y acá el motivo es más fuerte.** `git worktree add` hace checkout de lo
   **trackeado**, así que al worktree llegan dos archivos de `specs/` y ningún spec — un checkout
   principal al menos puede tener la caché de una corrida anterior. Sin
   `python .claude/scripts/hidratar_specs.py <NNN>` el agente revisa sin criterios de aceptación y
   **igual termina y reporta**.

   **No hay `install` que correr, pero sí hay una importación**, y saltearla cuesta una corrida
   entera. `addons/` está vendorizado, así que no falta ninguna dependencia; lo que falta es
   `.godot/`, que está en el `.gitignore` y por lo tanto **ningún worktree nuevo lo tiene**. Sin
   esa caché Godot no tiene el registro de clases globales, `addons/gdUnit4/bin/GdUnitCmdTool.gd`
   no resuelve sus propios `class_name`, y el nodo `tests` sale **rojo** —no salteado— con:

   ```text
   Parse Error: Could not find type "GdUnitTestCIRunner" in the current scope.
   ```

   **El síntoma no nombra la causa**: no dice `.godot`, no dice worktree, no dice importación, y
   nombra un tipo de gdUnit4, que manda a revisar el addon. Por eso va acá y no en el
   troubleshooting: para cuando el agente busca, ya gastó una corrida de `verificar.py`. La cura
   es una línea, una sola vez por worktree y **antes** del primer `verificar.py`:

   ```bash
   "$GODOT_BIN" --headless --path . --import --quit
   ```

   **Medido el 2026-08-31** en la corrida sobre el lote 001/002/004/007: **los cuatro carriles lo
   pisaron, los cuatro en la primera corrida, y los cuatro salieron verdes en la segunda ya
   importados.** `.github/workflows/verify.yml:75` ya hacía este paso, con un comentario que
   describe exactamente esto — o sea que **la CI lo sabía y el skill que crea los worktrees decía
   lo contrario**.
3. **Las seis cláusulas del Paso 0 bis van encima de la política de triage**, y dos de ellas
   **cambian** lo que `pr-review` haría solo: lo que no sea `+` en el propio diff se reporta como
   `PERTENECE-A-PR-<N>` en vez de arreglarse, y un fix sobre una escena de la lista caliente **no se
   aplica**. Un agente que no las tenga va a arreglar dos veces lo mismo, o a corromper una escena.
4. **El reporte es para el padre, no para el usuario**, así que cambia de forma: 30–50 líneas con
   veredicto en la primera, los bloqueantes con `archivo:línea`, lo `BLOQUEADO` con quién lo
   bloqueó, los `PERTENECE-A-PR-<N>`, los fixes sobre escena compartida sin aplicar, **si algún
   nodo se salteó y cuál**, y dos cosas que `pr-review` no necesita porque no hay nadie arriba
   suyo:
   - **La lista exacta de archivos que tocó** — es lo único con lo que el padre calcula el costo de
     rebase del Paso 6.
   - **El SHA del push.** Sin él el padre no puede verificar que el push llegó, que es el único
     modo de falla silencioso que le queda.

   **Cada hallazgo que vuelve sin aplicar tiene que caer en una de las dos casillas de ruteo** —
   `PERTENECE-A-PR-<N>` o escena compartida— **o en `BLOQUEADO`.** No hay una cuarta. El padre lo
   cruza contra esa lista, así que declararlo mal no lo hace desaparecer: lo devuelve.

   Y **pedile que no afirme qué otros PR tocan sus archivos.** No lo puede saber:
   `origin/staging..HEAD` sólo ve hacia abajo.

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
  bueno: un 🟡 **que no era cierto**. Corregilo antes de que salga — escrito como estaba, el próximo
  que pase lo «arregla» a algo peor. Y si el hallazgo falso ya se convirtió en un PR propio,
  **cerralo**: un PR abierto por un hallazgo inexistente es peor que un issue.
- **El lote no está cerrado mientras quede un hallazgo sin descargar** —salvo con `--dry`—. Es el
  único paso que puede cerrarlos, porque el padre corre en el checkout principal y con los permisos
  que a un worktree le faltan:
  - Cada `BLOQUEADO` **lo aplicás vos**. Y si el bloqueo fue el hook, mirá el nombre de la rama
    antes de nada. Lo que no puedas aplicar tampoco vos **hace fallar la corrida** y lo dice el
    Paso 8 en su primera línea; no se tapa con un issue.
  - Cada `PERTENECE-A-PR-<N>` **se aplica en su PR**, y verificás que se haya aplicado. Es ruteo,
    no descarga: si llega al reporte sin aterrizar, es deuda con nombre de tránsito.
  - Cada fix sobre una **escena compartida** lo aplicás vos, en el orden del Paso 6. Ningún agente
    podía.
  - Un fix que el propio review destapó **sobre el skill o sobre el repo** —no sobre un PR—
    también se aplica: el padre es el único que corre el pipeline entero y a la vez lee su propia
    prescripción. Es la descarga 3 de [`sin-deuda.md`](sin-deuda.md), y es la más
    barata de saltear porque no la reclama ningún PR.
- **Con `--comentar`**, un general por PR encabezado por el SHA, con las cuatro secciones:
  bloqueantes resueltos, mejoras aplicadas, **lo que salió a su propio PR** con el número, y **lo
  que obligó a corregir el spec**. **No abras inline sobre tu propio PR ya arreglado**: es ruido
  con costo.

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

1. **Se merge sobre la rama del PR de destino**, parado en ella y no en una rama inventada: es la
   que ya matchea el hook, y es la ref a la que va a salir el push del punto 6. Una rama de
   andamio acá agrega un nombre que después hay que reconciliar a mano con el remoto.
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
   Este paso no abre ramas remotas ni PR: cada unión vuelve a la rama del PR que ya estaba abierto.

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

**Antes de destruir nada, verificá que cada rama del lote es idéntica a su
`origin/<headRefName>`.** Si difieren, algo no se pusheó y ese worktree es lo único que lo tiene —
y `--todos` lo borra sin preguntar. No hay ramas de andamio que limpiar después: los carriles
trabajaron sobre las ramas de los PR, que siguen existiendo y así tienen que quedar.

---

## Paso 8 — El reporte

En este orden y en ~40 líneas más la tabla:

0. **Si algo quedó `BLOQUEADO` y el padre tampoco pudo aplicarlo, la primera línea dice que la
   corrida falló.** No «se cerró casi todo». Es la descarga 5 y es un rojo.
1. **Una tabla, una fila por PR:** número, rama, hallazgos por severidad, el SHA del review, el
   SHA del merge si el Paso 6 lo tocó, y **si `verificar.py` pasó a la primera, a la segunda, o
   con algún nodo salteado**. La tercera columna no se omite: un salteado no es un verde.
2. **Lo que apareció en más de un PR** — el patrón transversal es el entregable propio del batch.
3. **Los PR nuevos que abrió esta corrida** para lo que caía fuera del alcance de cada spec, con
   su número y en qué orden entran. Quien mergea tiene que saber que la corrida dejó más PRs de
   los que revisó.
4. **Lo que obligó a corregir un `spec.md`**, y que se devolvió al issue con `publicar_spec.py
   publicar`. Y **si esta corrida corrigió un `SKILL.md`**, cuál y qué regla se le agregó — es el
   entregable más caro del lazo, y el único que impide que el hallazgo vuelva.
5. **Cómo quedó la pila después del Paso 6**: qué cadena está al día contra qué, con qué SHA, y
   cada conflicto resuelto **con el criterio que lo resolvió**. La verificación va escrita al lado:
   que cada cadena contenga entera a la de abajo —`git log <abajo>..<arriba>` vacío— y que no haya
   aparecido ninguna ref remota nueva.
6. **Las escenas compartidas que quedaron sin mergear**, con qué hay que rehacer a mano. Es lo que
   este repo agrega y lo que ningún merge va a resolver después.
7. **Lo que queda entre cadenas independientes, con la resolución textual.** Y el orden de merge,
   de abajo hacia arriba, más el aviso de que un squash obliga a rebasear el PR de arriba.

La pregunta que el reporte tiene que dejar contestada es **«¿puedo mergear esto ya?»**. Si la
respuesta es «sí, salvo un conflicto», el conflicto va con su texto final resuelto adentro del
reporte, no como una advertencia.

---

## Lo que no hace

- **No mergea a `staging`, y no mueve estados en `specs/mapa.json`** — los mueve ese merge y la
  Action, que son del usuario. Sí mergea **hacia arriba dentro de la pila**, en el Paso 6.
- **No revisa specs que todavía son texto.** Eso es `spec-revise-batch`, corre antes, y sale mucho
  más barato: un cruce detectado como texto cuesta un párrafo y detectado en dos ramas cuesta un
  rebase.
- **No reimplementa el review de un PR.** Ese método es `pr-review`, y con **un** PR abierto usá
  ése: todo lo que este skill agrega —la cadena, la lista caliente, las seis cláusulas, el Paso 6—
  no tiene nada que hacer, y a cambio te cobra un worktree que después hay que limpiar.
- **No abre PRs ni ramas de feature.** Trabaja sobre lo que ya está abierto.
- **No abre el juego.** Corre la suite en headless, que es otra cosa. Si un fix toca algo que se
  ve, la verificación en pantalla la pide el spec: acá queda **declarada en el reporte** como
  pendiente, con qué habría que medir.
