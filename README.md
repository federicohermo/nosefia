Evidencia de #373, cabeza final `f0c37482a315972d4de58020e6a247e78d7a55f3`.

Producto exportado y renderizado: `33828836d19b8913efbc0c3d2dc09186b5af13f6`. `diff-producto-a-final.patch` contiene sólo
el orden de la declaración exportada de imagen y el nombre de un test; sus cuerpos, datos,
callbacks, proyecto, preset y arte se conservan. No se usa una captura de un producto distinto.

Verificación final: 7/7 nodos, 236/236 suites y 1808/1808 casos.
El conteo de archivos se ejecutó inmediatamente al terminar el verificador. La primera
convergencia fue 6/7, con gdUnit íntegro verde y sólo lint rojo; se conserva completa.
No hay errores de script ni huérfanos de gdUnit. El diagnóstico completo de motor coincide
con #370 incorporado, normalizando únicamente IDs autogenerados de nodos; todos los warnings
se conservan. `base/harness-tests.log` también conserva la medición anterior de 141 ObjectDB,
100 recursos y PagedAllocator, con stdout y stderr (el antiguo log de motor aislado omitía stderr).

Las PNG de la raíz y sus métricas son las capturas finales aprobadas, a 1920×1080 y 1280×720.
Web usa Chrome que dibuja, CDP pasivo userGesture:false, física/reloj reales y ningún wrapper
de solicitudes; Q es el primer gesto después de la placa. Consolas completas sin errores,
RAF 133/138, seis fases de lock false/false/false/true/false/true. Se observa el lock real del DOM.
La foto de esta prueba usa dos mensajes efímeros, una persiana y el adjunto largo de 292caracteres;
no modifica los tres guiones literales del juego. La flecha geométrica se ve en ambas plataformas.

`paquete/` conserva el import frío, export warm, sonda PCK estrictos limpios y SHA256 de todas
las piezas. El preset es el versionado exacto; sólo se deshabilitan editor_plugins en la copia
externa y se cambia su main_scene para observar el flujo real. `arnes/` conserva sus fuentes.

`verificacion/` contiene rojos por aserción y focales verdes. `tdd/` contiene las huellas y
fuentes conservadas del rojo UI y los dos contrastes de cursor. El segundo rojo de cursor es
posterior al primer mínimo verde y corrige el getter headless del fixture: no se afirma que
esa segunda repetición haya precedido a la implementación. Los rojos de dominio/sistemas
precedieron a sus mínimos verdes; no se inventan hashes de sus fuentes originales no guardados.

`historico/` conserva intentos inválidos: fixtures con scripts/World3D/referencias defectuosas,
cache global no reimportada, primer export frío con 8 recursos, observador activo y recorridos
web que rechazaron el cursor antes de la corrección de cáscara. Sus PNG y logs NO cuentan
como evidencia aprobada. La clasificación y los resúmenes están en 373-trazabilidad-TDD.json.

`sha256.json` lista bytes y SHA256 de cada artefacto previo al manifiesto. La publicación se
contrasta además contra cada blob Git remoto y se informa su commit en el PR.
