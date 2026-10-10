# Evidencia de #370

Cabeza de producto probada: `35009014d90c61bd0d719d7744e134bab99a7519`.
Base fijada antes de editar: `270506c1d5e72c8da2ccd1289621fd3e0d358ca3`.
Base integrada antes de producción: `a59b80ad906c04e669a83c7649db0f23242c95dc` (#369 corregido, #301 y contratos).
Primera publicación de seis PNG: `537fbba7224a4f211cfffbe49a3e0c417d5d3323`; se conserva como ancestro.

## TDD y lectores

- `370-rojo.log` / `report_1-results.xml`: 1/1 caso, cero errores y tres aserciones fallidas: J1 todavía mostraba sus tres bolsas. Es un rojo observable, anterior a la implementación.
- `370-rojo-dominio-sistema2.log` / `report_2-results.xml`: 4/4 suites, 28/28 casos, cero errores y veinte aserciones fallidas. Las firmas mínimas ya existían; fallaban la cantidad por jornada, extracción, entrega del mismo cuerpo, evento y título de la nota.
- `370-inversion-inicial2.log` / `report_3-results.xml`: primer barrido completo de 25/25 lectores, 212/212 casos, 37 aserciones fallidas y un error. El error preciso fue `rescates[-1]` sobre array vacío en `red_de_seguridad_integrada_test`: la bolsa oculta de J1 no tenía forma habilitada, por lo que `RedDeSeguridad.revisar` no la revisó ni produjo rescate. También falló la expectativa de un depósito de ese caso. Se corrigió su precondición de bolsa real en J2, sin alterar auditoría ni umbrales.
- El lector, notas, dos matrices de caja, dos matrices de puertas/paneles y la mezcla de útiles daban verde tomando una bolsa oculta de J1. El padre publicó el issue entero con siete precondiciones precisas antes de editarlas. La apertura J2 ocurre antes de tickets, puertas o cargar y mezclar agua; no se trasladaron esas suites enteras a J2.
- `370-lectores-verde1.log` / `report_4-results.xml`: 24/24 suites, 203/203 casos, cuatro errores y dos aserciones fallidas. Tres errores eran búsquedas de una bolsa que el nuevo ayudante había dejado bajo el ancla de respaldo después de sacar→soltar; el cuarto era un assert_array añadido sobre el conteo entero de bolsas. El ayudante conserva ahora el padre original y lo restaura mediante reparent, después de que Agarre restaura las capas; se usa assert_int. Este intento se conserva y no se presenta como verde.
- `370-lectores-verde2.log` / `report_5-results.xml`: 24/24 suites, 203/203 casos, cero errores, fallos, flaky, skipped y orphans, 8 min 9 s 875 ms de motor. Incluye todos los lectores modificados y los seis casos nuevos de escena.

Los archivos en `borradores-testigo/` son borradores de sesión conservados: los dos primeros son fragmentos anexados a sus suites y el tercero es una versión temprana de la suite de escena. No se presentan como una copia exacta de todas las fuentes de cada intento. `protocolo/370-stubs.py` documenta las firmas mínimas usadas para el rojo puro. `fuentes-finales/test/` contiene los blobs exactos de las pruebas y ayudantes del commit protegido; los XML y crudos identifican cada caso efectivamente ejecutado. La corrección UTF-8 conserva los comentarios heredados y se documenta en `370-reparar-texto.py`.

## Intentos invalidados conservados

`370-rojo-dominio-sistema.log` conserva el error de parseo del iterador de jornada sin tipo; no es evidencia de TDD válida. `370-inversion-inicial.log` conserva el intento con `Tacho.size()` no constante; la implementación usa el último enum contiguo más uno. `370-capturas1.log` conserva la opción de resolución inválida `1280,720`; se corrigió a `1280x720` antes de tomar los PNG aprobados.

## Convergencia

Full1: **7/7 nodos verdes en 778,2 s**, sin nodos omitidos. Tests: 771,2 s; gdUnit: 232/232 suites, 1774/1774 casos, cero errores, fallos, flaky, skipped y orphans, 12 min 31 s 603 ms de motor. Conteo inmediato report_6: 232 suites corridas y 232 archivos.

El contraste de stdout+stderr con 369-final-2-tests.log conserva todas las líneas ERROR y su multiplicidad, sin SCRIPT ERROR nuevo. Persisten exactamente los avisos heredados de salida: 141 ObjectDB, 100 recursos y PagedAllocator. Los cambios de warning son IDs automáticos, redondeos de coordenadas y el rescate de BolsaDeBasura1 solicitado por el caso nuevo. Los errores de puerto 0 y assert_error se identificaron por sus trazas. Harness: 577 tests, un caso condicionado heredado (sin .res comprimidos), nodo verde.

`370-final-1.log` conserva el resultado de los siete nodos y el conteo inmediato; `370-final-1-*.log` conserva stdout y stderr de cada nodo y de la importación, incluso en verde. `conteo-full1-inmediato.txt` es un extracto identificado de ese stdout, no una nueva ejecución. El XML de la última corrida y `full1-godot.log` complementan el crudo.

## Capturas

`370-capturas2.log` termina con CAPTURAS_370_OK, sin errores ni avisos de fuga. Son seis PNG de jornada 2, antes/después de sacar cada bolsa, abiertos individualmente por el carril y por el padre. El padre aprobó los encuadres consistentes, la caja genérica acordada en la boca y luego en mano, y los tachos contorneados. Se conservaron cuerpos, arte y geometría.

El guard valida el piso libre real, cápsula, alcance, foco, rayo, contorno, estado de la bolsa y pose física/dibujada antes y después de frame_post_draw, justo antes de save_png. Las distancias reales al foco son 1,058 m local y 1,273 m escritorio/baño. Al desmontar se detiene el audio y se libera su stream antes de queue_free. `protocolo/370-capturar.gd` y `370-render.py` preservan el procedimiento.

## Publicación y procedencia

`manifiesto.json` registra bytes, SHA256 y OID de cada blob publicado, incluidos los seis PNG originales. Se calcula leyendo git cat-file blob después de publicar los contenidos y se verifica otra vez contra la cabeza final y cada URL raw por commit. La procedencia local se registra por separado y no sustituye los hashes publicados. El manifiesto se excluye de su propio hash para evitar circularidad.
