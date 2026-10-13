Capturas y mediciones reales del alcance que el usuario decidió el 2026-10-13 para #368/#417.

Godot 4.7.2, OpenGL Compatibility, NVIDIA RTX 4050 Laptop, Windows, 1280x720. El proyecto arranca maximizado: el fixture lo pasa a ventana y comprueba el tamaño real antes de guardar. La cámara conserva las tres poses publicadas originalmente. Las colisiones se mantienen activas; sólo se detienen procesos y se congelan cuerpos rígidos.

Reproducción desde la cabeza final del PR:

```powershell
godot --path . --windowed --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 --script <ruta>/fixture_captura.gd -- capturar <salida> resultado
godot --path . --windowed --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 --script <ruta>/fixture_medicion.gd -- medir <salida>/base.json base
godot --path . --windowed --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 --script <ruta>/fixture_medicion.gd -- medir <salida>/propuesta.json propuesta
```

Usar APPDATA propia fuera del usuario del juego. Los fixtures escriben evidencia, no cambios en la fuente.

El control runtime reproduce el dibujo del PR anterior e659fa9a: saturación 0.45, brillo 0.70, referencias superiores y zócalo en color, huecos ocultos. No cambia la geometría ni las posiciones. Mide el costo del dibujo, sin incluir la construcción inicial de los nodos.

La propuesta aplica saturación 0, brillo 1 a las referencias y alpha 0.65 al ruido gris de los huecos. La secuencia fue ruido-a, ruido-b, base-1, prop-1, prop-2, base-2, base-3, prop-3. Cada carga mide tres vistas, con 8 cuadros de calentamiento y 40 medidos por vista, sin otros tests o renderers del lote.

`poses-resultado.json` conserva la pose y el foco de cada imagen. `pose-hover.json` afirma el foco real del mismo casillero vacío que se repone en las dos capturas adicionales.
