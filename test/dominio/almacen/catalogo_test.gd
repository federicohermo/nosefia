## Qué productos existen en el almacén y con qué valores.
##
## Los AC de acá son el único lugar del repo que se pone en rojo cuando el catálogo y el
## `enum Id` se desincronizan: agregar un producto al enum y olvidarse de su fila deja un
## `Catalogo.de(id)` que devuelve `null`, y nada más lo caza.
extends GdUnitTestSuite

## Los 31 nombres, en el orden del enum. Fija las dos mitades del criterio del catálogo: los 23 de
## antes no cambian de nombre ni de lugar —una partida guardada nombra al producto por su
## número— y los 8 que entran van al final, con el nombre de su ficha.
const NOMBRES: Array[String] = [
	"Actroncito",
	"Durextra",
	"Burbaloo",
	"Zucarachas",
	"Laysntt",
	"Malbardo",
	"Prongles",
	"Jorgillo",
	"Arvejas",
	"Chisitos",
	"Oremos",
	"Pepitos",
	"Saladik",
	"Uakas",
	"Coracola",
	"Frotlups",
	"Marolini",
	"Amargadito",
	"Cindolor",
	"Flinpuf",
	"Donsaturados",
	"Petisas",
	"Macumbas",
	"Cosa de Maní",
	"Duronga",
	"Fernet God",
	"Mayonchis",
	"Oaaaa",
	"Terminator",
	"Marranos",
	"Feel Ricky Fort",
]

## Los precios de los 8 que entran. La ficha no los trae: los decidió el issue que los sumó, en el
## rango de los que ya estaban.
const PRECIOS_NUEVOS := {
	"Cosa de Maní": 700,
	"Duronga": 1300,
	"Fernet God": 4500,
	"Mayonchis": 1100,
	"Oaaaa": 600,
	"Terminator": 2800,
	"Marranos": 1400,
	"Feel Ricky Fort": 800,
}

## La sonoridad de los 8 que entran, de la columna «Familia sonora» de su ficha. Dos familias de
## la ficha no existen en el juego —botella de vidrio y caja de cereal—: suenan como la más
## parecida, y el hueco es OQ-STK-004.
const SONORIDADES_NUEVAS := {
	"Cosa de Maní": EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO,
	"Duronga": EntradaSonora.Sonoridad.CAJITA,
	"Fernet God": EntradaSonora.Sonoridad.BOTELLA_PLASTICA,
	"Mayonchis": EntradaSonora.Sonoridad.ENVOLTORIO_PLASTICO,
	"Oaaaa": EntradaSonora.Sonoridad.CAJA,
	"Terminator": EntradaSonora.Sonoridad.CAJA,
	"Marranos": EntradaSonora.Sonoridad.LATA,
	"Feel Ricky Fort": EntradaSonora.Sonoridad.CAJITA,
}

## Los productos que el depósito guarda en caja chica, según la columna «Caja» de la ficha. Los
## demás van en caja grande. **No sale del volumen de la unidad**: Actroncito es una caja grande
## de remedio y va en caja chica, y Zucarachas al revés.
const EN_CAJA_CHICA: Array[String] = [
	"Actroncito", "Arvejas", "Durextra", "Jorgillo", "Malbardo", "Duronga", "Oaaaa", "Cosa de Maní"
]


func test_el_catalogo_tiene_los_31_productos_en_el_orden_del_enum() -> void:  # AC-STK-002
	var nombres: Array[String] = []
	for producto in Catalogo.todos():
		nombres.append(producto.nombre)
	assert_array(nombres).contains_exactly(NOMBRES)


func test_los_que_entran_tienen_su_precio() -> void:  # AC-STK-002
	var por_nombre := _por_nombre()
	for nombre: String in PRECIOS_NUEVOS:
		(
			assert_bool(por_nombre.has(nombre))
			. override_failure_message("%s no está en el catálogo" % nombre)
			. is_true()
		)
		if por_nombre.has(nombre):
			assert_int(por_nombre[nombre].precio).is_equal(PRECIOS_NUEVOS[nombre])


func test_los_que_entran_suenan_como_dice_su_ficha() -> void:  # AC-STK-027
	var por_nombre := _por_nombre()
	for nombre: String in SONORIDADES_NUEVAS:
		(
			assert_bool(por_nombre.has(nombre))
			. override_failure_message("%s no está en el catálogo" % nombre)
			. is_true()
		)
		if por_nombre.has(nombre):
			(
				assert_int(Catalogo.sonoridad_de(por_nombre[nombre].id))
				. override_failure_message(nombre)
				. is_equal(SONORIDADES_NUEVAS[nombre])
			)


