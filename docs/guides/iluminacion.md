# Iluminación

Los muebles toman la luz de un lightmap horneado. Los productos y las cajas la toman de las
sondas del horneado y de las mismas luces en tiempo real.

## Por qué

- En Compatibility, una luz de área no da sombra y atraviesa las paredes. El horneado respeta
  las paredes.
- Compatibility alumbra cada objeto con un tope de luces. Una luz por estante lo pasa.
- Cada luz con sombra vuelve a dibujar todo lo que alumbra. Horneada, la luz no cuesta nada
  sobre los muebles.

Cómo se mide el costo de las luces, en [rendimiento](./rendimiento.md).

## Cómo está armado

- **Las luces viven en `ambiente_del_almacen.tscn`, en modo `Static`.** Las de heladera, en
  `estructura_del_almacen.tscn`. Una luz `Static` se hornea sobre los muebles y se dibuja en
  tiempo real sobre lo que no tiene lightmap. No van en `almacen.tscn`: esa escena sólo cablea,
  y su test lo cobra.
- **El `LightmapGI` cuelga de la raíz de `almacen.tscn`.** Hornea el subárbol de su padre. Sus
  datos viven al lado: `almacen.lmbake`, `almacen.exr` y `almacen.exr.import`. Los tres se
  commitean. El `.import` dice en cuántas capas se corta el atlas: sin él, otra máquina lo corta
  mal.
- **El modelo se importa con `Static Lightmaps`.** Eso le da a cada malla el segundo juego de UV
  que pide el horneado. El tamaño del texel está en la misma importación.
- **Todo lo que no viene del modelo lleva GI `Dynamic`.** Sin UV2 no se hornea, y con GI
  estático queda negro. Lo dinámico toma la luz de las sondas.
- **Lo que gira también lleva GI `Dynamic`, aunque venga del modelo:** las hojas que abren y la
  tapa del contenedor. Horneadas, dejarían su sombra en la posición en la que se hornearon.
- **Los pallets de la entrega también son dinámicos:** aparecen con las cajas de la primera
  noche y se retiran en la siguiente. Reutilizan la madera del pallet de piso y reciben luz de
  las sondas; no dejan sombras permanentes en el horneado.
- **Los estantes del fondo interceptan la luz cenital del depósito.** Su madera inferior
  necesita luz rebotada para leerse. Se ajustan los plafones del depósito y su energía indirecta
  y se vuelve a hornear. El brillo global, la niebla y el bloom conservan sus valores.
- **Un grupo de productos toma esa luz en un solo punto: el centro de su caja.** El horneador
  reparte las sondas por los bordes de las mallas, y muchas caen adentro de una pared o de un
  mueble. Ahí salen negras, y apagan lo que toma la luz cerca. Por eso el horneador rellena cada
  sonda negra con el promedio de sus vecinas con luz (`addons/hornear/sondas.gd`). Un horneado
  hecho a mano desde el editor no pasa por ese paso.
  El umbral sólo detecta radiancia prácticamente nula: una sonda tenue del depósito es válida
  y se conserva. Reemplazarla por vecinas luminosas arrastraba el verde del salón a las cajas.

## Cómo se hornea

El exportador aplica `blender/separar_hojas_de_entrada.py` antes de generar el modelo. Ese paso
reconstruye las dos hojas de entrada con el vidrio como hijo y el origen en cada bisagra.
Para actualizar también la fuente visible en Blender, se ejecuta ese script sobre el `.blend`
con `-- --aplicar`. Editar las hojas a mano se pierde al exportar.

```bash
python .claude/scripts/hornear.py
```

