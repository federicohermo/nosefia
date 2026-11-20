# Entrega K. Bloques del cuartito de limpieza

- Rama. `improvement/bloques-del-cuartito` (desde `origin/improvement/mejorar-texturas-del-local`, sin PR).
- Commit de geometría, UV, pipeline y tests. `c5a1f74f`.
- Commit de consulta previa al horneado. `52d21e66`.
- Commit del horneado único y de corte de luz. `73091a76`.
- Estado. Horneado único aplicado, oclusión horneada verificada, capturas web repetidas y mediciones finales dentro de los topes.

## Qué causaba cada corte

1. **Línea vertical sobre las esquinas superiores del marco (`22.png`, `antes-jamba-esq-izq.png` y `antes-jamba-esq-der.png`).** `cuartito_revestimiento` tenía tres cuadriláteros desconectados con `12` vértices sin soldar y dos uniones en T en `(8.083, 13.14, 2.722)` y `(8.083, 14.78, 2.722)`. Sus UV de color ya eran continuas. Al importar con `light_baking = 2`, xatlas separó los tres cuadriláteros en tres islas UV2 distintas y giradas (`[0.386..0.614]`, `[0.023..0.250]` y `[0.750..0.977]`). El mapa de luz horneado y la oclusión dejaron distinto brillo a cada lado de `y = 13.14` y `y = 14.78` sobre el dintel, partiendo las dos hiladas superiores sin junta.
2. **Jambas y cuatro rincones interiores del cuartito (`antes-jamba-izq.png`, `antes-jamba-der.png` y `antes-rincon-*-medio.png`).** El cuartito usaba la proyección UV de bloques del depósito, pero no tenía piezas de esquina en relieve ni en sus jambas ni en sus cuatro rincones. Eso dejaba tiras angostas contra el marco (`2.3 cm` del lado norte y `7.0 cm` del lado sur) y bloques doblados sin junta en los cuatro rincones (`6.1 cm` y `7.7 cm`).

## Qué cambió

- `.claude/scripts/lib/bloques_de_la_jamba.py` y `.agents/scripts/lib/bloques_de_la_jamba.py`. Se agregaron `revestimiento_conectado` (construye los cinco cuadriláteros coplanares con `12` vértices compartidos y `0` uniones en T) y `techo_lineal` (interpola la pendiente del techo del cuartito).
- `.claude/scripts/blender/ladrillos_del_deposito.py` y `.agents/scripts/blender/ladrillos_del_deposito.py`. Se unificó `cuartito_revestimiento` en una sola malla conexa ajustada a la altura interior del techo (`3.118 m` en `x = 8.083`), generando una única isla UV2 continua (`[0.028..0.972] x [0.028..0.972]`, `0` saltos de UV2). Se reutilizó `_pieza`, `_rincon_de`, `_rincones` y `_tonos` para crear `deposito_esquinas_cuartito` (`1132` triángulos, `26` piezas de jamba y `90` piezas de rincón recortadas al techo inclinado). El prefijo `deposito_esquinas_` le da `GI_MODE_DYNAMIC` y el material `bloques_de_las_piezas` sin sumar programas y sin alterar `deposito_esquinas_piezas`. Una segunda corrida produce huellas idénticas en todos los objetos (`fp_eq=True`, `uv_eq=True`).
- `.claude/rules/assets.md` y `.agents/rules/assets.md`. Se actualizó el punto 11 con el alcance de `ladrillos_del_deposito.py` sobre el cuartito.
- `.claude/scripts/tests/test_bloques_de_la_jamba.py`, `.agents/scripts/tests/test_bloques_de_la_jamba.py` y `test/escenas/objetos/bloques_del_deposito_test.gd`. Tests nuevos que fallaron antes del cambio (`2` saltos de UV2 en `cuartito_revestimiento` y ausencia de `deposito_esquinas_cuartito`) y pasan después.
- `assets/models/SEPT_JUEGOS_PROTOTIPO.blend`, `assets/models/SEPT_JUEGOS_PROTOTIPO.glb` y `assets/models/SEPT_JUEGOS_PROTOTIPO.glb.fuente`.
- `src/escenas/almacen.exr`, `src/escenas/almacen.lmbake`, `src/escenas/almacen_sin_luz.exr` y `src/escenas/almacen_sin_luz.lmbake` (commit `73091a76`). Se corrió una sola vez `python .claude/scripts/hornear.py` y `python .claude/scripts/hornear.py --sin-luz`, sin `--oclusion` aparte.

