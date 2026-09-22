# Iluminación

Los muebles toman la luz de un lightmap horneado. Los productos y las cajas la toman de las
sondas del horneado y de las mismas luces en tiempo real.

## Por qué

Medido el 2026-09-21 en escritorio, con la vista del local entero
([rendimiento](./rendimiento.md#medición-de-las-luces)):

- Las seis luces de área eran el 75 % de la GPU del cuadro, y en Compatibility no dan sombra:
  atravesaban las paredes.
- Una luz por estante son 36 luces. Compatibility alumbra cada objeto con 8 como mucho, y cada
  luz con sombra vuelve a dibujar todo lo que alumbra: 2277 llamadas de dibujo en vez de 104.
- Horneadas, las mismas luces cuestan cero sobre los muebles: el cuadro pasó de 486 llamadas de
  dibujo y 1,73 ms de GPU a 85 y 0,23 ms. Y el horneado respeta las paredes.

## Cómo está armado

- **Las luces viven en `ambiente_del_almacen.tscn`, en modo `Static`.** Las de heladera, en
  `estructura_del_almacen.tscn`. Una luz `Static` se hornea sobre los muebles y se dibuja en
  tiempo real sobre lo que no tiene lightmap. No van en `almacen.tscn`: esa escena sólo cablea,
  y su test lo cobra.
- **El `LightmapGI` cuelga de la raíz de `almacen.tscn`.** Hornea el subárbol de su padre. Sus
  datos viven al lado: `almacen.lmbake` y `almacen.exr`. Los dos se commitean.
- **El modelo se importa con `Static Lightmaps`.** Eso le da a cada malla el segundo juego de UV
  que pide el horneado. El tamaño del texel está en la misma importación.
- **Todo lo que no viene del modelo lleva GI `Dynamic`.** Sin UV2 no se hornea, y con GI
  estático queda negro. Lo dinámico toma la luz de las sondas.
- **Un grupo de productos toma esa luz en un solo punto: el centro de su caja.** El horneador
  reparte las sondas por los bordes de las mallas, y más de la mitad cae adentro de una pared o
  de un mueble. Ahí sale negra, y apaga lo que toma la luz cerca. Por eso el horneador rellena
  cada sonda negra con el promedio de sus vecinas con luz (`addons/hornear/sondas.gd`). Un
  horneado hecho a mano desde el editor no pasa por ese paso.

## Cómo se hornea

```bash
python .claude/scripts/hornear.py
```

Con el editor del repo **cerrado** y una sesión con pantalla. Prende el plugin `addons/hornear`
en `project.godot`, abre el editor, aprieta «Bake Lightmaps», rellena las sondas negras, guarda,
cierra y devuelve `project.godot` como estaba. Se corre cada vez que cambia el modelo, una luz
o el `LightmapGI`, y se commitea lo que deja.

Los mandos: la energía de cada luz en su escena, `generate_probes_subdiv` en el `LightmapGI`,
el tamaño del texel en la importación del modelo, y el umbral de sonda negra en `sondas.gd`.

## Qué lo verifica

`test/escenas/iluminacion_horneada_test.gd`: que el `LightmapGI` tenga datos, y que ninguna
malla con GI estático se haya quedado afuera del horneado. Las sondas no se pueden verificar en
headless: el `.lmbake` se carga sin ellas.
