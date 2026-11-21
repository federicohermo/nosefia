# Entrega: el canto de las piezas en relieve lleva la textura del bloque

## Commit

- Rama: `improvement/canto-de-las-piezas`
- Commit del arreglo: `db70d132d0325f8f18efa161c21b0ede4675ba41`

## Causa comprobada

Se midió en Blender, en la malla importada de Godot y en la build web base (`web-antes`):

1. **No era muestreo de mortero.** En Blender, las UV viejas de los cantos muestreaban píxeles de ladrillo con luminancia media `0,57` (`deposito_esquinas_cuartito` `0,571`, `deposito_esquinas_piezas` `0,566`), igual que los frentes (`0,58`).
2. **No era falta de luz.** En el cuartito, los cantos con normal `+X` miran directo a `LuzDelCuartito` y salían negros (`luma ~14/255`).
3. **La causa era la UV horizontal colapsada (`du = 0`) en los cantos.** `ladrillos_del_deposito.py` asignaba una sola coordenada `u_de(s_ref)` constante a los cuatro vértices de cada canto (`502` triángulos en `deposito_esquinas_piezas` y `256` en `deposito_esquinas_cuartito`).
4. **Tangente degenerada en MikkTSpace.** Al importar con `meshes/ensure_tangents=true`, Godot asigna la tangente de respaldo `(1, 0, 0, 1)` a los triángulos con área UV cero. En todos los cantos con normal `(±1, 0, 0)` (`158` triángulos en el depósito y `116` en el cuartito), la tangente queda colineal con la normal (`|N · T| = 1`), `cross(N, T)` colapsa a cero y el mapa de normales anula toda la iluminación en WebGL2. En los cantos con normal `(0, 0, ±1)`, la tangente no era colineal pero la UV colapsada estiraba una sola columna de píxeles a lo ancho del canto.

## Qué cambió

- `.claude/scripts/lib/bloques_de_la_jamba.py` (y espejo `.agents/`): se agregó `u_del_canto`, que apoya el canto en `u_de(costado)` sobre el plano de la pared (`t = t_min`) y recorre la cara del mismo bloque en escala real 1:1 al avanzar hacia el frente (`t > t_min`). Donde el canto toca la pared queda el borde de junta de la pared plana.
- `.claude/scripts/blender/ladrillos_del_deposito.py` (y espejo `.agents/`): `_pieza()` usa `u_del_canto` para todo canto no-jamba. El arreglo aplica a `deposito_esquinas_piezas` y `deposito_esquinas_cuartito`.
- `assets/models/SEPT_JUEGOS_PROTOTIPO.blend`, `assets/models/SEPT_JUEGOS_PROTOTIPO.glb` y `assets/models/SEPT_JUEGOS_PROTOTIPO.glb.fuente`: regenerados y reimportados. No se tocó el horneado.
- `.claude/scripts/tests/test_bloques_de_la_jamba.py` (y espejo `.agents/`): prueba unitaria de `u_del_canto`.
- `test/escenas/objetos/bloques_del_deposito_test.gd`: prueba de comportamiento que verifica UV horizontal no colapsada y tangente ortogonal a la normal en todas las caras verticales de `deposito_esquinas_piezas` y `deposito_esquinas_cuartito` (corrió en rojo antes del arreglo y pasó en verde después).

## Mediciones

### Conteo de programas web (tope 98)

- Antes: `112` enlaces, `97` fuentes distintas (`C:/Users/fede_/.cache/nosefia/canto-m/programas-antes.json`).
- Después: `112` enlaces, `97` fuentes distintas (`C:/Users/fede_/.cache/nosefia/canto-m/programas-despues.json`).

### Tamaño del export web (tope 150 MiB)

- Antes: `145.433.271` bytes (`138,70 MiB` en `9` archivos).
- Después: `145.434.167` bytes (`138,70 MiB` en `9` archivos).

### Auditoría de malla, `.glb` e idempotencia

