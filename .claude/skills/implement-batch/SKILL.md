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

**Una pausa para integrar otra base invalida el preflight anterior.** Al reanudar, actualizar los
worktrees limpios a una cabeza explícita y volver a cruzar recursos, lectores y geometría. Los
borradores preparados sobre la base anterior no se ejecutan sin esa revisión. Si cambió la
premisa, actualizar el issue entero antes de implementar. En el lote del 2026-10-08, la nueva
base reemplazó el fondo de computadora por un shader y ya traía las hojas del baño: comprimir
la imagen vieja o crear hojas A4 habría trabajado sobre recursos que el juego ya no necesitaba.

**Si el issue cita un prototipo o un protocolo que no trae escrito, conseguilo antes de
repartir.** «Los 600 estados del protocolo» o «las 24 poses medidas» no se pueden reproducir
sin sus parámetros. Se le pide al usuario dónde está, y va al preámbulo. En el lote del
2026-10-06 el prototipo apareció con los carriles en vuelo: el de #320 rehízo su escenario,
dos exports y una ronda de mediciones.

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
- **Un issue abierto fuera del lote que parte de una regla que el lote cambia.** No se reparte,
  pero queda mintiendo el día que el lote aterrice. Se buscan por el spec que tocan, no por el
  número. En el lote del 2026-09-29, #176 —abierto— contaba un depósito de 10 que #263 pasaba a
  8, y el usuario lo sumó al lote.
- **Un borde que describe un gesto que el juego no tiene.** Se implementa inventando la regla que
  falta. En el mismo lote, dos issues vendían «de la góndola» contra `BR-CTR-014`.

**Un issue que el cruce reescribe se reescribe entero**: su premisa, su contrato y sus
criterios. El contrato sale de la premisa, y la premisa nueva deja mintiendo al viejo. En el lote
del 2026-09-29, el cruce reescribió la premisa de #176 (la caja cuenta desde el depósito), y su
contrato siguió pidiendo `sacar() -> bool` y una caja que guarda su propio número.

Lo que aparezca se corrige ahora —el issue con `gh issue edit`, el contrato con `to-spec`— y no
se reparte roto.

## Paso 3 — Un worktree por carril

Lanzá los carriles en **un solo mensaje**, un `Agent` por carril con `isolation: "worktree"`.

Cada agente recibe, literal:

- **El preámbulo destilado una vez para todo el lote**: las cuatro capas y su dirección, las
  convenciones verificables con quién verifica cada una, y las trampas de este repo. Es el ahorro
  propio del batch — sin esto, N carriles lo re-derivan N veces desde frío.
- **Y el preámbulo se mide en la máquina donde corren los carriles.** Los comandos de este skill
  son los de la máquina Windows del equipo. En un contenedor Linux de la nube no hay PowerShell,
  ni Godot, ni Blender, y `download.blender.org` puede estar bloqueado. Lo que anduvo el
  2026-09-29, medido antes de repartir:
  - Godot del zip de la release, con un enlace en el PATH: `lib/godot.py` lo encuentra ahí.
  - Blender como `bpy` de PyPI, de la serie que pinnea `lib/blender.py`, envuelto en un script
    que emula `blender <x.blend> --background --python <s.py> -- <args>`, y declarado en
    `BLENDER_BIN` adelante de cada comando. Reexportó el `.glb` con el mismo tamaño en bytes.
  - Las capturas, con `xvfb-run` y `--rendering-driver opengl3` (llvmpipe).
  - El horneado, con `xvfb-run` y lavapipe: `VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json`.
  - El conteo crudo sale sin volver a correr: `grep -c "<testsuite "` sobre el `results.xml` del
    último `reports/report_N/`.
  - **El `-rd` de gdUnit4 es relativo al proyecto aunque empiece con `/`**: `-rd /tmp/x` crea
    `tmp/x` adentro del repo. Pasó en dos carriles del lote del 2026-09-29, el segundo con la
    advertencia en su preámbulo, y por eso `/tmp/` está en `.gitignore`.
  - **Los reportes se piden con `-rd res://reports`, también los focales con su subcarpeta.**
    La URI se globaliza a una ruta absoluta antes de la limpieza del historial. `-rd reports`
    funciona hasta superar veinte reportes; entonces gdUnit4 repite la ruta relativa contra el
    `DirAccess` abierto y falla al retirar el más antiguo. Medido en #303 del 2026-10-09 con
    una sonda de veintiún reportes. No se modifica el addon ni el tope para eludir el error.
  - Las variables de entorno no sobreviven entre llamadas a Bash: van adelante del comando.
  - Lo que corre de fondo va con el `run_in_background` de Bash. Un `nohup … &` adentro de un
    comando muere con él, sin dejar salida: le pasó a una verificación integrada del padre el
    2026-09-30.
