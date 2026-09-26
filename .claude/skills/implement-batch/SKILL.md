---
name: implement-batch
description: "Implementa N issues de No se fía en paralelo —un carril por cadena de dependencias, cada uno en su worktree— delegando cada issue a implement-feature, y cierra con un PR por issue, verificar.py en verde y ningún criterio sin test que lo cite. Usar al implementar dos o más issues de una. Para uno solo, implement-feature."
argument-hint: "<NN NN ...>"
---

# implement-batch — No se fía

**El método de cada issue es `implement-feature`**, y no se repite acá.
Lo de este archivo es lo que sólo existe con más de un issue a la vez: repartir en carriles,
aislar en worktrees y cerrar el lote.

**No deja deuda**, y eso está en [`sin-deuda.md`](sin-deuda.md).

## Paso 0 — Leer el lote, y sacar los que no van

```bash
gh issue list --state open --limit 50
gh issue view <N>          # uno por issue del lote
```

De cada issue salen las tres cosas que deciden el reparto: qué **criterios** entrega, qué dice su
fila **«Se escribe»**, y a quién declara depender.

**Sacá del lote, antes de repartir:**

- El que ya tiene PR abierto. `gh pr list --state open`.
- El que depende de algo que **no está en el lote** y todavía no aterrizó. Una arista que apunta
  afuera no la ve ningún reparto.
- El que tiene una `OQ-<COD>-###` sin contestar de por medio.

**Y re-medí lo que el issue declara.** Un número que el issue midió bien puede haber envejecido
entre que se escribió y hoy. Lo que se mide es el árbol de hoy, no lo que el issue dice del árbol
de ayer.

## Paso 1 — Repartir en carriles

**Un carril es una cadena de dependencias**, y los carriles corren concurrentes. Tres cosas
obligan a poner dos issues en el mismo carril, en orden:

1. **Una dependencia declarada** (`Depende de #N`).
2. **Un archivo compartido para escritura.** Las dos filas «Se escribe» se cruzan. Un `.gd` o
   un spec con cambios chicos en zonas distintas no obliga: el padre prueba el merge con
   `git merge-tree --write-tree <rama> <rama>` y resuelve lo que choque. En el lote del
   2026-09-26, la regla estricta dejaba 13 issues en un solo carril, y los carriles separados
   chocaron sólo en dos specs y un `.gd`.
3. **Una escena compartida.** Éste no se negocia: **un `.tscn` no se mergea.** Un merge de tres
   vías sobre una escena no da un conflicto, da una escena corrupta. Dos issues que tocan la misma
   escena van en serie aunque no compartan nada más.

Todo lo demás va en carriles distintos.

## Paso 2 — El checker cruzado, antes de escribir una línea

Antes de lanzar nada, cruzá los issues del lote entre sí y **decí qué encontraste**:

- Dos issues que entregan el **mismo criterio**. Uno de los dos sobra.
- Un criterio que **ningún issue del lote entrega** y que el lote da por hecho.
- Dos issues que contradicen la misma regla del contrato.

Lo que aparezca se corrige ahora —el issue con `gh issue edit`, el contrato con `to-spec`— y no
se reparte roto.

## Paso 3 — Un worktree por carril

Lanzá los carriles en **un solo mensaje**, un `Agent` por carril con `isolation: "worktree"`.

Cada agente recibe, literal:

- **El preámbulo destilado una vez para todo el lote**: las cuatro capas y su dirección, las
  convenciones verificables con quién verifica cada una, y las trampas de este repo. Es el ahorro
  propio del batch — sin esto, N carriles lo re-derivan N veces desde frío.
- **La rama se llama `<tipo>/<issue>-<kebab>`, con el tipo del issue, y eso no es decorativo.**
  `gate_de_rama.py` corre como hook y **sólo deja escribir en `src/` desde `feature/`, `bugfix/`,
  `refactor/` e `improvement/`**. El síntoma es un `Edit` denegado, que se lee como un
  problema de permisos y no como uno de nombre. **Es la falla número uno de un carril**, y aparece
  recién en la primera edición, con el worktree ya abierto.
