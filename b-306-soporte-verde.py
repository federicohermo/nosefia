from pathlib import Path
root=Path.cwd()
p=root/'src/escenas/puestos/exterior_del_almacen.gd';t=p.read_text(encoding='utf-8')
old='\t\t\tsuelo\n\t\t)\n\tvar fondo'
assert old in t;t=t.replace(old,'\t\t\tsuelo\n\t\t).create_trimesh_collision()\n\tvar fondo',1)
t=t.replace('material: ShaderMaterial\n) -> void:\n\tvar datos: Array', 'material: ShaderMaterial\n) -> MeshInstance3D:\n\tvar datos: Array',1)
t=t.replace('\tadd_child(instancia, true)\n','\tadd_child(instancia, true)\n\treturn instancia\n',1)
p.write_text(t,encoding='utf-8')
p=root/'test/escenas/objetos/mancha_en_el_piso_test.gd';t=p.read_text(encoding='utf-8')
t=t.replace('test_los_espejos_estan_y_el_almacen_no_decide_nada','test_las_reglas_de_limpieza_tienen_sus_espejos')
a=t.index('\tvar almacen := FileAccess.get_file_as_string("res://src/escenas/almacen.gd")',t.index('func test_las_reglas_de_limpieza_tienen_sus_espejos'))
t=t[:a]+t[t.index('\n\n',t.index('\n\t)',a))+2:]
p.write_text(t,encoding='utf-8')
p=root/'docs/architecture/capacidades.md';t=p.read_text(encoding='utf-8').replace('  CLN -- "obligatorias cumplidas" --> SHF','  CLN -- "obligatorias cumplidas" --> SHF\n  CLN -- "motivos únicos de la noche" --> EMP\n  STK -- "unidades sueltas" --> CLN');p.write_text(t,encoding='utf-8')
p=root/'test/dominio/reglas_test.gd';t=p.read_text(encoding='utf-8').replace('\tassert_int(Reglas.APERCIBIMIENTOS_POR_AVISO).is_equal(1)','\tassert_int(Reglas.MEDIOS_POR_APERCIBIMIENTO).is_equal(2)\n\tassert_int(Reglas.MEDIOS_POR_LLAMADO).is_equal(1)\n\tassert_int(Reglas.APERCIBIMIENTOS_POR_AVISO).is_equal(1)');p.write_text(t,encoding='utf-8')
p=root/'test/dominio/empleo/politica_de_guardado_test.gd';t=p.read_text(encoding='utf-8').replace('test_los_datos_llevan_la_jornada_y_los_apercibimientos_de_la_partida', 'test_los_datos_llevan_la_jornada_y_los_medios_de_la_partida').replace('assert_int(retomada.apercibimientos()).is_equal(partida.apercibimientos())','assert_int(retomada.medios()).is_equal(partida.medios())');p.write_text(t,encoding='utf-8')
