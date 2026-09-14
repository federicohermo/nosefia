---
name: spec-implement
description: Especialización de /spec-implement para No se fía (Godot). El paralelismo lo declara en prosa el `## Orden obligado` del plan.md, el TDD es obligatorio y verificado, y el nodo de convergencia es verificar.py. Se lee junto con el skill global.
---

# spec-implement — No se fía

Este archivo **no reemplaza** al skill global: aporta lo que en este repo es distinto. El
método, el fake-edge test y la convergencia salen de allá.

**No deja deuda**, y eso está en [`sin-deuda.md`](sin-deuda.md). Lo propio de
implementar es el lazo: **si acá aparece un problema de planteo, el defecto no es de este spec — es
del skill que lo dejó salir así**, y se corrigen los dos en esta corrida. Ver «Cuando el spec no
alcanza», abajo.

## Antes de arrancar

**La rama la abrís vos, y es el primer movimiento.** `spec-create` deja el spec publicado y su
fila en `staging`, y nada más.

```bash
git checkout staging && git pull                      # ahí está la fila del spec
git checkout -b feature/<NNN>-<descripcion-kebab>     # de acá saca el número el gate
python .claude/scripts/hidratar_specs.py <NNN>        # specs/ es caché: hace falta en CADA worktree
```

**El nombre de la rama no es decorativo**: `feature/<NNN>-` es de donde el hook y
`derivar_mapa.py` sacan el número del spec. A `src/` lo pueden tocar `feature/`, `bugfix/` y
`hotfix/`, pero **a `feature/` el hook le exige el `NNN` en tres dígitos**: sin él, la primera
edición se bloquea.

Si el spec ya tiene rama, no la vuelvas a crear: puede haberla abierto otra sesión, y ahí lo
que corresponde es un worktree propio sobre esa rama.

**`specs/` está en el `.gitignore`.** Leerlos anda igual —`Read` y `cat` los abren— pero
**`Grep` no los ve**: es ripgrep y respeta el `.gitignore`, así que una búsqueda ahí devuelve
cero resultados **sin decir que no miró**. Para buscar en specs: `rg --no-ignore … specs/`.

## El paralelismo viene declarado — no lo derives de cero

Vive en el `## Orden obligado` del `plan.md`, en prosa: dice **qué no se puede paralelizar** y
por qué. Todo lo que no nombra es paralelizable, que es la declaración honesta — la lista
completa de lo que sí se puede hacer junto exigiría conocer los archivos antes de abrirlos, y
está medido que esa predicción falla.

**No hay IDs de tarea ni marcas `[P]`**: se fueron con el `tasks.md`. Los nodos del `--dry` se
nombran por lo que hacen, y el orden que el `plan.md` declara es el único que bloquea.

**Seguí usando el fake-edge test sobre lo declarado, no en su lugar.** Un paralelo mal
declarado es un conflicto de escritura que aparece recién al implementar; si el test
contradice a la declaración, gana el test y **decilo** — es un hallazgo sobre el spec.

## El test va primero, y el gate lo verifica

Esto es lo que más cambia respecto de un repo cualquiera. En Godot **no hay cobertura**, así
que la disciplina no se sostiene sola: la sostienen cuatro reglas que
`python .claude/scripts/gate_de_tests.py` verifica, y que están explicadas con su modo de
falla en `.claude/scripts/lib/tdd.py`.

En la práctica, para cada tarea que toca `src/dominio/` o `src/sistemas/`:

1. **Escribí `test/<capa>/<nombre>_test.gd` primero** y corrélo: tiene que fallar, y fallar por
   lo que se espera. Un rojo de `nonexistent function` no verifica nada — verifica que el
   archivo no existe.
2. Lo mínimo para que pase.
3. Limpiar, con el test de testigo.

**Si algo no se puede probar sin levantar una escena, no va en esas dos capas.** Va en `ui/` o
en `escenas/`, que son cáscara — y entonces la regla que tenía adentro hay que bajarla al
dominio. Ésa es la conversación que el gate fuerza, y es la que hace que el juego se pueda
probar.

## Cuando lo que escribís es un gate sobre prosa

Una parte grande de lo que este repo verifica no es código: es que un `.md` diga algo. Tres
cosas se pisaron ahí, las tres medidas el 2026-09-06 en el lote 003/010/012/027/030, y las tres
cuestan una vuelta entera porque el rojo miente sobre su causa.

