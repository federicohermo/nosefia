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
