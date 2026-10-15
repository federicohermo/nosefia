# Notas del juego en Blender

Las hojas se capturaron con Godot 4.7.2 a partir de `src/escenas/objetos/nota_pegada.tscn`, sus SVG originales y `assets/ui/manada/notas/orange_lovely.otf`. El texto se leyó de `src/dominio/almacen/nota_pegada.gd` y `src/dominio/jornada/apertura.gd`.

- `tareas_jornada_1.png`: lista estática de la primera jornada; el juego calcula su lista por jornada.
- `mantener_local_ordenado.png`: instrucciones originales del corcho.
- `fuera_de_servicio_manuscrito_papel.png`: texto original de `AvisoDeHeladera` en `estructura_del_almacen.tscn`, con la misma fuente manuscrita del corcho solicitada para Blender y el color del papel existente.

La captura de las hojas usa cámara ortográfica, conserva la composición 3D original y se aplica a los soportes con las proporciones de la escena del juego. Las imágenes están empaquetadas en la sesión de Blender además de conservar estas rutas externas. No se modificaron escenas ni scripts del juego. `source.json` conserva el contenido capturado de las dos hojas.
