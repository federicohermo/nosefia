---
paths:
  - ".claude/scripts/**/*.py"
---

# Las herramientas del harness

Python 3.11+, **sin una sola dependencia**: sólo la biblioteca estándar y `unittest`. Lo único
que se instala en la máquina es `gdtoolkit`, que es el linter del juego y no de estas
herramientas.

Esa pobreza es deliberada. Un harness con dependencias pide instalar un `requirements.txt` y
activar un entorno virtual. Es una forma más de que la CI y la máquina de alguien no hagan lo
mismo. Acá `python archivo.py` alcanza.

## La forma: lo puro en `lib/`, el cableado en el script

Todo script de `.claude/scripts/` es **cableado**: stdin, disco, red, `sys.exit`. Lo que
**decide** vive en `lib/` y no toca ninguna de esas cosas.

No es prolijidad: es lo único que hace que tenga tests. Mientras la lógica vive adentro de un
ejecutable, importarla lo corre. La única forma de ejercerla es lanzar un subproceso, y así no
se fabrican los modos de falla que importan.

Cuando el módulo **necesita** el mundo, el mundo se **inyecta** en vez de importarse. Los casos
que ya existen, y qué habilita cada inyección:

| Módulo | Qué recibe | Qué se puede probar gracias a eso |
|---|---|---|
| `rutas_protegidas.py` | el módulo de rutas | dos discos de Windows, en Linux y en la CI |
| `godot.py` | el entorno y el PATH | que no esté declarado `GODOT_BIN` |

## Un gate que no puede correr lo dice

Es la regla más importante de este directorio. Un gate que se saltea **callado** se ve igual
que uno que pasó. En esa diferencia se esconden los bugs que este harness existe para evitar.
Cada salteo declara qué no miró y cómo hacer que mire.

## Un gate falla abierto, salvo que sea su trabajo fallar cerrado

Los del hook **dejan pasar** ante cualquier error propio, y lo dicen. Un gate que rompe la
sesión entera se desactiva el mismo día, y ahí no queda gate. Los que corren en `verificar.py`
fallan cerrado, porque ahí el rojo es el producto.

## La consola va en UTF-8 y eso se configura

Todo script de acá llama a `configurar()` de `lib/consola.py` antes de imprimir nada. En
Windows, la salida a una tubería sale en cp1252 y **cualquier acento tira el script abajo** —
incluido el mensaje de bloqueo del hook. El porqué entero está en el encabezado de ese módulo.

## Un test que commitea declara su identidad de git

La CI no tiene ninguna, y sin ella `commit-tree` y `commit` salen con 128. Un caso que pasa
acá porque la máquina tiene `user.name` falla allá. Va por el entorno del proceso, así la
heredan también los `git` del script que el caso corre. Medido el 2026-09-30 en el PR #280:
tres casos de `test_capturas_a_rama.py`.

## El veredicto sale del código de salida

El principio está en la [constitución](../../docs/architecture/constitution.md).

**Encadenar `rg` con `&&` también falla en silencio.** Un `rg A && rg B && rg C`
corta en el primero sin match, que devuelve 1. **Los otros dos no corren, sin decirlo.** La
salida vacía se lee como «ninguno matcheó», y sólo se preguntó por el primero. **Un `rg` por
línea, separados por `;`, nunca por `&&`.**

**Y `--no-ignore` no alcanza para buscar acá adentro.** Ripgrep saltea los directorios ocultos
aunque se le apague el `.gitignore`. Un `rg --no-ignore` sobre la raíz **no mira `.claude/`**:
ni el harness, ni las reglas, ni los skills. Contesta cero con la misma cara que si hubiera
mirado. Para el árbol entero: `rg --no-ignore --hidden`.

## El estilo

Líneas de hasta 100 y `snake_case`. Los docstrings explican **por qué**, como pide la
[directriz de comentarios](../../docs/guides/conventions.md). Acá son largos a propósito: casi
todos guardan el modo de falla que justifica una línea rara.
