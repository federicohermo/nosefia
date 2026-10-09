### BR-CLN-030 — Papel en el inodoro

CUANDO se acepta tirar al menos un ticket al inodoro durante una jornada abierta, el sistema
DEBE anotar un único llamado por papel en el inodoro, aunque se tiren varios. Este motivo
DEBE sumar un medio apercibimiento al cierre, además de la banda y de los otros motivos.
Vaciar el balde o enjuagar la mopa NO DEBE anotarlo. Un evento sin jornada abierta o con
partida terminada NO DEBE sumar ni quedar pendiente para otra noche.

### AC-CLN-047 — El papel aceptado cuenta una vez *(verifica BR-CLN-030)*

DADO una noche impecable CUANDO se aceptan uno o dos tickets propios en el inodoro ENTONCES
el cierre suma un medio. Vaciar el balde o enjuagar la mopa no lo suma. DADO un evento antes
de abrir, después del cierre o con partida terminada ENTONCES no cambia la deuda ni contamina
la siguiente noche. Abrir otra noche permite anotar de nuevo el mismo motivo.

### AC-CLN-048 — Tickets activos, mano, examen y destinos *(verifica BR-CLN-027, BR-CLN-028, BR-CLN-029, BR-CLN-030)*

DADO tickets propios activos ENTONCES la consulta entrega una copia independiente y omite
cuerpos liberados o pendientes de liberar; conserva los válidos de ranura, mundo, mano, examen
y contenedor. DADO tickets dentro de local, depósito o baño CUANDO cierra ENTONCES no producen
desorden ni afuera; uno o varios afuera producen un único motivo de afuera. Recuperarlos al
interior o sostenerlos sin examen elimina ese motivo. DADO dos cuerpos con los mismos datos
ENTONCES sólo se excluye el sostenido; un examen real lo hace contar por su posición física
y terminarlo vuelve a excluirlo. Un ticket aceptado por el inodoro se libera sin volver a
consultarlo al cerrar; uno tirado al contenedor sigue vivo y queda excluido por ese destino,
sin anotar papel en el inodoro. Abrir otra noche retira ambos del registro activo.

### AC-CLN-049 — Tres motivos son siete con GRAVE *(verifica BR-CLN-028, BR-CLN-029, BR-CLN-030)*

DADO deuda cero, un ticket aceptado en el inodoro, una caja desordenada y una unidad afuera
CUANDO termina la jornada con GRAVE ENTONCES el cierre registra siete medios antes del parte
y checkpoint y no despide. CUANDO la noche siguiente termina impecable y sin motivos ENTONCES
conserva siete. Un evento durante la placa no contamina esa noche siguiente y repetir el
cierre no suma otra vez.