- **El issue entero, pegado.** El worktree no trae el plan: el plan está en GitHub. Un carril que
  tiene que salir a buscarlo pierde una vuelta, y uno que no lo busca implementa de memoria.
- **El contrato de la capacidad sí viaja**: `specs/` está trackeado, así que `git worktree add` lo
  trae. Es la diferencia con el régimen viejo, donde el árbol de specs era caché y había que
  hidratarlo en cada worktree.
- **`GODOT_BIN` tiene que estar en el entorno del carril**: sin ella el nodo `tests` sale **rojo**,
  no salteado. Ese salteo vence — existe sólo mientras no haya un solo `*_test.gd`, y hay muchos.
  Un carril que sale a buscar un salteado que nunca va a aparecer pierde una vuelta.
- **Con `verificar.py`, la importación no es un paso del carril.** `.godot/` está en el
  `.gitignore` y ningún worktree nuevo lo tiene, pero desde el 2026-09-18 el nodo `tests` importa
  antes de correr la suite, siempre. Cuesta 6 s sobre los ~180 s del nodo, y evita los dos rojos
  que costaba olvidarlo: `Could not find type "GdUnitTestCIRunner"` en un worktree nuevo, e
  `Identifier "X" not declared` con el archivo ya en disco cada vez que se escribe un
  `class_name`. Medido el 2026-08-31: lo pisaron los cuatro carriles del lote.
- **Y va en PowerShell porque desde Bash no corre, y eso hay que decírselo.** En un worktree
  aislado **cualquier forma de invocar Godot como comando desde Bash se rechaza**: la variable y
  la ruta literal entre comillas por igual. Lo que sí pasa desde Bash es
  `python .claude/scripts/verificar.py` con `GODOT_BIN` exportada, porque ahí **el comando es
  `python`**. **Medido el 2026-09-06: lo pisaron TRES de los cuatro carriles**, cada uno perdiendo
  una vuelta, y los tres con el comando escrito por este mismo skill en la forma que no corre.
- **Y ese `--import` no es una vez: es una por `class_name` nuevo.** Crear el `.gd` no alcanza
  para que su test lo vea, y hasta el `--import` siguiente el error es `Parse Error: Identifier
  "X" not declared` **con el archivo ya escrito en disco**. Se lee como un error del código y no
  de la caché. **Medido el 2026-09-01: lo pisaron los dos carriles que crearon clases.**
- **Dale al carril el comando del conteo crudo, no sólo la orden de mirarlo.** `verificar.py` **no
  imprime** el `Executed test suites: (N/N)`. **La primera línea importa**: `verificar.py` lo
  hace solo, pero este comando no, y en un worktree nuevo sin ella sale
  `Could not find type "GdUnitTestCIRunner"`. Medido el 2026-09-23: lo pisaron los dos carriles.

  ```powershell
  & $env:GODOT_BIN --path . --headless --import 2>$null | Out-Null
  & $env:GODOT_BIN --path . --headless -s -d --remote-debug tcp://127.0.0.1:0 `
    res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a test --continue --ignoreHeadlessMode `
    -rd reports 2>$null | Select-String "Executed test suites"
  ```

- **El carril no corrige un skill: reporta la falla, y la regla la escribe el padre.**
  `implement-feature` le pide cerrar el lazo, y en un lote eso da N copias de la misma lección.
  Medido el 2026-09-23: los dos carriles escribieron la misma regla en `to-issue` y en las siete
  copias de `sin-deuda.md`, y los dos PR chocaban en ocho archivos.
- **Un nombre propio para cada archivo de scratch.** Dos carriles que escriben el mismo archivo
  temporal se pisan sin conflicto visible. **Y se escribe con `Write`.**
- **Un comando que este skill entrega se vuelve a correr antes de repartirlo**, nunca se copia de
  la corrida anterior: un comando roto se reparte N veces.

### La condición de terminado del carril — no se negocia

