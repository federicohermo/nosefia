# Desfase del contrato y la fuente de Duronga

Se conserva el diagnóstico anterior completo: no se reescriben crudos ni se presentan los
ceros de Duronga como aceptación del contrato vigente.

La fuente Notion tiene una respuesta de Tiago del 15/10/2026 a las 18:25:14.413 UTC,
comentario `3fa86efe-cd9d-80a9-b6dc-001d84ccea09`, que mantiene Duronga exhibible hasta
su reemplazo futuro. El mapa sitúa su tanda inferior derecha de la estantería de no
comestibles, con Poético a la izquierda y Actroncito/Durextra arriba.

`fetch(include_discussions)` devuelve una vista con sólo el comentario previo de las
16:41 y cuenta uno. `get_comments(include_all_blocks, include_resolved)` devuelve ambos
comentarios. La vista resumida no acredita que no haya una respuesta posterior. Se
preservan ambos resultados completos y el PNG descargado (SHA5606fab8231186ab6676cebe2fb9acf06fc3268ff58c8a6e9f819aceac4ab0cb).

En c780, el reparto y BR-STK-044/AC-STK-088/089 todavía declaraban Duronga sólo-depósito.
El cuerpo GitHub ya tenía exhibición provisional en su objetivo y notas, pero retenía
contradicciones de cupo cero en Contrato y una OQ008 pendiente. El carril continuó con el
alcance anterior y no detectó esa inconsistencia al actualizar las filas. Es un fallo
de contraste de la fuente completa; no una nueva decisión sobre las filas.

La historia remota del issue se preserva en `issue-historia-ediciones.json`, con 12 ediciones
y sus fechas registradas por GitHub. La edición de 16/10/2026 02:05:02 UTC contiene ya
la decisión de Tiago y exhibición en su texto, mientras mantiene partes contradictorias.
`historia-resumen.json` facilita ubicar esas entradas. No se deducen horas de publicación
desde fechas de git o mtimes de archivos locales.

La corrección elimina contradicciones del cuerpo ENTERO, fija el destino visible medido y
actualiza el spec ANTES del reparto: commit19b7ee73. BR-STK-044 y los AC conservan sus IDs;
la capacidad futura de sólo-depósito queda separada de Duronga. Los tests de reparto
existentes pasan primero por cinco aserciones rojas y luego 27/27 verdes. Los casos D0
previos y su pipeline fallido quedan como historia del alcance anterior, no como prueba
de la exhibición nueva. La cabida y alcance del reparto actualizado todavía deben medirse.

OQ-STK-008 permanece resuelta: Actroncito y Prongles conservan las dos hileras que ya tenían.
OQ-STK-007 no se cierra ni autoriza nuevas alturas, chapas u orientaciones.
