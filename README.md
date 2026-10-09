# Lectura de las cinco notas existentes — #298

Cabeza de producción: b22e7f8f, sobre e3689678. Las mallas, hojas, materiales, imágenes, colisiones y luz horneada del artista permanecen idénticas.

Cada nota tiene captura en el mundo y lectura ampliada a 1920×1080 y 1280×720: IDs0tareas,1ordenado,2jabones/manchas,3instrucciones,4inodoro. Sólo los dos soportes del corcho reciben textos nuevos comunes al dato y a la lectura. Las otras tres vistas amplían su imagen original completa.

TDD válido: a-298-rojo-2.log,6/6suites31/31casos113fallos de aserción,0errores/skip/huérfanos. El primer rojo conserva el diagnóstico de un literal ñ dañado en el cableado antes de corregirlo; no cuenta como witness. Primer verde detectó dos aserciones de fixture null.is_same(null), luego corregidas. Verde ampliado:10/10suites81/81casos,0errores/fallos/skip/huérfanos.

Sonda final de foco y desmontaje: a-298-foco-montaje-final.log. Wrapper exige los marcadores de finalización y rechaza ERROR/fugas; alcanza las5hojas desde piso real y cápsula libre. El verbose previo identifica fugas temporales de audio y se conserva como diagnóstico; no se presenta como evidencia limpia. La sonda final detiene y libera exclusivamente las voces del montaje externo antes de salir.

Rendimiento y captura definitivos: a-298-evidencia-final-2.log. Frente al baño: medias0,111844/0,11753025ms (mano vacía/unidad), máximos por lote0,12969/0,19134ms, bajo0,5ms. Pasillo: medias0,017071/0,01733125ms,1candidato y0hojas. Antes:0,0881175/0,08594025ms frente al baño; pasillo0,016834/0,016503ms y0hojas.40lotes de100llamadas por escenario. Arte y posiciones no se ajustan para la sonda.
