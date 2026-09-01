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

## Las subcarpetas: dos capas, dos formas de medir el mismo alcance

En las dos la carpeta **no repite el nombre del archivo**: dice **qué se rompe si tocás lo que
hay adentro**. Lo que cambia es contra qué se mide ese alcance — en `ui/`, si el reloj sigue
corriendo mientras la pantalla está arriba; en `escenas/`, cuántas instancias hay.

### `ui/` — si el reloj sigue corriendo

```text
src/ui/
├── hud.gd            ← está siempre en pantalla, por eso no está en ninguna
├── diegetica/        pantalla_de_computadora · app_caja · app_chats · app_notas
│                     · panel_de_la_ventanilla
└── interrupciones/   pantalla_de_cierre · menu_de_inicio
```

**Mirar la computadora cuesta minutos del turno; la pantalla de cierre no, porque el turno ya
terminó.** Es la distinción de diseño más cara de esta capa, y sin la carpeta no está escrita en
ningún lado: `app_caja.gd` no dice que abrirla te sale plata.

### `escenas/` — cuántas instancias hay

```text
src/escenas/
├── almacen.gd/.tscn · jugador.gd/.tscn · inicio.gd/.tscn   ← las raíces y el cuerpo
├── puestos/   estructura_del_almacen · estante · escritorio · ventanilla · zona_de_descarte
│              · limpieza_del_almacen · audio_del_almacen · manos_del_jugador
└── objetos/   objeto_agarrable · caja_de_productos · mancha_en_el_piso
```

`puestos/` se instancia **una vez** y vive cableado en la escena por `@export`; `objetos/` se
instancia **N veces**, se crea y se destruye en juego. Es la diferencia que decide si algo se
puede referenciar por `@export` o hay que salir a buscarlo — o sea, exactamente la que la regla
de cableado de arriba vuelve verificable.

**El criterio es cuántas instancias hay, no si el nombre suena a puesto de trabajo.**
`audio_del_almacen` y `manos_del_jugador` no son puestos en el sentido del GDD y van igual en
`puestos/`: hay uno solo de cada uno y llegan cableados. Forzar una tercera carpeta para ellos
sería una que repite lo que el nombre del archivo ya dice.

**Quién verifica las dos: `gate_de_capas.py`**, con `CARPETAS_POR_CAPA` de `lib/repo.py`. Valida
los **nombres** de carpeta —que exista `diegetica/` y no `pantallas/`— y **no** valida que un
archivo esté en la carpeta correcta: eso es semántica, ninguna herramienta lo puede contestar, y
lo mira la revisión. La raíz de cada capa la admite a propósito, que es donde se quedan `hud.*`,
`almacen.*`, `jugador.*` e `inicio.*` porque cruzan o son la raíz del árbol.

**Y acá mira los `.tscn` además de los `.gd`**, que en estas dos capas es la mitad que importa:
`escenas/` es casi toda escenas, y la distinción entre `puestos/` y `objetos/` se decide sobre
un `.tscn`. Es lo único que el gate lee de una escena — la **ruta**, nunca el contenido: adentro
de un `.tscn` de `escenas/` referenciar hacia abajo es correcto por definición.

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
