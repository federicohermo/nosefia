"""Lo que este repo es: rutas, nombre, ramas y capas.

Existe para que ninguno de esos datos esté escrito dos veces. Cada uno lo leen entre dos y
cinco herramientas —el gate del hook, los cuatro scripts de specs, los dos gates de código,
`verificar.py`— y una copia que se separa de la otra produce un gate que verifica una regla
que ya no es la del repo, **en verde**, que es el peor resultado posible.
"""

from pathlib import Path

#: La raíz del repo. `lib/` está en `.claude/scripts/lib/`, o sea tres niveles adentro.
RAIZ = Path(__file__).resolve().parents[3]

#: El repositorio en GitHub, donde viven los specs y la deuda.
REPO = "federicohermo/nosefia"

#: La rama que integra el trabajo y donde vive el registro de specs.
#:
#: `main` es release: lo que se publica en cada entrega de la cátedra. `staging` es adonde
#: aterriza cada PR de spec, y por eso es la default del repositorio — y eso es lo que la
#: vuelve peligrosa: es adonde apunta cada `gh pr create` y cada clone fresco, o sea el
#: lugar más fácil de todo el repo donde quedarse parado sin haberlo decidido.
RAMA_DE_INTEGRACION = "staging"

#: Las ramas COMPARTIDAS: las que reciben trabajo de otros y donde por lo tanto no se edita
#: una ruta protegida.
#:
#: Nombrarlas no cambia el veredicto —ninguna rama que no matchee `feature/<NNN>-` pasa el
#: gate— pero cambia el **diagnóstico**: «la rama `staging` no nombra un spec» se lee como
#: una invitación a renombrarla, que es lo peor que se puede hacer con la rama de
#: integración. El mensaje correcto dice que el problema es DÓNDE estás parado.
RAMAS_COMPARTIDAS = ("main", RAMA_DE_INTEGRACION)

#: Lo que el gate de spec protege: nada se edita acá sin un spec detrás de la rama.
#:
#: `specs/` y `.claude/` quedan afuera **a propósito**: son adonde el flujo te manda a
#: escribir primero, y `.claude/` es además donde vive el gate. Un gate que se impide
#: arreglarse a sí mismo se termina borrando en vez de corrigiéndose.
#:
#: `project.godot`, `addons/` y los configs tampoco: el gate no puede impedir habilitar un
#: plugin o tocar una configuración del editor, y pretenderlo lo volvería molesto sin
#: volverlo útil.
PROTEGIDAS = ("src", "docs")

#: Las capas de `src/`, de la más pura a la más acoplada al motor, y **qué puede importar
#: cada una**.
#:
#: El orden no es decorativo: una capa puede referenciar a las que están antes que ella y a
#: ninguna otra. Lo verifica `gate_de_capas.py`, que lo lee de acá.
#:
#: - `dominio/` — GDScript puro: `RefCounted` y `Resource`, sin `Node`, sin escenas, sin
#:   `get_tree()`. Las reglas del turno, las tareas, el inventario, las consecuencias. Es la
#:   capa que se puede testear headless sin levantar una escena, y por eso es donde tiene
#:   que vivir todo lo que se pueda decidir con números.
#: - `sistemas/` — los `Node` y autoloads que orquestan el dominio y hablan con el motor:
#:   el reloj del turno, el guardado, el bus de señales. Conocen `dominio/`; no conocen la
#:   pantalla.
#: - `ui/` — HUD, la computadora, la ventanilla. Presentación.
#: - `escenas/` — los scripts pegados a un `.tscn`. Son la cáscara: cablean, no deciden.
CAPAS: tuple[tuple[str, tuple[str, ...]], ...] = (
    ("src/dominio", ()),
    ("src/sistemas", ("src/dominio",)),
    ("src/ui", ("src/dominio", "src/sistemas")),
    ("src/escenas", ("src/dominio", "src/sistemas", "src/ui")),
)

#: Los nombres de subcarpeta que cada capa admite, y **qué alcance mide cada uno**.
#:
#: El criterio es uno solo, aplicado cuatro veces: **la carpeta dice qué se rompe si tocás lo
#: que hay adentro**. Lo que cambia por capa es contra qué se mide ese alcance, y en las cuatro
#: es la misma pregunta que el juego hace: ¿esto le cuesta tiempo al turno?
#:
#: Las claves son las mismas cadenas que las de `CAPAS` —`src/dominio`, no `dominio`— para que
#: `capa_de()` devuelva una clave de este diccionario sin traducir nada en el medio.
#:
#: **Declarar un nombre no crea la carpeta.** Están acá las de `ui/` y las dos de `sistemas/`
#: que todavía no tienen un solo archivo: es lo que hace que el spec que cree el primero
#: aterrice bien sin discutirlo, y que `src/ui/pantallas/` dé rojo el mismo día.
#:
#: **Y la raíz de una capa es válida a propósito**: `reglas.gd`, `hud.gd`, `almacen.tscn` cruzan
#: dos carpetas o son la raíz del árbol. Lo que este conjunto cierra es la puerta de atrás
#: —inventar un nombre en vez de usar el criterio—, no la clasificación, que es semántica y la
#: mira la revisión.
#:
#: - `src/dominio` — **cuánto dura el efecto**. `jugador/` cambia cómo se siente moverse y no
#:   puede cambiar el resultado de una noche; `jornada/` es la aritmética de la tensión central;
#:   `empleo/` es el arco entre noches —apercibimientos, despido— y ninguna noche suelta.
#: - `src/sistemas` — **si consume tiempo del turno, y para qué**. `marco/` no lo consume: hace
#:   correr el juego, y un bug ahí no cambia el balance, lo detiene. `tareas/` lo consume y
#:   cumple una obligatoria. `investigacion/` lo consume y no cumple nada: es el otro lado.
#: - `src/ui` — **si el reloj sigue corriendo mientras está en pantalla**. `diegetica/` sí
#:   —mirar la computadora cuesta minutos—; `interrupciones/` no, porque el turno ya terminó.
#: - `src/escenas` — **cuántas instancias hay**. `puestos/` se instancia una vez y vive cableado
#:   por `@export`; `objetos/` se instancia N veces, se crea y se destruye en juego.
CARPETAS_POR_CAPA: dict[str, frozenset[str]] = {
    "src/dominio": frozenset({"jugador", "jornada", "empleo"}),
    "src/sistemas": frozenset({"marco", "tareas", "investigacion"}),
    "src/ui": frozenset({"diegetica", "interrupciones"}),
    "src/escenas": frozenset({"puestos", "objetos"}),
}

#: Dónde viven los tests, y de qué son espejo.
#:
#: `test/<capa>/<nombre>_test.gd` para `src/<capa>/<nombre>.gd`. Que sea un espejo y no una
#: carpeta suelta es lo que permite que un gate conteste «esto no tiene test» sin que nadie
#: mantenga una lista.
TESTS = "test"

#: Las capas cuyo código **no se mergea sin test**. Ver `gate_de_tests.py`.
#:
#: Son las dos que se pueden ejercer sin levantar una escena. `ui/` y `escenas/` quedan
#: afuera: ahí el test necesita el `scene_runner` de gdUnit4 y un frame de verdad, y exigirlo
#: por gate empujaría a escribir tests de humo que pasan sin ejercer nada — que es peor que
#: no tenerlos, porque además mienten.
CAPAS_CON_TEST_OBLIGATORIO = ("src/dominio", "src/sistemas")

#: El directorio donde gdUnit4 deja sus reportes. Está en el `.gitignore`.
REPORTES = "reportes"