- `audit_mesh.py` antes (`C:/Users/fede_/.cache/nosefia/canto-m/audit-antes.json`), después (`audit-despues.json`) y segunda corrida (`audit-corrida2.json`):
  - `deposito_esquinas_piezas`: geometría y materiales idénticos, triángulos con UV colapsada `1736 -> 1234` (`0` cantos colapsados), segunda corrida idéntica (`despues == corrida2`).
  - `deposito_esquinas_cuartito`: geometría y materiales idénticos, triángulos con UV colapsada `848 -> 592` (`0` cantos colapsados), segunda corrida idéntica (`despues == corrida2`).
  - `almacen-col`, `cuartito_revestimiento`, `cuartito_cuerpo-col`: sin cambios en geometría, materiales ni UV.
- Comparación de las `210` mallas del `.glb`: sólo cambiaron `deposito_esquinas_piezas` y `deposito_esquinas_cuartito` (`bano_lavatorio_2-convcol porcelana.001` y `vanitory-convcol porcelana.001` variaron sólo el orden de índices y tienen los mismos triángulos exactos).

### Comparación de píxeles en la misma pose (build web)

- `cuartito-cerrada`: `98,92%` sin cambios (`diff <= 2/255`), `0,67%` con `diff > 15` (luminancia media de los cantos `14,0 -> 68,3`).
- `cuartito-rincon-so`: `99,46%` sin cambios, `0,42%` con `diff > 15` (luminancia `13,8 -> 62,3`).
- `cuartito-rincon-no`: `99,59%` sin cambios, `0,22%` con `diff > 15` (luminancia `23,7 -> 55,4`).

### Suites y linters

- `gdformat --check test/escenas/objetos/bloques_del_deposito_test.gd`: verde.
- `gdlint test/escenas/objetos/bloques_del_deposito_test.gd`: verde.
- `bloques_del_deposito_test.gd`: `5/5` verde.
- `test_bloques_de_la_jamba.py`: `6/6` verde.
- `test_modelo_actualizado.py`: `6/6` verde.
- `test_texturas_del_modelo.py`: `9/9` verde.
- `test_largo_de_oracion.py`: `12/12` verde.
- Espejo `.claude/` y `.agents/`: idéntico.

## Capturas web (antes y después)

- Cuartito, pared izquierda mirando puerta cerrada:
  - Antes: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-antes/antes-cuartito-cerrada.png`
  - Después: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-despues/despues-cuartito-cerrada.png`
- Cuartito, rincón SO (cantos `+X`):
  - Antes: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-antes/antes-cuartito-rincon-so.png`
  - Después: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-despues/despues-cuartito-rincon-so.png`
- Cuartito, rincón NO (cantos `+X`):
  - Antes: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-antes/antes-cuartito-rincon-no.png`
  - Después: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-despues/despues-cuartito-rincon-no.png`
- Cuartito, rincón SE (cantos `-X` y `-Z`):
  - Antes: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-antes/antes-cuartito-rincon-se.png`
  - Después: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-despues/despues-cuartito-rincon-se.png`
- Cuartito, rincón NE (cantos `-X` y `+Z`):
  - Antes: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-antes/antes-cuartito-rincon-ne.png`
  - Después: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-despues/despues-cuartito-rincon-ne.png`
- Depósito, rincón NE (cantos `-X` y `+Z`):
  - Antes: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-antes/antes-deposito-rincon-ne.png`
  - Después: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-despues/despues-deposito-rincon-ne.png`
- Depósito, puerta sur y rincón SE:
  - Antes: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-antes/antes-deposito-puerta-sur.png`
  - Después: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-despues/despues-deposito-puerta-sur.png`
  - Antes rincón SE: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-antes/antes-deposito-rincon-se.png`
  - Después rincón SE: `C:/Users/fede_/.cache/nosefia/canto-m/capturas-despues/despues-deposito-rincon-se.png`