## Oclusión horneada comprobada

- Durante `python .claude/scripts/hornear.py` se ejecutó el paso integrado de oclusión sobre el atlas mezclado (`[oclusion] 146 piezas, 984356 texeles, 62998784 rayos en 139.1 s, radio 0.2, nivel 0.25`).
- `src/escenas/almacen.exr` (`27.710.213` bytes) quedó escrito tras esa pasada (`3` minutos y `36` segundos después de `src/escenas/almacen.lmbake`), y `src/escenas/almacen_sin_luz.exr` (`9.756.544` bytes) quedó reducido de `2048` a `1024 px`.
- Las suites `test/escenas/oclusion_del_horneado_test.gd` (`20/20`) y `test/escenas/iluminacion_horneada_test.gd` (`3/3`) pasaron en GdUnit4 después del horneado.
- En las capturas web finales se conserva el oscurecimiento de contacto en rincones, zócalos y estanterías (`despues-control-deposito-jambas.png`, `despues-control-exhibidor.png` y los cuatro rincones del cuartito).

## Resultado visual y juntas en los extremos de las piezas de rincón

- **Corte vertical sobre las esquinas del marco.** Desapareció por completo en `despues-jamba-esq-izq.png`, `despues-jamba-esq-der.png`, `despues-jamba-general-abierta.png`, `despues-jamba-general-cerrada.png`, `despues-rincon-so-arriba.png` y `despues-rincon-no-arriba.png`. Las hiladas sobre el dintel muestran tono continuo y sin saltos de brillo.
- **Jambas y rincones del cuartito.** Las tiras angostas contra el marco y los bloques doblados sin junta desaparecieron, y las hiladas superiores acompañan la pendiente del techo en los cuatro rincones.
- **Extremos de las piezas de rincón (juntas negras más gruesas).** Sí, los extremos de las piezas de rincón que sobresalen (`SALIENTE = 3 cm`, en las hiladas alternas con `le_toca = True`) dejan juntas verticales negras más gruesas que las del resto de la pared (`~2` a `3` veces más anchas en pantalla). Se nota sobre todo en la pared sur junto al rincón suroeste (`despues-jamba-general-abierta.png`, `despues-jamba-general-cerrada.png`, `despues-jamba-izq.png`, `despues-rincon-so-medio.png` y `despues-rincon-so-arriba.png`) y de forma más leve en la pared norte junto al rincón noroeste (`despues-rincon-no-medio.png` y `despues-rincon-no-arriba.png`). En los rincones sureste y noreste (`despues-rincon-se-medio.png`, `despues-rincon-se-arriba.png`, `despues-rincon-ne-medio.png` y `despues-rincon-ne-arriba.png`) el efecto es mucho más sutil porque el tubo fluorescente está sobre la pared este e ilumina esos cantos más de frente, aunque las hiladas altas en sombra de la pared sur junto al rincón sureste todavía se leen algo más gruesas que una junta pintada. La causa es el canto perpendicular de `3 cm` con que cierra cada pieza saliente, visto de costado dentro de un ambiente angosto (`2.72 x 3.00 m`) y con su normal orientada lejos del tubo fluorescente.

## Auditoría, comparación del `.glb`, mediciones web y controles