## Cada producto declara su caja, y no hay una que falte: un producto sin fila acá iría a parar a
## una caja por defecto que nadie eligió.
func test_la_caja_de_cada_producto_es_la_de_su_ficha() -> void:
	assert_int(Catalogo.TAMANOS_DE_CAJA.size()).is_equal(Producto.Id.size())
	for producto in Catalogo.todos():
		var chica := EN_CAJA_CHICA.has(producto.nombre)
		var esperada := Catalogo.TamanoDeCaja.CHICA if chica else Catalogo.TamanoDeCaja.GRANDE
		(
			assert_int(Catalogo.caja_de(producto.id))
			. override_failure_message(producto.nombre)
			. is_equal(esperada)
		)


func _por_nombre() -> Dictionary:
	var productos := {}
	for producto in Catalogo.todos():
		productos[producto.nombre] = producto
	return productos


func test_hay_exactamente_una_fila_por_cada_valor_del_enum() -> void:  # AC-STK-002
	# Mira `FILAS` y no `todos()` porque es la aserción que sobrevive a la desincronización que
	# viene a cazar: medido el 2026-09-01, un enum con un valor de más hacía reventar a `de()`
	# adentro del test y la aserción no llegaba a correr.
	assert_int(Catalogo.FILAS.size()).is_equal(Producto.Id.size())
	for id: Producto.Id in Producto.Id.values():
		assert_bool(Catalogo.FILAS.has(id)).is_true()


func test_hay_exactamente_un_producto_por_cada_valor_del_enum() -> void:  # AC-STK-002
	# El AC que se pone en rojo el día que alguien agregue un producto al enum sin darle fila.
	assert_array(Catalogo.todos()).has_size(Producto.Id.size())


func test_el_catalogo_lista_los_productos_en_el_orden_del_enum() -> void:
	# El orden no es adorno: es el que lista la pantalla de la caja, y sin afirmarlo un `todos()`
	# que barajara la lista entre dos cuadros pasaría los otros AC sin despeinarse.
	var ids: Array[int] = []
	for producto in Catalogo.todos():
		ids.append(producto.id)
	assert_array(ids).contains_exactly(Producto.Id.values())


func test_cada_producto_del_catalogo_esta_completo() -> void:  # AC-STK-002
	# Recorre el enum entero y no una muestra: una fila a medio llenar en cualquiera de ellos
	# pasaría desapercibida si el test mirara un solo producto.
	for id: Producto.Id in Producto.Id.values():
		var producto := Catalogo.de(id)
		# Sin este corte, un `id` sin fila desreferencia `null` y aborta la función: el caso se
		# reporta sin haber afirmado nada, que es justo el modo de falla que este archivo cierra.
		assert_object(producto).is_not_null()
		if producto == null:
			continue
		assert_int(producto.id).is_equal(id)
		assert_str(producto.nombre).is_not_empty()
		assert_int(producto.precio).is_greater(0)


func test_dos_llamadas_al_catalogo_dan_objetos_distintos_con_el_mismo_id() -> void:
	# La decisión escrita como test: la identidad de un producto es su `id`, nunca la
	# instancia. Quien indexe por instancia va a encontrar ausente lo que guardó la otra.
	var una := Catalogo.de(Producto.Id.ACTRONCITO)
	var otra := Catalogo.de(Producto.Id.ACTRONCITO)
	assert_object(una).is_not_same(otra)
	assert_int(una.id).is_equal(otra.id)


func test_ningun_producto_queda_sin_sonoridad() -> void:  # AC-STK-027
	for id: Producto.Id in Producto.Id.values():
		(
			assert_int(Catalogo.sonoridad_de(id))
			. override_failure_message("%s no tiene sonoridad" % Producto.Id.find_key(id))
			. is_not_equal(EntradaSonora.Sonoridad.NINGUNA)
		)
	for id: Producto.Id in [Producto.Id.ARVEJAS, Producto.Id.CORACOLA, Producto.Id.PRONGLES]:
		assert_int(Catalogo.sonoridad_de(id)).is_equal(EntradaSonora.Sonoridad.LATA)
