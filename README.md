# Barra de carga de J2 a J3

Evidencia real de dos exportaciones web locales, antes y despu?s del arreglo del PR #630.

Base `6ec29f6dd8f100b90097a5f0b1c4aff2643fb89c`. Arreglo `b398fb60e9eb3ee2884a2a66272abba43d73f43c`.

La plantilla de ambas exportaciones pas? `python .github/scripts/preparar_plantilla_web.py --comprobar`. Se copi? desde el worktree `build-web-release` indicado en el pedido. No se us? la plantilla oficial sin parche.

| Versi?n | Navegador | Muestras | Descensos de la estimaci?n | Descensos de la barra |
|---|---|---:|---:|---:|
| antes | chrome 155.0.8059.86 | 174 | 146 | 146 |
| antes | firefox 157.0 | 15 | 0 | 0 |
| despues | chrome 155.0.8059.86 | 146 | 114 | 0 |
| despues | firefox 157.0 | 15 | 0 | 0 |

Cada carpeta contiene capturas PNG del navegador, la consola y `valores.json`. Cada fila de `valores` contiene `[performance.now(), estimaci?n recibida por pintar, ProgressBar.value despu?s de pintar, presentaci?n]`. La presentaci?n entre noches vale 1. El tiempo s?lo ordena muestras, no es un benchmark. `retrocesos` contiene las filas cuyo valor visible es menor al anterior.

Chrome reprodujo el defecto. Despu?s del arreglo, la estimaci?n todav?a baj? y la barra conserv? su m?ximo. Firefox no reprodujo un descenso en la corrida previa y tampoco lo mostr? despu?s. Las cuatro corridas llegaron a J3.

Se us? Playwright con Chrome instalado, sin ventana y con ANGLE D3D11, y Firefox de Playwright sin ventana. Se cerr? un navegador antes de abrir el siguiente. Las capturas son del canvas del juego renderizado en cada navegador.

## Reproducci?n

El controlador temporal `repro_barra.gd.txt` se carg? como autoload desde `src/repro_barra.gd`. `repro_avance.gd.txt` es la copia del helper de tests que termina las instrucciones iniciales. No se modific? ning?n `.tscn`. El controlador escribe un guardado separado de J2, usa la entrada real del men?, completa las tareas y adelanta el reloj al cierre. La transici?n, sus ?tiles, la persiana y la compilaci?n usan el c?digo real del juego.

La ?nica instrumentaci?n en `PantallaDeCarga.pintar`, despu?s de asignar la barra, fue:

```gdscript
if _en_la_web:
	JavaScriptBridge.eval("(window.__barra ??= []).push([performance.now(), %s, %s, %d])" % [progreso, _barra.value, presentacion])
```

`medir.mjs` espera J2, pide el cierre y captura la transici?n y J3. Se ejecut? desde `reports/barra` con `node reports/barra/medir.mjs antes chrome 8071`, luego Firefox, y despu?s con `despues` en el puerto 8072. El servidor fue `.github/scripts/servir_export.py`. El import de Playwright del script corresponde a esa ubicaci?n local.

Los controladores, la instrumentaci?n y la modificaci?n temporal del autoload se retiraron del ?rbol de c?digo antes del commit del arreglo. Estas copias s?lo documentan la reproducci?n.

## Tests

`rojo.log` conserva el fallo de monoton?a antes del arreglo. `verde.log` conserva los cuatro casos de pantalla aprobados. `menu.log` conserva las dos suites puntuales del men?, 23 casos aprobados. No se ejecut? el ?rbol entero ni `verificar.py` localmente.

El aviso de `ObjectDB` al cerrar las suites del men? tambi?n aparece en la base. Una comparaci?n con salida detallada registr? 86 RefCounted en la base y 83 en el arreglo. Ambos recorridos terminaron con c?digo 0, sin errores de script ni nodos hu?rfanos contados por gdUnit4. Las consolas web conservan tambi?n los avisos WebGL de la build, presentes antes y despu?s.

`decision.md` documenta la elecci?n del estado visible como ?nica fuente de progreso. No hay decisiones provisorias de dise?o.
