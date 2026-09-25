---
name: implement-feature
description: "Implementa UN cambio de No se fía — un issue, o un spec recién escrito sin issue — con TDD obligatorio y verificado, y verificar.py como nodo de convergencia. Cierra con el PR abierto, los criterios del issue cumplidos y cada criterio del spec citado por un test. Para dos o más issues de una, implement-batch."
argument-hint: "[NN del issue | capability con spec sin issue]"
---

# implement-feature — No se fía

**Lo que se implementa es un issue**, o un spec que se escribió sin issue. El issue es el plan
de esta vez: qué se toca y cómo se sabe que está. El spec —`specs/<capability>/<capability>.md`—
es el contrato que queda. Muchos issues no tocan ningún spec.

**No deja deuda**, y eso está en [`sin-deuda.md`](sin-deuda.md). Lo propio de implementar es el
lazo: **si acá aparece un problema de planteo, el defecto no es de este issue — es del skill que
lo dejó salir así**, y se corrigen los dos en esta corrida.

## Antes de arrancar

```bash
gh issue view <N>                                  # el plan entero
git checkout staging && git pull
git checkout -b <tipo>/<N>-<descripcion-kebab>
```

**El prefijo de la rama es el tipo del issue**, y el hook sólo deja escribir en `src/` desde
`feature/`, `bugfix/`, `refactor/` e `improvement/`. `feature/` es para código que parte de
un spec: si el spec todavía no está escrito, primero `to-spec`, en esta misma rama. Lo
que no toca `src/` se nombra por lo que toca — `harness/` o `docs/`.

Si el issue ya tiene rama, no la vuelvas a crear: puede haberla abierto otra sesión, y ahí lo que
corresponde es un worktree propio sobre esa rama. **Un worktree se abre sólo en
`.claude/worktrees/<nombre>` del checkout principal**, y lo bloquea un hook si va a otro lado:
es el único lugar que limpia `limpiar_worktrees.py`.

**Si el cambio toca un spec, leelo entero, no sólo sus criterios nuevos.** Las reglas de la
capacidad son el marco: un criterio que se cumple rompiendo otra regla no está cumplido.

## Los límites del issue son límites

La tabla de **límites de archivo** del issue no es una sugerencia: la fila «No se toca» es una
lista negativa y cerrada. Si el trabajo pide escribir algo de esa fila, **eso es un hallazgo sobre
el issue** y se descarga por la 2 o la 4 de `sin-deuda.md` — no se escribe igual.

Los `.tscn` compartidos son el caso caro: **una escena no se mergea.** Dos issues que tocan la
misma escena se ordenan, no se paralelizan.

## El test va primero, y el gate lo verifica

Esto es lo que más cambia respecto de un repo cualquiera. En Godot **no hay cobertura**, así que
la disciplina no se sostiene sola: la sostienen cuatro reglas que
`python .claude/scripts/gate_de_tests.py` verifica, y que están explicadas con su modo de falla en
`.claude/scripts/lib/tdd.py`.

Para cada cosa que toca `src/dominio/` o `src/sistemas/`:

1. **Escribí `test/<capa>/<nombre>_test.gd` primero** y corrélo: tiene que fallar, y fallar por lo
   que se espera. Un rojo de `nonexistent function` no verifica nada — verifica que el archivo no
   existe.
2. Lo mínimo para que pase.
3. Limpiar, con el test de testigo.

**El nombre del test cita su criterio**, y se escribe ahí mismo y no al final:

```gdscript
func test_dos_jornadas_graves_seguidas_despiden() -> void:  # AC-EMP-004
```

**Un test que compara dos lecturas del mismo cuadro tiene que forzar la escritura antes de leer.**
`await get_tree().process_frame` sigue **antes** del `_process` de los nodos. Leer justo después
del `await` compara la escritura del cuadro anterior contra el instante de éste. Medido el
2026-09-14: 30,98 mm de desfasaje aparente con el arreglo ya puesto, que se lee como que el
arreglo no alcanza. O se llama al método a mano antes de leer, o se comparan dos instantes
declarados distintos.

