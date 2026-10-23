# Barra de carga de J2 a J3

Evidencia real de dos exportaciones web locales, antes y después del arreglo del PR #630.

Base `6ec29f6dd8f100b90097a5f0b1c4aff2643fb89c`. Arreglo `b398fb60e9eb3ee2884a2a66272abba43d73f43c`.

La plantilla de ambas exportaciones pasó `python .github/scripts/preparar_plantilla_web.py --comprobar`. Se copió desde el worktree `build-web-release` indicado en el pedido. No se usó la plantilla oficial sin parche.

| Versión | Navegador | Muestras | Descensos de la estimación | Descensos de la barra |
|---|---|---:|---:|---:|
| antes | chrome 155.0.8059.86 | 174 | 146 | 146 |
| antes | firefox 157.0 | 15 | 0 | 0 |
| despues | chrome 155.0.8059.86 | 146 | 114 | 0 |
| despues | firefox 157.0 | 15 | 0 | 0 |

Cada carpeta contiene capturas PNG del navegador, la consola y `valores.json`. Cada fila de `valores` contiene `[performance.now(), estimación recibida por pintar, ProgressBar.value después de pintar, presentación]`. La presentación entre noches vale 1. El tiempo sólo ordena muestras, no es un benchmark. `retrocesos` contiene las filas cuyo valor visible es menor al anterior.

Chrome reprodujo el defecto. Después del arreglo, la estimación todavía bajó y la barra conservó su máximo. Firefox no reprodujo un descenso en la corrida previa y tampoco lo mostró después. Las cuatro corridas llegaron a J3.

Se usó Playwright con Chrome instalado, sin ventana y con ANGLE D3D11, y Firefox de Playwright sin ventana. Se cerró un navegador antes de abrir el siguiente. Las capturas son del canvas del juego renderizado en cada navegador.

## Reproducción

El controlador temporal `repro_barra.gd.txt` se cargó como autoload desde `src/repro_barra.gd`. `repro_avance.gd.txt` es la copia del helper de tests que termina las instrucciones iniciales. No se modificó ningún `.tscn`. El controlador escribe un guardado separado de J2, usa la entrada real del menú, completa las tareas y adelanta el reloj al cierre. La transición, sus útiles, la persiana y la compilación usan el código real del juego.

La única instrumentación en `PantallaDeCarga.pintar`, después de asignar la barra, fue:

```gdscript
if _en_la_web:
	JavaScriptBridge.eval("(window.__barra ??= []).push([performance.now(), %s, %s, %d])" % [progreso, _barra.value, presentacion])
```

`medir.mjs` espera J2, pide el cierre y captura la transición y J3. Se ejecutó desde `reports/barra` con `node reports/barra/medir.mjs antes chrome 8071`, luego Firefox, y después con `despues` en el puerto 8072. El servidor fue `.github/scripts/servir_export.py`. El import de Playwright del script corresponde a esa ubicación local.

Los controladores, la instrumentación y la modificación temporal del autoload se retiraron del árbol de código antes del commit del arreglo. Estas copias sólo documentan la reproducción.

## Tests

`rojo.log` conserva el fallo de monotonía antes del arreglo. `verde.log` conserva los cuatro casos de pantalla aprobados. `menu.log` conserva las dos suites puntuales del menú, 23 casos aprobados. No se ejecutó el árbol entero ni `verificar.py` localmente.

El aviso de `ObjectDB` al cerrar las suites del menú también aparece en la base. Una comparación con salida detallada registró 86 RefCounted en la base y 83 en el arreglo. Ambos recorridos terminaron con código 0, sin errores de script ni nodos huérfanos contados por gdUnit4. Las consolas web conservan también los avisos WebGL de la build, presentes antes y después.

`decision.md` documenta la elección del estado visible como única fuente de progreso. No hay decisiones provisorias de diseño.
