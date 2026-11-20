# Entrega K (consulta antes del horneado). Bloques del cuartito de limpieza

- Rama. `improvement/bloques-del-cuartito` (desde `origin/improvement/mejorar-texturas-del-local`, sin PR).
- Commit de geometría, UV, pipeline y tests. `c5a1f74f`.
- Estado. Cambios aplicados en el `.blend`, exportados al `.glb` y verificados en build web previa al horneado. Pendiente de confirmación antes de correr el horneado único.

## Qué causaba cada corte

1. **Línea vertical sobre las esquinas superiores del marco (`22.png` y `antes-jamba-esq-izq.png`, `antes-jamba-esq-der.png`).** `cuartito_revestimiento` tenía tres cuadriláteros desconectados con `12` vértices sin soldar y dos uniones en T en `(8.083, 13.14, 2.722)` y `(8.083, 14.78, 2.722)`. Sus UV de color ya eran continuas. Al importar con `light_baking = 2`, xatlas separó los tres cuadriláteros en tres islas UV2 distintas y giradas (`[0.386..0.614]`, `[0.023..0.250]` y `[0.750..0.977]`). El mapa de luz horneado y la oclusión dejaron distinto brillo a cada lado de `y = 13.14` y `y = 14.78` sobre el dintel, partiendo las dos hiladas superiores sin junta.
2. **Jambas y cuatro rincones interiores del cuartito (`antes-jamba-izq.png`, `antes-jamba-der.png`, `antes-rincon-so-medio.png`, `antes-rincon-no-medio.png`, `antes-rincon-se-medio.png`, `antes-rincon-ne-medio.png`).** El cuartito usaba la proyección UV de bloques del depósito, pero no tenía piezas de esquina en relieve ni en sus jambas ni en sus cuatro rincones. Eso dejaba tiras angostas contra el marco (`2.3 cm` del lado norte y `7.0 cm` del lado sur) y bloques doblados sin junta en los cuatro rincones (`6.1 cm` y `7.7 cm`).

## Qué cambió

- `.claude/scripts/lib/bloques_de_la_jamba.py` y `.agents/scripts/lib/bloques_de_la_jamba.py`. Se agregaron `revestimiento_conectado` (construye los cinco cuadriláteros coplanares con vértices compartidos y sin uniones en T) y `techo_lineal` (interpola la pendiente del techo del cuartito).
- `.claude/scripts/blender/ladrillos_del_deposito.py` y `.agents/scripts/blender/ladrillos_del_deposito.py`. Se unificó `cuartito_revestimiento` en una sola malla conexa ajustada a la altura interior del techo (`3.118 m` en `x = 8.083`), lo que genera una única isla UV2 continua en Godot (`0` saltos de UV2 en vértices compartidos). Se reutilizó `_pieza`, `_rincon_de`, `_rincones` y `_tonos` para crear `deposito_esquinas_cuartito` con las jambas de la puerta del cuartito (ambas a `0.68 m < CERCA_DEL_RINCON`) y los cuatro rincones interiores recortados contra el techo inclinado. `deposito_esquinas_cuartito` es un objeto separado con el prefijo `deposito_esquinas_`, así toma `GI_MODE_DYNAMIC` y el mismo material `bloques_de_las_piezas` sin sumar programas y sin tocar `deposito_esquinas_piezas`. Una segunda corrida produce huellas idénticas en todos los objetos (`fp_eq=True`, `uv_eq=True`).
- `.claude/rules/assets.md` y `.agents/rules/assets.md`. Se actualizó el punto 11 con el alcance de `ladrillos_del_deposito.py` sobre el cuartito.
- `.claude/scripts/tests/test_bloques_de_la_jamba.py`, `.agents/scripts/tests/test_bloques_de_la_jamba.py` y `test/escenas/objetos/bloques_del_deposito_test.gd`. Tests nuevos que fallaron antes del cambio (`2` saltos de UV2 en `cuartito_revestimiento` y ausencia de `deposito_esquinas_cuartito`) y pasan después.
- `assets/models/SEPT_JUEGOS_PROTOTIPO.blend`, `assets/models/SEPT_JUEGOS_PROTOTIPO.glb` y `assets/models/SEPT_JUEGOS_PROTOTIPO.glb.fuente`.

