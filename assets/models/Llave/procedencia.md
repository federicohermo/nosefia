# La llave (pista 7C)

`llave.blend` es un modelo propio, hecho para el juego. Es la llave de la oficina de Enrique,
que está bajo una estantería del depósito en la jornada 7 (pista 7C). `llave.glb` es su
exportación, y es lo que carga `src/escenas/objetos/llave.tscn`.

| Dato | Valor |
|---|---|
| Autor | Hecha con Blender 5.2 para No se fía (5 de noviembre de 2026) |
| Licencia | La del repositorio |
| Medidas | 6,4 cm de largo, 2 cm de ancho y 6,4 mm de canto |
| Objeto | `Llave`: anillo, vástago con collar y paletón con tres dientes |
| Material | `metal_llave`: hierro oscuro, óxido localizado y desgaste en los biseles |
| Mapa UV | `UVMap`: una isla por pieza, sin solapes |

Las tres piezas son componentes separados de una sola malla, y por eso la escena dibuja un
solo objeto. El largo va en X, el canto en el eje vertical y los dientes hacia +Z de Godot. El
origen está en el centro de la caja del modelo, y la escena no lo corre.

`metal_llave` usa dos texturas de 256 × 256, empaquetadas dentro del `.blend`:

- `llave_base_color`: el color, en sRGB.
- `llave_orm`: datos lineales. G es la rugosidad y B lo metálico. R vale uno y no agrega
  oclusión. No hay mapa normal.

El `.glb` lleva las texturas embebidas, y Godot las extrae al importar como
`llave_llave_base_color.png` y `llave_llave_orm.png`.

El `.glb` se exporta desde el `.blend` con el exportador glTF de Blender, en formato binario y
con +Y arriba. Un cambio en el `.blend` pide exportar de nuevo.

`texturizar.py` rehace las dos texturas sobre la UV existente, las empaqueta, guarda el `.blend`
y exporta el `.glb`. No toca la geometría ni la UV. El ruido de Blender cambia entre corridas, y
cada corrida da otra variante del mismo acabado. Se corre desde la raíz del repositorio:

```text
blender --background assets/models/Llave/llave.blend --python-exit-code 1 --python assets/models/Llave/texturizar.py
```