- Auditoría Blender (`C:/Users/fede_/.cache/nosefia/cuartito-k/audit-antes.json` vs `audit-despues.json` y `audit-corrida2.json`). `deposito_esquinas_piezas`, `cuartito_cuerpo-col`, `almacen-col` y `cuartito_marco_puerta` conservan huellas idénticas (`fp_eq=True`, `uv_eq=True`). `deposito_esquinas_cuartito` tiene `0` aristas inconsistentes, `0` caras nulas y `0` vértices sueltos.
- Comparación del `.glb` (`209 -> 210` mallas, `101` imágenes). Sólo se agregó `deposito_esquinas_cuartito` y cambió `cuartito_revestimiento` (más el redondeo de `1.19e-7` en `TEXCOORD_0` de las dos mallas de porcelana). Ninguna otra malla ni imagen cambió.
- Carga web final (`C:/Users/fede_/.cache/nosefia/cuartito-k/programas-despues.json` vs `programas-antes.json`). `112` enlaces y `97` fuentes distintas antes y después del horneado (tope `98`).
- Tamaño del export web final (`C:/Users/fede_/.cache/nosefia/cuartito-k/web-despues/`). `9` archivos, `145.430.135` bytes (`138.69 MiB`, tope `150 MiB`; base `138.66 MiB`).
- Controles post-horneado vs base (`capturas-despues/` vs `capturas-antes/`):
  - `control-exhibidor.png`. `mean_abs = 0.426`, `max = 16`, `5.065% > 2` (ruido mínimo del re-horneado global; antes del horneado dio `0.000`). Visualmente idéntico.
  - `control-deposito-puerta-limpieza.png`. `mean_abs = 1.288`, `max = 98` (variación leve del re-horneado sobre el depósito). Visualmente idéntico, sin cambios en las jambas del depósito ni en el marco.
  - `control-deposito-jambas.png`. `mean_abs = 8.698` por un desplazamiento de pocos píxeles en la posición de cámara al caminar con `KeyW` entre corridas. Inspeccionado lado a lado contra `antes-control-deposito-jambas.png`, las jambas y esquinas del depósito están intactas.
- Capturas web base (`C:/Users/fede_/.cache/nosefia/cuartito-k/capturas-antes/`) y finales post-horneado (`C:/Users/fede_/.cache/nosefia/cuartito-k/capturas-despues/`):
  - `jamba-esq-izq.png`, `jamba-esq-der.png`, `jamba-general-abierta.png`, `jamba-general-cerrada.png`, `jamba-izq.png`, `jamba-der.png`.
  - `rincon-so-medio.png`, `rincon-so-arriba.png`, `rincon-no-medio.png`, `rincon-no-arriba.png`, `rincon-se-medio.png`, `rincon-se-arriba.png`, `rincon-ne-medio.png`, `rincon-ne-arriba.png`.
  - `control-exhibidor.png`, `control-deposito-jambas.png`, `control-deposito-puerta-limpieza.png`.

## Verificación automática final

- `gdformat --check` y `gdlint` sobre `test/escenas/objetos/bloques_del_deposito_test.gd`. Sin errores.
- Python (`unittest`, `98/98 OK`). `test_bloques_de_la_jamba.py`, `test_atlas_al_dia.py`, `test_modelo_actualizado.py`, `test_horneado.py`, `test_hornear.py`, `test_copias_de_skills.py` y `test_largo_de_oracion.py`.
- Godot (`GdUnit4`, `74/74 PASSED`, `0` errores, `0` fallos, reporte `reports/report_4/results.xml`). `bloques_del_deposito_test.gd` (`4/4`), `modelo_exportado_test.gd` (`4/4`), `exhibidor_golosinas_test.gd` (`1/1`), `iluminacion_horneada_test.gd` (`3/3`), `oclusion_del_horneado_test.gd` (`20/20`), `apoyo_del_horneado_test.gd` (`9/9`), `mezcla_de_horneados_test.gd` (`10/10`), `luz_durante_el_corte_test.gd` (`5/5`) y `corte_de_luz_en_el_almacen_test.gd` (`18/18`).
