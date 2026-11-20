# Entrega. Apoyo de la oclusión de contacto

## Commit

`dc89002b` en la rama `improvement/apoyo-de-la-oclusion` (sobre `2c2c1054`).

## Qué cambió

1. **Zonas de contacto dentro de `radio` y manchas bajo demanda (`src/escenas/objetos/oclusion_de_contacto.gd`).**
   - La zona de apoyo reúne todos los vértices del objeto dentro de `radio` (0,05 m) desde su punto más bajo medido hacia abajo del mundo, en lugar de `BANDA_DE_APOYO` (1 cm).
   - Los vértices de esa zona se agrupan primero por conectividad de triángulos y posiciones coincidentes (1 mm) y luego por cercanía de cajas horizontales alineadas al cuerpo dentro de `radio`. Las hebras separadas del cepillo forman un solo grupo; dos zonas alejadas (como cepillo y extremo bajo del palo) forman grupos separados.
   - Cada grupo lanza su propio rayo hacia abajo, crea una mancha sólo si hace falta y la reusa (`sombras`, manteniendo `sombra` como `sombras[0]`). Cada mancha usa la superficie real que tiene debajo, recorta con `_recortar_en_el_apoyo`, calcula su intensidad con `intensidad_a` y orienta su plano con el eje del cuerpo más paralelo a la superficie para no inflar objetos largos en giros intermedios.
   - El cálculo de grupos conserva caché por mallas, poses relativas, dirección hacia abajo y `radio`: trasladar un objeto en la mano no recalcula grupos.
   - `BANDA_DE_APOYO`, `vertices_de` y `plano` siguen intactos para `src/escenas/puestos/oclusion_de_la_gondola.gd`.
2. **Base oscurecida en el tubo metálico de la mopa (`src/escenas/objetos/cabeza_de_la_mopa.gdshader`, `src/escenas/objetos/fibras_de_la_mopa.gd`).**
   - `cabeza_de_la_mopa.gdshader` incorpora `uniform float metal = 0.0` y asigna `METALLIC = metal`.
   - En `fibras_de_la_mopa.gd`, la rama del tubo metálico (`util_mango_acero`) pasa a `ShaderMaterial` con `cabeza_de_la_mopa.gdshader`, sin agregarse a `_rigidas` (mantiene `articulacion` identidad y `CONTORNO` sin deformación). Recibe `oclusion_de_contacto.gdshaderinc` sin sumar programas y sin alterar el aspecto metálico lejos del piso.
3. **Tests y guía (`test/escenas/objetos/oclusion_de_contacto_apoyo_test.gd`, `test/escenas/objetos/oclusion_de_los_objetos_test.gd`, `docs/guides/iluminacion.md`).**
   - Tests de comportamiento para dos zonas separadas, contorno completo cerca de la superficie, tramo elevado sobre `radio`, creación bajo demanda y reuso de manchas, intensidad por altura, apoyo en dos superficies a distinta altura, caché de traslación en mano, giros de objeto alargado (0°, 45°, 84°, 90°), mopa tirada en tres giros y verificación de uniformes en todas las superficies de mopa y balde.
   - Actualización de la sección de oclusión dinámica en `docs/guides/iluminacion.md`.

## Conteo de programas en la carga web

Medido sobre la build web de `dc89002b` con:

```bash
node C:/Users/fede_/.cache/nosefia/medir_con_firmas.mjs http://localhost:8182 C:/Users/fede_/.cache/nosefia/web-g/programas-propuesta.json --sin-ventana --software --corridas=1 --sin-enlace-en-paralelo
```

| Métrica | Base (`2c2c1054`) | Propuesta (`dc89002b`) | Tope |
|---|---|---|---|
| Programas enlazados | 97 | 97 (+0) | 98 |
| Fuentes distintas | 84 | 84 | - |
| `index.wasm` | 29 149 696 bytes | 29 149 696 bytes | 31 457 280 bytes |

Validado también con `python .github/scripts/tope_de_carga.py` sin errores.

## Costo medido por cuadro en la web

Medido en Chrome headless sobre GPU real (`ANGLE (NVIDIA, NVIDIA GeForce RTX 4050 Laptop GPU (0x000028E1) Direct3D11 vs_5_0 ps_5_0, D3D11)`, `EXT_disjoint_timer_query_webgl2`), mirando el salón tras entrar con "Nuevo juego", en 5 rondas alternadas de 60 cuadros válidos por build (`C:/Users/fede_/.cache/nosefia/web-g/costo-salon.json`, 0 errores).

