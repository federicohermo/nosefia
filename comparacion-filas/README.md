# Actroncito y Prongles: una o dos filas

Copias de visualización de poses medidas. No es el reparto final generado ni una decisión
tomada. OQ-STK-008 sigue pendiente. Estas imágenes muestran únicamente la diferencia entre
las dos opciones; los demás cambios del reparto son iguales en ambas.

Dorado: fila de adelante. Azul: fila de atrás. Gris: mueble y referencia vecina conservados.
Son renders reales de geometría Blender, con colores de diagnóstico para distinguir filas.
Los colores no representan el material final del juego. No se modificaron geometría, escala,
altura, inclinación ni poses entre opciones. La cámara y su escala son idénticas en cada par.

| Producto | Una fila | Dos filas |
|---|---|---|
| Actroncito, frontal | [Ver](actroncito-1-fila-frontal.png) | [Ver](actroncito-2-filas-frontal.png) |
| Actroncito, oblicua | [Ver](actroncito-1-fila-lateral-oblicua.png) | [Ver](actroncito-2-filas-lateral-oblicua.png) |
| Prongles, frontal | [Ver](prongles-1-fila-frontal.png) | [Ver](prongles-2-filas-frontal.png) |
| Prongles, oblicua | [Ver](prongles-1-fila-lateral-oblicua.png) | [Ver](prongles-2-filas-lateral-oblicua.png) |

Actroncito conserva seis lugares delanteros y puede tener seis copias posteriores;
Prongles conserva doce delanteros y puede tener doce posteriores. Agregar la fila posterior
no agrega casilleros reponibles. Se ilustra la tanda principal N.sur.2 / B.oeste.2; la decisión
global sobre estos productos también rige sus tandas fijas, ya medidas en el cierre anterior.
Durextra y Donsaturados conservan dos filas y matrices idénticas entre opciones.

La primera cámara lateral alta ocultó Prongles detrás de la chapa superior. Se conservan las
cuatro laterales originales en incidente-lateral01/; ese par de Prongles no sirve para elegir.
Se corrigió sólo la cámara observadora a una oblicua más baja, sin mover productos ni mueble.
El nombre lateral-alta en el script y crudo del segundo intento es heredado; las ocho imágenes
de la tabla son las aceptadas tras abrirlas. No se necesitan más vistas.

Fuente: assets/models/SEPT_JUEGOS_PROTOTIPO.blend de c90d1523e51816813702a27c3ae6f994f9233d5f,
SHA256 0c23ea7db6393ea4a0fa86088b4d4897a5d7484d81ae0c0aedf7f8e7d7213f19.
La copia fuente.blend no se incluye para evitar duplicar el binario; copiar ese archivo con
ese hash a esta carpeta para reproducir. Los helpers son copias externas del protocolo del
cierre geométrico previo. Se verifica apoyo completo y cero intersecciones antes de renderizar.
No se llama save_mainfile. El árbol434 quedó limpio, con el mismo HEAD y arte byteidéntico.

Blender5.2.1LTS; dos turnos FIFO de6s cada uno, cada ejecución limitada a180s. stdout y stderr
completos están en protocolo/blender01.log y blender02.log; los tiempos/cola en turno01/02.log.
render01/02.json conservan matrices, cámaras y pins realmente ejecutados. controles.json
contrasta delanteras, vecinos y poses de ambas corridas. Los textos publicados se normalizan
sólo en copias a LF; normalizacion.json conserva hashes originales y publicados. sourcepins*.json
son los pins operativos de las copias LF; protocolo/sourcepins-original*.json guarda los originales.
Para reproducir, ejecutar ejecutar.py y ejecutar02.py sólo en una copia externa y por la cola
común del lote. Los PNG publicados son los bytes originales sin edición.

Los 29 archivos anteriores de la rama capturas/434, commit
a63b5df190c575d8b667b6beb659744b74d39810, se conservan sin reemplazar ninguno.
