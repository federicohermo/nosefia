# Carga entre noches

Revisión comprobada `5641d9e0b23ef00876fad9cc875ba217d5629687`.
Base observada `e0892649`, que ya contiene `81627377`.

## Resultado

La barra, la fuente y su posición ya coinciden entre las dos presentaciones en la base.
No se reprodujeron el elemento sobrante ni el desplazamiento descritos en el pedido.
La captura original no estaba adjunta a esta conversación.

La diferencia comprobada era el latido en escritorio. Allí los puntos eran caracteres
estáticos. Ahora son tres cuadrados que cambian de escala y opacidad entre noches.
Su tamaño y posición salen de la fuente del texto, y su color sale del tema de la barra.
La carga inicial queda intacta. Su captura nativa de 1280×720 tiene cero píxeles distintos
antes y después. No se modificó ningún `.tscn`.

## Capturas

`antes-0.png` y `antes-1.png` son las dos presentaciones de la base en escritorio a 1280×720.
`web-antes-0.png` y `web-antes-1.png` son la comparación web de la base a esa resolución.
Los archivos `despues-<resolución>-0.png` muestran la inicial en escritorio.
Los terminados en `-1.png` muestran la de entre noches.
Los terminados en `-pulso.png` muestran otro instante del latido nativo.
Los archivos `web-despues-*` siguen la misma numeración.

Se probaron 1280×720, 960×720 y 1440×640 en ambos motores.
Las capturas son de las escenas reales instanciadas en una ejecución aislada.
La inicial cuelga de un Control con tema, como en el menú; la otra cuelga de un Node3D
con CanvasLayer sobre la persiana, como en el almacén. No se recorrieron noches completas.
Se mantiene el mismo progreso de barra para comparar.

En web se midieron tres animaciones activas de 900 ms con desfases de 0, 150 y 300 ms.
La ubicación del conjunto de puntos coincide entre las dos presentaciones en cada resolución.
Después de medirlas activas, se pausaron en 450 ms sólo para tomar capturas comparables.
`medidas-web.json` conserva la lectura previa a esa pausa.

La comparación de máscaras de los colores opacos de barra y texto no tiene diferencias
entre presentaciones en las tres resoluciones web. No compara el fondo ni los bordes
semitransparentes que se mezclan con fondos distintos. `comparacion.json` conserva el resultado.

## Pruebas

El primer commit contiene el test, que falló con `Expecting 3 but was 0` y código 100.
El segundo contiene el arreglo. Pasan los dos casos de la suite, sin errores ni nodos huérfanos.
`test-rojo.log` y `test-final.log` conservan las salidas sin códigos de color.
También pasaron gdformat y gdlint sobre los dos archivos cambiados.

La CI de la revisión terminó aprobada en las seis particiones y en `verify`.
Corrida <https://github.com/federicohermo/nosefia/actions/runs/39855163256>.

## Decisiones

Se conservan el tema y la escena compartidos, que ya definen las medidas.
La web conserva su CSS para que los puntos sigan animados aunque el motor compile shaders.
La animación nativa corre con los cuadros del motor y puede detenerse si éste se bloquea.
Replica duración y desfases del CSS; usa una curva de coseno en lugar del Bézier CSS.
La temporización queda declarada en ambos lados para conservar intacta la referencia web.

Se aplicó Fix Root Causes al no cambiar medidas que ya coincidían.
Model the Domain mantuvo los tres puntos en un Array de ColorRect dentro de PantallaDeCarga.
Test Behavior, Not Implementation guió las aserciones sobre igualdad visual y cambio de opacidad.
Prove It Works llevó a capturar ambos motores y comparar la referencia inicial.

## Repetir la medición

Los scripts adjuntos son instrumentos de esta sesión, no código del juego.
Colocar `medir_carga.gd`, `medir_carga.tscn` y los Python en `build/` del checkout.
El script de preparación conserva las rutas reales de escenas y assets en un proyecto mínimo.
Adaptar la ruta de la plantilla web a la copia aprobada local.
Importar ese proyecto y exportar `Web` a `web/prueba3.html` con el motor aprobado.
`servir_medicion.py` sirve esa carpeta con COOP y COEP en el puerto 8765.
Abrir cada presentación con `?p=0` o `?p=1`.
`capturar_web.py` necesita el ID de una pestaña propia de Orca.
`comparar_capturas.py` lee las capturas desde `build/`.