- **Las capturas que pide un issue suben con `scripts/capturas_a_rama.py`**, a la rama huérfana
  `capturas/<N>`, que no se mergea, y el PR las muestra por su URL cruda. **No con un worktree
  aparte**: el guard rechaza `git -C <otro worktree>` desde el worktree de un carril. Medido el
  2026-09-29 en el carril de #267, que las subió a mano con plumbing de git.
- **Y Bash rechaza un comando con la palabra `source` en una ruta**, con «runs a string through
  source». Para mirar `assets/source/` va `Glob`, `Grep` o Python. Medido el mismo día. También
  rechaza, con «too complex to verify», un subshell que corre Godot, `godot … "$VAR"`, un `for`
  que corre Godot con una variable y un heredoc largo de Python con `git` adentro. En el carril
  de #276 rechazó además tres comandos sin Godot: un `for` sobre `$(rg -l …)`,
  `gdlint $(git diff --name-only …)`, y `git rev-parse … && test -z "$(rg …)"`. Lo que tienen en
  común es una sustitución `$(…)` como argumento. Todo eso va a un script en el scratch del
  carril, que se corre en una línea.
- **Un carril se corta sin avisar, y se retoma, no se relanza.** El límite de sesión de la API
  corta a todos los carriles a la vez, y un reinicio del contenedor mata sus procesos. El
  worktree y el scratch sobreviven; el proceso, no. Se retoma con `SendMessage` al mismo
  agente: el mensaje dice en qué commit quedó el worktree, qué quedó sin commitear y que no se
  apoye en un log cortado. Por eso cada carril commitea y empuja a medida que avanza. En el
  lote del 2026-09-29 pasó cuatro veces, y no se perdió nada que estuviera commiteado.
- **`nosefia-index` no mira el worktree del carril.** Lo levanta la sesión desde el checkout
  principal, y los subagentes lo comparten: contesta sobre ese árbol. En un carril apilado sobre
  otro PR describe el árbol de antes. El 2026-09-29, en el carril de #263, decía 18 reglas y 21
  criterios de `store-stock`, y la rama tenía 20 y 25. Adentro de un carril, lo que cuenta es el
  `rg` sobre el worktree.
- **Y la rama sale de una base explícita, porque el worktree no arranca en ella.** El
  `isolation: "worktree"` arma el worktree sobre `origin/main`: medido el 2026-09-29, 469
  commits detrás de `staging`, en los dos primeros carriles del lote. Un carril que crea su rama
  desde donde está trabaja sobre el árbol de la última entrega. Va `git fetch origin <base>` y
  `git checkout --no-track -b <rama> origin/<base>`, y `git merge-base --is-ancestor
  origin/<base> HEAD` antes de la primera edición. **El `--no-track` evita que dos carriles
  escriban a la vez el `.git/config` compartido.** Al de #264 le pasó: la rama quedó creada, el
  índice cambiado y HEAD todavía en `worktree-agent-…`. El upstream lo pone el `push -u`.
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
- **Y en Bash, un comando por llamada.** En un worktree aislado, Bash rechaza por «too complex
  to verify» un comando compuesto que nombra `git`, un `&&` largo, y un heredoc con `mkdir` y
  `cat >`. El carril lo lee como un permiso negado. Los archivos se escriben con `Write`. Medido
  el 2026-09-27: lo pisaron los cuatro carriles del lote.
- **Y ese `--import` no es una vez: es una por `class_name` nuevo.** Crear el `.gd` no alcanza
  para que su test lo vea, y hasta el `--import` siguiente el error es `Parse Error: Identifier
  "X" not declared` **con el archivo ya escrito en disco**. Se lee como un error del código y no
  de la caché. **Medido el 2026-09-01: lo pisaron los dos carriles que crearon clases.**
- **Dale al carril el comando del conteo crudo, no sólo la orden de mirarlo.** `verificar.py` **no
  imprime** el `Executed test suites: (N/N)`. `python .claude/skills/implement-batch/scripts/conteo.py`
  lo saca del `results.xml` de la corrida que `verificar.py` acaba de hacer, y sale con 1 si una
  suite no corrió. Va justo después de `verificar.py`: una suite suelta en el medio deja otro
  reporte último. Hasta el 2026-10-06 el conteo pedía otra corrida entera del motor.

- **El carril no corrige un skill: reporta la falla, y la regla la escribe el padre.**
  `implement-feature` le pide cerrar el lazo, y en un lote eso da N copias de la misma lección.
  Medido el 2026-09-23: los dos carriles escribieron la misma regla en `to-issue` y en las siete
  copias de `sin-deuda.md`, y los dos PR chocaban en ocho archivos.
