---
paths:
  - "assets/**"
---

# Assets

1. **`source/` no se importa.** Lleva un solo `.gdignore` arriba, así que Godot saltea el árbol
   entero: el arte de origen y los packs de terceros no cuestan importación ni entran a la build.
   Antes eran cuatro `.gdignore` sueltos, y cinco carpetas de textura fuente que **sí** se
   importaban sin que nada las usara.

2. **Lo que el juego carga tiene su carpeta**, y el nombre va en inglés como el de cualquier
   carpeta fuera de `src/`: `models/` y `reactions/`.

3. **Las texturas del modelo viven al lado del `.glb` y no se mueven.** Godot las extrae al
   importar `SEPT_JUEGOS_PROTOTIPO.glb` y las deja ahí, con su prefijo. Los `.res` de `models/`
   las referencian **por ruta y en binario**: moverlas pide reescribir un `RSRC` a mano, y el
   prefijo ya las agrupa. El día que Blender exporte otra vez, Godot vuelve a dejarlas ahí.

4. **Renombrar una carpeta de `source/` rompe el `.blend`, y ningún nodo lo ve.** Sus rutas son
   relativas al archivo (`//carpeta/textura.png`), el `.glb` lleva las texturas **embebidas**, y
   el juego sigue idéntico: los siete nodos quedan verdes y la escena se abre entera en magenta,
   que es el color de textura faltante de Blender. Reorganizar `assets/` costó 37 de 39 imágenes
   el 2026-09-18.

   Si ya pasó, se reapunta cada imagen contra `source/` desde la consola de Python de Blender,
   indexando por **(carpeta, archivo)** y no sólo por archivo: `jorgillo.png` está dos veces, y
   sólo la carpeta que la ruta vieja nombraba las desempata.

5. **Dónde va cada unidad de la góndola lo dice `disposicion_de_la_gondola.tres`, no el `.glb`.**
   El modelo trae **una** unidad de cada producto; las copias que llenan el estante viven en la
   colección `guia` del `.blend` —visible para el artista, excluida al exportar— y las dibuja un
   `MultiMesh` por bloque. Mover una caja en Blender no llega al juego hasta regenerar ese
   recurso: el `.glb` no la lleva.

6. **Y después va `exportar_modelo.py`.** El par `.blend` ↔ `.glb` se verifica por hash, así que
   un `.blend` que cambió sin reexportar es rojo — aunque el cambio no toque una sola malla. No
   es burocracia: reapuntar las texturas dejó la estructura igual —67 mallas, 42 materiales, 35
   imágenes— y el `.glb` salió 279 KB distinto, porque el exportador recodifica las imágenes.
