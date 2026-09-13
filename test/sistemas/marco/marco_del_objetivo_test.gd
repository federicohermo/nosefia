extends GdUnitTestSuite


class Mueble:
	extends Node3D
	var mallas: Array[MeshInstance3D] = []


func test_resalta_siete_mallas_vinculadas_y_no_las_ajenas() -> void:  # 039-AC1
	var marco: MarcoDelObjetivo = auto_free(MarcoDelObjetivo.new())
	var raiz: Node3D = auto_free(Node3D.new())
	var mueble := Mueble.new()
	raiz.add_child(mueble)
	for indice in 7:
		var malla := _malla()
		(raiz if indice % 2 else mueble).add_child(malla)
		mueble.mallas.append(malla)
	var ajena := _malla()
	mueble.add_child(ajena)
	marco.enfocar(mueble)
	for malla in mueble.mallas:
		assert_object(malla.material_overlay).is_not_null()
	assert_object(ajena.material_overlay).is_null()
	marco.apagar()
	for malla in mueble.mallas:
		assert_object(malla.material_overlay).is_null()


func test_restaura_overlays_distintos_y_conserva_geometria_y_materiales() -> void:  # 039-AC2 039-AC3
	var marco: MarcoDelObjetivo = auto_free(MarcoDelObjetivo.new())
	var mueble: Mueble = auto_free(Mueble.new())
	var previos: Array[Material] = [null, StandardMaterial3D.new(), ShaderMaterial.new()]
	for previo in previos:
		var malla := _malla()
		malla.material_overlay = previo
		malla.material_override = StandardMaterial3D.new()
		mueble.add_child(malla)
		mueble.mallas.append(malla)
	var geometria: Mesh = mueble.mallas[0].mesh
	var superficie: Material = geometria.surface_get_material(0)
	var uv: PackedVector2Array = geometria.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var material_previo := mueble.mallas[0].material_override
	marco.enfocar(mueble)
	assert_object(mueble.mallas[0].material_overlay).is_not_null()
	assert_object(mueble.mallas[0].mesh).is_same(geometria)
	assert_object(geometria.surface_get_material(0)).is_same(superficie)
	assert_object(mueble.mallas[0].material_override).is_same(material_previo)
	assert_bool(geometria.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] == uv).is_true()
	assert_int(mueble.get_child_count()).is_equal(3)
	marco.enfocar(mueble)
	marco.apagar()
	for indice in previos.size():
		assert_bool(mueble.mallas[indice].material_overlay == previos[indice]).is_true()
	assert_object(mueble.mallas[0].mesh).is_same(geometria)
	assert_object(geometria.surface_get_material(0)).is_same(superficie)
	assert_object(mueble.mallas[0].material_override).is_same(material_previo)
	assert_bool(geometria.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV] == uv).is_true()
	assert_int(mueble.get_child_count()).is_equal(3)


func test_cambiar_de_dueno_restaura_el_anterior() -> void:  # 039-AC4
	var marco: MarcoDelObjetivo = auto_free(MarcoDelObjetivo.new())
	var primero: Node3D = auto_free(Node3D.new())
	var segundo: Node3D = auto_free(Node3D.new())
	var malla := _malla()
	var otra := _malla()
	primero.add_child(malla)
	segundo.add_child(otra)
	marco.enfocar(primero)
	assert_object(malla.material_overlay).is_not_null()
	marco.enfocar(segundo)
	assert_object(malla.material_overlay).is_null()
	assert_object(otra.material_overlay).is_not_null()
	marco.apagar()
	assert_object(otra.material_overlay).is_null()


func test_sin_mallas_y_apagados_repetidos_no_cambian_el_dueno() -> void:  # 039-AC1 039-AC5
	var marco: MarcoDelObjetivo = auto_free(MarcoDelObjetivo.new())
	var vacio: Node3D = auto_free(Node3D.new())
	marco.apagar()
	marco.apagar()
	marco.enfocar(vacio)
	marco.apagar()
	marco.apagar()
	assert_int(vacio.get_child_count()).is_zero()


func test_el_overlay_recibe_los_valores_del_dominio() -> void:  # 039-AC6
	var marco: MarcoDelObjetivo = auto_free(MarcoDelObjetivo.new())
	var malla: MeshInstance3D = auto_free(_malla())
	marco.enfocar(malla)
	var material := malla.material_overlay as ShaderMaterial
	assert_object(material).is_not_null()
	assert_bool(material.get_shader_parameter("color") == IndicacionDelFoco.COLOR).is_true()
	assert_float(material.get_shader_parameter("grosor")).is_equal(IndicacionDelFoco.GROSOR)
	marco.apagar()


func _malla() -> MeshInstance3D:
	var malla := MeshInstance3D.new()
	var geometria := BoxMesh.new()
	geometria.material = StandardMaterial3D.new()
	malla.mesh = geometria
	return malla
