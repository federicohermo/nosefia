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

3. **Las texturas del modelo viven en la raíz y no se mueven.** Godot las extrae al importar
   `SEPT_JUEGOS_PROTOTIPO.glb` y las deja al lado, con su prefijo. Los `.res` de `models/` las
   referencian **por ruta y en binario**: moverlas pide reescribir un `RSRC` a mano, y el prefijo
   ya las agrupa. El día que Blender exporte otra vez, Godot vuelve a dejarlas ahí.
