# Compradores de la primera jornada

Los 16 PNG son copias sin modificación de `origin/modelossupermercado`, revisión
`379df911f49eafffc273fcaa84490d848b620f1c`. Conservan RGBA y 1086 × 1448 píxeles.

| Destino | Origen (01 a 08, en orden) |
|---|---|
| `martin/` | `assets/personajes/Martin/nuevomartin-idle NN.png` |
| `tiago/` | `assets/personajes/Tia/Tia-idle NN.png` |

Los recursos `idle.tres` reproducen los ocho dibujos en orden numérico y en bucle.
Por decisión explícita del usuario del 2026-10-09, **todos los cuadros de ambos compradores
duran 0,5 segundos**: velocidad 2 cuadros/s, duración relativa 1 y bucle de 4 segundos.
Esta decisión reemplaza el criterio inicial de exposiciones no uniformes.

Referencias: `assets/personajes/Martin/personaje martin.mp4` (89 cuadros) y
`assets/personajes/Tia/mov-personaje Tia.mp4` (82 cuadros), ambos a 24 fps.
Los videos se consultaron como referencia visual; no son recursos reproducidos en el juego.

El diseño y los textos salen de [Manada — UI](https://www.figma.com/design/SQEAfczyRvyOHokmzPOee7/Manada---UI?node-id=510-240).
Las capas de Martín están superpuestas al marco como hermanas en la página: texto inicial
`510:245`, `510:251`, `510:256`, despedida `510:261`, rechazos `568:655` y `568:663`.
Tiago usa `510:267`, `510:271`, `510:278`, `510:282`, `510:286` y rechazo `571:678`.
Se conserva el teléfono enmascarado de Figma. Las cantidades siguen Notion y #339: una
Marolini, una Coracola y un Malbardo para Martín; dos Zucarachas y un Pepito para Tiago.
Pura-Cola se normaliza a Coracola por decisión del usuario. El recordatorio reúne el pedido
completo usando el texto «Quiero» de los rechazos; el rechazo conserva «Yo no pedí esto.».
Los productos llevan además negrita, como exige #339.

Los personajes se dibujan detrás de la ventanilla dentro del mundo, también con la interfaz
cerrada. Mantienen posición y orientación fijas hacia el interior del local, sin seguir al
jugador ni girar con su cámara, por decisión del usuario. La profundidad conserva la oclusión.
La interfaz sólo muestra el diálogo de Figma y proyecta el blanco de clic desde el sprite.
