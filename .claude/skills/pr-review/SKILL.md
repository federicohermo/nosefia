---
name: pr-review
description: Revisa UN PR abierto de GitHub contra los AC de su spec y las convenciones del repo, arregla lo que encuentra, verifica con verificar.py, commitea y pushea a la rama del PR. Usar al querer cerrar el review de un PR de este repo. Para dos o más de una, pr-review-batch.
argument-hint: "<NN> | (vacío = el PR de la rama actual) [--comentar] [--dry]"
# Sin `allowed-tools`, igual que el resto de los skills de este repo: declarar una lista
# parcial le sacaría todo lo que no estuviera en ella —`gh`, `verificar.py`, los git— y lo
# rompería en silencio a mitad de corrida.
---

# pr-review — No se fía

Encuentra, arregla, verifica, commitea y pushea a la rama del PR. **El reporte es lo que queda,
no el producto.**

## Qué es de acá y qué es del batch

`pr-review-batch` **no es este skill corrido N veces**: es este skill más todo lo que sólo se ve
con los N diffs adelante. Saber cuál es cuál evita las dos formas de usarlos mal.

| | acá (un PR) | `pr-review-batch` |
|---|---|---|
| Dónde trabaja | **el checkout principal**, en una rama de andamio | un worktree por PR |
| La cadena de bases | la base es un dato: la lee y listo | **la dibuja**, y es su entregable |
| Un hallazgo que es del PR de abajo | no existe: no hay «abajo» que mirar | `PERTENECE-A-PR-<N>`, y se rutea |
| Un conteo que el lote mueve | no hay lote | es del padre, y no se delega |
| Poner la pila al día | no aplica | el Paso 6, y es lo que la deja mergeable |

**Y por eso acá no hay worktree.** El batch los usa porque N agentes no pueden compartir un
árbol: corren `verificar.py` a la vez y cada uno hace `git add`. Para un PR solo, un worktree es
gimnasia sin comprador — y encima hay que limpiarlo, que en Windows es el paso que más falla.

**El precio es que te lleva el árbol de trabajo a otra rama**, así que el Paso 1 empieza
verificando que esté limpio, y el Paso 8 te devuelve donde estabas.

**El método es compartido y vive una sola vez**, en [`hallazgos.md`](./hallazgos.md): los ejes, el
filtro de confianza y la política de triage. El batch lo lee de acá por ruta de hermano.

---

## Paso 0 — Cuál es el PR, y contra qué base

`$ARGUMENTS`: el número del PR. **Sin argumento**, el de la rama en la que estás:

```bash
gh pr list --repo federicohermo/nosefia --state open --head "$(git branch --show-current)" \
  --json number,headRefName,baseRefName,author,title
```

Si no hay ninguno, **preguntá cuál**: no revises `staging` contra sí misma.

Tres datos, y el segundo es el que se equivoca solo:

1. **`headRefName`** — de acá sale el `NNN` del spec: `feature/<NNN>-<kebab>`.
2. **`baseRefName`, que no es `staging` por default.** Si este PR está apilado sobre otro
   abierto, diffear contra `staging` mete los commits del de abajo y el review se llena de
   hallazgos ajenos. Por eso `diff_pr.py` recibe la base como argumento y no tiene default.

   **Y si la base es otro PR abierto, decilo en el reporte**: un hallazgo tuyo puede ser suyo, y
   el test es mecánico — **si la línea no aparece como `+` en tu `pr.diff`, no es tuya**, aunque
   todavía no esté en `staging`. Con dos o más PR en la cadena, esto es `pr-review-batch`.
3. **El autor.** Si no sos vos, **la corrida es `--dry`**: se revisa y se reporta, no se escribe
   ni se pushea. Pushear la rama de otro no es tuyo.

Con `--dry` no se escribe nada: ni fixes, ni issues, ni push.

## Paso 1 — Pararte en la cabeza, sin perder lo que tenías

```bash
git status --short                  # tiene que estar limpio: esto te cambia de rama
git fetch origin
git checkout -B feature/<NNN>-rev-pr-<N> origin/<headRefName>
```

