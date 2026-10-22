# Mancha sobre el cartel

Capturas reales de `src/escenas/almacen.tscn` con Godot 4.7.2 y GL Compatibility, en una NVIDIA RTX 4050. Se usa la cámara del jugador, sin modificar el cartel ni la iluminación. El script oculta las pantallas superpuestas y detiene el turno para fijar el encuadre.

`antes.png` muestra la base `6afac29e`. `despues.png` muestra el cambio de una línea publicado en `92a6e68a`. Ambas imágenes usan la jornada 4 y la cámara en `(10.9, 1.802237, 4.55)`, apuntada a `(10.94, 1.7, 6.27)`.

La malla de la mancha tiene normal hacia -Z. Su origen mundial pasa de `z=6.275` a `z=6.266`. El papel permanece en `z=6.270..6.272`. El buffer de profundidad ocultaba la parte de mancha situada detrás del papel.

`despues-lateral.png` usa la cámara en `(10.48, 1.802237, 5.18)`. Las capturas de jornadas 6, 7 y 8 abren esas jornadas reales, que reutilizan la misma instancia de pared.

Para reproducir, copiar `capturar.gd` a `tmp/mancha-cartel/capturar.gd` desde la raíz del checkout. Ejecutar Godot con un renderizador real.

```powershell
& $env:GODOT_BIN --path . --rendering-method gl_compatibility --windowed --script tmp/mancha-cartel/capturar.gd -- despues 4
& $env:GODOT_BIN --path . --rendering-method gl_compatibility --windowed --script tmp/mancha-cartel/capturar.gd -- despues-lateral 4 lateral
```

La primera opción nombra el archivo PNG. La segunda indica la jornada. Una tercera opción activa la vista oblicua. Las imágenes se guardan en `tmp/mancha-cartel/`.

La validación local se limitó a `gdformat` y `gdlint`. No se ejecutó `verificar.py` ni suites locales. La CI del PR verifica el proyecto completo.