- **Godot con `--script` lleva siempre `--path .`, y el script termina con `quit()`.** Sin
  `--path`, `res://` es el directorio actual, y fuera de la raíz del repo cada `load` falla. Si
  el script aborta antes de `quit()`, Godot imprime el error y no sale nunca. Medido el
  2026-09-27: lo pisó el carril que cargaba todos los scripts con el motor.
- **Un nombre propio para cada archivo de scratch.** Dos carriles que escriben el mismo archivo
  temporal se pisan sin conflicto visible. **Y se escribe con `Write`.**
- **Una copia completa del proyecto para exportar o medir vive fuera de cualquier checkout o
  worktree.** El scratch interno guarda scripts, logs, JSON y capturas; no otro árbol del
  proyecto. `.gdignore` limita Godot, pero no los barridos Python del harness. En el lote del
  2026-10-08, una copia vieja bajo scratch hizo que el gate de `AGENTS.md` comparara sus reglas
  con las de la base nueva: Godot pasó 190 suites y el harness salió rojo. Se movió la copia a
  una carpeta propia bajo `Temp` y pasó el nodo afectado. No se borran los `AGENTS.md` de una
  copia para eludir ese control.
- **Un comando que este skill entrega se vuelve a correr antes de repartirlo**, nunca se copia de
  la corrida anterior: un comando roto se reparte N veces.

- **Coordiná las corridas del motor y las capturas entre carriles.** Una suite que mide tiempos
  por cuadro puede fallar bajo carga aunque el código no cambie. En el lote 282–285 del
  2026-10-02, las primeras verificaciones de #283 y #284 fallaron sólo en el caso del mouse de
  `giro_parejo_test.gd`; las dos repeticiones aisladas pasaron. Las capturas también corrían
  durante la primera verificación de #283. No hagas capturas durante la suite completa y
  asigná un turno para cada corrida completa del motor. Los carriles pueden seguir escribiendo
  en sus worktrees mientras otro verifica. Ante un fallo, conservá el log, comprobá el caso
  aislado y repetí la convergencia con la carga controlada. No cambies el umbral del test para
  esconder el fallo ni declares verde la primera corrida.
- **El turno lo da `scripts/turno.py`, y es una cola.** Todo lo que levanta el motor entero,
  exporta o mide va adentro: `python .claude/skills/implement-batch/scripts/turno.py <cola>
  <etiqueta> <log> -- <comando>`. `<cola>` es una carpeta del scratch del lote, la misma para
  todos los carriles. Va con `run_in_background`: la espera pasa los 10 minutos. Un servidor
  levantado no carga la máquina y queda afuera. En el lote del 2026-10-06 el turno era un cerrojo
  que cada carril reintentaba: una prueba de 30 s esperó 55 minutos, y los carriles pasaron a
  encadenar sus pasos adentro de un solo turno.
- **El árbol queda congelado desde que se encola hasta recibir el resultado.** Vale también para
  la espera, la importación y los rojos y verdes cortos: no se edita, formatea ni cambia de rama
  mientras el motor puede leerlo. Los borradores externos pueden avanzar. En #300 se agregó un
  caso mientras el loader ya había leído la suite anterior: corrieron 17 casos y el archivo tenía
  18. Ese caso nuevo no tenía testigo rojo; hubo que repetir contra el árbol congelado.
- **La carga que no es del lote se mide y se dice, porque no se apaga.** El usuario usa la
  máquina. El 2026-10-06, con Slack y Chrome en el 70 % de la CPU, el nodo `tests` tardó entre
  11 y 43 minutos en vez de 3, y la base sobre `staging` dio dos rojos en `giro_parejo_test.gd`
  que aislados pasaron. Corré `verificar.py` sobre la base antes de repartir, y poné su
  resultado en el preámbulo: el carril sabe así qué rojo es suyo.
- **`node_modules/` adentro de un worktree tira la importación de Godot.** Godot importa los
  SVG de `playwright-core`, y el nodo `tests` sale con `exit 3221225477`. Medido el 2026-10-06,
  dos veces. Playwright no se instala en el worktree: Node sube hasta el `node_modules/` del
  checkout principal, del que el worktree cuelga.
- **Un puerto se asigna después de mirar que esté libre**, con `Get-NetTCPConnection -State
  Listen`. Windows deja a dos servidores escuchar el mismo puerto, y Chrome cae en cualquiera
  de los dos. El 2026-10-06 el 8061 era de otra sesión, y la primera medición del carril de
  #317 murió por tiempo sin decir por qué.
- **Una afirmación sobre el motor se prueba con una sonda antes de repartirla**, igual que un
  comando. El 2026-10-06 el padre repartió que un alias de un `PackedArray` copia al escribir.
  En Godot 4 no copia: lo que copia es un `duplicate()` vivo. Dos carriles gastaron una sonda
  cada uno en desmentirlo.
