# Iluminación

Toda la luz de los muebles está horneada. Lo único que se dibuja en tiempo real son las luces de
estante y de heladera, sin sombra y sólo sobre los productos.

## Por qué

Medido el 2026-09-21 en escritorio, con la vista del local entero
([rendimiento](./rendimiento.md#medición-de-las-luces)):

- Las seis luces de área eran el 75 % de la GPU del cuadro, y en Compatibility no dan sombra:
  atravesaban las paredes.
- Una luz por estante son 36 luces. Compatibility alumbra cada objeto con 8 como mucho, y cada
  luz con sombra vuelve a dibujar todo lo que alumbra: 2277 llamadas de dibujo en vez de 104.
- Horneadas, las mismas luces cuestan cero: el cuadro pasó de 486 llamadas de dibujo y 1,73 ms
  de GPU a 85 y 0,23 ms. Y el horneado respeta las paredes.

## Cómo está armado

- **Las luces viven en `ambiente_del_almacen.tscn`, en modo `Static`.** Las de techo cuelgan
  de la raíz y están ocultas; las de estante y de cabecera, de un nodo por góndola que lleva la
  posición de esa góndola. Compatibility dibuja una luz horneada igual que una común si está a
  la vista, así que una luz de techo prendida cuesta lo mismo que antes. No van en
  `almacen.tscn` porque esa escena sólo cablea, y su test lo cobra.
- **El `LightmapGI` cuelga de la raíz de `almacen.tscn`**, porque hornea el subárbol de su
  padre. Sus datos viven al lado: `almacen.lmbake` y `almacen.exr`. Los dos se commitean.
- **El modelo se importa con `Static Lightmaps`**, que es lo que le da a cada malla el segundo
  juego de UV que pide el horneado. El tamaño del texel está en la misma importación.
- **Todo lo que no viene del modelo lleva GI `Dynamic`**: los productos, que van por
  `MultiMesh`; las cajas; las guías; lo que se instancia por script. Sin UV2 no se hornea, y
  con GI estático quedaría negro. Lo dinámico toma la luz de las sondas que el horneado deja
  repartidas por el local.
- **Un grupo de productos toma esa luz en un solo punto: el centro de su caja.** Un grupo que
  abarca una góndola tiene el centro adentro del mueble, donde la luz es negra. Por eso la caja
  de cada grupo se estira hacia arriba hasta que el centro queda en el aire, y por eso la luz
  de cada estante no le llega a los productos por sondas.
- **Las luces de estante y de heladera se dibujan en tiempo real sólo sobre los productos**,
  que viven en la capa visual 2, y sin sombra. Para los muebles esas mismas luces están
  horneadas. Medido: 0,1 ms de GPU, ninguna llamada de dibujo más. Los topes de luces del
  renderizador están subidos en `project.godot` para que entren las de una góndola entera.

## Cómo se hornea

```bash
python .claude/scripts/hornear.py
```

Con el editor del repo **cerrado** y una sesión con pantalla. Prende el plugin `addons/hornear`
en `project.godot`, abre el editor, aprieta «Bake Lightmaps», guarda, cierra y devuelve
`project.godot` como estaba: unos segundos. Hay que correrlo cada vez que cambia el modelo, una
luz o el `LightmapGI`, y commitear lo que deja.

Los mandos, si el resultado no gusta: la energía y la energía indirecta de cada luz en su
escena, `generate_probes_subdiv` en el `LightmapGI`, y el tamaño del texel en la importación del
modelo.

## Qué lo verifica

`test/escenas/iluminacion_horneada_test.gd`: que ninguna luz alumbre los muebles en tiempo real,
que los productos estén en la capa de las luces de estante, que el `LightmapGI` tenga datos, y
que ninguna malla con GI estático se haya quedado afuera del horneado.
