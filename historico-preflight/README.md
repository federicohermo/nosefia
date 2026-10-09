# Preparación externa de #309

No es implementación entregada, no pasó Godot ni tiene PR. El worktree C de #327 queda
limpio. Todos estos archivos viven fuera de cualquier checkout. No copiar nada a una
rama de implementación hasta recibir la cabeza A304 certificada del padre.

## Fuentes leídas

- Issue vigente #309 descargado completo en `issue-309-vigente.json`.
- Issue vigente #302 descargado completo en `issue-302-vigente.json`.
- Ficha Notion 🟩 Notificaciones, `3e486efe-cd9d-808b-b505-c198429d316d`:
  arriba a la derecha, texto y símbolo, por encima de interfaces; cinco tipos en el diseño.
  #309 delimita dos, duración de tres segundos, debajo de pausa y corte por identidad.
- Figma `SQEAfczyRvyOHokmzPOee7`: frames `243:150` y `477:243`, contexto y captura leídos.
  Placa 1431 × 240, crema `#f0f4d1`, texto `#04060c`, Unscii 16, símbolo izquierdo.
  Se propone conservar proporciones a escala 0,4, con ajuste uniforme al viewport.
- Export SVG original del grupo cliente `213:191`: 155 × 176, 572 bytes.
- Export SVG original de la cruz `480:319`: 138 × 141, 365 bytes.
  SHA-256 y dimensiones están en `preflight.json`; no redibujar ni recortar los SVG.
- CLAUDE, implement-feature/to-spec y sin-deuda, reglas GDScript/dominio/presentación/tests/specs/assets,
  AGENTS de dominio/UI/escenas/test/dominio, plantilla de capacidad y mapa MCP consultados.

## Estado del árbol leído

Base C `c8990685`, geometría `f17948fe` y preset `444d05db`. No contiene #302 todavía:
no existen sus dos clases principales ni la caja o lector nuevos. Ventanilla publica
`comprador_llegado(Comprador)` también al reabrir; Comprador es RefCounted y se distingue
por referencia, nunca por nombre. RelojDelTurno publica `turno_cerrado(cumplidas:int)`.
El hook gdUnit4 aparta el guardado por proceso y lo borra entre casos; conservarlo.

Contrato futuro #302: GeneradorDeTickets.Resultado = ANOTADO, NO_ES_PRODUCTO, LLENO;
CajaRegistradora.lectura_rechazada(motivo:GeneradorDeTickets.Resultado). No conectar
cobro_rechazado. La señal de lectura anotada no avisa. Ticket pasa a ser papel impreso,
la lista de la ventanilla pasa a llamarse pedido: estos borradores no crean otro Ticket.

El dominio usa una lista de Comprador avisados por identidad y tiempos transcurridos por
Tipo. Los tiempos se acumulan, evitando restar 2,9 + 0,1 sobre un resto con epsilon que
retendría un aviso después del límite. visibles() devuelve una copia; vaciar() olvida todo.
UI sólo traduce, avanza delta y dibuja el estado; no usa Timer ni decide motivos.
El contrato explícito pasa delta sin escalar por Ritmo (60 segundos ficticios por segundo
de sesión); no convertir una placa legible de tres segundos en 0,05 segundos reales.

## Orden de dibujo

Las escenas leídas ponen computadora/ventanilla/pausa en layer=3. El orden del árbol
por sí solo no garantiza dos CanvasLayer de índice igual según la documentación oficial:
https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html#class-canvaslayer-property-layer
La raíz entregó #64 (PR #344, cabeza `416aef86`), que agrega CapaDeDialogo en capa 4.
Aunque la base C todavía no contiene su cableado, A304 la tendrá como ancestro.
La propuesta usa pila=5 y override de la instancia MenuDePausa=6, únicamente en el
archivo permitido interfaz_del_almacen.tscn; no edita menu_de_pausa.tscn. Cotejar también
las capas del programa de tickets y del diálogo al recibir A304. El test compara
desigualdades estrictas con todas las interfaces y carga también el recurso real del
diálogo; no compara sus índices con literales 5/6. Confirmar por captura real y clic.

## Borradores preparados

- Spec NTF nuevo, draft: seis BR del issue y una séptima para presentación e interacción;
  diez AC, todos citados en los borradores de test. Ratificar sólo con comportamiento verde.
