# Entrega J. Bloques de la jamba y exhibidor de golosinas

- Rama. `improvement/bloques-de-la-jamba` (apilada sobre `origin/improvement/hoja-del-bano`, sin PR).
- Commit de geometría, UV y tests. `97c68430` (`fix: restaurar espesor izquierdo del exhibidor y cerrar juntas internas en las jambas del depósito`).
- Commit de consulta previa. `c6d55047` (`PREGUNTA: confirmar horneado único y piezas de rincón sobre la puerta del depósito`).
- Commit de horneado único. `e36fe510` (`chore: hornear iluminación tras engrosar el lateral del exhibidor`).

## Qué cambió y causas raíz

### 1. Exhibidor de golosinas (`exhibidor_golosinas-col`)

- **Causa.** El panel lateral izquierdo (`+X`, lado del freezer) tenía espesor `0 mm` en `x_local = 0.432`. Su cara exterior (`f=40`, normal `+X`), su cara interior (`f=41`, normal `-X`), las cuatro caras de canto (`f=42..45`, área `0.00000`) y las cinco tapas de los escalones (`f=10, 16, 22, 28, 33`, normal `+X`) coincidían en el mismo plano. El panel derecho (`-X`) tiene `20 mm` (`x_local = -1.094 .. -1.074`). Esa superposición producía autooclusión negra y rayas negras a lo largo de los escalones en el mapa de luz horneado.
- **Corrección.** `.claude/scripts/lib/exhibidor_de_golosinas.py` y `.claude/scripts/blender/engrosar_lateral_exhibidor.py` (con espejo en `.agents/scripts/`). Mueve los cuatro vértices de `f=40` a `x_local = 0.452` (`+20 mm`, espejo del panel derecho). Recupera el área y las normales hacia afuera de los cuatro cantos (`zero_area_faces` pasa de `4` a `0`). Conserva `30 mm` de aire respecto de `freezer_helados-col` (`x = 0.3469` frente a `0.3769`) y no mueve `exhibido_golosinas`. Una segunda corrida reporta `ya_engrosado: true`, `vertices_movidos: 0` y `caras_area_cero: 0`.
- **Auditoría.** `C:/Users/fede_/.cache/nosefia/exhibidor-audit-antes.json` frente a `C:/Users/fede_/.cache/nosefia/exhibidor-audit-despues.json`. `zero_area_faces` pasa de `4` a `0` y `uv_eq=True`.

### 2. Bloques junto a las jambas del depósito (`deposito_esquinas_piezas`)

- **Causas.**
  1. En las jambas proyectadas desde la pared (`puerta_sur` jamba derecha `x = 5.933` en hiladas `2, 5, 8, 11`, `puerta_este` jamba sur `y = 13.14` en hiladas `0, 3, 6, 9, 12` y `porton` jamba norte `y = 13.654` en hiladas `2, 5, 8, 11, 14`), el frente cruzaba una junta vertical interna cerca del borde del vano y dejaba una tira angosta contra el marco (`2.4 cm` en `puerta_sur`). Además, en caras `es_jamba` junto a un rincón, el espejado de UV cruzaba el `quiebre` en hiladas de dos bloques.
  2. En `puerta_sur` jamba izquierda (`x = 7.555`, hilada `6`, cara `101`), la cara del escalón tenía la normal invertida (`4` aristas con orientación contradictoria) por calcular la orientación con el centroide de un perfil no convexo.
  3. Borrar caras ocultas con `FACES_ONLY` dejaba `294` aristas sueltas (`wire_edges`).
- **Corrección.** `.claude/scripts/lib/bloques_de_la_jamba.py` y `.claude/scripts/blender/ladrillos_del_deposito.py` (con espejo en `.agents/scripts/`). Estira el bloque de la pared sobre el frente cuando una junta cae dentro de la jamba y mantiene el encuentro exacto en `brazo`. Orienta cada perfil 2D en sentido antihorario, acota el espejado de `es_jamba` al primer bloque y elimina las aristas sueltas. El relieve de las jambas se conserva. Una segunda corrida devuelve los mismos `2340` triángulos.
- **Esquina superior izquierda sobre el dintel (`h = 13..17`).** Sin cambios de diseño según la respuesta a la consulta (`respuesta-web-j.md`). Comprobamos en el `.blend`, el `.glb` y `deposito_bloques_color.png` que `almacen-col` (cara `245`) tiene UV continuas (`max_uv_err = 1.59e-7`) y que las cinco piezas de rincón ya terminan sobre juntas verticales reales de la pared (`5.2 mm` del centro de la junta).
- **Auditoría.** `C:/Users/fede_/.cache/nosefia/jamba-audit-antes.json` frente a `C:/Users/fede_/.cache/nosefia/jamba-audit-despues.json`. `wire_edges` pasa de `294` a `0`, `inconsistent_winding_edges` pasa de `4` a `0` y `bounds_eq=True`. `almacen-col` queda idéntica (`bounds_eq=True`, `geo_eq=True`, `uv_eq=True`).

### 3. Horneado único de iluminación

- Corrimos `python .claude/scripts/hornear.py` (normal y con apoyo de `16` obstáculos, reparó `1` línea de `452` téxeles, mezcló `146` piezas en `0.75`, comprobó `0` líneas y aplicó oclusión sobre `146` piezas con `984462` téxeles, `63005568` rayos, radio `0.2`, nivel `0.25`) y luego `python .claude/scripts/hornear.py --sin-luz` (`24` luces y `10` materiales emisivos apagados, reparó `1` línea de `440` téxeles, redujo atlas `2048 -> 1024 px`). No corrimos `--oclusion` aparte.
- Actualizamos `src/escenas/almacen.exr`, `src/escenas/almacen.lmbake`, `src/escenas/almacen_sin_luz.exr` y `src/escenas/almacen_sin_luz.lmbake`.
- **Comprobación de oclusión horneada.** En `exhibidor-lado-izq-interior` (misma pose), comparamos el rincón detrás del tacho (`y = 180..290, x = 0..300`) contra la pared alta (`y = 0..120, x = 0..200`). La relación rincón/pared pasó de `0.7202` (`104.08 / 144.51`) antes a `0.7238` (`105.37 / 145.57`) después. La oclusión en los rincones se mantiene.

