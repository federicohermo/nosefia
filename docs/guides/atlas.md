# Mallas unidas y atlas de texturas

Dos pasos del exportador del modelo que bajan los dibujos de la web sin cambiar la imagen.

## Por qué existen

El renderizador de la web (Compatibility) dibuja una vez por superficie de cada malla,
comparta o no la textura. Un atlas solo no baja dibujos. Sirve para poder unir objetos que hoy
llevan texturas distintas. Por eso hay dos pasos, y van en este orden.

## Mallas unidas

`blender/unir_mallas_para_exportar.py` une, mientras dura la exportación, las mallas fijas que
comparten ambiente y material. El `.blend` no cambia. Lo que se une lo decide
`lib/union_de_mallas.py`.

Se queda afuera:

- lo que `src/` nombra: un override de la escena, un `get_node`, un grupo;
- lo que se mueve o cambia de luz: puertas, hojas, tapas, vidrios y lo que `importar_modelo.gd`
  pasa a luz dinámica;
- lo que Godot interpreta por su sufijo: `-col`, `-convcol`, `-colonly`, `-noimp`;
- lo que cuelga de algo que se queda afuera.

Un ambiente no se une con otro: Godot recorta por instancia, y una malla unida se dibuja entera
si se ve un pedazo. Los ambientes salen de las cajas que declara `estructura_del_almacen.tscn`.

Después de unir: `python .claude/scripts/exportar_modelo.py` y `python .claude/scripts/hornear.py`.
Unir cambia las mallas del lightmap.

## Atlas

`python .claude/scripts/armar_atlas.py` arma, desde las texturas originales:

- un atlas por formato, BC1 para lo opaco y BC3 para lo que tiene alfa;
- cada textura con el tamaño con el que viaja hoy: el atlas no baja resolución;
- un borde de 16 píxeles que repite el último píxel de cada lado, para que los mips no mezclen
  vecinas;
- cada textura en un múltiplo de 16, en x y en y. Así los bloques de compresión de sus primeros
  mips son los mismos que cuando viajaba suelta;
- un tope de 4096 por lado. Si no entra, arma otro atlas.

Escribe los PNG, `assets/source/atlas/atlas.json` y, para las cajas, el reparto que lee el juego.

El exportador (`blender/aplicar_atlas.py`) hace tres cosas.

- Apunta cada material de etiqueta al atlas.
- Lleva la UV1 de cada cara a su celda. **UV2 no se toca.**
- Une los materiales que quedan iguales.

Se corta en dos casos. El primero: el atlas no corresponde a sus fuentes. El segundo: una cara de
una etiqueta tiene UV fuera de 0..1. En un atlas la textura no se repite.

El atlas de las cajas va aparte. Lo lee `caja_de_productos.gd`, que pone como escala y desplazamiento
de la UV el rectángulo que dice `assets/boxes/atlas_de_cajas.json`. Ese archivo sale del mismo
comando.

### Cambiar una textura

1. Reemplazar el PNG de origen. Puede tener el mismo tamaño u otro.
2. `python .claude/scripts/armar_atlas.py`.
3. `python .claude/scripts/exportar_modelo.py`.
4. `godot --headless --path . --script assets/models/extraer_mallas.gd`: las mallas de los
   productos llevan las UV del atlas.
5. `python .claude/scripts/hornear.py`.

Una textura nueva es una línea en `ETIQUETAS` de `lib/atlas.py`. Una caja nueva es un PNG en
`assets/source/boxes/`.

`python .claude/scripts/armar_atlas.py --comprobar` dice si el atlas está al día, sin Blender.
`test_atlas_al_dia.py` lo exige: un atlas viejo no da ningún error en el juego, y una etiqueta
sale con el dibujo de otra.

`--sellar` registra los PNG que ya están, para cuando otra herramienta los generó con el reparto
del manifiesto. `--destino <carpeta>` arma en otra carpeta sin tocar el árbol.