**Si algo no se puede probar sin levantar una escena, no va en esas dos capas.** Va en `ui/` o en
`escenas/`, que son cáscara — y entonces la regla que tenía adentro hay que bajarla al dominio.
Ésa es la conversación que el gate fuerza, y es la que hace que el juego se pueda probar.

**Lo que se mira en la web se mira en un Chrome que dibuja.** Un Chrome manejado por Playwright
que queda tapado por otra ventana casi no pide cuadros: dos capturas seguidas salen iguales. En el
#181 el agua parecía quieta en la web, y el juego no llegó a 240 cuadros en 20 segundos. Va con
`--disable-backgrounding-occluded-windows` y `--disable-renderer-backgrounding`, y antes de leer
una captura se cuentan los `requestAnimationFrame` de un segundo.

## Cuando lo que escribís es un gate sobre prosa

Una parte de lo que este repo verifica no es código: es que un `.md` diga algo. Tres cosas se
pisaron ahí, las tres medidas el 2026-09-06, y las tres cuestan una vuelta entera porque el rojo
miente sobre su causa.

- **Aplaná los saltos de línea antes de buscar.** Los docs van cortados a 100 columnas, así que la
  frase que buscás cae partida y el test da rojo diciendo que el doc no lo dice **cuando sí lo
  dice**. Va `re.sub(r"\s+", " ", texto)` antes de comparar, y se compara por párrafo.
- **Si el criterio pide que N documentos nombren un verificador, la cadena tiene que incluir QUÉ
  verifica.** Buscar `` `gate_de_capas.py` `` a secas dio verde sobre el archivo que venía a
  corregirse, porque ya lo nombraba **de otra cosa**.
- **La falsificación se mide con el nodo en verde de base, y el par se toma en la misma corrida.**
  Primero verde, después rojo con el cambio, después verde otra vez, seguido.

## La dirección de dependencia la verifica otro gate

`dominio/` → `sistemas/` → `ui/` → `escenas/`, sólo hacia abajo. Y **cuenta también nombrar un
`class_name` de otra capa**, que en Godot es la forma normal de escribir código y no deja rastro
en ningún import: por eso el gate construye el índice y busca los identificadores.

Si te frena, la salida no es una excepción: es mover la decisión hacia abajo, o pasar el dato por
parámetro en vez de ir a buscarlo.

## El nodo de convergencia es `verificar.py`, no los tests

```bash
python .claude/scripts/verificar.py
```

Corre los siete nodos en paralelo: `lint`, `formato`, `capas`, `tdd`, `specs`, `harness` y
`tests`. Correr sólo la suite de gdUnit4 deja afuera los gates, que son justamente los que cuidan
lo que en este motor nadie más cuida.

**Un nodo salteado no es un nodo verde**, y el reporte lo distingue. Pero `tests` sin `GODOT_BIN`
**no se saltea: sale rojo** — ese salteo vale sólo mientras no exista un solo `*_test.gd`, y hay
muchos.

**Y `verificar.py` verde no prueba que la suite haya corrido.** Una suite de gdUnit4 que no parsea
se descarta **en silencio** y el nodo `tests` sale verde igual — es el estado normal del paso 1 del
TDD, y también el de un `class_name` recién creado. La única señal es el conteo crudo, que
`verificar.py` **no imprime**:

```powershell
& $env:GODOT_BIN --path . --headless -s -d --remote-debug tcp://127.0.0.1:0 `
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a test --continue --ignoreHeadlessMode `
  -rd reports 2>$null | Select-String "Executed test suites"
```

**Va en PowerShell y no en Bash**, porque en un worktree aislado Bash rechaza cualquier forma de
invocar Godot como comando. **Y el `2>$null` no se saca**: PowerShell no pasa el stderr de Godot
por `Select-String`, y sin él la corrida devuelve 4,5 MB. Medido el 2026-09-24.

