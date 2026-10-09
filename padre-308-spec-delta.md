### BR-CLN-031 — Tirar objetos importantes

CUANDO se acepta tirar al contenedor un objeto que no sea bolsa ni ticket durante una jornada
abierta, el sistema DEBE anotar un único llamado por objeto importante tirado. Varios objetos
importantes tirados DEBEN producir un solo motivo en esa noche. Las bolsas y los tickets
DEBEN conservar su descarte normal sin este motivo. Una unidad ordinaria, la mopa, el balde
y los jabones NO DEBEN considerarse exentos. El motivo DEBE sumar un medio al cierre, además
de la banda y los demás motivos, y reiniciarse al abrir otra noche sin borrar la deuda.
Un gesto rechazado o fuera de jornada abierta NO DEBE anotar este motivo.

### AC-CLN-050 — Las excepciones son bolsas y tickets *(verifica BR-CLN-031)*

DADO una bolsa o un ticket CUANDO se acepta tirarlo al contenedor ENTONCES no agrega el
motivo de objeto importante y la bolsa sigue contando para su obligatoria. DADO una unidad
ordinaria, la mopa, el balde o cualquiera de los tres jabones ENTONCES no está exento.
La ausencia de objeto no constituye una excepción válida ni un descarte aceptado.

### AC-CLN-051 — El descarte importante cuenta una vez por noche *(verifica BR-CLN-026, BR-CLN-031)*

DADO una noche impecable CUANDO se tira una unidad o una mopa al contenedor abierto ENTONCES
el cierre suma un medio y el objeto tirado no produce desorden ni afuera. DADO dos importantes
tirados en la misma noche ENTONCES suman un solo medio. CUANDO abre otra noche, tirar otro
importante permite anotar de nuevo el motivo; una noche impecable sin motivos conserva la deuda.

### AC-CLN-052 — Tres motivos permiten continuar y cuatro despiden *(verifica BR-CLN-028, BR-CLN-029, BR-CLN-030, BR-CLN-031)*

DADO deuda cero, un objeto importante tirado al contenedor, desorden y otro objeto afuera
CUANDO termina la noche con GRAVE ENTONCES registra siete medios, los guarda y permite
continuar. DADO además un ticket aceptado en el inodoro ENTONCES registra ocho medios,
despide y guarda ese resultado. Al continuar desde siete, los objetos persistentes vuelven
a poder usarse y una noche impecable sin motivos conserva los siete medios.
