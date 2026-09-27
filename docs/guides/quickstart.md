# Inicio rápido

## Lo que hace falta instalar

| Qué | Cómo | Para qué |
|---|---|---|
| **Godot** | del sitio oficial, es un `.exe` suelto | el juego, y correr los tests |
| **Python** | del sitio oficial o Microsoft Store | las herramientas del harness |
| **gdtoolkit** | `pip install` con la versión que fija `.github/workflows/verify.yml` | `gdlint` y `gdformat` |
| **GitHub CLI** | de [cli.github.com](https://cli.github.com), después `gh auth login` | abrir y leer los issues |
| **ffmpeg** | `scoop install ffmpeg`, o del sitio oficial | comprimir un audio nuevo con `python .claude/scripts/comprimir_audio.py` |

**gdUnit4 no se instala**: está vendorizado en `addons/gdUnit4/` y viene con el clone. Las
versiones las declaran `.godot-version` para el motor, `addons/gdUnit4/plugin.cfg` para el
addon, y `verify.yml` para Python y gdtoolkit.

## El motor y el addon se mueven juntos

**El motor y el addon de tests son un solo pin.** gdUnit4 declara una versión mínima de Godot, y
Godot rompe la sintaxis vieja del addon. Afuera de su ventana, el addon **no compila**, y la
corrida sale con código 0 igual. Moverlos es un cambio para todo el equipo y para la CI a la vez.

- **`.godot-version` es la única fuente de la versión del motor.** `verify.yml` y
  `desplegar.yml` la leen de ahí. Dos copias harían que la CI verifique con un motor y el
  despliegue exporte con otro, sin un rojo.
- **La compatibilidad sale de la tabla «GdUnit4 Version / Godot minimal required»** del README
  de gdUnit4. No de los badges de «Supported Godot Versions», que mezclan las series.
- **La versión de cada máquina va en `GODOT_BIN`.**

## Declarar dónde está Godot

Es el único paso que no se puede adivinar: Godot no se instala, se baja, y cada máquina lo
tiene en otro lado.

```powershell
# PowerShell, una sola vez. Después hay que CERRAR el host de la terminal (ver abajo).
[Environment]::SetEnvironmentVariable("GODOT_BIN", "C:\ruta\a\Godot_v<versión>-stable_win64_console.exe", "User")
```

```bash
# bash / macOS / Linux — en el perfil, para que sobreviva a la terminal
export GODOT_BIN="/ruta/a/godot"
```

Tres advertencias que cuestan una tarde cada una:

- **Abrir una terminal nueva NO alcanza.** En Windows un proceso hereda el bloque de entorno de
  su padre y no lo lee del registro, así que una pestaña nueva que abre el mismo host viejo sigue
  sin ver la variable. Hay que **cerrar el host de la terminal** —la ventana entera— o cerrar
  sesión de Windows. El síntoma es cruel: el registro contesta la ruta correcta y el script dice
  que no la encuentra, las dos cosas ciertas a la vez.
- **En Windows conviene el `_console.exe`**, no el otro. El ejecutable normal no escribe en la
  consola, así que la salida de los tests se pierde entera y la corrida parece colgada.
- **No lo dejes adentro de OneDrive.** Si el archivo está sólo en la nube, Windows lo rechaza
  con «el proveedor de archivos de nube no se está ejecutando» y los tests no arrancan — con
  un mensaje que no nombra ni a Godot ni a los tests.

Si `GODOT_BIN` no está, el nodo `tests` de `verificar.py` **no se saltea callado**: falla y te
dice esto mismo.

## Abrir el proyecto

Abrí `project.godot` con Godot. El plugin de gdUnit4 ya está habilitado en el archivo, así que
la primera apertura lo carga sola y aparece el panel de tests.

## Correr todo

```bash
python .claude/scripts/verificar.py
```

Es **lo único que hay que correr antes de un PR**, y es lo mismo que corre la CI. Qué hace cada
nodo y qué se saltea, en [verificación](./verificacion.md).

## Empezar un cambio

El camino, de la idea al PR, está en `CLAUDE.md`. Los prefijos de rama y qué exige el hook, en
[ramas](../infra/ramas.md). Si el hook te frenó, el mensaje dice cómo salir.

## Leer un contrato

Los contratos **están en el repo** y se leen como cualquier archivo: `specs/<capability>/`. Qué
decide cada capacidad y qué pasa entre ellas, en
[capacidades](../architecture/capacidades.md).