- **Cargar un recurso no prueba que su script haya parseado.** Una sonda de paquete inicia el
  motor con `--main-pack`, con su directorio y `--path` en el export, fuera del proyecto fuente.
  Exige un marcador final y falla ante `SCRIPT ERROR`, `Parse Error` o `ERROR`, aunque el motor
  salga con 0 y `ResourceLoader.load()` devuelva un recurso. Ejercita las escenas, audio y datos
  que el juego usa. En #327 la primera sonda anunció 63 cargas mientras había errores de parseo;
  se invalidó. La sonda corregida cargó 356 recursos del paquete real sin errores.
- **Bash rechaza `python "$VAR/script.py"`**, con «runs python with a script computed at
  runtime». La ruta del script va literal. Medido el 2026-10-06 en el carril de #321.
- **Comparar dos exports de un escenario ya tiene herramienta.**
  `.github/scripts/exportar_escenario.py` exporta una revisión con el escenario como escena
  principal, y `.github/scripts/recoger_informe.mjs` guarda el informe que el escenario imprime.
  El método está en `docs/guides/rendimiento.md`. Como la copia sale de `git archive`, el carril
  commitea primero el escenario y después el cambio: son las dos revisiones que se comparan.

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
- **Antes de preguntarle algo al usuario, el padre mide lo que la pregunta supone**: qué cara
  ve el jugador, qué muestra la textura en esa cara, qué decidió ya el usuario. Si una sola
  opción cumple todo, se decide y se informa con su evidencia. Al usuario va sólo lo que
  ninguna medición contesta, y con la captura de cada opción. En el lote del 2026-09-29 se
  preguntó «Actroncito de costado» sin mirar que su lateral era liso, y deshacerlo costó otra
  vuelta de pipeline y de horneado. Después se preguntó cómo etiquetar las cajas, cuando el
  usuario ya había dicho «no modifiques el modelo»: las dos respuestas se podían medir.
- **El lazo, y es del padre por construcción**: si dos carriles corrigen el mismo `SKILL.md` a la
  vez, se pisan sin conflicto visible. Sale en su propio PR `harness/` desde `staging`, no en el PR
  de un carril: el issue del carril no lo cubre.
- **El contrato de la capacidad, si dos carriles lo editaron.** `specs/` está trackeado, así que
  dos carriles que agregan una regla a la misma capacidad dan un conflicto de merge de verdad —
  que es mejor que el silencio, pero lo resuelve el padre.
- **Un conflicto entre dos carriles se resuelve en una rama, no en el reporte.** Dos carriles que
  se juntan recién en `staging` le dejan el conflicto a quien mergee el segundo PR. El padre los
  pone en una sola pila: el primer issue del carril que va después trae la cabeza final del otro,
  y su PR se repunta a esa rama. En el lote del 2026-09-29, #265 y #266 chocaban en dos
  encabezados de test, y #264, la base de #266, pasó a salir de #265.
- **`python .claude/scripts/verificar.py`** en el checkout principal, con todo mergeado hacia
  arriba. Los siete nodos verdes por carril no implican los siete verdes juntos.

## Paso 5 — Destruir los worktrees

```bash
python .claude/skills/implement-batch/scripts/limpiar_worktrees.py <ruta> [<ruta> ...]
```

**Las rutas son las del lote, una por carril, y nunca `--todos`.** Cada notificación de un
carril trae su `worktreePath`. `--todos` toma todo lo que hay bajo `.claude/worktrees/`, y eso
incluye los worktrees de otra sesión que corre al mismo tiempo. Medido el 2026-09-27: se llevó
dos worktrees ajenos y mató el editor de Godot que tenía uno abierto.

**Va antes del reporte, no después, y no se hace a mano.** `git worktree remove` falla con
`Directory not empty` en **todo worktree que haya corrido `verificar.py`**, o sea en todos: el
nodo `tests` levanta Godot headless y Godot escribe su caché en `.godot/`. `--force` no ayuda — no
es un problema de cambios sin commitear.

Y mata **por ruta del worktree, nunca por nombre de proceso**: un filtro por `godot.exe` se
llevaría puesto el editor que el usuario tiene abierto con el checkout principal.

Si imprime `SIGUE AHI`, el handle es de afuera. **Lo cierra el usuario, no vos**: decilo.

Si imprime `SALTEADO: tiene cambios sin commitear`, el worktree queda y el script sale con 1.
Puede ser un carril tuyo que no terminó o el de otra sesión que todavía corre: **no se
fuerza**. Si es tuyo, el carril no cerró, y eso va primero en el reporte.

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
