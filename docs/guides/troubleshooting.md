# Troubleshooting

Errores reales ya pisados en este repo. Cada uno con el síntoma **tal cual aparece**, porque el
síntoma es lo que se busca cuando pasa.

## `No se encontró Godot. Declaralo una vez en GODOT_BIN` — y ya está declarada

```
$ [Environment]::GetEnvironmentVariable("GODOT_BIN","User")
D:\Godot\Godot_v4.7.2-stable_win64_console.exe     ← contesta la ruta correcta
$ python .claude/scripts/verificar.py
  FALLA     tests       No se encontró Godot. Declaralo una vez en `GODOT_BIN`
```

**Las dos afirmaciones son ciertas a la vez**, y eso es lo que vuelve caro el diagnóstico. En
Windows un proceso hereda el bloque de entorno **de su padre** y no lo lee del registro al
arrancar. `SetEnvironmentVariable(…, "User")` escribe en `HKCU\Environment` y avisa por
broadcast, pero sólo lo recogen los procesos que manejan ese aviso. Una terminal abierta antes
del cambio conserva el bloque viejo **y se lo pasa a todo lo que lance**.

**Abrir una terminal nueva no alcanza si el host es anterior al cambio**: la pestaña nueva la
lanza el mismo host viejo. Medido acá: la variable se declaró a las 21:20, se abrió una terminal
nueva, y el `powershell.exe` de las 21:51:57 seguía sin verla.

La salida es **cerrar el host de la terminal** —la ventana entera, no una pestaña— o cerrar
sesión de Windows. Mientras tanto, `lib/godot.py` la rescata leyendo el registro como segunda
fuente y **lo declara**: si `verificar.py` avisa que la leyó de ahí, tu terminal quedó atrás y la
próxima herramienta que no tenga ese rescate —empezando por el `runtest.cmd` del propio
gdUnit4— va a volver a no verla.

Para una corrida suelta, declararla en la misma línea alcanza:

```bash
export GODOT_BIN="C:\ruta\a\Godot_v4.7.2-stable_win64_console.exe" && python .claude/scripts/verificar.py
```

## «El proveedor de archivos de nube no se está ejecutando»

```
Error al ejecutar el programa 'Godot_v4.4.1-stable_win64_console.exe':
El proveedor de archivos de nube no se está ejecutando
```

**Godot está adentro de OneDrive y el archivo no está descargado**, sólo está el marcador en la
nube. El mensaje no nombra ni a Godot ni a los tests, así que se busca cualquier otra cosa.

Las dos salidas, en orden de preferencia:

1. **Sacar Godot de OneDrive.** Un ejecutable de 100 MB sincronizándose no le sirve a nadie, y
   además evita el problema para siempre.
2. Arrancar OneDrive y marcar el archivo como «mantener siempre en este dispositivo».

Pasó en la máquina donde se armó este harness, y es por lo que `lib/godot.py` lo dice en su
mensaje de ayuda.

## `UnicodeEncodeError: 'charmap' codec can't encode characters`

```python
UnicodeEncodeError: 'charmap' codec can't encode characters in position 2-3
```

**La salida de Python en Windows, cuando va a una tubería o a un archivo en vez de a una
consola, sale en cp1252** — que es el encoding del sistema en una instalación en español. Ahí
no entran ni `──` ni `→`, y los acentos entran a veces. Como todo este harness está escrito en
español, cualquier script se cae al imprimir su propio reporte.

Lo arregla `lib/consola.py`, que todos los scripts llaman antes de imprimir nada. Si escribís
un script nuevo en `.claude/scripts/`, tiene que llamar a `configurar()`.

Lo peor de este bug no era el reporte: era el **hook**. Su mensaje de bloqueo lleva acentos, así
que sin esto bloquear se convertía en caerse — y un hook que se cae en vez de contestar es un
hook que alguien apaga.

## El agente busca en `specs/` y no encuentra nada

**`Grep` es ripgrep y respeta el `.gitignore`**, y `specs/[0-9]*/` está ignorado. O sea que una
búsqueda ahí devuelve **cero resultados sin decir que no miró**, que es la peor respuesta
posible: no se distingue de «eso no existe».

