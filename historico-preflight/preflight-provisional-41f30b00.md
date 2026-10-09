# Lectura provisional, no base certificada ni autorización de fuente

A304 anunció 41f30b0040aa843f45a89c7cee02fbfa08ad8929 mientras su primera verificación
completa sigue activa. No se creó rama ni se editó C309. Repetir este cotejo cuando A
entregue el SHA certificado, PR y conteo final.

El generador vigente es `src/dominio/almacen/generador_de_tickets.gd`, clase
GeneradorDeTickets. Su enum Resultado tiene ANOTADO, NO_ES_PRODUCTO, LLENO y SIN_LECTOR.
La jornada manual retorna SIN_LECTOR; la notificación no debe tratar ese resultado como
un error de lectura. La fuente actual sigue imprimiendo un recurso Ticket y existe
`src/dominio/almacen/ticket.gd` con class_name Ticket. No asumir un renombre de clase
a Pedido por el vocabulario de pantalla/issue.

`src/sistemas/tareas/caja_registradora.gd` expone lectura_rechazada(motivo:
GeneradorDeTickets.Resultado) y ticket_desechado sin argumentos. El segundo sólo informa
aceptación de papel propio según A304; no se conecta a un aviso de lectura fallida.

`src/sistemas/tareas/ventanilla.gd` expone comprador_llegado(comprador: Comprador).
En almacen.gd existen exports `_atenciones: Ventanilla`, `_caja: CajaRegistradora`
y `_programa_de_tickets: ProgramaDeTickets`; el borrador de cableado usa esos dos
primeros exports. La señal de llegada/rechazo no se cablea hoy allí, por lo que la
implementación de avisos agregará conexiones, sin sustituir consumidores existentes.

La pantalla manual conserva el recurso `src/ui/diegetica/programa_de_tickets.gd`,
pausa_pedida/cierre_pedido/cerrar_las_listas. El protocolo de aviso+popup antes de Esc,
y pausa con listas cerradas, continúa siendo el cotejo previsto. Capas e índices se
medirán de nuevo en la base certificada y mediante captura real, no sólo con enteros.
