from pathlib import Path

root = Path.cwd()
emp = root / 'specs/employment-record/employment-record.md'
text = emp.read_text(encoding='utf-8').replace('status: ratified', 'status: draft', 1)
text = text.replace('| **Legajo** | el contador de apercibimientos, y lo único que cruza la noche |', '| **Medio** | media unidad de apercibimiento, conservada exactamente entre noches | fracción flotante |\n| **Llamado** | un motivo distinto de la noche que suma medio apercibimiento | repetición, banda |\n| **Legajo** | el contador de apercibimientos, y lo único que cruza la noche |')
start = text.index('SI el legajo llega a **4 apercibimientos o más**')
end = text.index('\n### BR-EMP-004', start)
text = text[:start] + 'SI el legajo llega a **8 medios o más**, equivalentes a 4 apercibimientos, ENTONCES el sistema\nDEBE declararlo despedido. Con 7 medios todavía no está despedido.\n' + text[end:]
text = text.replace('de noches graves repartida entre dos sesiones tiene que despedir igual.', 'de noches graves repartida entre dos sesiones tiene que despedir igual. El sistema DEBE conservar\nexactamente los medios acumulados como entero. Sin ese dato, o con un tipo distinto de entero,\nDEBE restaurar cero medios sin perder una jornada válida. Un dato antiguo de apercibimientos\nno DEBE sustituir el dato de medios ni migrarse.')
text = text.replace('cuántos apercibimientos lleva. Ese comentario satura en el tope:', 'cuántos apercibimientos enteros lleva, descartando sólo para el comentario el medio restante.\nCon 7 medios dice lo mismo que con 6. Ese comentario satura en el tope:')
rules = '''### BR-EMP-012 — Los llamados suman medios por motivo

MIENTRAS la jornada está abierta, el sistema DEBE registrar cada motivo de llamado una sola vez.
CUANDO cierra, DEBE sumar un medio por motivo distinto, además del peso de la banda, incluso
con NINGUNA. Abrir otra jornada DEBE vaciar los motivos pendientes. Antes de abrir, después de
cerrar y con la partida terminada, anotar un llamado NO DEBE modificar el legajo ni una noche
futura. Los motivos pendientes no DEBEN persistirse ni mostrar un contador nuevo.

'''
text = text.replace('## Criterios de aceptación', rules + '## Criterios de aceptación', 1)
criteria = '''### AC-EMP-017 — La banda y los motivos se suman *(verifica BR-EMP-002, BR-EMP-012)*

DADO un legajo limpio CUANDO cierra impecable con un motivo ENTONCES lleva 1 medio; con dos
motivos distintos, 2; con GRAVE y dos motivos, 6. Repetir el mismo motivo conserva una sola suma.

### AC-EMP-018 — Los motivos pertenecen sólo a la noche abierta *(verifica BR-EMP-006, BR-EMP-007, BR-EMP-012)*

DADO un motivo anotado antes de abrir, durante una jornada ya cerrada o después del final
CUANDO se consulta o abre otra noche ENTONCES no suma deuda. DADO una noche con un motivo
CUANDO se abre la siguiente y cierra sin motivos ENTONCES conserva sólo la deuda anterior.

### AC-EMP-019 — Siete y ocho medios *(verifica BR-EMP-003, BR-EMP-012)*

DADO 6 medios CUANDO cierra impecable con un motivo ENTONCES lleva 7 y no está despedido.
DADO 7 medios CUANDO cierra impecable con un motivo ENTONCES lleva 8 y está despedido.

### AC-EMP-020 — El guardado conserva el medio *(verifica BR-EMP-008)*

DADO 7 medios CUANDO se guarda, se lee el archivo y se reanuda ENTONCES conserva el entero 7;
una noche impecable sin motivos sigue con 7. DADO el dato ausente, antiguo o con valor 7,0
CUANDO se reanuda ENTONCES restaura 0 medios y conserva una jornada válida. Si también hay un
dato antiguo, el entero 7 de medios sigue prevaleciendo.

### AC-EMP-021 — El comentario usa apercibimientos enteros *(verifica BR-EMP-009)*

DADO un legajo con 7 medios CUANDO se arma el parte ENTONCES su comentario es el mismo que con
6 medios; no agrega un contador visible de medios.

### AC-EMP-022 — La quinta impecable admite siete medios *(verifica BR-EMP-004, BR-EMP-005, BR-EMP-008)*

DADO la quinta jornada con 7 medios CUANDO cierra impecable sin motivos ENTONCES conserva 7
y termina con contrato cumplido. DADO un motivo adicional ENTONCES llega a 8 y termina despedido.

'''
text = text.replace('## No objetivos', criteria + '## No objetivos', 1)
text = text.replace('puede venir de un guardado.', 'puede venir de un guardado; motivos de la jornada abierta.')
text = text.replace('la banda, los apercibimientos, si está despedido', 'la banda, los medios exactos y los apercibimientos enteros, si está despedido')
emp.write_text(text, encoding='utf-8', newline='\n')

