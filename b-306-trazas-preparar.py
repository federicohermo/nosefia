from pathlib import Path
import hashlib, json, subprocess

root = Path.cwd()
out = root / '.godot/b306-diagnostico'
out.mkdir(exist_ok=True)
scratch = Path(__file__).parent
filters = json.loads(Path('C:/Users/fede_/AppData/Local/Temp/nosefia-batch-64-309/c-gdunit-casos-exactos/argumentos-2390328d.json').read_text())
helper = '''

func _b306_golpe(golpe: Dictionary) -> Dictionary:
	if golpe.is_empty():
		return {}
	var cuerpo := golpe.collider as CollisionObject3D
	var dueno := cuerpo.shape_owner_get_owner(cuerpo.shape_find_owner(golpe.shape)) as Node
	return {"cuerpo": str(cuerpo.get_path()), "dueno": str(dueno.get_path()), "pos": str(golpe.position), "normal": str(golpe.normal), "rid": str(golpe.rid)}

func _b306_traza(almacen: Node3D, jugador: CharacterBody3D, objeto: Node3D, etapa: String) -> void:
	var espacio := almacen.get_world_3d().direct_space_state
	var exclusiones: Array[RID] = [jugador.get_rid(), (objeto as CollisionObject3D).get_rid()]
	var ray := PhysicsRayQueryParameters3D.create(jugador.global_position + Vector3.UP * 0.5, Vector3(objeto.global_position.x, jugador.global_position.y + 0.5, objeto.global_position.z))
	ray.exclude = exclusiones
	var piso := PhysicsRayQueryParameters3D.create(jugador.global_position + Vector3.UP * 0.1, jugador.global_position + Vector3.DOWN * 5.0)
	piso.exclude = exclusiones
	var ojo: Transform3D = jugador.call("mira")
	var mira := PhysicsRayQueryParameters3D.create(ojo.origin, ojo.origin - ojo.basis.z * ReglasDelJugador.ALCANCE_DE_LA_MIRA)
	mira.exclude = exclusiones
	var datos := {"etapa": etapa, "objeto": str(objeto.name), "pos": str(objeto.global_position), "jugador": str(jugador.global_position), "velocidad": str(jugador.velocity), "en_piso": jugador.is_on_floor(), "padre": str(objeto.get_parent().get_path()), "segmento": _b306_golpe(espacio.intersect_ray(ray)), "piso_jugador": _b306_golpe(espacio.intersect_ray(piso)), "mira": _b306_golpe(espacio.intersect_ray(mira))}
	if objeto is RigidBody3D:
		var cuerpo := objeto as RigidBody3D
		var formas: Array[CollisionShape3D] = jugador.call("_formas_de", cuerpo)
		var limites: AABB = jugador.call("_limites_de", cuerpo, formas)
		var capsula := (jugador.get_node("Cuerpo") as CollisionShape3D).shape as CapsuleShape3D
		var ancho := Vector2(limites.size.x, limites.size.z).length() / 2.0
		var lugares := LugaresDelPiso.alrededor(espacio, jugador.global_position, jugador.call("frente"), capsula.radius + ancho + ReglasDeLosObjetos.ROCE, limites.size.y, ReglasDeLosObjetos.CAIDA_HASTA_EL_PISO, ReglasDeLosObjetos.LADOS_ALREDEDOR, cuerpo.collision_mask, exclusiones)
		datos["lugares"] = str(lugares)
	print("B306TRAZA ", JSON.stringify(datos))
'''
rows = []
for label in ['soltado', 'charco', 'notas']:
    item = filters[label]
    source = root / item['suite']
    text = source.read_text(encoding='utf-8')
    original = text
    if label == 'soltado':
        old = '\t_accion(jugador, objeto, ReglasDeLosObjetos.ACCION_AGARRAR)\n\t(\n\t\tassert_object(agarre.manos().sostenido())'
        new = '\t_b306_traza(almacen, jugador, objeto, "antes_" + donde)\n\t_accion(jugador, objeto, ReglasDeLosObjetos.ACCION_AGARRAR)\n\t_b306_traza(almacen, jugador, objeto, "despues_" + donde)\n\t(\n\t\tassert_object(agarre.manos().sostenido())'
        assert text.count(old) == 1
        text = text.replace(old, new)
    elif label == 'charco':
        old = '\t\t_apuntar_a(jugador, mancha)\n'
        assert text.count(old) == 1
        text = text.replace(old, '\t\t_b306_traza(almacen, jugador, caja, "antes_" + str(mancha.name))\n' + old)
        old = '\t\t_accion(jugador, mancha, ReglasDeLosObjetos.ACCION_AGARRAR)\n'
        assert text.count(old) == 1
        text = text.replace(old, old + '\t\t_b306_traza(almacen, jugador, caja, "despues_" + str(mancha.name))\n')
    else:
        text = text.replace('\t\t\tif golpe.is_empty():\n\t\t\t\tcontinue', '\t\t\tprint("B306NOTA ", hoja.get_path(), " candidato=", punto, " piso=", JSON.stringify(_b306_golpe(golpe)))\n\t\t\tif golpe.is_empty():\n\t\t\t\tcontinue')
        text = text.replace('\t\t\t\tcontinue\n\t\t\tvar posicion:', '\t\t\t\tprint("B306NOTA rechazo_nombre")\n\t\t\t\tcontinue\n\t\t\tvar posicion:')
        old = '\t\t\tif not espacio.intersect_shape(volumen).is_empty():\n\t\t\t\tcontinue'
        assert text.count(old) == 1
        text = text.replace(old, '\t\t\tvar obstaculos := espacio.intersect_shape(volumen)\n\t\t\tif not obstaculos.is_empty():\n\t\t\t\tfor obstaculo: Dictionary in obstaculos:\n\t\t\t\t\tprint("B306NOTA rechazo_capsula ", obstaculo.collider.get_path())\n\t\t\t\tcontinue')
        text = text.replace('\t\t\tvar impacto := espacio.intersect_ray(consulta)\n', '\t\t\tvar impacto := espacio.intersect_ray(consulta)\n\t\t\tprint("B306NOTA ojo=", ojo, " hoja=", centro, " impacto=", JSON.stringify(_b306_golpe(impacto)))\n')
    text += helper
    dest = out / (label + '_test.gd')
    dest.write_text(text, encoding='utf-8')
    virtual = 'res://' + dest.relative_to(root).as_posix()
    actual = dest.relative_to(root).as_posix()
    args = ['-a', virtual]
    for excluded in item['excluidos']:
        args += ['-i', actual + ':' + excluded]
    rows.append({'label': label, 'original': item['suite'], 'original_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'copy': str(dest), 'copy_sha256': hashlib.sha256(dest.read_bytes()).hexdigest(), 'case': item['caso'], 'args': args})
    import difflib
    (scratch / ('b-306-trazas-' + label + '.diff')).write_text(''.join(difflib.unified_diff(original.splitlines(True), text.splitlines(True), fromfile=item['suite'], tofile=virtual)), encoding='utf-8')
proof = {'head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(), 'tracked_diff_sha256': hashlib.sha256(subprocess.check_output(['git', 'diff', '--binary'])).hexdigest(), 'diagnostico_no_final': True, 'timing_perturbado_por_prints': True, 'suites': rows}
(scratch / 'b-306-trazas-manifest.json').write_text(json.dumps(proof, indent=2), encoding='utf-8')
print(json.dumps(proof, indent=2))
