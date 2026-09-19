# Inicio rápido

## Lo que hace falta instalar

| Qué | Cómo | Para qué |
|---|---|---|
| **Godot 4.7** | del sitio oficial, es un `.exe` suelto | el juego, y correr los tests |
| **Python 3.11+** | del sitio oficial o Microsoft Store | las herramientas del harness |
| **gdtoolkit** | `pip install "gdtoolkit==4.*"` | `gdlint` y `gdformat` |
| **GitHub CLI** | de [cli.github.com](https://cli.github.com), después `gh auth login` | abrir y leer los issues |

**gdUnit4 no se instala**: está vendorizado en `addons/gdUnit4/` y viene con el clone.

## Los dos números se mueven juntos, y no se pueden mover de a uno

**El motor y el addon de tests son un solo pin.** gdUnit4 declara una versión mínima de Godot y
Godot rompe la sintaxis vieja del addon, así que cada serie del addon vive dentro de una ventana
de versiones del motor y afuera **no compila**. La combinación vigente es **Godot 4.7.2 con
gdUnit4 6.2.1**, y moverla es un cambio para **todo el equipo** y para la CI a la vez, así que
va con su spec.

Las dos direcciones del desajuste están medidas, y **las dos salen con código 0**, que es lo
que las hace difíciles de ver:

- **addon 5.x bajo motor 4.7** — la 5.x llama a `FileAccess.get_as_text(true)`, que en 4.7 no
  acepta argumentos, y declara un `func call(arg0=null, …)` cuya firma 4.7 valida contra
  `Object.call`. El plugin del editor no carga.
- **addon 6.x bajo motor 4.4** — la 6.x pide **Godot 4.5 o más** y usa `...varargs`, que 4.4 ni
  siquiera parsea. Es el que ve quien hace `pull` y sigue en 4.4.x.

Y hay un dato que le va a hacer falta al próximo que mire: **la 6.2.1 declara compatibilidad
hasta 4.7.1 y no nombra a 4.7.2.** Se eligió 4.7.2 igual, y la evidencia de que la combinación
funciona en *este* proyecto es una medición y no la tabla: **medido el 2026-09-01**, 23/23
suites y 171/171 casos en verde, sin tocar un test. **El conteo de casos se mueve con cada
spec que agrega uno** —el 028 lo deja en 177—, así que lo que sostiene la afirmación es la
fecha y no el número: quien lo vea distinto no lo corrija, remídalo. El plan B, si algo
aparece, es bajar a **4.7.1** —que sí está en la matriz— sin tocar el addon.

La versión que bajan los workflows vive en **`.godot-version`, en la raíz, y en ningún otro
lado**: `verify.yml` y `desplegar.yml` la leen de ahí. Hasta el 2026-09-06 estaba escrita en un
`env:` de `verify.yml` y otra vez en este párrafo, con el encabezado de ese archivo diciendo
«la versión vive UNA vez» tres líneas más arriba de la segunda copia. Con dos workflows que
bajan Godot, dos copias que se separan hacen que la CI verifique con un motor y el despliegue
exporte con otro, **y eso no da rojo en ningún lado**: las dos corridas salen verdes, cada una
con el suyo. El **4.7.2** de la tabla de arriba es prosa que lo cita, no una segunda
fuente; quien lo vea distinto de `.godot-version`, corrija esto. La de cada máquina va en
`GODOT_BIN`. La tabla «GdUnit4 Version / Godot minimal required» del
README de gdUnit4 es la fuente — **no** los badges de «Supported Godot Versions», que listan las
versiones que el proyecto soporta *en alguna* de sus series y hacen creer que la última sirve
para todas.

## Declarar dónde está Godot

Es el único paso que no se puede adivinar: Godot no se instala, se baja, y cada máquina lo
tiene en otro lado.

```powershell
# PowerShell, una sola vez. Después hay que CERRAR el host de la terminal (ver abajo).
[Environment]::SetEnvironmentVariable("GODOT_BIN", "C:\ruta\a\Godot_v4.7.2-stable_win64_console.exe", "User")
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

Es **lo único que hay que correr antes de un PR**, y es lo mismo que corre la CI. Los seis
nodos van en paralelo:

```
  ok        capas       0.1s
  ok        formato     1.2s
  ok        harness     0.4s
  ok        lint        1.1s
  ok        tdd         0.1s
  ok        tests       5.1s
```

Para uno solo: `python .claude/scripts/verificar.py --solo tests`.

**Un nodo `salteado` no es un nodo verde**, y el reporte lo distingue diciendo qué no miró.

## Arreglar el formato en vez de mirarlo

`verificar.py` sólo **avisa** que el formato está mal (`gdformat --check`). Para arreglarlo:

```bash
gdformat src test
```

El formato no se discute en una revisión: lo decide la herramienta.

## Empezar un cambio

**No se edita `src/` sin un issue detrás de la rama** — y no es una recomendación: lo bloquea un
hook antes de que se escriba la primera línea. `docs/` estuvo protegido hasta el 2026-09-05 y
dejó de estarlo: pedir un spec para corregir una línea de documentación no produce más specs,
produce documentación que nadie corrige.

El camino entero está en el skill `/to-spec`, y en corto es:

```bash
# 1. el contrato de la capacidad, si el comportamiento todavía no está escrito
#    specs/<capability>/<capability>.md, por su propio PR
python .claude/scripts/gate_de_specs.py

# 2. el issue, que es el plan: qué criterios entrega, qué toca y con qué comandos cierra
gh issue create --title "<qué cambia>" --body-file <archivo>

# 3. y recién ahí, la rama
git checkout -b feature/<issue>-<kebab>
```

Si el gate te frenó, el mensaje dice cuál de los casos es y cómo salir. **No lo saltees**: si de
verdad el cambio no necesita issue —un typo, un asset, revertir el commit anterior— la rama igual
no puede ser `main`.

## Leer un contrato

Los contratos **están en el repo** y se leen como cualquier archivo: `specs/<capability>/`. Qué
decide cada capacidad y qué pasa entre ellas, en
[capacidades](../architecture/capacidades.md).
