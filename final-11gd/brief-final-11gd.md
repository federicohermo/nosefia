# Corrección independiente de calentamiento, carga y fixtures

Base final: `02e3562c1acb9dc4c768c9b33da2155b69792fdf`, rama
`harness/64-309-actualizar-el-preflight`. Candidato: `cd994731`, rama
`bugfix/64-309-calentamiento-y-fixtures-validos`. El padre autorizó este bugfix sin issue
nuevo, spec nuevo ni modificación de reglas jugables.

Una escena vacía podía escribir `Camera3D.size=0`; una carga FAILED no retiraba su pedido del
motor. Fixtures inválidos consultaban transforms sin montaje, metadata sin default o MultiMesh
sin instancia. Además, liberar una caja con material de superficie propio producía materialNULL
en el renderer dummy. La reproducción nativa válida con malla compartida y override duplicado
descarta una causa exclusiva del addon; retirar el override antes de liberar elimina el error.

La corrección conserva el ancho exacto de geometría válida, retira LOADED y FAILED antes del
aviso terminal y desmonta sólo el override0 de Malla durante PREDELETE. No lo hace al salir
del árbol: agarrar, devolver y reparentar deben conservar la etiqueta.

## Alcance cerrado

| Ruta exacta | Públicos finales | Casos |
|---|---:|---:|
| `src/sistemas/marco/calentamiento_de_shaders.gd` | 2 | 0 |
| `src/sistemas/marco/carga_en_segundo_plano.gd` | 2 | 0 |
| `src/escenas/objetos/caja_de_productos.gd` | 7 | 0 |
| `test/sistemas/marco/calentamiento_de_shaders_test.gd` | 19 | 19 |
| `test/sistemas/marco/carga_en_segundo_plano_test.gd` | 7 | 7 |
| `test/escenas/volumen_de_los_solidos_test.gd` | 5 | 5 |
| `test/escenas/indicacion_del_foco_test.gd` | 3 | 3 |
| `test/escenas/objetos/mancha_en_el_piso_test.gd` | 11 | 11 |
| `test/sistemas/investigacion/examen_test.gd` | 20 | 20 |
| `test/sistemas/tareas/ventanilla_test.gd` | 15 | 14 |
| `test/escenas/objetos/caja_de_productos_test.gd` | 15 | 15 |

No se escribe ninguna otra ruta, escena, spec, asset, import, addon ni herramienta del repo.
Los nueve archivos anteriores a la ampliación de caja conservan blobs idénticos a `55af8724`.
El rebase de tres commits sobre la base final dio range-diff `= = =`. Un archivo del worktree
normalizó finales de línea al checkout; el blob y el parche permanecieron idénticos.

## Criterios y pruebas

- F1: una escena vacía termina con progreso completo y sin error. Caso vacío existente de
  calentamiento; rojo inicial por tamaño inválido y verde posterior.
- F2: MultiMesh dibuja una instancia real y conserva recuento tras avances. Su fixture declara
  formato3D, instance_count1 y transform identidad; se conservan las aserciones originales.
- F3: ausencia de metadata no exime; clave vacía tampoco, razón escrita sí. Cinco casos de
  volumen conservan resultado con default String vacío.
- F4: el doble del jugador se monta con escena e hijos reales antes de consultar transforms.
  Se conservan señales, HUD y material_overlay, afirmando el montaje.
- F5: la mancha montada conserva visibilidad y colisión en limpia/sucia.
- F6: Examen sin cablear emite su push_error esperado sin revelar ni iniciar.
- F7: cuatro métodos de Ventanilla sin cablear emiten cada uno su push_error, sin efectos.
- F8: verificar.py original completo, siete nodos sin salteos; conteo inmediatamente en el
  mismo turno. Revisar raw completo además del XML y no ocultar errores de callbacks o GC.
- F9: geometría pequeña válida conserva ancho exacto. El caso existente afirma0.2; RED2
  observa1.0 con clamp. El setter final sólo evita anchos inválidos.
- F10: tras fallo, ResourceLoader informa INVALID porque se retiró el pedido. RED2 observa
  FAILED, luego GREEN7; se conservan señal única, listas0, progreso y reintento. El consumidor
  carga_del_almacen también se comprueba, sin modificarlo.
- F11: giro se repite sin cambiar suite ni umbral; focal existente8/8. Su fallo histórico en
  FULL1 se conserva y no se presenta como verde.
- F12: reparent conserva identidad de etiqueta, textura, producto y datos; malla y material
  genérico compartidos no cambian. Caso funcional nuevo reemplaza expresamente el veto
  lexical de todo if/match de la caja, que no verificaba reglas de cupo.
- F13: liberar dos cajas válidas con material propio no emite error. El caso de tamaño conserva
  todas sus aserciones y toma ownership explícito de dos cajas. detach/free ocurre dentro de
  assert_error.is_success, sin auto_free duplicado. RED3f falla exactamente por materialNULL
  en línea113 (15 casos,1 fallo,exit100); GREEN3g pasa con el hook mínimo.
- F14: liberar una caja nunca montada no emite error. get_node_or_null protege PREDELETE sin
  asumir _ready. El caso F12 retiene recursos y comprueba identidad/textura después del free.

## Evidencia y límites

GREEN3g completo: tres suites,45 casos (15 caja,20 caja llevada,10 caja recibida), cero fallos,
errores, skips y huérfanos. Raw: cero materialNULL, ObjectDB y recursos en uso. Sólo aparecen
los dos diagnósticos del puerto remoto0 explícito de cada proceso.

RED3 inválido por parseo y RED3b/c/d/e verdes inesperados permanecen archivados; ninguno se
cuenta como rojo. La prueba F12/F14 era verde antes del hook. El rojo F13 válido es RED3f.
Sondas nativas original1/PREDELETE0 conservan16 comprobaciones; retener o soltar la última
referencia de material no explica por sí solo la diferencia con GdUnit.

FULL1 histórico:6/7 por giro,191 suites/1496 casos. FULL2 de nueve GD:7/7,191/1496, cero
fallos/errores/skips y cero ObjectDB/recursos, pero24 materialNULL. La matriz readonly localizó
19 y dejó cinco sin atribución individual. FULL3 de once GD debe demostrar eliminación global
comparando raw completo; no se atribuyen los cinco a una suite sin haberlos observado allí.

Todas las corridas usan FIFO absoluto, árbol congelado desde encolar hasta terminar, APPDATA
de tests y logs nuevos. Commit y push preceden FULL3. El wrapper externo conserva la salida de
los nodos Godot y ejecuta el main original con sus siete controles; no sustituye sus checks.
Resultado final de FULL3 y CI: pendiente de finalizar, se agregará antes del PR certificado.