```bash
rg --no-ignore "consecuencia" specs/
```

Leerlos anda normal: `.gitignore` es cosa de git, no del sistema de archivos, así que `Read`,
`cat` y `head` los abren sin problema. Lo que hay que hacer antes es **traerlos**:
`python .claude/scripts/hidratar_specs.py <NNN>`.

## El hook no bloquea nada

**Claude Code lee la configuración de hooks al arrancar la sesión**, no en cada llamada. Si
acabás de cambiar `.claude/settings.json` —o de clonar el repo por primera vez— el hook **no
está activo hasta la sesión siguiente**. Es a propósito: si la config se releyera en caliente,
un cambio en un archivo del repo podría instalar un comando que corre solo.

Para comprobar que el gate funciona sin depender del hook:

```bash
echo '{"tool_name":"Edit","tool_input":{"file_path":"src/dominio/x.gd"}}' \
  | python .claude/scripts/gate_de_spec.py
```

Desde `main` o `staging` tiene que contestar `"permissionDecision": "deny"`. Si contesta eso y
la sesión igual te deja editar, lo que falta es reiniciarla.

## El hook bloquea una edición y no está claro por qué

El mensaje dice cuál de los tres casos es:

| Dice | Qué pasa |
|---|---|
| «No se edita `X` desde `staging`» | estás parado en una rama compartida. `staging` es la **default del repo**, así que es el lugar más fácil donde quedarse sin haberlo decidido |
| «La rama `X` no puede editar `Y`» | el prefijo no es del producto. A `src/` lo tocan `feature/`, `bugfix/` y `hotfix/`, y ninguno más |
| «es de feature y no nombra su spec» | falta el `NNN`, y va en **tres** dígitos: `feature/038-…`, no `feature/38-…` |

**No lo saltees.** Si el cambio de verdad no necesita spec —un typo, un asset, revertir el
commit anterior— la rama igual no puede ser `main` ni `staging`: abrí una `harness/`, `docs/` o
`ci/` según qué toques, y tocá lo que no está protegido.

El hook **ya no cruza el `NNN` contra `specs/mapa.json`**, así que un spec sin publicar no frena
la primera edición. Ese cruce lo cobra `test_criterios_de_la_rama.py` en el nodo `harness`, con
el PR todavía abierto: «dice ser del spec NNN, que no está hidratado ni tiene entrada en
`specs/mapa.json`».

Si el gate se rompe, **deja pasar y lo dice** en `permissionDecisionReason`. Ese mensaje es la
señal de que el gate no está protegiendo nada: hay que arreglarlo, no ignorarlo.

## `can't open file '…\.claude\scripts\.claude\scripts\gate_de_spec.py'`

```
python: can't open file 'D:\…\.claude\scripts\.claude\scripts\gate_de_spec.py':
[Errno 2] No such file or directory
```

**La ruta aparece duplicada, y con eso `Bash` y `Edit` quedan bloqueados los dos a la vez.** El
comando del hook usa una ruta relativa al directorio de trabajo; un `cd` a un subdirectorio la
rompe, y **un comando de hook que sale distinto de cero bloquea la herramienta**. O sea que el
gate falla **cerrado**, que es lo contrario de lo que promete: no queda ninguna forma de editar
el archivo que lo arreglaría.

Pasó montando este harness, y la salida de ese encierro fue escribir con la herramienta de
PowerShell — que en ese momento el matcher no miraba, o sea que el gate se salteaba solo con
cambiar de herramienta.

Por eso el comando de `.claude/settings.json` prueba las dos formas de ubicarse y termina en
`|| exit 0`:

```
python .claude/scripts/gate_de_spec.py || python "$CLAUDE_PROJECT_DIR/.claude/scripts/gate_de_spec.py" || exit 0
```

Si igual quedaste encerrado, el `exit 0` del final es lo que hay que verificar antes que nada: un
gate que no puede correr **deja pasar**, nunca bloquea.

## El addon de gdUnit4 y el motor no se corresponden