Ese `(N/N)` tiene que dar igual que `find test -name '*_test.gd' | wc -l`. Si da menos, hay una
suite que no corrió y el nodo verde no lo dice.

**El escalón que cuesta una vuelta:** crear el `.gd` no alcanza para que su test lo vea. Un
`class_name` nuevo no entra al registro global hasta que se vuelve a correr
`& $env:GODOT_BIN --headless --path . --import --quit`, desde PowerShell, y hasta entonces el error
es `Parse Error: Identifier "X" not declared` **con el archivo ya escrito en disco**. Re-importá
después de crear cada archivo con `class_name` nuevo.

**Y el rojo del paso 1 no se lee en el conteo de fallos.** Cuando el recurso que el caso carga
todavía no existe, el error de script **aborta la función** y gdUnit4 no cuenta ninguna aserción
fallida: el caso sale **`PASSED`** por no haber llegado a afirmar nada. Medido el 2026-09-01: **4
de 5 casos en verde** con la escena sin escribir. El «falla por lo que se espera» se verifica en el
`ERROR: Failed loading resource` de la salida cruda. Ese `ERROR:` va por stderr: se lee corriendo
sólo esa suite, con `-a <ruta>` y sin `2>$null`. Los dos `ERROR:` de `--remote-debug` no son un
fallo.

**Y `--import` reescribe `project.godot`.** El editor no guarda un ajuste igual a su valor por
defecto: lo borra del archivo. Medido el 2026-09-14 con
`common/physics_ticks_per_second=60` escrito a mano: la línea desaparece; con `=90` se conserva.
Después de editar `project.godot`, corré `--import` y volvé a leer el archivo antes de dar el
criterio por cerrado.

## Cuando el issue o el contrato no alcanzan — el lazo

**Para cuando llegás acá no debería quedar ninguna duda de planteo.** Se resuelven en `to-issue`
y en `to-spec`, que es donde cuestan un párrafo. Una duda que aparece implementando es
evidencia de que uno de esos dos tiene un agujero.

La descarga son dos mitades, las dos en esta corrida:

1. **Corregí lo que falta** —el criterio que no se puede ver fallar, el límite de archivo mal
   medido, la regla que estaba en la capa equivocada—. Si es del contrato, se edita
   `specs/<capability>/<capability>.md` **en este mismo PR**. Si es del issue, se edita el issue
   con `gh issue edit <N>`.
2. **Corregí el `SKILL.md` que lo permitió**, con la regla que lo habría atajado. La tabla de
   correspondencias está en [`sin-deuda.md`](sin-deuda.md), y **si no entra en ninguna fila,
   agregá la fila**.

Va al reporte como sección propia. **Es el entregable más caro de la corrida y el más fácil de
saltear**, porque no lo reclama ningún test ni ningún PR.

**Nunca se ajusta el contrato para que coincida con el código.** Si difieren, eso es el hallazgo:
se corrige el código.

## Al cerrar

- **Cada criterio del spec que el cambio agrega o cambia, nombrado por el test que lo verifica**
  —`# AC-EMP-004`, con el código de la capacidad—, en `test/` o en `.claude/scripts/tests/`. Es
  el ancla anti-deuda que cobra el gate.
- **Cada criterio propio del issue, cumplido y marcado en el issue.** Esos no llevan ID ni se
  citan: mueren con el issue.
- **Si la capacidad quedó con todos sus criterios citados, pasala a `ratified`** en el frontmatter
  del spec, en este PR. Desde ahí el gate la cobra.
- `python .claude/scripts/verificar.py` en verde, sin nodos salteados.
- **El PR declara, por cada `AC-<COD>-###`, `AC → test → resultado`**, y lleva `Closes #N` si hay
  issue.
- **Lo que aparece implementando se hace, no se anota.** Un issue incompleto no se cierra abriendo
  otro issue: se completa.
- Si el trabajo falsificó algo que la documentación afirma en presente, actualizá `docs/`,
  `.claude/rules/` y `CLAUDE.md`.
