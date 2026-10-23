# Paso uniforme entre productos de un estante (#622)

Capturas del juego real en Godot 4.7.2 `nosefia_classdb_1`, renderizador Compatibility, jornada 1 (16 productos).
Misma cámara y mismo encuadre antes y después. Script: `medicion/medir_aire.gd`, el de #621.
Antes: disposición de `d1531b6c`. Después: la de este PR.

| Estante | Antes | Después |
|---|---|---|
| Isla A este, Terminator / Zucarachas | [abrir](antes-16/A-este.png) | [abrir](despues-16/A-este.png) |
| Isla A oeste, Arvecor / Marolini | [abrir](antes-16/isla-costado.png) | [abrir](despues-16/isla-costado.png) |
| Isla B este, Pepito / Petisas | [abrir](antes-16/B-este.png) | [abrir](despues-16/B-este.png) |
| Isla B oeste, Progres / Don Saturados | [abrir](antes-16/B-oeste.png) | [abrir](despues-16/B-oeste.png) |
| No comestibles, Actroncito / Duronga | [abrir](antes-16/no-comestibles.png) | [abrir](despues-16/no-comestibles.png) |

## Medidas

Huecos entre cajas vecinas de la fila frontal, nivel inferior, en milímetros. Las mide Blender sobre las mallas que dibuja el juego
(`medicion/medir_pasos.py`; salida cruda en `medicion/pasos-antes.log` y `pasos-despues.log`).
`X` marca el cambio de producto.

| Estante | Antes | Después |
|---|---|---|
| A este | 15 ×10, **75 X**, 35 ×3 | 35 ×13, **35 X** |
| A oeste | 15 ×7, **61 X**, 35 ×4 | 15 ×7, **35 X**, 35 ×4 |
| B este | 40 ×4, **74 X**, 25 ×4 | 40 ×4, **40 X**, 25 ×4 |
| B oeste | 23 ×10, **71 X**, 25 ×4 | 23 ×10, **25 X**, 25 ×4 |
| No comestibles | 44 ×4, **77 X**, 25 ×6 | 44 ×4, **44 X**, 25 ×6 |

Cabeceras y heladeras: idénticas antes y después. Cupos: sólo cambia Terminator, de 44 a 40 casilleros (11 a 10 frontales).
El juego dibuja 728 unidades antes y 720 después. Ver `antes-16/mediciones.json` y `despues-16/mediciones.json`.

## Mapa de 32

`medicion/pasos-32.log` mide la disposición de 32 que está en el `.blend`. Ese reparto usa otro colocador y no se tocó.
Deja un único hueco por estante entre las huellas de los envases. Quedan cuatro encuentros con 10 mm de más
(por ejemplo 45 mm contra 35 mm), que vienen del envase contra la malla de esos productos.
