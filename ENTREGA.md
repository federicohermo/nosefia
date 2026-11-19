# Entrega. Prototipo de oclusión de contacto en la góndola

## Commit

`04d84c27` en la rama `improvement/oclusion-en-la-gondola`.

## Qué hace cada parte

1. **Base oscurecida (`base_activa`).** `src/escenas/puestos/oclusion_de_la_gondola.gd` activa `contacto_en_base_local` en `src/escenas/objetos/oclusion_de_contacto.gdshaderinc` para los materiales de cada bloque (`ProductosDe*` y `VencidosDeCindolor`). El shader oscurece la parte inferior de cada unidad según la altura local del vértice sobre el eje local de apoyo, con los mismos valores iniciales que `OclusionDeContacto` (`radio = 0.05` m, `intensidad = 0.25`). No lanza rayos y no suma dibujos ni programas.
2. **Mancha por bloque (`manchas_activas`).** `OclusionDeLaGondola` crea un `MultiMeshInstance3D` (`SombrasDe<Producto>`) por bloque con `src/escenas/objetos/sombra_de_contacto.gdshader`, `use_custom_data = true` y `render_priority = -2`. Usa la misma huella de apoyo (`BANDA_DE_APOYO = 0.01` m), esquinas (`0.1`), elevación (`0.003` m), radio (`0.05` m) e intensidad (`0.25 * 0.5 = 0.125`) que `OclusionDeContacto` en las unidades sueltas. Cada instancia sigue la normal real del estante debajo de la unidad (incluida una rampa inclinada) y lleva en `INSTANCE_CUSTOM` el recorte `(min_x, min_z, max_x, max_z)` para no desbordar el canto del estante ni atravesar divisores. Al sacar o reponer una unidad, `ReposicionManual._mostrar_lo_puesto()` compacta el buffer de manchas con el mismo orden del bloque. Los huecos quedan ocultos y los vencidos conservan su mancha hasta que el jugador los saca.

## Cómo prender y apagar cada parte en vivo

En GDScript, buscar el nodo en el grupo `oclusion_de_la_gondola`:

```gdscript
var oclusion := get_tree().get_first_node_in_group(&"oclusion_de_la_gondola")
oclusion.base_activa = false      # apaga sólo la base oscurecida
oclusion.manchas_activas = false  # apaga sólo las manchas
oclusion.radio = 0.05             # cambia el alcance en ambas partes
oclusion.intensidad = 0.25        # cambia la intensidad en ambas partes
```

En la consola del navegador de la build web, llamar a `window.oclusion_gondola(base_activa, manchas_activas, radio, intensidad)`:

```js
window.oclusion_gondola(false, false) // todo apagado
window.oclusion_gondola(true, false)  // sólo base oscurecida
window.oclusion_gondola(false, true)  // sólo manchas
window.oclusion_gondola(true, true)   // ambas partes prendidas
```

## Conteo de programas en la carga web

Medido con `node C:/Users/fede_/.cache/nosefia/medir_con_firmas.mjs http://localhost:8181 C:/Users/fede_/.cache/nosefia/oclusion-gondola-programas.json --sin-ventana --software --corridas=1 --sin-enlace-en-paralelo`.

| Componente | Programas sumados | Evidencia |
|---|---|---|
| Base (rama origen) | 96 | Línea base declarada en el plan |
| Parte 1 (base oscurecida en `oclusion_de_contacto.gdshaderinc`) | +0 | Reusa el shader `producto_de_la_gondola.gdshader` ya compilado |
| Parte 2 (manchas en `MultiMesh` con `sombra_de_contacto.gdshader`) | +1 | Firma nueva con `USE_INSTANCING` y `ENABLE_INSTANCE_CUSTOM` (`huella -962271207`) |
| **Total** | **97** | **84 fuentes distintas, debajo del tope de 98** |

## Costo medido por cuadro en la web

Medido en Chrome headless sobre GPU real (`ANGLE NVIDIA GeForce RTX 4050 Laptop GPU Direct3D11`, `EXT_disjoint_timer_query_webgl2`, 1536×760, sin vsync) con la góndola entera a la vista en `?jornada=3`, en 5 rondas alternadas de 60 cuadros cada una (`C:/Users/fede_/.cache/nosefia/oclusion-gondola-costo.json`).