cln = root / 'specs/store-cleanup/store-cleanup.md'
text = cln.read_text(encoding='utf-8').replace('status: ratified', 'status: draft', 1)
rules = '''### BR-CLN-027 — Pertenencia a las habitaciones

El sistema DEBE distinguir el interior del local, del depósito y del baño, incluidos sus pasos
de acceso, según piso, paredes y techos existentes. Cada habitación DEBE admitir una unión
finita de volúmenes locales sin rellenar huecos, ensanchar pasos ni elevar techos bajos. Un
punto fuera de las tres DEBE clasificarse afuera. Trasladar o rotar el conjunto NO DEBE agrandar
sus interiores ni cambiar la pertenencia de un punto que conserva su posición relativa.

### BR-CLN-028 — El desorden cuenta una vez al cierre

CUANDO termina la jornada, el sistema DEBE anotar un llamado por desorden si queda alguna
unidad suelta dentro de cualquier habitación, una caja dentro y fuera del depósito o un útil
dentro y fuera del baño. El cuerpo sostenido DEBE excluirse por identidad, salvo mientras se
examina: entonces cuenta en su posición física. Lo ya tirado al contenedor DEBE excluirse.
Una bolsa adentro no DEBE producir desorden. Varios cuerpos desordenados DEBEN producir un
único motivo. La foto DEBE tomarse antes de registrar el legajo, armar el parte y guardar.

### BR-CLN-029 — Lo que queda afuera conserva su cuerpo

CUANDO termina la jornada, el sistema DEBE anotar un llamado si queda al menos un cuerpo
levantable afuera, excluyendo el sostenido sin examen y lo tirado al contenedor. Varios cuerpos
afuera DEBEN producir un único motivo, independiente del desorden. Recuperarlo antes del cierre
DEBE eliminar ese motivo; una unidad recuperada y suelta adentro puede producir desorden.
Las superficies existentes de pavimento exterior DEBEN sostener los cuerpos soltados por el
hueco real de ventanilla, conservándolos recogibles dentro del alcance vigente, sin extender
soporte sobre huecos que el pavimento no ocupa ni duplicar su dibujo.

'''
text = text.replace('## Criterios de aceptación', rules + '## Criterios de aceptación', 1)
criteria = '''### AC-CLN-040 — Interiores, techos y pasos exactos *(verifica BR-CLN-027)*

DADO el almacén al abrir ENTONCES todas las cajas están en depósito, los cinco útiles en baño
y el jugador en local. CUANDO se consultan centros de los pasos ENTONCES pertenecen a su
habitación destino; un punto junto al lateral o sobre un techo bajo queda afuera. DADO una
unión disjunta trasladada y girada 45° ENTONCES sus partes conservan pertenencia y sus huecos
siguen afuera, incluso cuando caen dentro de una envolvente mayor.

### AC-CLN-041 — Suelta no significa visible ni apoyada en el piso *(verifica BR-CLN-028)*

DADO una unidad suelta en local, depósito o baño, incluso agrupada o apoyada en caja o góndola,
CUANDO cierra ENTONCES hay desorden. DADO la unidad colocada, devuelta o sostenida sin examen
ENTONCES no lo produce. El cuerpo de repuesto no cuenta como unidad suelta.

### AC-CLN-042 — Cada clase tiene su habitación *(verifica BR-CLN-027, BR-CLN-028)*

DADO una caja en local CUANDO cierra ENTONCES hay desorden; en depósito o su paso, no.
DADO un útil en local o depósito ENTONCES hay desorden; en baño o su paso, no. DADO una bolsa
adentro ENTONCES no produce desorden. DADO la lista vacía ENTONCES no hay ninguno de los motivos.

### AC-CLN-043 — La mano excluye sólo su cuerpo *(verifica BR-CLN-028, BR-CLN-029)*

DADO dos cajas distintas con los mismos datos y una sostenida CUANDO la otra queda desordenada
o afuera ENTONCES conserva su motivo. DADO el cuerpo sostenido CUANDO inicia un examen real
ENTONCES cuenta por su posición; al terminar vuelve a excluirse. Esto también vale para una
unidad que salió del grupo de sueltas al agarrarse. Mover y devolver lo sostenido conserva su
identidad; soltar, entregar y vaciar dejan la mano sin cuerpo.

### AC-CLN-044 — Afuera y recuperación *(verifica BR-CLN-028, BR-CLN-029)*

DADO una bolsa, caja, unidad o útil afuera CUANDO cierra ENTONCES hay un único motivo por
afuera, aunque haya varios. CUANDO se recuperan antes del cierre y se sostienen, colocan o
devuelven ENTONCES no hay ese motivo; una unidad recuperada y suelta adentro produce desorden.

### AC-CLN-045 — El pavimento sostiene lo soltado *(verifica BR-CLN-029)*

DADO las seis superficies existentes del pavimento ENTONCES su soporte coincide con sus
triángulos y no cubre los huecos ajenos. CUANDO se suelta un cuerpo por los bordes libres del
hueco real de ventanilla, a ambos lados y arriba del vidrio, ENTONCES cae, se apoya estable en
el pavimento y puede recogerse dentro del alcance vigente.

### AC-CLN-046 — Dos motivos antes del registro *(verifica BR-CLN-028, BR-CLN-029)*

DADO caja desordenada y unidad afuera CUANDO agota la jornada con GRAVE ENTONCES el legajo
lleva 6 medios desde cero antes de armar el parte y escribir el checkpoint. DADO esos cuerpos
tirados al contenedor ENTONCES no generan motivos; abrir otra noche vacía el registro de tirados
y restaura los persistentes, sin consultar unidades o tickets ya retirados.

'''
text = text.replace('## No objetivos', criteria + '## No objetivos', 1)
text = text.replace('el pedido de tirar lo sostenido.', 'el pedido de tirar lo sostenido y el estado físico de los cuerpos al cerrar.')
text = text.replace('está cumplida y qué objeto se tiró.', 'está cumplida, qué objeto se tiró y los motivos únicos del cierre.')
cln.write_text(text, encoding='utf-8', newline='\n')
