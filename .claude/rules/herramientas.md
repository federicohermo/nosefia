---
paths:
  - ".claude/scripts/**/*.py"
---

# Las herramientas del harness

Python 3.11+, **sin una sola dependencia**: sólo la biblioteca estándar y `unittest`. Lo único
que se instala en la máquina es `gdtoolkit`, que es el linter del juego y no de estas
herramientas.

Esa pobreza es deliberada. Un harness con dependencias tiene un `requirements.txt` que hay que
instalar, un entorno virtual que hay que activar y una forma más de que la CI y la máquina de
alguien no hagan lo mismo. Acá `python archivo.py` alcanza.

## La forma: lo puro en `lib/`, el cableado en el script

Todo script de `.claude/scripts/` es **cableado**: stdin, disco, red, `sys.exit`. Lo que
**decide** vive en `lib/` y no toca ninguna de esas cosas.

No es prolijidad: es lo único que hace que tenga tests. Mientras la lógica vive adentro de un
ejecutable, importarla lo corre, así que la única forma de ejercerla es lanzar un subproceso —
y los modos de falla que importan no se pueden fabricar así.

Cuando el módulo **necesita** el mundo, el mundo se **inyecta** en vez de importarse. Los tres
casos que ya existen, y qué habilita cada inyección:

| Módulo | Qué recibe | Qué se puede probar gracias a eso |
|---|---|---|
| `rutas_protegidas.py` | el módulo de rutas | dos discos de Windows, en Linux y en la CI |
| `gh.py` | ejecutar, existe, plataforma | que no haya `gh`, en una máquina que sí lo tiene |
| `godot.py` | el entorno y el PATH | que no esté declarado `GODOT_BIN` |
| `derivacion.py` | las consultas y el disco | una lista de `gh` truncada, sin pedir mil issues |

## Un gate que no puede correr lo dice

Es la regla más importante de este directorio. Un gate que se saltea **callado** se ve igual
que uno que pasó, y en esa diferencia se esconden los bugs que este harness existe para no
tener. Cada salteo declara qué no miró y cómo hacer que mire.

## Un gate falla abierto, salvo que sea su trabajo fallar cerrado

El del hook (`gate_de_spec.py`) **deja pasar** ante cualquier error propio, y lo dice: un gate
que rompe la sesión entera se desactiva el mismo día, y ahí no queda gate. Los otros —capas,
tdd, mapa— fallan cerrado, porque corren en `verificar.py` y ahí el rojo es el producto.

## La consola va en UTF-8 y eso se configura

Todo script de acá llama a `configurar()` de `lib/consola.py` antes de imprimir nada. En
Windows, la salida a una tubería sale en cp1252 y **cualquier acento tira el script abajo** —
incluido el mensaje de bloqueo del hook. El porqué entero está en el encabezado de ese módulo.

## El veredicto sale del código de salida

Nunca de un grep de la salida. Un `| grep` que no matchea devuelve 1 y se traga la salida
entera: es la forma más corta conocida de declarar verde una corrida rota.

**Y encadenar `rg` con `&&` es la misma falla en la otra dirección.** Un `rg A && rg B && rg C`
corta en el primero sin match —que devuelve 1— y **los otros dos no corren, sin decirlo**: la
salida vacía se lee como «ninguno matcheó» cuando sólo se preguntó por el primero. **Un `rg` por
línea, separados por `;`, nunca por `&&`.** Medido el 2026-09-01 verificando los AC del 023.

**Y `--no-ignore` no alcanza para buscar acá adentro.** Ripgrep saltea los directorios ocultos
aunque se le apague el `.gitignore`, así que un `rg --no-ignore` sobre la raíz **no mira
`.claude/`** —ni el harness, ni las reglas, ni los skills— y contesta cero con la misma cara que
si hubiera mirado. Hace falta `--hidden`. Medido el 2026-09-05 revisando el PR 56: buscar
`sin-deuda` con `--no-ignore` no devolvió **ni uno solo de los 14 archivos de `.claude/` que la
nombran** —sólo los de `specs/` y la raíz—, y uno de esos 14 era un puntero muerto adentro del
mensaje de un gate. El total no se cita porque se mueve con los specs hidratados, que son caché;
lo que no se mueve es que `.claude/` aporta cero. Para el árbol entero: `rg --no-ignore --hidden`.

## El estilo

Líneas de hasta 100, `snake_case`, docstrings que explican **por qué** y no qué. Los
comentarios de este directorio son largos a propósito: casi todos guardan el modo de falla que
justifica una línea rara, y ése es el dato que no se puede recuperar leyendo el código.
