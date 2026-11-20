# Entrega J (consulta antes del horneado). Bloques de la jamba y exhibidor de golosinas

- Rama. `improvement/bloques-de-la-jamba`
- Estado. Cambios de geometría, UV y tests aplicados y exportados al `.glb`. Pendiente de confirmación antes de ejecutar el único horneado de luz.

## Qué cambió

### 1. Exhibidor de golosinas (`exhibidor_golosinas-col`)

- **Causa comprobada.** El panel lateral izquierdo (`+X`, lado del freezer) estaba colapsado a espesor `0 mm` en `x_local = 0.432`. Su cara exterior (`f=40`, normal `+X`), su cara interior (`f=41`, normal `-X`), las cuatro caras de canto (`f=42..45`, todas con área `0.00000`) y las cinco tapas de los escalones (`f=10, 16, 22, 28, 33`, normal `+X`) compartían el mismo plano `x_local = 0.432`. El panel derecho (`-X`) tiene `20 mm` de espesor (`x_local = -1.094 .. -1.074`). Esa superposición causaba autooclusión negra en el horneado y rayas negras a lo largo de los escalones del costado izquierdo (captura base `C:/Users/fede_/.cache/nosefia/capturas-jamba-exhibidor/antes2-exhibidor-lado-izq-interior.png`).
- **Corrección.** `.claude/scripts/lib/exhibidor_de_golosinas.py` y `.claude/scripts/blender/engrosar_lateral_exhibidor.py` (con espejo en `.agents/scripts/`). Mueve los cuatro vértices de la cara exterior (`f=40`) a `x_local = 0.452` (`+20 mm`, espesor espejo del panel derecho). Las cuatro caras de canto recuperan su área y sus normales hacia afuera (`zero_area_faces: 4 -> 0`). El exhibidor conserva `30 mm` de aire contra `freezer_helados-col` (`x = 0.3469` frente a `0.3769`) sin mover las golosinas hijas (`exhibido_golosinas`). La segunda corrida reporta `ya_engrosado: true` y `vertices_movidos: 0`.
- **Tests.** `.claude/scripts/tests/test_exhibidor_de_golosinas.py` (`4/4 OK`) y `test/escenas/objetos/exhibidor_golosinas_test.gd` (falló antes con `espesor izquierdo = 0.00000 m` y pasa ahora `1/1 PASSED`).

### 2. Bloques junto a las jambas del depósito (`deposito_esquinas_piezas`)

- **Causas comprobadas.**
  1. En las jambas proyectadas desde la pared (`puerta_sur` jamba derecha `x = 5.933` en hiladas `2, 5, 8, 11`, `puerta_este` jamba sur `y = 13.14` en hiladas `0, 3, 6, 9, 12` y `porton` jamba norte `y = 13.654` en hiladas `2, 5, 8, 11, 14`), el frente de la pieza cruzaba una junta vertical interna cerca del borde del vano y dejaba una tira angosta partida contra el marco (`2.4 cm` en `puerta_sur`, visible en `antes2-esquina-der-cerca.png` y `antes2-jamba-der-cerca.png`). Además, en las caras `es_jamba` junto a un rincón, el espejado de UV cruzaba el `quiebre` en hiladas de dos bloques.
  2. En `puerta_sur` jamba izquierda (`x = 7.555`, hilada `6`, cara `101`), la cara vertical del escalón tenía la normal invertida (`4` aristas con orientación contradictoria) porque la orientación se calculaba con el centroide de un perfil no convexo.
  3. Borrar las caras ocultas con `FACES_ONLY` dejaba `294` aristas sueltas (`wire_edges`).
- **Corrección.** `.claude/scripts/lib/bloques_de_la_jamba.py` y `.claude/scripts/blender/ladrillos_del_deposito.py` (con espejo en `.agents/scripts/`). Cuando una junta vertical cae dentro del frente de una jamba, estira ese mismo bloque de la pared sobre el frente conservando el encuentro exacto con la junta en `brazo`. Orienta cada perfil 2D en sentido antihorario para garantizar normales hacia afuera en perfiles no convexos, acota el espejado de `es_jamba` al primer bloque y elimina las aristas sueltas (`wire_edges: 294 -> 0`, `inconsistent_winding_edges: 4 -> 0`). La pared `almacen-col` queda idéntica byte a byte (`geo_eq=True`, `uv_eq=True`). La segunda corrida devuelve el mismo conteo (`2340` triángulos).
- **Tests.** `.claude/scripts/tests/test_bloques_de_la_jamba.py` (`3/3 OK`) y `test/escenas/objetos/bloques_del_deposito_test.gd` (falló antes con `4` aristas contradictorias y `38` triángulos con junta interna, y pasa ahora `2/2 PASSED`).