> **Un carril termina con el PR abierto y sin un solo criterio sin test que lo cite. No antes.**
>
> Por cada issue suyo: `verificar.py` en verde **sin nodos salteados**, todo lo que el issue pide
> hecho, rama pusheada, PR abierto contra la base que le toca y con `Closes #N`.
>
> **No existe volver con «quedó listo para commitear», «falta abrir el PR» ni «lo dejo en el
> working tree».** Y no existe volver con trabajo abierto: si el issue tenía trabajo que no se
> hizo, el carril no terminó.
>
> Si algo bloquea de verdad, el carril **igual vuelve con lo que sí cerró**, y el bloqueo escrito
> con su evidencia y el comando exacto. Lo que no vuelve nunca es un carril entero sin entregar
> nada.

**El padre lo verifica, no lo cree.** Cuando vuelva un carril:

```bash
gh pr list --repo federicohermo/nosefia --head <tipo>/<N>-<kebab> --json number,statusCheckRollup
rg -n "AC-<COD>-###" test/ .claude/scripts/tests/
```

La cita de cada criterio **no se cuenta a mano**: `gate_de_specs.py` la cobra sobre los specs
`ratified`, y el `rg` contesta por los que todavía están en `draft`.

Un reporte que dice «listo» sin PR es un carril incompleto: terminalo vos o relanzalo con lo que
le faltó. Esperá a que vuelvan todos antes del reporte.

## Paso 4 — Lo que sólo el padre puede cerrar

- **Las ediciones fuera de carril**, en serie, para que el diff se lea.
- **El lazo, y es del padre por construcción**: si dos carriles corrigen el mismo `SKILL.md` a la
  vez, se pisan sin conflicto visible. Sale en su propio PR `harness/` desde `staging`, no en el PR
  de un carril: el issue del carril no lo cubre.
- **El contrato de la capacidad, si dos carriles lo editaron.** `specs/` está trackeado, así que
  dos carriles que agregan una regla a la misma capacidad dan un conflicto de merge de verdad —
  que es mejor que el silencio, pero lo resuelve el padre.
- **`python .claude/scripts/verificar.py`** en el checkout principal, con todo mergeado hacia
  arriba. Los siete nodos verdes por carril no implican los siete verdes juntos.

## Paso 5 — Destruir los worktrees

```bash
python .claude/skills/implement-batch/scripts/limpiar_worktrees.py --todos
```

**Va antes del reporte, no después, y no se hace a mano.** `git worktree remove` falla con
`Directory not empty` en **todo worktree que haya corrido `verificar.py`**, o sea en todos: el
nodo `tests` levanta Godot headless y Godot escribe su caché en `.godot/`. `--force` no ayuda — no
es un problema de cambios sin commitear.

Y mata **por ruta del worktree, nunca por nombre de proceso**: un filtro por `godot.exe` se
llevaría puesto el editor que el usuario tiene abierto con el checkout principal.

Si imprime `SIGUE AHI`, el handle es de afuera. **Lo cierra el usuario, no vos**: decilo.

## Paso 6 — El reporte

1. **Si algo quedó bloqueado, la primera línea dice que la corrida falló.** No «se cerró casi
   todo».
2. **Una tabla, una fila por issue:** número, carril, PR, criterios que entregó, y **si
   `verificar.py` pasó a la primera, a la segunda, o con algún nodo salteado**. La tercera opción
   no se omite.
3. **Los carriles, su ancho, y cuántas de las dependencias declaradas resultaron falsas.**
4. **Qué encontró el Paso 2 y qué se decidió** — el entregable propio de este skill.
5. **Qué obligó a editar un contrato o un issue.**
6. **Qué `SKILL.md` se corrigió y con qué regla.** Es el lazo, y es lo único que impide que el
   mismo problema vuelva en el lote siguiente.
7. **El orden de merge, de abajo hacia arriba**, y qué PR hay que repuntar a `staging` antes de
   que se borre su base.
8. **Las escenas que el lote tocó**, y si alguna hay que rehacer a mano en el editor.
9. **Qué capacidades quedaron ratificables**, o sea con todos sus criterios citados.

**El reporte no puede decir «queda pendiente».** Si aparece esa frase, algo no se descargó.
