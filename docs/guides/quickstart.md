# Inicio rápido

## Lo que hace falta instalar

| Qué | Cómo | Para qué |
|---|---|---|
| **Godot 4.4** | del sitio oficial, es un `.exe` suelto | el juego, y correr los tests |
| **Python 3.11+** | del sitio oficial o Microsoft Store | las herramientas del harness |
| **gdtoolkit** | `pip install "gdtoolkit==4.*"` | `gdlint` y `gdformat` |
| **GitHub CLI** | de [cli.github.com](https://cli.github.com), después `gh auth login` | publicar y traer specs |

**gdUnit4 no se instala**: está vendorizado en `addons/gdUnit4/` y viene con el clone.

## Declarar dónde está Godot

Es el único paso que no se puede adivinar: Godot no se instala, se baja, y cada máquina lo
tiene en otro lado.

```powershell
# PowerShell, una sola vez. Después hay que abrir una terminal nueva.
[Environment]::SetEnvironmentVariable("GODOT_BIN", "C:\ruta\a\Godot_v4.4.1-stable_win64_console.exe", "User")
```

```bash
# bash / macOS / Linux — en el perfil, para que sobreviva a la terminal
export GODOT_BIN="/ruta/a/godot"
```

Dos advertencias que cuestan una tarde cada una:

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
  ok        tests      12.3s
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

**No se edita `src/` ni `docs/` sin un spec detrás de la rama** — y no es una recomendación:
lo bloquea un hook antes de que se escriba la primera línea.

El camino entero está en el skill `/spec-create`, y en corto es:

```bash
# 1. medir, escribir specs/<NNN>-<kebab>/{spec,research,plan,tasks}.md
python .claude/scripts/publicar_spec.py crear
python .claude/scripts/publicar_spec.py publicar
git add specs/mapa.json && git commit && git push origin staging

# 2. y recién ahí, la rama
git checkout -b feature/<NNN>-<kebab>
```

Si el gate te frenó, el mensaje dice cuál de los tres casos es y cómo salir. **No lo saltees**:
si de verdad el cambio no necesita spec —un typo, un asset, revertir el commit anterior— la
rama igual no puede ser `main` ni `staging`.

## Traer un spec para leerlo

Los specs no viven en el repo: cada uno es un issue.

```bash
python .claude/scripts/hidratar_specs.py 007
```

Y para buscar adentro de ellos, `rg --no-ignore`: están en el `.gitignore`, así que una
búsqueda normal contesta cero **sin decir que no miró**.