| Build | Dibujos/cuadro (mediana, rango entre rondas) | Tiempo GPU (mediana, rango entre rondas) |
|---|---|---|
| Base (`2c2c1054`) | 564 (564 a 564) | 2,299 ms (2,277 a 2,355 ms) |
| Propuesta (`dc89002b`) | 564 (564 a 564) | 2,335 ms (2,284 a 2,379 ms) |

Veredicto del costo. Suma 0 dibujos por cuadro. La diferencia de mediana en GPU (+0,036 ms) cae dentro del solapamiento entre rondas (amplitud de 0,078 ms en la base y 0,095 ms en la propuesta; en la ronda 5 la propuesta midió 2,284 ms frente a 2,328 ms de la base).

## Manchas en todo el local al empezar la noche

Medido en `almacen.tscn` al iniciar la noche tras asentar las físicas de inicio.

| Momento | Nodos `OclusionDeContacto` | Manchas creadas | Manchas visibles | Manchas extra creadas |
|---|---|---|---|---|
| Antes (`2c2c1054`) | 77 | 77 | 40 | 0 |
| Después (`dc89002b`) | 77 | 77 | 40 | 0 |

## Capturas web y comparación de píxeles

Todas tomadas en la build web con la misma pose antes (`2c2c1054`) y después (`dc89002b`), en `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/` (`diffs.json`).

| Caso | Píxeles distintos | Diferencia máx. (0-255) | Resultado visual |
|---|---|---|---|
| `mopa_giro_0` | 11 356 | 143 | Sin mancha bajo el tramo alto del palo; manchas en cepillo y extremo bajo |
| `mopa_giro_45` | 10 240 | 62 | Sin mancha bajo el tramo alto del palo; manchas en cepillo y extremo bajo |
| `mopa_giro_84` | 11 599 | 145 | Sin mancha diagonal bajo el palo; manchas alineadas en cepillo y extremo bajo |
| `mopa_metal_cerca` | 67 017 | 7 | Cara inferior del tubo metálico oscurecida cerca del piso y sombra en extremo bajo |
| `mopa_parada_metal` | 1 106 | 2 | Tubo metálico lejos del piso igual a `StandardMaterial3D` (variación residual <= 2/255) |
| `bolsa_chisitos` | 49 888 | 7 | Bolsa acostada con mancha suave alrededor de todo su contorno |
| `caja` | 116 | 1 | Caja en el piso igual que antes (diferencia máxima 1/255) |
| `balde` | 6 492 | 10 | Una sola mancha circular. La pared baja curva del `.glb` pasa de `r = 0,147 m` en `dy = 0` a `r = 0,183 m` en `dy = 0,04 m` (dentro de `radio = 0,05 m`), por lo que la huella se ensancha 3,6 cm siguiendo la forma real |

Rutas de las capturas:

- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/mopa_giro_0_antes.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/mopa_giro_0_despues.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/mopa_giro_45_antes.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/mopa_giro_45_despues.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/mopa_giro_84_antes.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/mopa_giro_84_despues.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/mopa_metal_cerca_antes.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/mopa_metal_cerca_despues.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/mopa_parada_metal_antes.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/mopa_parada_metal_despues.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/bolsa_chisitos_antes.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/bolsa_chisitos_despues.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/caja_antes.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/caja_despues.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/balde_antes.png`
- `C:/Users/fede_/.cache/nosefia/capturas-apoyo-de-la-oclusion/balde_despues.png`

## Verificación automática

- `gdformat --check` y `gdlint` en verde sobre los 4 scripts modificados.
- Suites gdUnit4 en verde (52/52 casos, 0 errores, 0 fallos, 0 huérfanos):
  - `test/escenas/objetos/oclusion_de_contacto_test.gd` (19/19)
  - `test/escenas/objetos/oclusion_de_contacto_apoyo_test.gd` (11/11)
  - `test/escenas/objetos/oclusion_de_los_objetos_test.gd` (5/5)
  - `test/escenas/oclusion_de_la_gondola_test.gd` (7/7)
  - `test/escenas/objetos/fibras_de_la_mopa_test.gd` (4/4)
  - `test/escenas/objetos/calentamiento_de_utiles_test.gd` (1/1)
  - `test/escenas/luz_durante_el_corte_test.gd` (5/5)
