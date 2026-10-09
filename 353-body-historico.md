Una escena vacía escribía un tamaño de cámara inválido, las cargas fallidas dejaban pedidos pendientes y destruir cajas rotuladas producía errores de material. Se conserva el ancho exacto de geometría válida, se retiran los pedidos FAILED antes de avisar y se libera el override de superficie sólo en PREDELETE. Reparentar conserva la etiqueta.

Los fixtures se montan antes de leer transforms globales; el MultiMesh dibuja una instancia real y la metadata ausente usa un default válido. Las guardas conservan sus comprobaciones funcionales y verifican los errores deliberados. El veto lexical de todo `if`/`match` de la caja se reemplaza expresamente por pruebas de reparent, identidad, textura y liberación. Las políticas de cupos siguen en el dominio.

Base: `harness/64-309-actualizar-el-preflight` (`02e3562c`). Cabeza: `cd994731`. Alcance final: once GD, sin cambios de escenas, specs, assets ni addon. Los nueve archivos anteriores conservan blobs idénticos a `55af8724`; el range-diff de los tres commits del rebase es `= = =`.

| Criterio | Prueba | Resultado |
|---|---|---|
| F1, F9: vacío termina; geometría válida conserva ancho | `calentamiento_de_shaders_test`: vacío y material reemplazado | RED por size inválido y RED2 por 1.0 frente a 0.2; GREEN2 19/19 |
| F2: MultiMesh real conserva recuento | `test_el_material_de_un_multimesh_cuenta_como_nuevo` | Verde |
| F3: falta de metadata no exime; razón escrita sí | `volumen_de_los_solidos_test` | 5/5 |
| F4, F5: transforms con montaje válido y estado conservado | `indicacion_del_foco_test`, `mancha_en_el_piso_test` | 3/3, 11/11 |
| F6, F7: guardas emiten su error sin efectos indebidos | `examen_test`, `ventanilla_test` | 20/20, 14/14 |
| F10: FAILED retirado; fallo único y reintentos | `carga_en_segundo_plano_test`; consumidor `carga_del_almacen_test` | RED2 FAILED frente a INVALID; GREEN2 7/7 y 6/6 |
| F11: giro conservado, sin cambiar suite ni umbral | `giro_parejo_test` | Focal 8/8 |
| F12, F14: reparent conserva materiales, producto y datos; free nunca montado válido | `test_reparentar_conserva_las_etiquetas_y_destruir_no_da_error` | GREEN3g |
| F13: liberar dos cajas válidas no emite error | `test_la_caja_tiene_el_tamano_que_le_da_el_catalogo`, conservando todas las aserciones de tamaño | RED3f 1 fallo por materialNULL en assert_error:113; GREEN3g |
| Regresiones de caja llevada y recibida | `caja_que_se_lleva_test`, `caja_que_recibe_y_cuenta_test` | GREEN3g 20/20 y 10/10; conjunto 45/45 |
| F8: convergencia y conteo inmediato | `verificar.py` original, siete nodos; `conteo.py` en el mismo turno FIFO | FULL3 7/7,697.0s;191/191 suites,1496 casos;0 fallos/errores/skips |

La salida cruda de GREEN3g tiene cero materialNULL, ObjectDB y recursos en uso. Conserva únicamente los dos diagnósticos deliberados de `--remote-debug tcp://127.0.0.1:0` por proceso.

Se conserva el historial completo: FULL1 6/7 por un caso de giro, FULL2 de nueve GD 7/7 (191 suites/1496 casos) con 24 errores materialNULL en GC. RED3 inválido por parseo y RED3b/c/d/e verdes inesperados permanecen identificados; no se presentan como rojos. RED3f es el rojo funcional válido. La matriz localizó 19 de los 24 errores y dejó cinco sin atribución focal; FULL3 demuestra la eliminación global (24→0 materialNULL,0 ObjectDB,0 recursos), sin inventar el origen individual de esos cinco.

Evidencia: [FULL3 XML](https://raw.githubusercontent.com/federicohermo/nosefia/capturas/fixtures-64-309/final-11gd/full3-results.xml), [raw completo](https://raw.githubusercontent.com/federicohermo/nosefia/capturas/fixtures-64-309/final-11gd/full3-tests-crudo.log), [verificación y conteo](https://raw.githubusercontent.com/federicohermo/nosefia/capturas/fixtures-64-309/final-11gd/full3-verificar-y-conteo.log), [comparación global](https://raw.githubusercontent.com/federicohermo/nosefia/capturas/fixtures-64-309/final-11gd/full3-comparacion-global.json), [RED3f XML](https://raw.githubusercontent.com/federicohermo/nosefia/capturas/fixtures-64-309/final-11gd/red3f-results.xml), [manifest de evidencia e historial](https://raw.githubusercontent.com/federicohermo/nosefia/capturas/fixtures-64-309/final-11gd/manifest-sha256.json).


El raw final conserva los diagnósticos deliberados del debugger (2), guardas de Disposición (1), Examen (1), Ventanilla (4), carga inexistente (3+3) y rescates de fixtures. No se presenta como ausencia de toda línea ERROR.

CI de la misma cabeza `cd994731`: [siete nodos verdes](https://github.com/federicohermo/nosefia/actions/runs/37904332850), sin salteos, 687.8 s. XML descargado y revisado por el padre: 191 suites y 1496 casos; cero fallos, errores, salteos e inestables. SHA-256 XML: `76da4f17b1f0df3076a7559e99f45a1dcd7790d03fa9afff9a4ade1f7ab55dd5`.
