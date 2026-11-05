# Llave de la pista 7C

Modelo propio de 6,4 cm. Reemplaza las primitivas de #810.

El material `metal_llave` usa hierro oscuro, óxido localizado y desgaste en los biseles.
La referencia de acabado es la palanca de `assets/models/Crowbar/`.

- `llave_base_color.png`: color en sRGB, 256 × 256.
- `llave_orm.png`: datos lineales, 256 × 256; G es rugosidad y B es metálico.
  R vale uno y no agrega oclusión. No se usa mapa normal.
- Las imágenes con prefijo `llave_llave_` las extrae Godot del GLB.
- `review/`: renders y capturas de la escena en Godot, antes y después del texturizado.
  La carpeta no se importa. Son vistas de inspección del objeto, no del depósito.

La malla, UVMap, transformaciones y asignaciones por cara se conservaron.
Las texturas externas usan rutas relativas al blend. El GLB las lleva embebidas.

Para rehacer las texturas desde la raíz del repositorio:

```text
blender --background assets/models/Llave/llave.blend --python-exit-code 1 --python assets/models/Llave/texturizar.py
```

La receta usa Blender 5.2.1 y su NumPy incluido. No modifica geometría ni UV.
El exportador general del almacén no se aplica a este objeto independiente.

En el juego: `?jornada=7`, bajo la estantería central derecha del depósito,
por el camino 4A, 5B, 6C.