**Los dos números son un solo pin.** La combinación vigente es **Godot 4.7.2 con gdUnit4
6.2.1**, y el desajuste no falla al instalar: falla al correr. Se llega por las dos direcciones,
las dos son alcanzables después de este cambio, y **las dos salen con código de salida 0** — o
sea que quien mire el veredicto por el código de salida las lee como una corrida en verde. El
porqué del pin único está en [el stack](../README.md).

### addon 5.x bajo motor 4.7

El que ve quien actualiza Godot y **no** hace `pull`. La serie 5.x llama a
`FileAccess.get_as_text(true)` y declara un `func call(arg0=null, …)`; en 4.7 el primero no
acepta argumentos y el segundo choca con la firma de `Object.call`:

```
SCRIPT ERROR: Parse Error: Too many arguments for "get_as_text()" call. Expected at most 0 but received 1.
   at: GDScript::reload (res://addons/gdUnit4/src/core/GdUnitFileAccess.gd:197)
SCRIPT ERROR: Compile Error: Failed to compile depended scripts.   (x7)
ERROR: Failed to load script "res://addons/gdUnit4/plugin.gd" with error "Compilation failed".
SCRIPT ERROR: Trying to assign value of type 'Nil' to a variable of type 'bool'.
   at: _enter_tree (res://addons/gdUnit4/plugin.gd:17)
```

Siete scripts en cascada y el plugin del editor caído, con `Exit code: 0`. Es la trampa de
`CLAUDE.md` en su forma más pura: el error está **sólo** en la salida cruda.

### addon 6.x bajo motor 4.4

El que ve quien hace `pull` y sigue en 4.4.x — y es el más probable de los dos, porque el `pull`
llega solo y el motor hay que bajarlo a mano.

```
SCRIPT ERROR: Parse Error: Could not resolve class "GdUnitCSIMessageWriter", …
ERROR: Failed to load script "res://addons/gdUnit4/bin/GdUnitCmdTool.gd"
```

**La serie 6.x pide Godot 4.5 o más**, y usa la sintaxis `...varargs`, que 4.4 ni siquiera
parsea (`Parse Error: Expected parameter name`). Acá el proceso además queda colgado hasta el
timeout, así que el síntoma parece un cuelgue y no un problema de versión.

### De dónde sale la matriz

De la tabla «GdUnit4 Version / Godot minimal required» del README de gdUnit4 — **no** de los
badges de «Supported Godot Versions», que listan lo que el proyecto soporta en *alguna* de sus
series y hacen creer que la última sirve para todas. Pasó acá al montar el harness: se eligió la
6.x mirando los badges.

Este repo tiene la **6.2.1** vendorizada. Si alguien la actualiza, la versión de Godot va en el
mismo cambio — y al revés también.

## `Parse Error: Could not find type "GdUnitTestCIRunner" in the current scope.`

El nodo `tests` sale **rojo —no salteado—** en un worktree recién creado, y el síntoma **no
nombra la causa**: no dice `.godot`, no dice worktree, no dice importación, y nombra un tipo de
gdUnit4, que manda a revisar el addon.

Lo que falta es `.godot/`, que está en el `.gitignore` y por lo tanto **ningún worktree nuevo lo
tiene**. Sin esa caché Godot no tiene el registro de clases globales y
`addons/gdUnit4/bin/GdUnitCmdTool.gd` no resuelve sus propios `class_name`.

La cura es una línea, una sola vez por worktree y **antes** del primer `verificar.py`:

```bash
"$GODOT_BIN" --headless --path . --import --quit
```

**Y no es una vez por worktree, sino una por `class_name` nuevo**: una clase recién escrita no
entra al registro global hasta el `--import` siguiente, y hasta entonces el error es
`Parse Error: Identifier "X" not declared` **con el archivo ya en disco**, idéntico al del
archivo que todavía no existe.

Medido el 2026-08-31 sobre el lote 001/002/004/007: lo pisaron los cuatro carriles.

## `Executed test suites: (22/23)` — con el nodo `tests` en `ok`

**Un verde de gdUnit4 puede ser una suite que no corrió**, y no lo ve ningún gate: `verificar.py`
hace lo correcto —el veredicto es el código de salida— y aun así declara verde, porque gdUnit4
devuelve 0.