**El nombre de la rama no es decorativo, y el `NNN` va adelante a propósito.**
`gate_de_spec.py` corre como hook y **bloquea toda escritura a `src/` y `docs/` desde una rama
que no matchee `^feature/(\d{3})-` con ese número en `specs/mapa.json`**. Una rama tipo
`rev-pr-<N>` no matchea, así que el review de un PR que toque esas dos carpetas se quedaría sin
poder arreglar **nada** — y el síntoma es un `Edit` denegado, que se lee como un problema de
permisos y no como un problema de nombre.

**Una rama de andamio y no `git checkout <headRefName>` a secas** por dos motivos: la rama real
puede estar tomada por otro worktree, y el andamio deja explícito que **el push va a la ref real**
(Paso 7) y no al nombre local.

**Si el PR no tiene spec** —una rama `fix/` o `chore/`, que este repo permite para lo que no toca
rutas protegidas— entonces por construcción no hay nada que arreglar en `src/` ni en `docs/`, y la
rama de andamio se llama como quieras. Si igual hiciera falta tocarlas, **eso ya es un hallazgo
sobre el PR**: le falta el spec.

## Paso 2 — Hidratar el spec. No es opcional y no falla solo

```bash
python .claude/scripts/hidratar_specs.py <NNN>
```

`specs/[0-9]*/` está en el `.gitignore`. Si el spec no está en disco, el Paso 4 lee un directorio
vacío, no encuentra los AC y **revisa sin criterios de aceptación** — que es la peor forma de este
bug, porque el review igual termina y reporta.

**Y para buscar ahí dentro, `rg --no-ignore`**: `Grep` es ripgrep y respeta el `.gitignore`, así
que contesta cero sin decir que no miró.

## Paso 3 — Materializar el diff, una sola vez

```bash
python .claude/skills/pr-review/scripts/diff_pr.py <baseRefName> <dir-temporal>
```

Emite el diff, el `--stat`, las listas de código, prosa y **escenas** por separado, el gate de
ejes y las afirmaciones numéricas que el diff agrega.

- **Un eje que salió `no` no se revisa.** No le busques hallazgos: la lista de ruido es el modo de
  falla de un review, no la de hallazgos perdidos.
- **Si `diff_size=grande`, no leas el diff entero.** Triageá con el `--stat` y leé por archivo.
  Leer 900 líneas para descubrir que 500 son markdown es el gasto más caro del pipeline.
- **`scene_files` distinto de cero** cambia lo que hacés, no sólo lo que mirás: ver
  [`hallazgos.md`](./hallazgos.md), eje «escenas».

## Paso 4 — Contrastar contra los AC del spec

Cada AC del `spec.md`, uno por uno, contra el diff. **Un AC sin contraparte verificable en el diff
es hallazgo aunque el código esté bien** — y en este repo eso tiene una forma concreta: el AC dice
que algo pasa, y no hay ni un test de gdUnit4 que lo vea fallar.

Al revés también: **un AC que no se puede ver fallar es un hallazgo sobre el spec**, no sobre el
PR. «El HUD muestra el tiempo» no; «con 3 minutos restantes, `tiempo_restante()` devuelve 180.0»
sí. Va como issue, no como fix.

## Paso 5 — Encontrar y arreglar

Con el método de [`hallazgos.md`](./hallazgos.md), que es donde viven los ejes, el filtro de
confianza y la tabla de triage. Tres cosas que no se negocian y que están allá con su porqué:

- **El default es arreglar.** No aplicar es lo que necesita justificarse, y los motivos válidos
  son exactamente tres: pelea con un AC, pediría un rediseño más grande que el PR, o lo cierra una
  persona. «Es preexistente» y «no lo medí» no están en la lista.
- **«Bloqueado» no es «descartado».** Si una herramienta te niega el fix, eso no es una decisión de
  triage: se reporta como `BLOQUEADO` con el fix exacto en una línea copiable. Y si el bloqueo vino
  del hook, **mirá el nombre de tu rama antes que nada** (Paso 1).
- **Un 🟡 que no se aplica se abre como issue**, con `gh issue create`, con título que se entienda
  fuera del contexto del spec, el cuerpo con la evidencia, y `Detectado en #N`. **El `#N` sale de
  `specs/mapa.json` y no del `NNN`** — el spec 001 es el issue #3.

## Paso 6 — `verificar.py` en verde, y el salteado no es verde