Qué hace y qué necesita lo dice el encabezado del script. Se corre cada vez que cambia el
modelo, una luz o el `LightmapGI`. Se commitea lo que deja: el `.lmbake`, el `.exr` y el
`.exr.import`. **Lo demás que el editor re-serializa al guardar, el script lo devuelve.** Sin
eso, `almacen.tscn` quedaba con un override por cada volumen de la estructura, y el override
congela su posición.
En Linux sin pantalla ni GPU anda con Xvfb y el Vulkan por software de Mesa; el comando está en
el encabezado. El error de OpenGL que obliga a hornear con Vulkan es el
[reporte 94407 de Godot](https://github.com/godotengine/godot/issues/94407).

Los mandos:

- la energía de cada luz, en su escena;
- `generate_probes_subdiv`, en el `LightmapGI`;
- el tamaño del texel, en la importación del modelo;
- la resolución de paredes y pisos, en la malla `almacen` de `estructura_del_almacen.tscn`.
  Evita que el filtrado del lightmap dibuje una franja verde al pie de la pared del depósito;
- la escala del texel de una malla chica (`gi_lightmap_texel_scale`), en
  `estructura_del_almacen.tscn`;
- el umbral de sonda negra, en `sondas.gd`.

## El horneado de la noche del corte de luz

La séptima noche se corta la luz. La oscuridad **no** apaga el `LightmapGI`: el local tiene un
segundo horneado, `almacen_sin_luz.lmbake` y `almacen_sin_luz.exr`. Lleva la luz de emergencia
sobre el tablero eléctrico y la de afuera. Al cortarse, `corte_de_luz.gd` le cambia los datos al
mismo `LightmapGI`; al restablecerse, le devuelve los de siempre. Cambian juntos los muebles y
las sondas de los productos.

- **Qué queda encendido:** la luz del grupo `luz_de_emergencia`, que es `LuzDelTablero`, y la
  luz de afuera. Las demás luces, los materiales emisivos de las lámparas, la niebla y los
  reflejos se apagan en tiempo real: no salen del horneado.
- **La luz de afuera es el cielo del horneado oscuro.** El horneador le pone al `LightmapGI` un
  entorno de color propio (`corte_de_luz.gd`). Un rayo que sale por un vidrio trae ese color, y
  las sondas lo guardan con su dirección. Así, un producto que mira al ventanal recibe más luz que
  uno que mira adentro del local. El juego no lo ve: la escena no se guarda.
- **Una luz puntual afuera no sirve para los productos.** Una sonda guarda la luz que llega de
  las superficies, nunca la directa de una luz. El rebote de una luz de afuera llega a la sonda
  desde el estante alumbrado, adentro del local. Con cinco luces así, la cara de la góndola que
  miraba al ventanal quedaba más oscura que la de adentro.
- **La emergencia tiene más energía, alcance y ángulo** que los de su escena, para alumbrar el
  depósito alrededor del tablero. Los valores están en `corte_de_luz.gd`. Valen para este
  horneado y, mientras dura el corte, para el juego. Así las cajas y los objetos del depósito la
  reciben igual que los muebles. Durante el corte también da sombra, para que no atraviese la
  pared del depósito hacia las heladeras.
- **Qué se apaga lo dice un solo archivo**, `corte_de_luz.gd`. Lo usa el juego al cortar y lo
  usa el horneador al hornear, así que no pueden diferir.
- **Se hornea aparte**, con `python .claude/scripts/hornear.py --sin-luz`. Apaga el local en la
  copia del editor, no guarda la escena y deja el `.lmbake`, el `.exr` y su `.import`. Se
  commitean. Hay que volver a correrlo cuando cambia el modelo, una luz o el `LightmapGI`, igual
  que el horneado con luz.

## Qué lo verifica

`test/escenas/iluminacion_horneada_test.gd`: que el `LightmapGI` tenga datos, y que ninguna
malla con GI estático se haya quedado afuera del horneado. También que ninguna hoja que abre
haya entrado. En headless el `.lmbake` se carga sin sondas. Por eso
`test/escenas/sondas_del_horneado.gd` las lee del archivo y las muestrea como el motor. Con eso,
`corte_de_luz_en_el_almacen_test.gd` verifica que la cara del ventanal reciba más luz que la de
adentro.
