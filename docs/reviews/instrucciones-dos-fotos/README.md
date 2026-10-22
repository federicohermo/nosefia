# Fotos de las instrucciones

Capturas reales del export Web de release en Chromium, con viewport de 1920 × 1080.
La versión anterior usa el código de `release/tutorial-8-jornadas` en `6afac29e`.
La versión posterior usa el cambio de este PR.

| Pantalla | Antes | Después |
| --- | --- | --- |
| Intro 2, reloj y listas | [Captura](intro2-antes.png) | [Captura](intro2-despues.png) |
| Intro 7, góndolas y estantería | [Captura](intro7-antes.png) | [Captura](intro7-despues.png) |
| Intro 3, una foto de la ventanilla | [Captura](intro3-antes.png) | [Captura](intro3-despues.png) |

El layout anterior reservaba 233 px para las fotos y agregaba las leyendas debajo.
El ancho de cada leyenda dependía de la proporción de la foto.
En Intro 7, el último epígrafe terminaba en 905 px respecto del origen del contenido.
El contenido termina en 690 px y el pie y los botones empiezan en 740 px.

El par ahora comparte ese espacio con una columna de leyendas de 350 px a la derecha.
La fuente sigue en 30 px. El título largo ocupa dos líneas y su sector ocupa una.
Las fotos conservan su proporción completa y comparten el alto disponible.
En Intro 7, los marcos miden 212 px de alto y las imágenes interiores miden 200 px.
Las leyendas terminan en 684 px y las fotos en 690 px.
Intro 2 ocupa 206 px de alto con sus leyendas.
La captura completa de Intro 3 es idéntica píxel por píxel antes y después.

Los rectángulos medidos por el motor están en [geometria-antes.json](geometria-antes.json)
y [geometria-despues.json](geometria-despues.json).

Para capturar se abrió la escena real de instrucciones con los mensajes originales del guion.
Un autoload temporal llamó a `mostrar` y avanzó hasta cada paso.
Intro 2 es el segundo paso de la jornada 1. Intro 7 es el primer paso de la jornada 2
sin condiciones adicionales. Intro 3 es el tercer paso de la jornada 1.
Se esperó un segundo antes de medir y capturar, hasta terminar la animación de entrada.
El export usó Godot 4.7.2 y la misma plantilla Web de release que la build original.
El servidor local aplicó los headers de `vercel.json`.
El autoload y la selección temporal de escena se retiraron al terminar.
Ningún `.tscn` cambió.

Sólo se ejecutaron `gdformat` y `gdlint` como verificaciones locales de código.
Las suites y `verificar.py` quedan a cargo de la CI del PR.
