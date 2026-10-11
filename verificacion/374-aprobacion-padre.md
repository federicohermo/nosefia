Revisión del padre de #374 sobre producto `4b589ec60b56c3b21c0145aa826d7881dbd5be2e`.

Abrí individualmente las siete fotos FINALES del generador. Cada una muestra su tema;
Intro 11 incluye mopa y balde completos y ambas notas; Intro 9 muestra cajas en estantería
y Intro 13 las pilas de jornada 1 con el estante vacío. Rayos finales 7/7, log sin diagnósticos.
Las huellas de esos mismos PNG están en `374-fotos-finales-aprobacion-padre.json`.

Abrí las doce capturas nativas (seis estados por resolución) y las catorce capturas web
(siete estados por resolución), a 1920×1080 y 1280×720. Aprobadas: primer paso sin Volver,
foto antes del texto, botones bajo el último paso, texto final y Comenzar, nombre/retrato/rol/
footer, placa NOCHE 1, chat y foto ampliada con su texto completo y negritas. Continuar muestra
NOCHE 3 y no muestra instrucciones. No hay caracteres faltantes ni recortes indebidos.

Leí ambas consolas web completas: sólo mensajes de arranque/carga y marcador de checkpoint;
sin errores. Contrasté `web-medidas.json` contra `textos374.json`: los catorce textos literales
coinciden exactamente en ambas resoluciones. Siete rutas de fotos, RAF 120/110, errores vacíos.
Presupuesto 43200 al primer paso, al paso 14 y durante la placa; disminuye después, durante
el uso real del celular. El checkpoint real carga jornada 3, medios 7, presupuesto 43200,
instrucciones ocultas. El navegador observa mediante CDP pasivo y usa entradas físicas.

Revisé el mínimo verde de dominio (3/3) después del rojo previo por 17 aserciones, sin SCRIPT.
Los focales aprobados ejercen UI 4, escena 7, entrada 6, menú 10, Partida 18 y celular 14.
El focal 1 preserva dos fixtures que no parseaban; focal 2 corrige tipos explícitos y pasa
UI/escena. Su crudo conserva errores del debugger 127.0.0.1:0 y la retención heredada en UI;
no se presenta como salida completamente limpia. La full formal se evalúa por separado.

Export/PCK y captura nativa usan la misma cabeza. El preset coincide con el versionado;
el aislamiento de plugins, main_scene y carga dinámica pertenecen sólo a la copia externa.
Se conservan el import frío y el warm verbose que identificaron referencias retenidas del
fixture; import warm2 y export2 estrictos quedan limpios. El paquete comprueba los diálogos
existentes y las 21 entradas nuevas, sus 14 textos, siete fotos y retrato.
# Adaptación posterior del fixture

La cabeza 9113524fa8391cae6e6545d62c9070637c765ae8 añade únicamente siete líneas al helper `_elegir_nuevo_juego()` de `test/escenas/carga_del_almacen_test.gd`, dentro del alcance publicado antes de editar. Conserva los seis casos y todas sus aserciones; añade que la carga permanece oculta durante el fundido. El diff completo contra 4b589ec60b56c3b21c0145aa826d7881dbd5be2e no modifica producto, recursos, preset ni generador. Las siete fotos y los recorridos finales de escritorio y web aprobados sobre 4b siguen representando exactamente el producto entregado.

La cabeza a9b695472165b55bd2faaab1773d139680d68c85 cambia además dos líneas del fixture nuevo de dominio: la constante conserva la ruta del mismo guion y el caso lo carga localmente. Revisé el diff completo; todas las aserciones permanecen idénticas. Los controles equivalentes de descubrimiento completo vuelven de 123 a 100 recursos tanto ejecutando Consecuencia como Instrucciones. El focal real conserva 3/3 casos y no retiene recursos. El producto sigue siendo idéntico a 4b; las capturas y export mantienen su aprobación.

La tercera completa sobre a9 pasó 7/7 en 747,3 s, tests 741,3 s, con conteo inmediato 239/239 suites y 1823 casos, cero fallos, errores, flaky, skipped, huérfanos y SCRIPT ERROR. La lectura independiente del padre confirma 141 ObjectDB/100 recursos y los mismos PagedAllocator heredados. La comparación conserva los 60 diagnósticos de #373, normalizando sólo sufijos numéricos de nodos. Dos advertencias de rescate de Balde varían sus coordenadas entre 1 y 2 millonésimas; el JSON publica ambas coordenadas exactas, sin redondearlas. No hay nuevas categorías de diagnóstico. Entrega aprobada para publicar PR y evidencias; la integrada final del padre se encoló sólo después de esta revisión.