- Dominio candidato, UI candidato y escena nueva; tres suites nuevas.
- El test de clic usa el botón real Notas de la computadora; primero afirma que su centro
  está cubierto por la placa y luego envía eventos al viewport. No prueba una llamada directa.
- La suite UI usa dos resoluciones y pausa real, además de texto/símbolos.
- Al recibir A304 certificada, comprobar el aviso con el `PopupMenu` real del manual abierto
  **antes de Esc**; después, Esc abre la pausa real y **cierra todas las listas**, conservando
  programa, aviso, selección y mano. No exigir popup abierto durante pausa: contradice #303.
  La desigualdad de índices `CanvasLayer` no demuestra superposición frente a ventanas;
  adjuntar captura anterior a Esc y captura con pausa/listas cerradas en 1920×1080 y 1280×720.
  RIGHT del popup conserva el cierre del programa. La adaptación externa nativa y su protocolo
  están en `nativa/`; no se ejecutaron ni se inició fuente/motor de #309.
- La suite de escena abre/cierra/reabre la ventanilla, emite ambos motivos y agota el turno.
- `cableado.txt` tiene las tres conexiones y la delta de interfaz. vaciar.unbind(1)
  adapta el argumento de turno_cerrado sin condiciones en almacen.gd.
- Esqueleto sin comportamiento separado para conseguir rojo de aserciones, no parseo.

## Al recibir A304

1. Leer su spec/contratos/historia y consultar índice más barrido local en esa cabeza.
   Ajustar `_caja`, ruta Servicios/CajaRegistradora, métodos del puesto y capas al árbol real.
2. Abrir rama/worktree propios desde esa cabeza, sin modificar ni limpiar C327.
3. Spec primero, draft, commit/push. No reutilizar IDs emitidos por otras capacidades.
4. Copiar tests de dominio primero y sólo el esqueleto. Importar y correr rojo por aserciones
   en la cola común, APPDATA aislado y GODOT_BIN/PATH inyectados. Guardar salida y exit.
5. Candidato mínimo verde, luego tests/UI/cableado; generar UID/import en el motor, no a mano.
6. Correr las tres suites en cola, revisar premisas y clic real; captura de ambos avisos,
   computadora/ventanilla y pausa en las dos resoluciones, sin motor paralelo.
7. Completar mapeo AC→test→resultado, ratificar NTF al cumplir todos, commit/push,
   full 7/7 sin salteos seguida inmediatamente por conteo, PR Closes #309.

gdformat y gdlint de estos borradores pasaron. Las comprobaciones estáticas de IDs/citas
y metadatos SVG pasaron. Ningún caso de juego corrió: no afirmar verde antes de esa base.

## Referencia de #303 para la comprobación nativa

Leídos source/diff de `06e1635e3f344799358524a9391d296c596b92a7`,
`a-303-popup-final-3.log` y capturas `303-popup-1280.png` / `303-pausa-1920.png` del scratch
compartido. Es una referencia provisional de A303, todavía pendiente de full y base #302;
no sustituye A304 certificada. La nativa303 registró exactamente dos Esc y dos RIGHT en las
dos resoluciones, con montaje liberado y sin errores. Es evidencia de #303, no verde de #309.

`ProgramaDeTickets` expone `selectores: Array[OptionButton]`, `cerrar_las_listas()`,
`pausa_pedida` y `cierre_pedido`. `almacen.gd` conecta pausa_pedida al ControlDePausa real y
su señal pausado a cerrar_las_listas. El Window hereda factor 1 / 0,6666667; los topes
medidos son 380×429 / 253×286, y los popups están embebidos. Se releen esos hechos en A304.
La preparación de captura309 no configura tamaños, escala, menú o escenas de #303.

La sonda cliente recibe la señal real `comprador_llegado`; no inventa un rechazo del lector
en jornada 3, cuyo programa manual no publica ese rechazo. Las otras capturas de #309 y
sus suites cubren el aviso de lectura fallida en el modo con lector.
En el corte303 leído, `GeneradorDeTickets.Resultado.SIN_LECTOR` ya existe y la caja no emite
lectura_rechazada para ese resultado. Ajustar el inventario de enum y los bordes de la suite al
árbol final A304, conservando que sólo LLENO avisa y el modo manual no crea ese rechazo.
