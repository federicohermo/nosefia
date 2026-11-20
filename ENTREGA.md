# Entrega I. Hoja de entrada al baño

- Rama. `improvement/hoja-del-bano`
- Commit del arreglo. `827b4252c9e1dea6b3c6748906d83851de654518`

## Qué causaba las franjas y las diagonales

Se comprobaron dos causas sobre `puerta2-col` (`Hoja del baño con panel integrado.001`) en `assets/models/SEPT_JUEGOS_PROTOTIPO.blend`, en `assets/models/SEPT_JUEGOS_PROTOTIPO.glb` y en la build web.

1. **Panel central hundido con cuatro trapecios inclinados por cara.** `renovar_bano.py` construyó cada cara grande con el perímetro en `y = ±0.0375` y el panel central en `y = ±0.0285` (tras el escalado del local, `±0.034277` y `±0.026050`, un hundimiento de `8.23 mm`). Los cuatro trapecios que unen borde y panel quedaron inclinados `2.41°` abajo, `2.71°` arriba y `4.29°` a los costados (`(±0.0748, ±0.9972, 0)`, `(0, ±0.9991, +0.0420)` y `(0, ±0.9989, -0.0473)`). Cada trapecio recibía la luz con otro ángulo y dibujaba franjas y diagonales en las esquinas.
2. **Costura de material y tramado S3TC en la cara exterior (`-Y`).** Aún con los vértices llevados al mismo plano (`0.0°` de desviación), en la primera verificación web siguió visible un marco rectangular. Los cuatro trapecios usaban `bano_entrada_blanca` sin textura (`sRGB (239, 239, 234)`), mientras el panel central usaba `bano_rejilla_texturizada` (`SEPT_JUEGOS_PROTOTIPO_rejilla_bano.png` con `compress/mode=2`, DXT1/BC1). La compresión RGB565 tramaba el fondo plano en `(239, 239, 230)`, `(244, 242, 236)`, `(241, 240, 233)` y `(247, 243, 239)`, aclarando el panel interior y marcando el borde con `Closest`.

## Qué cambió

- `.claude/scripts/lib/hoja_del_bano.py` y `.agents/scripts/lib/hoja_del_bano.py`. Lógica pura para identificar el plano exterior de cada lado, ordenar las cuatro esquinas exteriores, extrapolar las UV del panel en forma afín y medir la desviación angular de las caras grandes.
- `.claude/scripts/blender/aplanar_hoja_del_bano.py` y `.agents/scripts/blender/aplanar_hoja_del_bano.py`. Script de Blender idempotente sobre `puerta2-col`. Reemplaza los cinco cuadriláteros de cada cara grande por un único cuadrilátero plano sobre el perímetro exterior (pasa de `32` vértices y `26` caras a `24` vértices y `18` caras, desviación de `4.2897°` a `0.0°`). La cara exterior (`-Y`) usa `bano_rejilla_texturizada` con `extension = 'EXTEND'` (`CLAMP_TO_EDGE`) y UV extrapoladas linealmente desde el panel original para mantener las cuatro ranuras en su posición física exacta. La cara interior (`+Y`) usa `bano_entrada_blanca`. Conserva intactos los cuatro cantos, las dos manijas, la matriz, el pivote, las dimensiones, el encuentro con `bano_marco_entrada` y los `832` vecinos del `.blend`. En la segunda corrida reporta `ya_plana: true`, `caras_eliminadas: 0` y `vertices_eliminados: 0`.
- `assets/models/SEPT_JUEGOS_PROTOTIPO_rejilla_bano.png.import`. Cambia `compress/mode=2` a `compress/mode=0` (sin pérdida) para eliminar el tramado RGB565 de la cara exterior sin tocar `assets/source/`.
- `assets/models/SEPT_JUEGOS_PROTOTIPO.blend`, `assets/models/SEPT_JUEGOS_PROTOTIPO.glb` y `assets/models/SEPT_JUEGOS_PROTOTIPO.glb.fuente`. Modelo reexportado con `.claude/scripts/exportar_modelo.py` y reimportado tras borrar la caché del `.glb`.
- `.claude/scripts/tests/test_hoja_del_bano.py` y `.agents/scripts/tests/test_hoja_del_bano.py`. Cuatro tests unitarios sobre la construcción plana, la extrapolación UV y el cálculo de desviación angular.
- `test/escenas/objetos/hoja_del_bano_test.gd`. Test de comportamiento sobre `puerta2` en `SEPT_JUEGOS_PROTOTIPO.glb`. Verifica que ambas caras grandes son coplanares, sin inclinación y de un solo material. Falló antes del arreglo (`8` triángulos inclinados y rango `Z = 0.00823 m` por cara) y pasa después.