## Por qué hace falta hornear

`cuartito_revestimiento` es estático (`gi_mode = 1`) y participa en el mapa de luz horneado. Al soldar sus tres cuadriláteros en una sola malla conexa, Godot generó una única isla UV2 continua (`[0.028..0.972] x [0.028..0.972]`). Los atlas actuales (`src/escenas/almacen.exr` y `src/escenas/almacen_sin_luz.exr`) siguen teniendo el empaquetado viejo de tres islas. Hace falta correr una sola vez `python .claude/scripts/hornear.py` y `python .claude/scripts/hornear.py --sin-luz` para actualizar el horneado con la UV2 nueva. `deposito_esquinas_cuartito` lleva `GI_MODE_DYNAMIC` y no entra al horneado.

## Auditoría, comparación del `.glb` y mediciones web previas al horneado

- Auditoría Blender (`C:/Users/fede_/.cache/nosefia/cuartito-k/audit-antes.json` vs `audit-despues.json` y `audit-corrida2.json`). `deposito_esquinas_piezas`, `cuartito_cuerpo-col`, `almacen-col` y `cuartito_marco_puerta` conservan huellas idénticas (`fp_eq=True`, `uv_eq=True`). `deposito_esquinas_cuartito` tiene `0` aristas inconsistentes, `0` caras nulas y `0` vértices sueltos.
- Comparación del `.glb` contra `HEAD` (`209 -> 210` mallas, `101` imágenes). Sólo se agregó `deposito_esquinas_cuartito` y cambió `cuartito_revestimiento` (más el redondeo de `1.19e-7` en `TEXCOORD_0` de las dos mallas de porcelana). Ninguna otra malla ni imagen cambió.
- Carga web previa al horneado (`C:/Users/fede_/.cache/nosefia/cuartito-k/programas-antes.json` vs `programas-prebake.json`). `112` enlaces y `97` fuentes distintas antes y después (tope `98`).
- Tamaño del export web. `138.66 MiB` antes y `138.69 MiB` después (tope `150 MiB`).
- Comparación de píxeles en control `control-exhibidor.png`. `mean_abs = 0.000`, `max = 0`, `0.000%` de píxeles distintos.
- Capturas web base (`C:/Users/fede_/.cache/nosefia/cuartito-k/capturas-antes/`) y previas al horneado (`C:/Users/fede_/.cache/nosefia/cuartito-k/capturas-prebake/`):
  - `jamba-esq-izq.png`, `jamba-esq-der.png`, `jamba-general-abierta.png`, `jamba-general-cerrada.png`, `jamba-izq.png`, `jamba-der.png`.
  - `rincon-so-medio.png`, `rincon-so-arriba.png`, `rincon-no-medio.png`, `rincon-no-arriba.png`, `rincon-se-medio.png`, `rincon-se-arriba.png`, `rincon-ne-medio.png`, `rincon-ne-arriba.png`.
  - `control-exhibidor.png`, `control-deposito-jambas.png`, `control-deposito-puerta-limpieza.png`.

## Verificación automática ejecutada

- `gdformat --check` y `gdlint` sobre `test/escenas/objetos/bloques_del_deposito_test.gd`. Sin errores.
- Python (`unittest`). `test_bloques_de_la_jamba.py` (`5/5`), `test_copias_de_skills.py` (`4/4`), `test_largo_de_oracion.py` (`12/12`), `test_modelo_actualizado.py` (`6/6`), `test_atlas_al_dia.py` (`6/6`), `test_texturas_del_modelo.py` (`9/9`), `test_union_de_mallas.py` (`22/22`) y `test_volumenes_modelo.py` (`4/4`).
- Godot (`GdUnit4`). `bloques_del_deposito_test.gd` (`4/4`), `modelo_exportado_test.gd` (`4/4`) y `exhibidor_golosinas_test.gd` (`1/1`).

## Pregunta

¿Confirmás correr el horneado único (`python .claude/scripts/hornear.py` y `python .claude/scripts/hornear.py --sin-luz`) sobre el commit `c5a1f74f` para actualizar el atlas con la UV2 nueva de `cuartito_revestimiento`?
