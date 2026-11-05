# Llave de la pista 7C

Modelo propio de 6,4 cm. Reemplaza las primitivas de #810.

El material `metal_llave` usa hierro oscuro, óxido localizado y desgaste en los biseles.
La referencia de acabado es la palanca de `assets/models/Crowbar/`.

- `llave_llave_base_color.png`: color en sRGB, 256 × 256.
- `llave_llave_orm.png`: datos lineales, 256 × 256; G es rugosidad y B es metálico.
  R vale uno y no agrega oclusión. No se usa mapa normal.

El GLB lleva las texturas embebidas, y Godot las extrae al importar con el prefijo `llave_`.
La malla, UVMap, transformaciones y asignaciones por cara se conservaron.
El blend apunta a `llave_base_color.png` y `llave_orm.png`, que no se commitean:
`texturizar.py` las vuelve a escribir.

Para rehacer las texturas desde la raíz del repositorio:

```text
blender --background assets/models/Llave/llave.blend --python-exit-code 1 --python assets/models/Llave/texturizar.py
```

La receta usa Blender 5.2.1 y su NumPy incluido. No modifica geometría ni UV.
El exportador general del almacén no se aplica a este objeto independiente.

En el juego: `?jornada=7`, bajo la estantería central derecha del depósito,
por el camino 4A, 5B, 6C.
