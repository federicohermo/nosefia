# Entrega H. Textura de Arvecor

- Rama. `improvement/textura-de-arvecor`
- Commit del arreglo. `3ce882920f00361c9c2b5f2ba3526e1ee2bd3caa`

## Qué causaba los cortes

La imagen fuente `assets/source/products-textured/Arvejas/arvecor.png` y el atlas `etiquetas_bc1.png` estaban sanos. El script histórico `corregir_uv_de_las_bebidas.py` sólo tocaba Fernet y Progres, no Pura Cola ni Arvecor. Los cortes de Arvecor venían de tres defectos en la malla `Cylinder.001` (`producto_arvejas.res`).

1. **Corte de material en la franja superior de la etiqueta.** La pared cilíndrica de Arvecor tiene dos bandas verticales de caras (`33..64` abajo y `98..129` arriba, unidas en `z = 0.0802`). El script `ajustar_brillo.py` asignó `arvejas_acero` (`Metallic = 0.55`, `Roughness = 0.30`) al rango `65..193` e incluyó la banda `98..129` por error. En WebGL2 Compatibility ese cambio de material oscurecía y daba reflejo metálico a la parte alta de la etiqueta y del óvalo ARVECOR, generando la línea horizontal y los cortes en ambos laterales hasta el hombro.
2. **Dos caras con UV desplazadas en la banda superior.** Las caras `101` y `102` (sobre `36` y `37`, en el tramo `U = 0.717..0.768`) tenían `U = 0.023..0.082`, desplazadas hacia el borde izquierdo de la etiqueta.
3. **UV degeneradas sobre píxeles negros en el borde metálico superior.** Las 32 caras del cuello (`97` y `130..160`) tenían la misma UV en sus vértices inferiores y superiores (área cero) sobre el borde negro exterior de la tapa, produciendo una mancha negra en la parte trasera del borde plateado. Además, la cara `95` del hombro bajaba hasta `U = 0.0131`, invadiendo el margen izquierdo negro del recorte.

## Qué cambió

- `.claude/scripts/lib/uv_de_arvecor.py` y `.agents/scripts/lib/uv_de_arvecor.py`. Lógica pura para identificar la pared cilíndrica, alinear en `U` y `V` la banda superior contra la inferior sin saltos en la arista compartida y desplegar el hombro y el cuello sobre la franja plateada limpia (`U = 0.020..0.979`, `V = 0.520..0.542`).
- `.claude/scripts/blender/corregir_uv_de_arvecor.py` y `.agents/scripts/blender/corregir_uv_de_arvecor.py`. Script de Blender idempotente que reasigna toda la pared cilíndrica de `Cylinder.001` a `Material.001`, alinea las 32 caras de la banda superior y corrige las 64 caras del hombro y el cuello. En una segunda corrida sobre el mismo `.blend` reporta `caras_de_etiqueta_reasignadas: 0` y no introduce cambios.
- `.claude/scripts/blender/ajustar_brillo.py` y `.agents/scripts/blender/ajustar_brillo.py`. Se excluyen los polígonos `98..129` del conjunto de `arvejas_acero`.
- `.claude/scripts/tests/test_uv_de_arvecor.py` y `.agents/scripts/tests/test_uv_de_arvecor.py`. Seis tests unitarios de la transformación de UV y su idempotencia.
- `test/escenas/etiqueta_de_arvecor_test.gd`. Tres invariantes de comportamiento sobre `assets/models/producto_arvejas.res` (una sola superficie en la pared cilíndrica, sin saltos de UV en aristas horizontales compartidas y sin triángulos degenerados en el cuello). Fallaron los tres antes del arreglo y pasan los tres después.
- `assets/models/SEPT_JUEGOS_PROTOTIPO.blend`, `assets/models/SEPT_JUEGOS_PROTOTIPO.glb`, `assets/models/SEPT_JUEGOS_PROTOTIPO.glb.fuente`, `assets/models/SEPT_JUEGOS_PROTOTIPO.glb.unwrap_cache` y `assets/models/producto_*.res`. Modelo reexportado con `.claude/scripts/exportar_modelo.py` y mallas regeneradas con `.claude/scripts/extraer_mallas.gd`. En el `.glb`, `Cylinder.001` es la única malla de producto que cambió; el resto de los productos y las 101 imágenes embebidas quedaron idénticos byte a byte.