```bash
python .claude/scripts/verificar.py
```

**El modo de falla de este repo no es un rojo: es un salteado.** `verificar.py` saltea `tests` si
no encuentra `GODOT_BIN` y **lo declara** — pero un reporte que dice «6/6» sin leer los salteados
dio por corrida una suite que no corrió, y entonces no sabés si tu fix rompió algo.

1. **Leé los salteados antes que los rojos.** `tests` salteado es un rojo del review.
2. Si el salteo es por `GODOT_BIN`: en esta máquina **no está en el entorno de la terminal**, se
   lee del registro de Windows, y una terminal anterior a la variable le pasa el entorno viejo a
   todo lo que lance. Se arregla cerrando el **host** de la terminal, no una pestaña.
3. Si Godot está adentro de OneDrive y el archivo no está descargado, Windows contesta «el
   proveedor de archivos de nube no se está ejecutando», que no nombra ni a Godot ni a los tests.
4. **`gdformat` decide el formato.** Si el nodo `formato` está rojo, corré `gdformat src test` y
   commiteá lo que produzca; no se discute en una revisión.

**No commitees el árbol rojo.** Si queda rojo después de esto, revertí lo que lo rompió, no
pushees, y decilo. Un pipeline que pushea para completarse no sirve.

## Paso 7 — Commit y push

```bash
git push origin HEAD:refs/heads/<headRefName>
```

Sin `--force` y sin rebase: un rebase reescribe los commits que el autor del PR ya leyó.

**El mensaje de commit se escribe con `Write` a un archivo y se pasa con `-F`, nunca con
heredoc.** Los backticks y los `$` del contenido lo rompen con un `unexpected EOF` que cuesta más
diagnosticar que reescribirlo — está medido en esta máquina.

**Verificá que el push llegó**: `git fetch origin` y comparar el head remoto contra tu SHA. Un
«pusheado» con un remoto que no se movió es el único modo de falla silencioso que queda.

**Con `--comentar`**, un general en el PR encabezado por el SHA, con las cuatro secciones:
bloqueantes resueltos, mejoras aplicadas, **no aplicado con motivo**, y lo que sigue abierto. La
tercera es la que le da valor — un review que sólo cuenta lo que arregló no es confiable cuando
calla. **No abras inline sobre un PR que ya arreglaste**: es ruido con costo y se paga dos veces
en eco.

## Paso 8 — Devolver el árbol, y el reporte

```bash
git checkout <la rama donde estabas>
```

Y borrá la rama de andamio **recién después de verificar que es idéntica a su
`origin/<headRefName>`**. Si difieren, algo no se pusheó y la rama es lo único que lo tiene.

El reporte, en ~30 líneas:

1. **Veredicto en la primera línea**, y si `verificar.py` pasó a la primera, a la segunda, o **con
   algún nodo salteado**. Esa tercera opción no se omite.
2. **Los bloqueantes**, con `archivo:línea` y evidencia.
3. **Lo aplicado**, comprimido a conteos.
4. **Lo NO aplicado, con su motivo** —uno de los tres— y el número del issue que quedó abierto.
   **No es redundante con el PR**: el issue no está en el diff, así que quien mergea sólo lo ve
   acá.
5. **Lo `BLOQUEADO`**, con quién lo bloqueó y el fix exacto.
6. **Las escenas que toca**, si toca alguna, y si hay que rehacer algo a mano en el editor.
7. **El SHA**, y si la base era otro PR abierto.

---

## Lo que no hace

- **No mergea, y no mueve estados en `specs/mapa.json`.** El estado lo deriva la Action en el push
  a `staging`, y el gate da rojo si alguien lo escribe a mano.
- **No abre PRs ni ramas de feature.** Trabaja sobre lo que ya está abierto.
- **No revisa specs que todavía son texto.** Eso es `spec-review`, corre antes, y sale mucho más
  barato: un problema detectado como texto cuesta un párrafo.
- **No pone al día una pila de PRs.** Eso es el Paso 6 de `pr-review-batch`, y necesita ver la
  cadena entera.
- **No abre el juego.** Corre la suite en headless, que es otra cosa. Si un fix toca algo que se
  ve, la verificación en pantalla queda **declarada en el reporte** como pendiente, con qué habría
  que medir.
