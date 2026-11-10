## Por qué camino entra el jugador al almacén cuando la pantalla de carga lo deja pasar.
##
## En la web, el menú calienta una copia del almacén debajo de sí mientras el jugador elige. Cada
## shader se compila una sola vez por sesión: una copia ya calentada sirve para entrar, y un
## almacén nuevo, hecho después de ella, no necesita calentarse otra vez.
class_name EntradaAlAlmacen
extends RefCounted

enum Camino {
	## Entra la copia que se calentó debajo del menú.
	LA_COPIA,
	## La copia leyó un guardado que «Nuevo juego» ya borró: se la deja y se arma otro almacén,
	## que lee la partida nueva. Sus shaders ya están compilados.
	UN_ALMACEN_NUEVO,
	## No hay copia que valga: se arma un almacén y se lo calienta.
	CALENTAR_UN_ALMACEN,
}


## `con_las_preferencias`: la copia se calentó con las preferencias de ahora. Otras cambian los
## programas que compila el motor.
static func de(
	hay_copia: bool,
	con_las_preferencias: bool,
	nuevo_juego: bool,
	copia_leyo_un_guardado: bool,
) -> Camino:
	if not hay_copia or not con_las_preferencias:
		return Camino.CALENTAR_UN_ALMACEN
	if nuevo_juego and copia_leyo_un_guardado:
		return Camino.UN_ALMACEN_NUEVO
	return Camino.LA_COPIA