## Por qué hace falta hornear la luz

- `exhibidor_golosinas-col` usa `GI_MODE_STATIC` y está horneado en `src/escenas/almacen.lmbake`, `src/escenas/almacen.exr`, `src/escenas/almacen_sin_luz.lmbake` y `src/escenas/almacen_sin_luz.exr`.
- Al restaurar el espesor de `20 mm` del panel izquierdo, cambió su geometría y Godot regeneró `assets/models/SEPT_JUEGOS_PROTOTIPO.glb.unwrap_cache` con nuevas UV2. El atlas actual todavía conserva la oclusión negra horneada sobre la cara interior izquierda del exhibidor.
- `deposito_esquinas_piezas` lleva `GI_MODE_DYNAMIC` y no entra al horneado. `almacen-col` no cambió geometría ni UV.
- Con un único horneado (`python .claude/scripts/hornear.py` y `python .claude/scripts/hornear.py --sin-luz`) se actualiza el mapa de luz para toda la rama.

## Preguntas antes de hornear

1. **Confirmación de horneado.** ¿Confirmás correr `python .claude/scripts/hornear.py` y `python .claude/scripts/hornear.py --sin-luz` ahora sobre estos cambios?
2. **Esquina superior izquierda de `puerta_sur` (`jamba_m1.png`, hiladas `13..17`).** Medimos `jamba_m1.png`, nuestra build web base (`antes2-puerta-cerrada-entera.png`, `antes2-esquina-izq-cerca.png`), el `.blend`, el `.glb` y los píxeles de `deposito_bloques_color.png`. Encima de esa esquina (`x = 7.555, z > 2.72`), `almacen-col` (cara `245`) es un único plano con UV lineales continuas (`max_uv_err = 1.59e-7`) y las cinco piezas de rincón (`f=905, 909, 913, 917, 919`) ya terminan sobre juntas verticales reales de la pared (`5.2 mm` del centro de la junta, luminancia `0.15` en el PNG). No encontramos ningún bloque partido sin junta encima de esa esquina. ¿El corte que veía el usuario era la tira angosta de `2.4 cm` de la jamba derecha (`x = 5.933`) y la normal invertida de `h=6` en la jamba izquierda (ambos ya corregidos), o querés también algún cambio de diseño sobre las piezas de rincón encima del dintel (`h=13..17`, por ejemplo igualar su tono al de la pared o terminar el relieve en el dintel) antes de hornear?

## Comparación del `.glb` y mediciones base

- Mallas del `.glb` (`209` totales). Sólo cambiaron de verdad `deposito_esquinas_piezas` y `exhibidor_golosinas` (más el redondeo habitual de `5.96e-08` en `TEXCOORD_0` de las dos mallas de porcelana). Imágenes embebidas (`101` totales): `0` cambiadas.
- Medición web base (`export/web-antes`). `97` programas (`84` fuentes distintas, `C:/Users/fede_/.cache/nosefia/jamba-programas-antes.json`) y `138.7 MB` (`9` archivos).
- Capturas web base en `C:/Users/fede_/.cache/nosefia/capturas-jamba-exhibidor/` (`antes2-exhibidor-lado-izq-interior.png`, `antes2-exhibidor-lado-izq-exterior.png`, `antes2-exhibidor-lado-der-interior.png`, `antes2-exhibidor-lado-der-exterior.png`, `antes2-puerta-cerrada-entera.png`, `antes2-esquina-izq-cerca.png`, `antes2-jamba-izq-cerca.png`, `antes2-esquina-der-cerca.png`, `antes2-jamba-der-cerca.png`, `antes2-puerta-limpieza-arriba.png`).
