# Sprites de compradores en la ventanilla

Las imágenes muestran exports Web release del almacén real a las 20:30.
El cuadro de animación y la cámara permanecen fijos.
El fixture cambia los SpriteFrames del mismo AnimatedSprite3D y activa el MarcoDelObjetivo de producción.
El foco se activa directamente para aislar su dibujo. No se verifica su adquisición mediante raycast.

`antes/` usa los PNG de release/tutorial-8-jornadas anteriores a la limpieza.
`despues/` usa los PNG generados por el script del PR.
Cada comprador tiene una captura con foco y otra sin foco.
Las capturas sin foco separan el dibujo de la indicación interactiva.
El contorno continuo de foco es intencional.

La comparación del alfa del PNG y la textura importada produjo cero diferencias en los 32 cuadros.
Los logs del navegador incluyen avisos de blit de profundidad en ambas versiones.
La escena y los compradores se dibujan en las capturas adjuntas.

Los archivos de reproducción se guardan en `reproduccion/`.
Se ejecutaron desde `tmp/` en el checkout, con Playwright instalado y el motor corregido del proyecto.
`exportar_captura.py` cambia temporalmente la escena principal y las exclusiones, y restaura ambos archivos al terminar.
`servir_export.py` del proyecto aporta los headers COOP y COEP.
`capturar_web.mjs` espera el marcador de escena lista y guarda las capturas del navegador Edge.

No se ejecutó verificar.py ni suites locales. La CI del PR verifica el cambio.
