# Troubleshooting

Errores reales ya pisados en este repo. Cada uno con el síntoma **tal cual aparece**, porque el
síntoma es lo que se busca cuando pasa.

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
| «La rama `X` no nombra un spec» | falta la rama `feature/<NNN>-<kebab>` |
| «dice ser del spec NNN, que no tiene entrada en `mapa.json`» | el spec no se publicó, o el número está mal |

**No lo saltees.** Si el cambio de verdad no necesita spec —un typo, un asset, revertir el
commit anterior— la rama igual no puede ser `main` ni `staging`: abrí una `chore/` o `fix/` y
tocá lo que no está protegido.

Si el gate se rompe, **deja pasar y lo dice** en `permissionDecisionReason`. Ese mensaje es la
señal de que el gate no está protegiendo nada: hay que arreglarlo, no ignorarlo.

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

## Un `.tscn` mergeado quedó roto

Un merge de tres vías sobre una escena **no produce un conflicto: produce una escena
corrupta**. Git ve texto y mezcla; Godot ve un grafo y no abre.

Prevención: escenas chicas y compuestas, y avisar antes de tocar una escena que otro está
tocando. Es la única parte del repo donde el flujo de ramas no alcanza.

Si ya pasó, la salida es `git checkout --theirs` o `--ours` sobre el archivo entero y rehacer el
cambio a mano en el editor. Resolver un `.tscn` línea por línea no funciona.
