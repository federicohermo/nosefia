---
paths:
  - "src/ui/**/*.gd"
  - "src/escenas/**/*.gd"
  - "**/*.tscn"
---

# UI y escenas

La cáscara: el HUD, la computadora, la ventanilla, y los scripts pegados a un `.tscn`.
**Cablean, no deciden.**

## Estas dos capas no tienen test obligatorio, y eso no es una amnistía

`gate_de_tests.py` no las mira porque probarlas pide el `scene_runner` y frames de verdad.
Exigirlo por gate empujaría a escribir tests de humo que pasan sin ejercer nada — peor que no
tenerlos, porque además mienten sobre la cobertura.

**La consecuencia es la regla que importa acá: una regla del juego escrita en esta capa queda sin
test.** La salida no es testear la pantalla: es mover la regla a `dominio/`.

La pregunta antes de escribir un `if` acá: ¿esto es «cómo se ve» o «qué pasa»? Lo segundo no va.

## Las subcarpetas: dos capas, dos formas de medir el alcance

La carpeta dice **qué se rompe si tocás lo que hay adentro**. Lo que cambia es contra qué se mide.

- **`ui/` — si el reloj sigue corriendo.** `diegetica/` sí: mirar la computadora cuesta minutos
  del turno. `interrupciones/` no: el turno ya terminó. Es la distinción de diseño más cara de la
  capa, y sin la carpeta no está escrita en ningún lado.
- **`escenas/` — cuántas instancias hay.** `puestos/` se instancia **una vez** y llega cableado
  por `@export`; `objetos/` se instancia **N veces**, se crea y se destruye en juego. Es lo que
  decide si algo se puede referenciar por `@export` o hay que salir a buscarlo.

**El criterio es cuántas instancias hay, no si el nombre suena a puesto de trabajo.**
`audio_del_almacen` y `manos_del_jugador` no son puestos en el sentido del GDD y van igual en
`puestos/`: hay uno solo de cada uno y llegan cableados.

La raíz de cada capa se admite a propósito, y es donde se quedan los que cruzan o son la raíz del
árbol. El árbol de cada carpeta lo imprime `python .claude/scripts/estructura.py`.

**Quién verifica las dos: `gate_de_capas.py`**, con `CARPETAS_POR_CAPA`. Valida los **nombres** y
no que un archivo esté en la carpeta correcta: eso es semántica y lo mira la revisión.

**Y acá lee los `.tscn` además de los `.gd`** — la **ruta**, nunca el contenido: adentro de un
`.tscn` de `escenas/` referenciar hacia abajo es correcto por definición.

## Un `.tscn` es código

Se revisa como código y se mergea con el mismo cuidado: un merge de tres vías sobre una escena
grande produce una escena rota, no un conflicto. Las dos formas de que eso no pase: **escenas
chicas y compuestas**, y **avisar antes de tocar una que otro está tocando**.

## La escena raíz cablea; lo que tiene estructura entra instanciado

Los nodos que `almacen.tscn` declara son **todos hijos directos de su raíz**. Cualquier cosa con
hijos propios —un puesto, la geometría del local, un mueble con sus partes— va a su propio
`.tscn` y entra con una línea de instancia.

**Por qué, y no es estilo:** ocho specs tenían una tarea que editaba esa escena, y un `.tscn` no
se mergea. Con el blockout adentro —133 líneas que ninguno de los ocho escribió— cada uno abría
un archivo grande para agregar tres, y dos que se cruzaran chocaban sobre geometría ajena. El
se lo sacó a `estructura_del_almacen.tscn`. **La escena grande serializa el orden de
implementación de todo el juego.**

**Quién lo verifica: `test/escenas/almacen_test.gd`**, en `_violaciones_de_cableado()`. El
discriminador es el `owner` y no la profundidad: en una sub-escena instanciada el `owner` de cada
hijo es la raíz de la sub-escena, así que `Jugador/Camara` no la viola.

**Hasta dónde llega:** `gate_de_tests.py` no mira `test/escenas/`, así que nada obliga a que ese
caso exista, y la regla vale para `almacen.tscn` y nada más. Es un caso, no un gate, y el precio
se paga a cambio de no reimplementar el formato de escena en Python para contestar peor.

**Un anclaje no es un padre.** Un `Marker3D` como `HuecoDeLaVentanilla` es un punto de cableado:
colgarle una instancia la deja con `owner` en la raíz y un padre que no lo es. Se instancia como
hijo directo de la raíz **con el `transform` del anclaje**.

## La comunicación va por señales y `@export`

Hacia abajo `@export`, hacia arriba señales, y nunca `get_node("../../…")` — ver
[gdscript.md](./gdscript.md).

Cuatro modos de falla medidos, y **los cuatro cargan la escena sin un solo error**:

- **Un `@export` de tipo `Node` en un `.tscn` escrito a mano necesita su
  `node_paths=PackedStringArray("_hud", "_reloj")`** en el tag del nodo. El motor guarda el valor
  como `NodePath` y sin esa lista no lo resuelve: queda en `null` y el juego muere en el primer
  cuadro con un `Nonexistent function … in base 'Nil'` que no nombra ni al `.tscn` ni al
  `@export`. El editor lo escribe solo; una escena a mano, no. Está medido, y desde el
  2026-09-18 **lo cobra un gate**: `lib/escenas.py`, en el nodo `harness`.
- **Una sub-escena instanciada necesita su `script` declarado en su propio `.tscn`.** Sin él, el
  `@export` que la apunta desde afuera queda en `null` **con el `node_paths` bien escrito**. Es
  el mismo síntoma con otra causa, y por eso se diagnostica mal: se revisa el `node_paths`, que
  está bien. Medido en la ola 2 del lote del 2026-09-06.
- **Un `@export` que apunta a un script de `escenas/` no se puede tipar por su `class_name`**:
  esos scripts son cáscara y no declaran uno. Va `const X := preload("res://…/x.gd")` y después
  `@export var _x: X`. Sin eso el tipo estático es el del nodo —`Label3D`— y llamarle su método
  no compila. Está medido.
- **El `_ready()` de un hijo corre ANTES que el de su raíz.** Un puesto que se pinta en su propio
  `_ready()` contra un estado que le da el cableado muere con el mismo mensaje. **Quien pinta es
  el cableado**, cuando abre la jornada.

## Los textos que ve el jugador

Van en español rioplatense y en un solo lugar por pantalla, no repartidos entre el `.tscn` y el
script.