No se tocaron `almacen.exr`, `almacen.lmbake`, `project.godot`, `topes-de-carga.json`, `addons/hornear/` ni `oclusion_de_contacto*`.

## Mediciones en web

- **Programas de shader.** Medidos con `node C:/Users/fede_/.cache/nosefia/medir_con_firmas.mjs http://127.0.0.1:8187/ <json> --sin-ventana --software --corridas=1 --sin-enlace-en-paralelo`.
  - Antes (`C:/Users/fede_/.cache/nosefia/arvecor-programas-antes.json`). `97` programas, `84` fuentes distintas.
  - Después (`C:/Users/fede_/.cache/nosefia/arvecor-programas-despues.json`). `97` programas, `84` fuentes distintas (tope `98`).
- **Tamaño del export web.** Verificado con `python .claude/scripts/verificar_export.py export/web-despues`.
  - Antes (`export/web-antes`). `138.7 MB`.
  - Después (`export/web-despues`). `138.7 MB` (tope `150 MiB`, salida `0`).

## Comparación de otras latas

- En `SEPT_JUEGOS_PROTOTIPO.glb`, las mallas, materiales e imágenes de Pura Cola (`Cylinder.008`), Marranos (`Cylinder.009`), Progres y el resto de los productos son idénticos byte a byte respecto de la base.
- En la comparación de píxeles en la misma pose (`mano-frente`), Pura Cola al lado de Arvecor tiene `max_diff = 1` (`0.00%` de píxeles con diferencia mayor a 2) y la mitad inferior de Arvecor tiene `max_diff = 1` (`0.00%` mayor a 2). Los únicos píxeles modificados en toda la escena están en la franja superior y el borde plateado de Arvecor (en mano y en góndola).
- En `otras-latas`, Pura Cola y el fondo de góndola tienen `max_diff = 1` (`0.00%` mayor a 2). Marranos y Progres muestran una diferencia uniforme de `-2` a `-5` niveles de brillo (`0.00%` mayor a 5, sin cambio de silueta ni textura) por la interpolación temporal de sondas de `LightmapGI` al mover esas dos muestras por primera vez en el último cuadro de la corrida.

## Capturas web (antes y después)

Carpeta `C:/Users/fede_/.cache/nosefia/capturas-arvecor/`.

- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/antes-mano-frente.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/despues-mano-frente.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/antes-mano-girada-izq.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/despues-mano-girada-izq.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/antes-mano-girada-der.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/despues-mano-girada-der.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/antes-mano-girada-dorso.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/despues-mano-girada-dorso.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/antes-mano-hombro.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/despues-mano-hombro.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/antes-gondola.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/despues-gondola.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/antes-otras-latas.png`
- `C:/Users/fede_/.cache/nosefia/capturas-arvecor/despues-otras-latas.png`

## Verificación automática

- `gdformat --check test/escenas/etiqueta_de_arvecor_test.gd` y `gdlint test/escenas/etiqueta_de_arvecor_test.gd`. Sin errores.
- `test/escenas/etiqueta_de_arvecor_test.gd`. `3/3 PASSED`.
- `test/escenas/modelo_exportado_test.gd`. `4/4 PASSED`.
- `.claude/scripts/tests/test_uv_de_arvecor.py`. `6/6 OK`.
- `.claude/scripts/tests/test_copias_de_skills.py`. `4/4 OK`.
- `.claude/scripts/tests/test_modelo_actualizado.py`. `6/6 OK`.
- `.claude/scripts/tests/test_atlas_al_dia.py`. `6/6 OK`.
- `.claude/scripts/tests/test_texturas_del_modelo.py`. `9/9 OK`.