- **Aplaná los saltos de línea antes de buscar.** Los docs van cortados a 100 columnas, así que
  la frase que buscás cae partida y el test da rojo diciendo que el doc no lo dice **cuando sí lo
  dice**. Va `re.sub(r"\s+", " ", texto)` antes de comparar, y se compara por párrafo, no por
  línea.
- **Si el AC pide que N documentos nombren un verificador, la cadena tiene que incluir QUÉ
  verifica.** Buscar `` `gate_de_capas.py` `` a secas dio verde sobre el archivo que el spec venía
  a corregir, porque ese archivo ya nombraba al gate **de otra cosa**. La cadena era
  `` La pureza la verifica `gate_de_capas.py` ``. Un gate de una sola palabra nace mintiendo.
- **La falsificación se mide con el nodo en verde de base, y el par se toma en la misma corrida.**
  Desatar el invariante a mitad de camino da un rojo que no es el tuyo —lo tiran otros tests del
  mismo archivo, por artefactos que todavía no escribiste—, y el «vuelto atrás → verde» no llega
  nunca. Primero verde, después rojo con el cambio, después verde otra vez, seguido.

## La dirección de dependencia la verifica otro gate

`dominio/` → `sistemas/` → `ui/` → `escenas/`, sólo hacia abajo. Y **cuenta también nombrar un
`class_name` de otra capa**, que en Godot es la forma normal de escribir código y no deja
rastro en ningún import: por eso el gate construye el índice y busca los identificadores.

Si te frena, la salida no es una excepción: es mover la decisión hacia abajo, o pasar el dato
por parámetro en vez de ir a buscarlo.

## El nodo de convergencia es `verificar.py`, no los tests

```bash
python .claude/scripts/verificar.py
```

Corre los seis nodos en paralelo: `lint`, `formato`, `capas`, `tdd`, `harness` y `tests`.
Correr sólo la suite de gdUnit4 deja afuera los dos gates, que son justamente los que cuidan
lo que en este motor nadie más cuida.

**Un nodo salteado no es un nodo verde**, y el reporte lo distingue. Pero `tests` sin `GODOT_BIN`
**no se saltea: sale rojo** — ese salteo vale sólo mientras no exista un solo `*_test.gd`, y hoy
hay 23 (`verificar.py:132-141`). No salgas a buscar un salteado que no va a aparecer.

**Y `verificar.py` verde no prueba que la suite haya corrido.** Una suite de gdUnit4 que no
parsea se descarta **en silencio** y el nodo `tests` sale verde igual — es el estado normal del
paso 1 del TDD, y también el de un `class_name` recién creado que todavía no está en
`.godot/`. La única señal es el conteo crudo, que `verificar.py` **no imprime**. El comando,
para no reconstruirlo leyendo `verificar.py`:

```powershell
& $env:GODOT_BIN --path . --headless -s -d --remote-debug tcp://127.0.0.1:0 `
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a test --continue --ignoreHeadlessMode `
  -rd reports | Select-String "Executed test suites"
```

**Va en PowerShell y no en Bash**, porque en un worktree aislado —el caso normal bajo
`spec-implement-batch`— Bash rechaza cualquier forma de invocar Godot como comando: la variable y
la ruta literal entre comillas por igual. Y `--remote-debug tcp://127.0.0.1:0` contesta dos
`ERROR:` —«the remote port number must be between 1 and 65535» y «Unable to connect to
host»— que **no son un fallo**: la corrida sigue y escribe su `(N/N)`.

Ese `(N/N)` tiene que dar igual que `find test -name '*_test.gd' | wc -l`. Si da menos, hay una
suite que no corrió y el nodo verde no lo dice.

Las pruebas auxiliares usan `-rd reports/<spec>-<nodo>`. No comparten reportes con otra
corrida ni se ejecutan durante una importación: gdUnit4 puede borrar reportes aún en uso.
El comando `verificar.py` conserva su ruta de reportes.