| Estado | Dibujos/cuadro (mediana, rango) | Tiempo GPU (mediana, rango) |
|---|---|---|
| Apagado (`false, false`) | 657 (654 a 657) | 2.536 ms (2.393 a 2.556 ms) |
| Sólo base (`true, false`) | 657 (657 a 657) | 2.592 ms (2.567 a 2.672 ms) |
| Sólo manchas (`false, true`) | 689 (689 a 689) | 2.561 ms (2.402 a 2.623 ms) |
| Prendido (`true, true`) | 689 (689 a 689) | 2.556 ms (2.512 a 2.614 ms) |

Veredicto del costo. La parte 1 suma 0 dibujos por cuadro. La parte 2 suma exactamente 32 dibujos por cuadro (uno por bloque de producto, no por unidad). La diferencia de tiempo de GPU medida entre apagado y prendido (+0.020 ms en mediana) cae dentro de la variación entre rondas (0.163 ms), sin costo medible sobre esta GPU.

## Bordes verificados

- **Cabecera y rampa.** `test_en_una_rampa_inclinada_la_mancha_sigue_la_pendiente_y_se_corta_en_el_borde` verifica una rampa de 14 cm en 60 cm y confirma normal alineada y recorte en el canto. En la escena actual (`gondolanueva2`), el estante blanco de cabecera se validó en captura web sin desbordes.
- **Fila de atrás.** `ReposicionManual._armar_los_bloques()` sólo dibuja la fila delantera, y el recorte de estante + panel divisor evita que una mancha cruce hacia otro lado.
- **Corte de luz.** `sombra_de_contacto.gdshader` es negro con alfa (`Clase.TRANSPARENTE`). `test/escenas/luz_durante_el_corte_test.gd` pasó 5/5.
- **Heladeras.** Las manchas dibujan con `render_priority = -2`, detrás del vidrio (`render_priority = 0`). Comprobado en `heladeras-prendido.png` sin artefactos de ordenamiento.
- **Unidad suelta vs acomodada.** `test_una_unidad_suelta_sobre_el_mismo_estante_recibe_la_misma_mancha_que_la_acomodada` confirma igualdad de huella, tamaño, suavidad, esquinas e intensidad.

## Capturas web

Todas tomadas sobre la build web en `?jornada=3`, desde la misma pose por grupo, en `C:/Users/fede_/.cache/nosefia/capturas-oclusion-gondola/`:

- Estante de cerca (misma pose, diferencias medidas vs apagado en 43 690 px para sólo base, 40 659 px para sólo manchas y 61 096 px para ambas):
  - `C:/Users/fede_/.cache/nosefia/capturas-oclusion-gondola/estante-apagado.png`
  - `C:/Users/fede_/.cache/nosefia/capturas-oclusion-gondola/estante-solo-base.png`
  - `C:/Users/fede_/.cache/nosefia/capturas-oclusion-gondola/estante-solo-manchas.png`
  - `C:/Users/fede_/.cache/nosefia/capturas-oclusion-gondola/estante-prendido.png`
- Góndola entera (vista del benchmark):
  - `C:/Users/fede_/.cache/nosefia/capturas-oclusion-gondola/gondola-entera-apagado.png`
  - `C:/Users/fede_/.cache/nosefia/capturas-oclusion-gondola/gondola-entera-prendido.png`
- Heladeras a través del vidrio:
  - `C:/Users/fede_/.cache/nosefia/capturas-oclusion-gondola/heladeras-apagado.png`
  - `C:/Users/fede_/.cache/nosefia/capturas-oclusion-gondola/heladeras-prendido.png`

## Verificación automática

- `gdformat --check` y `gdlint` en verde sobre los scripts tocados.
- Suites gdUnit4 en verde: `oclusion_de_la_gondola_test.gd` (7/7), `oclusion_de_contacto_test.gd` (19/19), `oclusion_de_contacto_apoyo_test.gd` (3/3), `oclusion_de_los_objetos_test.gd` (4/4), `luz_durante_el_corte_test.gd` (5/5), `productos_con_materiales_test.gd` (2/2), `huecos_de_la_gondola_test.gd` (4/4), `vencidos_de_la_gondola_test.gd` (1/1) y `reposicion_manual_test.gd` (completa).
