# Evidencia de #309: avisos de llegada y lector lleno

Base certificada: `41f30b0040aa843f45a89c7cee02fbfa08ad8929` (#304).
Cabeza final: `fe620b92a38b556f27fff721d162c466c1e784fb`.
La nativa final y los últimos focales usaron `c315ccd5`; la única diferencia hasta la cabeza
final es `status: draft` → `status: ratified` en el spec. El inventario está en
`metadatos-finales.json`: veinte rutas dentro del alcance publicado de #309.

## Resultado y límites de lo observado

Los dos avisos se ven arriba a la derecha sobre ventanilla y computadora, con los símbolos
originales de Figma, texto legible y fondo crema. La nativa final contiene ocho PNG abiertos
y revisados a 1920 × 1080 y 1280 × 720: ventanilla, computadora, lista desplegable real antes
de Esc y pausa después de Esc. `nativa-2/nativa309.log` registra 70 validaciones y cuatro
eventos nativos enviados a la ventana propia; termina con el montaje liberado. Cero ERROR,
ScriptError, ObjectDB o recursos pendientes en esa corrida final.

El desplegable real permanece abierto antes de Esc y el aviso es visible simultáneamente.
Sus rectángulos no se cruzan en estas capturas: no se afirma haber probado una superposición
artificial sobre una Window. Después de Esc las listas están cerradas y el menú de pausa
está encima del aviso. Tras 3,1 segundos pausado, reanudar conserva aviso, programa, selección
y mano, sin reabrir listas; completar los tres segundos de juego retira el aviso. RIGHT
cierra el programa y devuelve el control, conservando la mano. No se cambia la escala de
tiempo del juego ni la configuración de los menús de #303.

FULL1 sobre la cabeza publicada pasó los siete nodos sin salteos en 715,9 segundos
(tests: 710,2). El conteo inmediato confirmó 207/207 suites y 1632 casos, cero fallos,
errores, salteos y flaky. XML SHA-256:
`156d3de5981150326aed54dc951c6450647fc7b6e7dce803d978d381d2bdc156`.

Los 22 casos propios pasaron en tres suites: doce de dominio, seis UI y cuatro de escena.
El test de clic usa el botón Notas real y comprueba primero que el cartel cubre el punto del
clic, a ambas resoluciones. Los índices de dibujo se contrastan con todas las interfaces,
incluido el diálogo; pausa es un override de instancia y su recurso no se edita.

## Historial conservado

| Corrida | Resultado real | Causa / lectura |
|---|---|---|
| RED dominio | 12 casos; 13 aserciones fallidas; sin error de parseo | API completa con comportamiento vacío; rojo válido antes de implementar |
| GREEN dominio | 12/12 | Reglas de identidad, motivos, tiempo, orden y cierre |
| GREEN all, primer intento | Rojo UI y huérfanos | Premisa de viewport del runner y tarjetas quitadas del árbol con queue_free; ambos corregidos |
| GREEN all2 | 22/22, cero huérfanos | Viewport explícito y free inmediato de las tarjetas de presentación |
| GREEN all3 | 22/22, cero huérfanos | Mismo comportamiento con los SVG originales finales |
| Nativa 1 | Descartada; driver exit 1 | La sonda emitía llegada sin preparar la atención; dos ScriptError de montaje. Sus ocho PNG y log se conservan |
| Nativa 2 | Exit 0; 70 validaciones; ocho PNG; cuatro eventos | Usa abrir/cerrar la ventanilla real y los SVG finales; cero diagnósticos inesperados |

Los focales incluyen diagnósticos heredados del arranque de la base: los dos mensajes del
debugger deshabilitado y el directorio de guardado aislado que aún no existe. No se presentan
como salida cruda limpia. El arreglo de arranque está separado en HARN/PR341 y no se duplica
en esta rama. FULL1 tiene cero categorías nuevas respecto al RAW de #304. Los errores
coinciden en tipo y conteo: material 24, meta 98, Transform3D 3, tamaño de cámara 2,
arranque 1, puerto 0 y guardas negativas, más ObjectDB 1 heredado. No son errores propios
introducidos por #309; tampoco se dan por correctos. Los fixes centrales HARN/PR341 y
fixtures/PR353 se integran aparte. Los rescates esperados son 31 frente a 30 en la base;
sus nombres automáticos y poses varían. No se afirma igualdad del RAW ni atribución
individual de esa variación. `full1-resumen-y-diagnosticos.json` compara categorías,
conserva el primer contexto y enlaza el RAW base exacto con su SHA-256.

La especificación se creó primero en `3fe080b9`, antes de fuente. Por una carrera de mensajes,
ese primer commit precedió a la publicación del cuerpo corregido por el padre. El ajuste
durable de términos quedó en `868f485c`, antes de implementar; la cronología no se reescribe.

## Arte y procedencia

Los primeros SVG del preflight tenían rectángulo gris; esas exportaciones históricas de
572/365 bytes se conservan en `figma/notificacion_*.svg`. No se recortaron ni redibujaron.
Se volvió a pedir get_design_context a los frames y se copiaron byte a byte sus exportaciones
actuales transparentes, conservadas como `figma/live_*.svg`:

| Símbolo | Frame / grupo de origen | Bytes | SHA-256 |
|---|---|---:|---|
| Cliente | 243:150 / 213:191 | 580 | 79fd6c1fde10475cdcb5d98f67afdc1c82499a6706f5828c85075ccf6503b8ae |
| Lector | 477:243 / 480:319 | 371 | 55376ab11eba930cf0a915fbf3d56c135a56a44dff92ceea5e3faec1ed42b4af |

Archivo Figma: `SQEAfczyRvyOHokmzPOee7`. Las dimensiones originales son 155 × 175,123 y
138 × 140,09; Godot informa sus tamaños enteros 155 × 176 y 138 × 141. No se modifica el SVG
para igualar esos enteros. Los hashes finales se comprueban contra los bytes del repositorio.
`historico-preflight/` es historia sobre bases anteriores: no sustituye esos metadatos finales.

## Protocolos y aislamiento

Toda ejecución de motor pasó por la cola FIFO absoluta del lote. `protocolos/` conserva el
runner focal, la sonda final, el driver Win32 y el wrapper de full/conteo. El driver es
PER_MONITOR_AWARE_V2, verifica PID, ejecutable y parentesco, y envía PostMessage sólo a su
ventana. APPDATA propio, sin guardar estado del usuario. No hay copias de proyecto en este
paquete ni dentro de otro checkout. El protocolo nativo conservado es el final; no se afirma
que sea una copia byte a byte del protocolo defectuoso de la primera nativa.

`focales/xml/` conserva los once reportes focales en orden. `registros/` reúne la salida de
la cola y FULL1 con RAW completo y XML; el conteo corre inmediatamente después de verificar
en el mismo proceso FIFO. `manifest-sha256.json` permite comprobar cada blob publicado;
también conserva tamaño/hash de la copia original antes de la normalización CRLF → LF que
Git aplica a los archivos de texto. La primera publicación tenía hashes de esas copias en
la columna de blobs; la revisión de los blobs detectó y corrigió esa diferencia de finales
de línea. Los PNG y SVG conservan sus bytes originales.

## AC → test → resultado

Los nombres completos están en las tres suites de la cabeza final. Todos estos casos pasaron
en GREEN all3 y FULL1 confirmó el conjunto completo del proyecto.

| AC-NTF | Test principal | Resultado |
|---|---|---|
| 001 | test_reabrir_con_el_mismo_comprador_no_reinicia_el_aviso; test_otro_comprador_renueva_el_tipo_sin_duplicarlo; test_la_ventanilla_abierta_avisa_una_vez_y_el_cierre_vacia | Verde |
| 002 | test_el_lector_avisa_solo_por_renglones_llenos; test_la_caja_publica_el_motivo_y_solo_lleno_avisa; test_el_programa_manual_no_publica_rechazo_ni_aviso | Verde |
| 003 | test_el_aviso_sigue_a_2_9_y_sale_a_3_0; test_un_cuadro_largo_saca_todos_los_avisos | Verde |
| 004 | test_repetir_el_tipo_lo_pone_primero_y_reinicia_solo_su_tiempo; test_repetir_un_tipo_no_renueva_el_otro | Verde |
| 005 | test_los_tipos_se_ordenan_del_mas_nuevo_al_mas_viejo; test_modificar_la_lista_devuelta_no_borra_lo_visible | Verde |
| 006 | test_vaciar_borra_ambos_tipos_y_olvida_compradores; test_vaciar_retira_los_carteles_del_arbol | Verde |
| 007 | test_null_y_avances_no_positivos_no_cambian_el_estado | Verde |
| 008 | test_pausar_suspende_el_procesamiento_sin_borrar_el_aviso; nativa real pausa/reanudar | Verde |
| 009 | test_los_textos_se_pintan_en_el_orden_del_dominio; test_los_dos_carteles_entran_en_la_esquina_en_dos_resoluciones; ocho PNG finales | Verde |
| 010 | test_ningun_control_de_la_pila_intercepta_el_mouse; test_el_clic_sobre_el_cartel_llega_al_boton_de_notas; test_la_pila_se_dibuja_sobre_las_interfaces_y_debajo_de_pausa; nativa real Popup/Esc/RIGHT | Verde |