**El escalón que cuesta una vuelta:** crear el `.gd` no alcanza para que su test lo vea. Un
`class_name` nuevo no entra al registro global hasta que se vuelve a correr
`"$GODOT_BIN" --headless --path . --import --quit`, y hasta entonces el error es
`Parse Error: Identifier "X" not declared` **con el archivo ya escrito en disco** — idéntico al
del archivo ausente, así que se lee como un error del código y no de la caché. Re-importá
después de crear cada archivo con `class_name` nuevo, no sólo una vez al abrir el worktree.

**Y el rojo del paso 1 no se lee en el conteo de fallos.** Cuando el recurso que el caso carga
todavía no existe, el error de script **aborta la función** y gdUnit4 no cuenta ninguna aserción
fallida: el caso sale **`PASSED`** por no haber llegado a afirmar nada. Medido el 2026-09-01
implementando el 023: **4 de 5 casos en verde** con la escena sin escribir. El «falla por lo que
se espera» se verifica en el `ERROR: Failed loading resource` de la salida cruda, no en el
`0 failures`.

## Cuando el spec no alcanza — el lazo

**Para cuando llegás acá no debería quedar ninguna duda de planteo.** Se resuelven entre
`spec-create` y `spec-revise`, que es donde cuestan un párrafo. Así que **una duda que aparece
implementando es evidencia de que uno de esos dos skills tiene un agujero**, y tratarla como un
problema de este spec la deja volver la próxima vez.

La descarga son dos mitades, las dos en esta corrida:

1. **Corregí el spec** para poder seguir —el AC que no se puede ver fallar, la tarea que falta, la
   regla que estaba en la capa equivocada— y **devolvelo al issue** con
   `python .claude/scripts/publicar_spec.py publicar`. Sin eso, `specs/` es caché y la próxima
   hidratación se lleva puesta la corrección.
2. **Corregí el `SKILL.md` que lo permitió**, con la regla que lo habría atajado:

   | Lo que apareció | Qué skill se corrige |
   |---|---|
   | un AC que no se puede ver fallar | `spec-create` |
   | una tarea que no dice qué archivo toca | `spec-create` |
   | una regla del juego ubicada en `ui/` o en `escenas/` | `spec-create` |
   | un paralelo que resultó falso | `spec-create` |
   | dos specs que se pisan la misma escena | `spec-revise-batch` |
   | una medición que el spec supuso en vez de correr | `spec-create` |

   **Si no entra en ninguna fila, agregá la fila** —en
   [`sin-deuda.md`](sin-deuda.md)—. La tabla está incompleta a propósito: es el
   registro de lo que este flujo ya aprendió.

Va al reporte como sección propia. **Es el entregable más caro de la corrida y el más fácil de
saltear**, porque no lo reclama ningún test ni ningún PR: el spec ya quedó andando sin él.

## Al cerrar

- **Cada criterio del spec nombrado por el test que lo verifica.** Escribí `NNN-ACn`
  —`030-AC1`, con el número del spec— en el nombre del test o en su comentario, en `test/` o
  en `.claude/scripts/tests/`. No es
  burocracia de cierre: es lo que reemplazó a la casilla como ancla anti-deuda, y hacerlo al
  final es escribirlo dos veces, y el gate de la rama lo cobra antes de que el PR aterrice.
- **Devolvé lo que editaste al issue**: `python .claude/scripts/publicar_spec.py publicar`. El
  árbol del disco es **caché**, y la próxima hidratación baja los archivos del issue y se
  lleva puesto todo lo que no se haya subido.
- **Lo que aparece implementando se hace, no se anota.** Un spec incompleto no se cierra
  abriendo un issue: se completa. Adentro del spec el ítem hereda su estado —un spec
  `Implementado` con trabajo abierto no le debe nada a nadie—, y afuera, en un issue, el
  trabajo que este spec necesitaba queda huérfano de la razón por la que existía.

  **Y lo verifica el gate:** una rama de spec con un criterio que ningún test nombra pone en
  rojo el nodo `harness` (`test_criterios_de_la_rama.py`), mientras el PR todavía está abierto.
- **El PR lleva un `Closes` por cada issue saldado**: el del spec más los de su `origen`.
- **No toques `specs/mapa.json` en el PR.** El estado lo deriva la Action en el push a
  `staging`, y el gate da rojo si el mapa dice `Implementado` mientras el PR está abierto.
- Si el spec falsificó algo que la documentación afirma en presente, actualizá `docs/`,
  `.claude/rules/` y `CLAUDE.md` — no los specs viejos, que son historia.
