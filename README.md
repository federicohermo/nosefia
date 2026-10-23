# Cami en la ventanilla

Capturas de Chrome 155.0.8059.86 y Firefox 157.0, ejecutados de a uno.
Se revisaron las imágenes de conversación y de los lados.
Los dos navegadores pasan 17 estados con cero errores de página.
Los JSON y las consolas completos están en sus carpetas.

| Estado | Chrome | Firefox |
|---|---|---|
| Frente y foco | [Abrir](chrome/front.png) | [Abrir](firefox/front.png) |
| Lado izquierdo | [Abrir](chrome/left.png) | [Abrir](firefox/left.png) |
| Lado derecho | [Abrir](chrome/right.png) | [Abrir](firefox/right.png) |
| Conversación | [Abrir](chrome/talk.png) | [Abrir](firefox/talk.png) |
| Vuelta al mundo | [Abrir](chrome/world.png) | [Abrir](firefox/world.png) |
| Alfa transparente sin foco | [Abrir](chrome/transparent.png) | [Abrir](firefox/transparent.png) |
| Cambio a Fede | [Abrir](chrome/fede.png) | [Abrir](firefox/fede.png) |
| Reinicio con Cami | [Abrir](chrome/reset.png) | [Abrir](firefox/reset.png) |

Cada carpeta conserva además `frame0.png` a `frame7.png`.
Las aserciones comprueban los ocho recursos, sus dimensiones, foco y contorno del cuadro actual,
visibilidad en la conversación y en el mundo, y reinicio sin retiradas sobrantes.

## Paquete y precarga

La base es `6ec29f6dd8f100b90097a5f0b1c4aff2643fb89c`.
El export final corresponde a `4caefdaf54710b517a20a1e88c284da84b2a861e`.
Ambos usan el preset Web del repo y la misma plantilla vigente.
`python .github/scripts/preparar_plantilla_web.py --comprobar` termina en cero.
El SHA-256 de la plantilla es `eb4bb1df03b0d38c06e325b307c44404878453295cf4f543bfb0e6cb52d29d20`.

| Magnitud | Base | Con Cami | Diferencia |
|---|---:|---:|---:|
| PCK, bytes | 97.499.488 | 98.169.268 | +669.780 |
| Cuadros leídos al precargar J1 | 32 | 40 | +8 |
| Imágenes RGBA de Cami, tamaño lógico calculado | 0 | 50.320.896 bytes | +47,99 MiB |

Los ocho `.ctex` de Cami suman 664.686 bytes dentro del PCK.
`paquetes.json` registra el tamaño y SHA-256 de cada paquete y el inventario completo.
`paquete.py` verifica MD5 y tamaño de cada entrada del paquete y resuelve cada import de Cami
a su textura incluida. También comprueba el remapeo del idle.
El cálculo RGBA usa ocho imágenes de 1086 × 1448 × 4 bytes.
No representa VRAM física ni memoria total del proceso.

Se hicieron cinco corridas por lado, alternadas, con contextos HTTP nuevos y Chrome con GPU.
El renderer informado fue ANGLE sobre NVIDIA GeForce RTX 4050 con Direct3D 11.
`precarga-web.json` contiene cada llamada a `readPixels`, sus dimensiones y su duración.
Todas las corridas terminaron sin errores de página o de consola.
Las últimas ocho lecturas corresponden a Cami por el orden de `ANIMACIONES`
y el recorrido de `precargar` sobre sus valores.

| Medida | Mediana | Rango |
|---|---:|---:|
| Ocho lecturas de Cami | 77,8 ms | 38,0 a 79,0 ms |
| Todas las lecturas de la base | 305,6 ms | 151,5 a 316,9 ms |
| Todas las lecturas con Cami | 388,2 ms | 375,0 a 404,8 ms |
| Clic a almacén, base | 5.851 ms | 5.381 a 17.397 ms |
| Clic a almacén, con Cami | 6.436 ms | 5.870 a 9.423 ms |

Las lecturas son sincrónicas con la GPU y ocurren dentro de la precarga de alfa.
El costo medido de esas ocho llamadas no incluye toda la descompresión ni la carga del almacén.
La variación de la carga completa impide atribuirle a Cami la diferencia de sus medianas.
No hay un umbral de aceptación para estos tiempos.
Se conserva la precarga inmediata que usa el soporte actual.

## Cómo se obtuvieron las capturas

El paquete productivo conserva su agenda y excluye los tests.
Para capturar a Cami se creó otra copia del PCK con un autoload de prueba y los tres scripts
del fixture. `paquete.py` hace esa copia sin modificar escenas ni scripts productivos.
`capture_driver.gd` ejecuta el mismo fixture que las pruebas sobre el almacén real.
El texto que se ve pertenece al fixture y no agrega un guion de Cami al juego.
`capturar.cjs` ejecuta y afirma los estados antes de guardar los PNG.

La primera corrida de Firefox con ventana pasó los estados pero registró
`WrongDocumentError` al pedir captura del puntero con el documento oculto.
Se repitió sin ventana. La corrida final terminó en cero y su JSON conserva el renderer
de ANGLE que Firefox informa con datos de GPU reducidos.
La evidencia final procede de esa repetición.

Los exports se sirvieron con `.github/scripts/servir_export.py`, con los headers del repo.
Para repetir, exportar base y cambio como `export/base/index.html` y `export/cami/index.html`,
copiar las herramientas de esta rama de capturas a `reports/cami-631/` y ejecutar:

```powershell
python reports/cami-631/paquete.py
python .github/scripts/servir_export.py export 8631
node reports/cami-631/medir-precarga.cjs base cami base cami base cami base cami base cami
node reports/cami-631/capturar.cjs chrome
node reports/cami-631/capturar.cjs firefox
```

El servidor queda en otra terminal. Se requiere Playwright y sus navegadores.
No se ejecutan ambos navegadores a la vez.

## Arte y pruebas

La copia inicial verificó bytes, RGBA8, 1086 × 1448, CRC de todos los chunks y SHA-256
contra cada blob de la revisión fijada. `originales.json` conserva la medición.
El documento versionado `assets/characters/cami_origen.md` registra la procedencia.
La limpieza compartida eliminó alfa residual en 114.845 píxeles de ocho PNG.
Conservó dimensiones y todos los canales RGB.
Una segunda aplicación revisó 40 PNG con cero residuos y hashes de Cami idénticos.
El informe sin aplicar también terminó con cero residuos.

El rojo por recurso ausente y el rojo por falta de entrada del enum están en sus logs.
La corrida de las tres suites pasó 22 casos y la final de Cami pasó ocho,
sin errores, fallos, salteos ni huérfanos.
La corrida final cubre los ocho cuadros y el cambio Cami a Fede y de vuelta a Cami.
Pasaron gdformat y gdlint de los cinco scripts afectados.
No se corrió verificar.py ni el árbol completo local.

Model the Domain mantuvo la identidad en el enum y el recurso en la tabla existente.
Test Behavior, Not Implementation llevó las aserciones al flujo de atención, foco y pausa.
Prove It Works llevó la comprobación al PCK y a capturas del juego en ambos navegadores.