No se tocaron `src/escenas/almacen.exr`, `src/escenas/almacen.lmbake`, `project.godot`, `.github/performance/topes-de-carga.json`, `addons/hornear/` ni la malla o las UV de Arvecor. `puerta2` usa `gi_mode = 2` (GI dinámico) y no entra en el horneado.

## Auditoría 3D y comparación del `.glb`

- `audit_mesh.py` sobre `puerta2-col` y `bano_marco_entrada` (`C:/Users/fede_/.cache/nosefia/hoja-bano-audit-antes.json` y `C:/Users/fede_/.cache/nosefia/hoja-bano-audit-despues.json`). Cero fallas (`failures: []`), `world_bounds` y `transform` idénticos en ambos objetos, `bano_marco_entrada` sin cambios (`32` vértices, `30` caras) y `puerta2-col` cerrada y con UV válidas (`24` vértices, `18` caras).
- Cierre y barrido de `0°` a `90°` comprobados en `aplanar_hoja_del_bano.py`. `rayos_sin_bloqueo: 0`, `holgura_minima_mm: 5.223`, `intersecciones_en_barrido: 0`.
- Comparación de las `209` mallas y `101` imágenes de `SEPT_JUEGOS_PROTOTIPO.glb` contra la base (`HEAD`).
  - `Hoja del baño con panel integrado.001`. Única malla con cambio real (`bano_entrada_blanca` pasa de `52` a `20` vértices; `bano_rejilla_texturizada` conserva `4` vértices cubriendo toda la cara `-Y`; `bano_acero` idéntico).
  - `bano_lavatorio_2-convcol porcelana.001` y `vanitory-convcol porcelana.001`. Diferencia máxima de `1.192e-07` (`1 ULP` de `float32`) sólo en `TEXCOORD_0` por redondeo del exportador glTF de Blender, sin cambios de vértices ni normales.
  - Las otras `206` mallas y las `101` imágenes embebidas son idénticas byte a byte.

## Mediciones en web

- **Programas de shader.** Medidos con `node C:/Users/fede_/.cache/nosefia/medir_con_firmas.mjs http://127.0.0.1:<puerto>/ <json> --sin-ventana --software --corridas=1 --sin-enlace-en-paralelo`.
  - Antes (`C:/Users/fede_/.cache/nosefia/hoja-bano-programas-antes.json`). `97` programas, `84` fuentes distintas.
  - Después (`C:/Users/fede_/.cache/nosefia/hoja-bano-programas-despues.json`). `97` programas, `84` fuentes distintas (tope `98`).
- **Tamaño del export web.** Verificado con `python .claude/scripts/verificar_export.py`.
  - Antes (`export/web-antes`). `138.7 MB` (`9` archivos).
  - Después (`export/web-despues`). `138.7 MB` (`9` archivos, tope `150 MiB`, salida `0`).

## Capturas web (antes y después)

Carpeta `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/`.

- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/antes-cerrada-frente.png`
- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/despues-cerrada-frente.png`
- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/antes-cerrada-cerca.png`
- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/despues-cerrada-cerca.png`
- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/antes-abierta-umbral.png`
- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/despues-abierta-umbral.png`
- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/antes-abierta-cara-exterior.png`
- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/despues-abierta-cara-exterior.png`
- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/antes-abierta-desde-abajo.png`
- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/despues-abierta-desde-abajo.png`
- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/antes-abierta-rejilla.png`
- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/despues-abierta-rejilla.png`
- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/antes-abierta-esquina-superior.png`
- `C:/Users/fede_/.cache/nosefia/capturas-hoja-bano/despues-abierta-esquina-superior.png`

## Verificación automática

- `gdformat --check test/escenas/objetos/hoja_del_bano_test.gd` y `gdlint test/escenas/objetos/hoja_del_bano_test.gd`. Sin errores.
- `test/escenas/objetos/hoja_del_bano_test.gd`. `1/1 PASSED`.
- `test/escenas/objetos/rejilla_del_bano_test.gd`. `1/1 PASSED`.
- `test/escenas/puestos/bano_publico_test.gd`. `18/18 PASSED`.
- `test/escenas/puestos/puerta_del_local_test.gd`. `20/20 PASSED`.
- `test/escenas/modelo_exportado_test.gd`. `4/4 PASSED`.
- `test/escenas/etiqueta_de_arvecor_test.gd`. `3/3 PASSED`.
- `.claude/scripts/tests/test_hoja_del_bano.py`. `4/4 OK`.
- `.claude/scripts/tests/test_rejilla_bano.py`. `2/2 OK`.
- `.claude/scripts/tests/test_copias_de_skills.py`. `4/4 OK`.
- `.claude/scripts/tests/test_modelo_actualizado.py`. `6/6 OK`.
- `.claude/scripts/tests/test_atlas_al_dia.py`. `6/6 OK`.
- `.claude/scripts/tests/test_texturas_del_modelo.py`. `9/9 OK`.
