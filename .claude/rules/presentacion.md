---
paths:
  - "src/ui/**/*.gd"
  - "src/escenas/**/*.gd"
  - "**/*.tscn"
---

# UI y escenas

La cáscara: el HUD, la computadora con sus chats e inventarios, la ventanilla, y los scripts
pegados a un `.tscn`. **Cablean, no deciden.**

## Estas dos capas no tienen test obligatorio, y eso no es una amnistía

`gate_de_tests.py` no las mira porque probarlas pide el `scene_runner` de gdUnit4 y frames de
verdad, y exigirlo por gate empujaría a escribir tests de humo que pasan sin ejercer nada —
peor que no tenerlos, porque además mienten sobre la cobertura.

**La consecuencia es la regla que sí importa acá: si un archivo de esta capa tiene una regla
del juego adentro, esa regla quedó sin test.** La salida no es escribirle un test a la
pantalla: es mover la regla a `dominio/`, donde el test es barato y obligatorio.

La pregunta antes de escribir un `if` acá: ¿esto es «cómo se ve» o es «qué pasa»? Lo segundo
no va en esta capa.

## Un `.tscn` es código

Se revisa como código y se mergea con el mismo cuidado: un merge de tres vías sobre una escena
grande produce una escena rota, no un conflicto. Las dos formas de que eso no pase:

- **Escenas chicas y compuestas.** Una escena por cosa, instanciada dentro de otra.
- **Avisar antes de tocar una escena que otro está tocando.** Es la única parte del repo donde
  el flujo de ramas no alcanza.

## La escena raíz cablea; lo que tiene estructura entra instanciado

`src/escenas/almacen.tscn` es una escena de **cableado**: los nodos que declara ella misma son
**todos hijos directos de su raíz**. Cualquier cosa con hijos propios —un puesto de trabajo, la
geometría del local, un mueble con sus partes— va a su propio `.tscn` y entra con una sola línea
de instancia.

**Por qué, y no es estilo:** ocho specs tienen una tarea que edita esa escena, y un `.tscn` no se
mergea. Con el blockout adentro —133 líneas que ninguno de los ocho escribió— cada uno abría un
archivo grande para agregar tres, y dos que se cruzaran chocaban sobre geometría ajena. El spec
023 lo sacó a `estructura_del_almacen.tscn`, y esta regla es lo único que impide que vuelva a
entrar. La escena grande no es un problema de gusto: es lo que serializa el orden de
implementación de todo el juego.

**Quién lo verifica: `test/escenas/almacen_test.gd`**, con la recorrida en
`_violaciones_de_cableado()`. El discriminador es el `owner` y no la profundidad —en una
sub-escena instanciada el `owner` de cada hijo es la raíz de la sub-escena, así que
`Jugador/Camara` no la viola aunque esté a dos niveles—.

**Y hay que decir hasta dónde llega, porque un gate llegaría más lejos.** `gate_de_tests.py` no
mira `test/escenas/`: nada obliga a que ese caso exista, y la regla vale para `almacen.tscn` y
nada más — una escena raíz futura no queda cubierta. Es un caso, no un gate, y el precio se paga
a cambio de no reimplementar el formato de escena en Python para contestar peor.

**Un anclaje no es un padre.** Un `Marker3D` como `HuecoDeLaVentanilla` es un punto de cableado:
colgarle una instancia la deja con `owner` en la raíz y un padre que no es la raíz, o sea que
rompe la regla. La forma correcta es instanciar como hijo directo de la raíz **con el `transform`
del anclaje**.

## La comunicación va por señales y `@export`

- Hacia abajo, `@export`: la escena recibe lo que necesita y se conecta en el editor.
  **Si el `.tscn` se edita a mano, un `@export` de tipo `Node` va declarado ADEMAS en el tag
  del nodo** — `node_paths=PackedStringArray("_hud", "_reloj")` —, porque el motor guarda el
  valor como `NodePath` y sin esa lista no lo resuelve. Queda en `null`, **la escena carga sin
  un solo error**, los seis nodos dan verde, y el juego muere en el primer cuadro con un
  `Nonexistent function … in base 'Nil'` que no nombra ni al `.tscn` ni al `@export`. El editor
  de Godot lo escribe solo; una escena escrita a mano, no. Medido en el spec 007.
- Hacia arriba, señales.
- Nunca `get_node("../../…")`, por lo que dice [gdscript.md](./gdscript.md).

## Los textos que ve el jugador

Van en español rioplatense y en un solo lugar por pantalla, no repartidos entre el `.tscn` y
el script. Un texto que aparece en dos lados se cambia en uno solo el día que haya que
cambiarlo.