## Comparación del `.glb` y límites de archivos

- Mallas del `.glb` (`209` totales). Sólo cambiaron `deposito_esquinas_piezas` y `exhibidor_golosinas` (más el redondeo de `5.96e-08` en `TEXCOORD_0` de las dos mallas de porcelana).
- Imágenes embebidas (`101` totales). `0` cambiadas.
- Archivos fuera de alcance (`project.godot`, `.github/performance/topes-de-carga.json`, `addons/hornear/`, hoja del baño y Arvecor). Sin cambios.

## Medición web

- **Programas WebGL** (`medir_con_firmas.mjs`, `--sin-ventana --software --corridas=1 --sin-enlace-en-paralelo`).
  - Antes. `97` programas y `84` fuentes distintas (`C:/Users/fede_/.cache/nosefia/jamba-programas-antes.json`).
  - Después. `97` programas y `84` fuentes distintas (`C:/Users/fede_/.cache/nosefia/jamba-programas-despues.json`).
  - Tope. `98`. Sin incremento (`0`).
- **Tamaño del export web** (`verificar_export.py`).
  - Antes (`export/web-antes`). `9` archivos, `138.7 MB`.
  - Después (`export/web-despues`). `9` archivos, `138.7 MB`.
  - Tope. `150 MiB`.

## Capturas web (antes y después)

Carpeta. `C:/Users/fede_/.cache/nosefia/capturas-jamba-exhibidor/`

- Exhibidor lado izquierdo interior. `antes2-exhibidor-lado-izq-interior.png` y `despues-exhibidor-lado-izq-interior.png` (desaparecen las rayas negras junto a los escalones, queda blanco y liso como el lado derecho).
- Exhibidor lado izquierdo exterior. `antes2-exhibidor-lado-izq-exterior.png` y `despues-exhibidor-lado-izq-exterior.png`.
- Exhibidor lado derecho interior. `antes2-exhibidor-lado-der-interior.png` y `despues-exhibidor-lado-der-interior.png`.
- Exhibidor lado derecho exterior. `antes2-exhibidor-lado-der-exterior.png` y `despues-exhibidor-lado-der-exterior.png`.
- Puerta del depósito cerrada entera. `antes2-puerta-cerrada-entera.png` y `despues-puerta-cerrada-entera.png`.
- Esquina superior izquierda cerca. `antes2-esquina-izq-cerca.png` y `despues-esquina-izq-cerca.png`.
- Jamba izquierda cerca. `antes2-jamba-izq-cerca.png` y `despues-jamba-izq-cerca.png` (normal corregida en `h = 6`).
- Esquina superior derecha cerca. `antes2-esquina-der-cerca.png` y `despues-esquina-der-cerca.png` (tira de `2.4 cm` eliminada).
- Jamba derecha cerca. `antes2-jamba-der-cerca.png` y `despues-jamba-der-cerca.png` (bloques continuos contra el marco).
- Puerta de limpieza arriba. `antes2-puerta-limpieza-arriba.png` y `despues-puerta-limpieza-arriba.png`.

## Verificación automática

- **Python (`unittest`).**
  - `test_exhibidor_de_golosinas.py`. `4/4 OK`.
  - `test_bloques_de_la_jamba.py`. `3/3 OK`.
  - `test_copias_de_skills.py`. `4/4 OK`.
  - `test_modelo_actualizado.py`. `6/6 OK`.
  - `test_atlas_al_dia.py`. `6/6 OK`.
  - `test_texturas_del_modelo.py`. `9/9 OK`.
  - `test_horneado.py`. `38/38 OK`.
  - `test_hornear.py`. `27/27 OK`.
  - `test_reducir_mapa_de_luz.py`. `6/6 OK`.
- **Godot (`GdUnit4`, `76/76 PASSED`, `0` errores, `0` fallos tras limpiar `.godot/imported/SEPT_JUEGOS_PROTOTIPO.glb-*` y correr `--import`).**
  - `test/escenas/objetos/exhibidor_golosinas_test.gd` (`1/1`, falló antes del arreglo con `espesor izquierdo = 0.00000 m`).
  - `test/escenas/objetos/bloques_del_deposito_test.gd` (`2/2`, falló antes del arreglo con `4` aristas contradictorias y `38` triángulos con junta interna).
  - `test/escenas/modelo_exportado_test.gd` (`4/4`).
  - `test/escenas/objetos/hoja_del_bano_test.gd` (`1/1`).
  - `test/escenas/etiqueta_de_arvecor_test.gd` (`3/3`).
  - `test/escenas/iluminacion_horneada_test.gd` (`3/3`).
  - `test/escenas/corte_de_luz_en_el_almacen_test.gd` (`18/18`).
  - `test/escenas/luz_durante_el_corte_test.gd` (`5/5`).
  - `test/escenas/apoyo_del_horneado_test.gd` (`9/9`).
  - `test/escenas/mezcla_de_horneados_test.gd` (`10/10`).
  - `test/escenas/oclusion_del_horneado_test.gd` (`20/20`).
- **Formato y lint.** `gdformat --check` (`2 files would be left unchanged`) y `gdlint` (`Success: no problems found`) sobre los dos tests nuevos.
