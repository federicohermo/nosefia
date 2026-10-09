from pathlib import Path
r=Path.cwd()
p=r/'test/dominio/almacen/reglas_del_cierre_test.gd';t=p.read_text(encoding='utf-8')
names=[('una_unidad_suelta_desordena_cualquier_habitacion','UNIDAD_SUELTA','[true, true, true, false]','AC-CLN-041'),('una_caja_solo_queda_ordenada_en_el_deposito','CAJA','[true, false, true, false]','AC-CLN-042'),('un_util_solo_queda_ordenado_en_el_bano','UTIL_DE_LIMPIEZA','[true, true, false, false]','AC-CLN-042'),('los_otros_objetos_adentro_no_producen_desorden','OTRO','[false, false, false, false]','AC-CLN-042, AC-CLN-044')]
for name,clase,expected,ids in names:
 a=t.index('func test_'+name);b=t.index('\n\nfunc ',a)
 body=f'''func test_{name}() -> void:  # {ids}
	var desorden: Array[bool] = {expected}
	for habitacion: ReglasDelCierre.Habitacion in HABITACION.values():
		for en_mano: bool in [false, true]:
			var estados: Array[ReglasDelCierre.Estado] = [
				ReglasDelCierre.Estado.new(CLASE.{clase}, habitacion, en_mano)
			]
			assert_bool(ReglasDelCierre.hay_desorden(estados)).is_equal(
				desorden[habitacion] and not en_mano
			)
			assert_bool(ReglasDelCierre.hay_objetos_afuera(estados)).is_equal(
				habitacion == HABITACION.AFUERA and not en_mano
			)
'''
 t=t[:a]+body+t[b:]
t=t[:t.index('## Cada fila se ejerce suelta')].rstrip()+'\n'
p.write_text(t,encoding='utf-8')
p=r/'test/escenas/puestos/habitaciones_del_almacen_test.gd';t=p.read_text(encoding='utf-8')
t=t.replace('\t_afirmar_centros(lector)','\tassert_array(_habitaciones_de_los_centros(lector)).contains_exactly(\n\t\t[ReglasDelCierre.Habitacion.LOCAL, ReglasDelCierre.Habitacion.DEPOSITO, ReglasDelCierre.Habitacion.BANO]\n\t)')
a=t.index('func _afirmar_centros');b=t.index('\n\nfunc ',a)
t=t[:a]+'''func _habitaciones_de_los_centros(lector: Habitaciones) -> Array[int]:
	return [
		lector.de(lector.to_global(lector.local[0].get_center())),
		lector.de(lector.to_global(lector.deposito[0].get_center())),
		lector.de(lector.to_global(lector.bano[0].get_center())),
	]
'''+t[b:]
p.write_text(t,encoding='utf-8')
