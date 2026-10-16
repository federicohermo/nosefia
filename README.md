# Evidencia de #437 — Fede y Mía

PR [#470](https://github.com/federicohermo/nosefia/pull/470), cabeza propia
`838e0baae3ed7f61f6f3190a00058a5d6c10b503`, base #433
`d8c0d8cb5a6e3d968d9cd8fd04f4a12c17829875` con #429 incorporado.
La exportación compartida #437+#444 usa
`4fa20754cd58c7f4a62699183a4a625df3e0d90a`. El usuario ordenó terminar antes de
17:30 ART, sin más verificaciones locales, dejando la validación al PR. Por esa
instrucción se cancelaron la completa local conjunta y las capturas compartidas.
Esta publicación preserva lo ejecutado y sus límites: no hay completa local final
verde ni un recorrido de capturas reales completado y aceptado de Fede/Mía. El PR queda listo para revisión con CI propia
verde; eso no marca cumplidos los ocho criterios ni equivale a aceptación final.

| Evidencia | Ubicación |
|---|---|
| Focal propio: 9/9, exit 0, cero fallos/errores/saltos/flaky | `focal-verde-02/` con canales crudos, XML, comandos y pines antes/después. |
| Congelación: 40 blobs coinciden con commit; pre/post iguales | `documentacion/revision-pines-B.json`. |
| CI exacta: 7/7 nodos, 286 suites, 2181 casos, cero problemas | `ci470-838e/`, workflow íntegro y XML descargado; [run 38957377068](https://github.com/federicohermo/nosefia/actions/runs/38957377068). |
| 16 PNG byteidénticos a originales, dos idle y tabla | `procedencia/` y `documentacion/437-head-manifest-B.json`. |
| Export final: import/export/guardias/probes exit 0 | `export-final-437-444-02/`, con `huellas.json`, protocolo, revisión y ambos canales/cronología. |
| Import frío Windows previo interrumpido nativamente | `incidentes/import-frio-nativo/`; código 3221226356 sin causa atribuida. |
| Rojo funcional y primeros intentos conservados | `intentos/`; el rojo01 falló por helper inválido y no se cuenta como rojo funcional. |
| Completa local final cancelada por instrucción del usuario | `full-final-parcial/`; acta, pines y resultados parciales. No cuenta como convergencia verde. |

El componente de capturas reales del séptimo criterio permanece pendiente: los
tests ejercen pose, alfa, foco, oclusión y ciclo, y el PCK carga los recursos, pero
no sustituyen capturas de cada comprador con panel abierto/cerrado después del
dibujo. No se fabrica ni se reutiliza una imagen de Tin/Tia para cubrirlo.

La CI utiliza checkout/import fríos Linux. El export Windows inicial documenta
ausencia previa de los dieciséis `.ctex` nuevos sobre caché base. El export final
usa esa caché, comprueba continuidad binaria de las dieciséis texturas y no se
presenta como una segunda importación fría. HTML, JS, PCK y WASM coinciden
byte a byte entre ambos exports. El PCK final tiene 109308012 bytes y SHA256
`9a974e7cdc6ffebe3017b2aafc7b91ec5843dc55c17728d087585deda93a5fc5`.
No se incluye PCK, WASM, archivo ZIP ni caché en esta publicación.

Las sondas externas finales terminan con `SPRITES437_PCK_OK` y
`PAQUETE444_FINAL fallos=0`, sin errores de script/parseo, ObjectDB, recursos,
Pages ni StringName retenidos en esos crudos. El primer probe444 se conserva
fallido: su selector tomaba un Node3D de la estructura como ticket. Se corrigió
únicamente la sonda versionada y se reexportó la nueva cabeza; los cuatro
artefactos resultantes siguen idénticos. No se atribuye ese fallo al producto.

El focal verbose propio conserva dos errores de conexión al depurador por el
argumento heredado `127.0.0.1:0` y 38 StringName de tipos builtin al cerrar; no
contiene SCRIPT ERROR, Parse Error, ObjectDB, recursos ni Pages retenidos. Los
canales se mantienen completos. Esa salida no se llama silenciosa ni se usa para
anticipar el resultado de la completa local conjunta.

Los archivos bajo `reproduccion/` son copias documentales de los controladores
externos usados. Sus rutas absolutas registran el entorno de ejecución original;
reproducirlos exige destinos externos propios y el preset/plantilla aprobados.
Los pines contienen los originales usados por la prueba, sin modificar su PNG.

El intento compartido adquirió FIFO al liberarse el turno de la completa: Web salió 1 y el nativo se interrumpió por instrucción del usuario. Se conservaron siete PNG Web y uno nativo como incidente parcial, sin nueva inspección ni aceptación visual. No se afirma ausencia total de imágenes ni se usan para completar el criterio. Acta, crudos y archivos parciales están en `capturas-parciales-no-aceptadas/`.