El número que vale es ése, y `verificar.py` **no lo imprime**. Se saca de la salida cruda y se
compara contra la cantidad de `*_test.gd`:

```bash
"$GODOT_BIN" --path . --headless -s -d --remote-debug tcp://127.0.0.1:0 \
  res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a test --continue --ignoreHeadlessMode \
  -rd reportes 2>&1 | grep "Executed test suites"
```

Son tres escalones y los tres salen `ok`: una suite que no parsea **se descarta en silencio**, un
`class_name` nuevo no existe hasta el `--import` siguiente, y un caso cuyo recurso falta sale
`PASSED` por abortar antes de afirmar. Los tres, con su medición, en
[.claude/rules/tests.md](../../.claude/rules/tests.md).

## La suite de gdUnit4 queda colgada

Si el proceso de Godot no termina nunca y no imprime nada, casi seguro **un `.gd` tiene un
error de parseo** y Godot abrió su depurador interactivo, que espera en un prompt `debug>` a
que alguien escriba algo.

Por eso `verificar.py` pasa `--remote-debug tcp://127.0.0.1:0`: el puerto 0 no se liga nunca,
así que la conexión se rechaza y el proceso muere en vez de esperar. Si igual pasa, corré
`gdlint src test` a mano: el error de sintaxis sale ahí.

## `gdformat` reformatea todo un archivo que no toqué

Casi siempre es **indentación con espacios en vez de tabs**. GDScript va con tabs, que es lo que
inserta el editor de Godot y lo que produce `gdformat`. Si un archivo entró con espacios, el
primer `gdformat` lo reindenta entero y el diff queda ilegible.

Lo previene el `.editorconfig`, si tu editor lo respeta. Si ya pasó: `gdformat src test` en un
commit solo, sin ningún otro cambio.

## El nodo `tests` dice que se saltea

```
── tests: salteado ──
no hay un solo `*_test.gd` todavía.
```

Eso es correcto **mientras no haya tests**. En cuanto exista el primero, el nodo pasa a
necesitar Godot, y si `GODOT_BIN` no está, **falla en vez de saltearse**.

Un salteo que no vence es un gate apagado: si ves este mensaje y sabés que hay tests, el
problema es que no los está encontrando — revisá que estén bajo `test/` y terminen en
`_test.gd`.

## `gh` no está en el PATH

En Windows el instalador lo deja en `C:\Program Files\GitHub CLI\` y **no agrega la carpeta al
PATH**. Los scripts lo rescatan solos de ahí y **avisan**, pero la solución de fondo es agregar
esa carpeta al PATH de usuario: arregla también todo lo demás que use `gh`.

Si el error es de sesión y no de instalación, el mensaje lo distingue: `gh auth login`.

## `Invalid call. Nonexistent function 'x' in base 'Nil'` en el primer cuadro

La escena carga **sin un solo error**, los seis nodos dan verde, y el juego muere en el primer
cuadro con un mensaje que no nombra ni al `.tscn` ni al `@export`.

Casi siempre es **un `@export` de tipo `Node` en un `.tscn` escrito a mano**. El motor guarda ese
valor como `NodePath`, y no lo resuelve si el nodo no declara además la lista:

```text
[node name="Almacen" type="Node3D" node_paths=PackedStringArray("_hud", "_reloj")]
```

Sin `node_paths` el `@export` llega en `null`. El editor de Godot escribe esa lista solo; una
escena editada a mano, no — y como nada falla al cargar, el primer aviso es el crash. Medido en
el spec 007.

## Un `.tscn` mergeado quedó roto

Un merge de tres vías sobre una escena **no produce un conflicto: produce una escena
corrupta**. Git ve texto y mezcla; Godot ve un grafo y no abre.

Prevención: escenas chicas y compuestas, y avisar antes de tocar una escena que otro está
tocando. Es la única parte del repo donde el flujo de ramas no alcanza.

Si ya pasó, la salida es `git checkout --theirs` o `--ours` sobre el archivo entero y rehacer el
cambio a mano en el editor. Resolver un `.tscn` línea por línea no funciona.
