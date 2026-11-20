# Entrega H (ronda 2). Nitidez de la etiqueta de Arvecor

- Rama. `improvement/textura-de-arvecor`
- Base de esta ronda. `9a755fbd` (ronda 1: `3ce88292`)

## Qué causaba lo borroso

El problema no era falta de espacio en el atlas ni densidad de texeles.

- **Resolución en origen y en atlas.** Tanto `assets/source/products-textured/Arvejas/arvecor.png` como `assets/source/products-textured/Cora cola/cora cola.png` miden `1254 × 1254` en origen y ocupan celdas idénticas de `512 × 512` en `etiquetas_bc1.png` (`3264 × 3456`). Arvecor está en `(1104, 1072)` y Pura Cola en `(1648, 1072)`.
- **Densidad de texeles en la pared cilíndrica.** Medida sobre `SEPT_JUEGOS_PROTOTIPO.glb`, la pared de Arvecor (`Cylinder.001`, circunferencia `47,13 cm`, alto `15,45 cm`, área `727,1 cm²`) cubre `489,5 × 241,9 px` (`10,39 px/cm` horizontal, `15,65 px/cm` vertical, `12,76 px/cm` media geométrica). La pared de Pura Cola (`Cylinder.008`, circunferencia `35,35 cm`, alto `22,83 cm`, área `807,3 cm²`) cubre `500,9 × 288,9 px` (`14,17 px/cm` horizontal, `12,65 px/cm` vertical, `13,37 px/cm` media geométrica). La densidad general difiere apenas un `4,5 %`, y en vertical Arvecor tiene más texeles por centímetro que Pura Cola.
- **Causa raíz en la imagen fuente.** En `cora cola.png`, toda la tipografía y el logotipo `Pura Cola` están dibujados a resolución nativa `1254 × 1254`. En `arvecor.png`, los textos chicos (`ARVEJAS SECAS REMOJADAS`, `LIBRE DE GLUTEN`, `SIN TACC`, `INFORMACIÓN NUTRICIONAL`, `El sabor de nuestra tierra`, `CALIDAD ARGENTINA` y el código de barras) ya estaban a resolución nativa `1254 × 1254` y salían nítidos en web, pero el arte principal del frente (`ARVECOR`, el óvalo azul y amarillo, el arco dorado interior, `Arvejas`, `SECAS`, el título lateral `ARVEJAS SECAS`, el arco verde claro, los bordes plateados y las tapas) venía rasterizado sobre una grilla gruesa de bloques de `7` a `8 px` en el PNG de `1254 × 1254`. Al reducir `1254 → 512` en `armar_atlas.py` y comprimir a BC1 en Godot, esos escalones de `~3 px` quedaban dentados y borrosos al lado de Pura Cola.

No hizo falta ampliar la celda del atlas ni tocar mallas, UV o materiales.

## Qué cambió

- `assets/source/products-textured/Arvejas/arvecor.png`. Se reconstruyó en `1254 × 1254` RGB (mismas dimensiones y formato sin alfa) con render vectorial sobremuestreado a `3×` y reducción Lanczos para el óvalo azul y amarillo (aro de `10,5 px` en origen, `~4,3 px` en el atlas, limpio para bloques BC1 `4 × 4`), el arco dorado, el logotipo `ARVECOR` (conservando la `A` alta con el trazo dorado), el título `Arvejas`, el subtítulo `SECAS` con sus barras doradas, el encabezado lateral `ARVEJAS SECAS`, el arco verde claro, el fondo verde cilíndrico, los bordes plateados superior e inferior y las tapas metálicas. Se conservaron intactos los textos nativos nítidos (`INFORMACIÓN NUTRICIONAL`, `PESO NETO`, código de barras, `ARVEJAS SECAS REMOJADAS`, `LIBRE DE GLUTEN`, `SIN TACC`, `LO BUENO DE TODOS LOS DÍAS`, `INDUSTRIA ARGENTINA`, `El sabor de nuestra tierra` y el sello `CALIDAD ARGENTINA`) y se suavizó el escalonado del cuenco de arvejas preservando su estilo ilustrado.
- `assets/source/atlas/etiquetas_bc1.png` y `assets/source/atlas/atlas.json`. Regenerados con `python .claude/scripts/armar_atlas.py`. Todas las celdas conservan sus coordenadas y tamaños exactos. Fuera de la celda con borde de Arvecor (`x = 1088..1631`, `y = 1056..1599`) cambiaron `0` píxeles.
- `assets/models/SEPT_JUEGOS_PROTOTIPO.glb`, `assets/models/SEPT_JUEGOS_PROTOTIPO_etiquetas_bc1.png` y `assets/models/SEPT_JUEGOS_PROTOTIPO_etiquetas_bc1.png.import`. Regenerados con `python .claude/scripts/exportar_modelo.py` (borrado de caché de `.godot/imported/` y `--import`) y `assets/models/extraer_mallas.gd`. En el `.glb`, nodos, mallas y materiales son idénticos a `9a755fbd` y sólo cambió `etiquetas_bc1` entre las `101` imágenes embebidas. Ningún `producto_*.res` cambió.

## Mediciones en web

- **Programas de shader.** Medidos con `node C:/Users/fede_/.cache/nosefia/medir_con_firmas.mjs http://127.0.0.1:8187/ C:/Users/fede_/.cache/nosefia/arvecor-ronda2-programas.json --sin-ventana --software --corridas=1 --sin-enlace-en-paralelo`.
  - Antes (`9a755fbd`). `97` programas, `84` fuentes distintas.
  - Después (`export/web-ronda2`). `97` programas, `84` fuentes distintas (tope `98`).
- **Tamaño del export web.** Verificado con `python .claude/scripts/verificar_export.py export/web-ronda2`.
  - Antes (`export/web-despues`). `138.7 MB`.
  - Después (`export/web-ronda2`). `138.7 MB` (tope `150 MiB`, salida `0`).

## Comparación de otras etiquetas en la misma pose

- En `etiquetas_bc1.png`, los píxeles fuera de la celda con borde de Arvecor tienen `0` diferencias.
- En las capturas web antes y después con exactamente la misma pose y cámara (`frente`, `cerca`, `izq`, `der`, `dorso` y `gondola`):
  - Cuerpo de Pura Cola en `frente`, `cerca`, `izq`, `der` y `dorso`. `max_diff = 1`, `0.00%` de píxeles con diferencia mayor a 2.
  - Don Saturados, Zucarachas y Marolini en góndola (`frente` y `gondola`). `max_diff = 1`, `0.00%` de píxeles con diferencia mayor a 2.

## Capturas web (antes y después)

Carpeta `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/`.

- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/antes-frente.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/despues-frente.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/antes-cerca.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/despues-cerca.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/antes-izq.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/despues-izq.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/antes-der.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/despues-der.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/antes-dorso.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/despues-dorso.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/antes-hombro.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/despues-hombro.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/antes-gondola.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor-ronda2/despues-gondola.png`

## Verificación automática

- `.claude/scripts/tests/test_atlas_al_dia.py`. `6/6 OK`.
- `.claude/scripts/tests/test_modelo_actualizado.py`. `OK`.
- `.claude/scripts/tests/test_texturas_del_modelo.py`. `9/9 OK`.
- `.claude/scripts/tests/test_uv_de_arvecor.py`. `6/6 OK`.
- `.claude/scripts/tests/test_copias_de_skills.py`. `4/4 OK`.
- `test/escenas/etiqueta_de_arvecor_test.gd`. `3/3 PASSED`.
- `test/escenas/modelo_exportado_test.gd`. `4/4 PASSED`.
