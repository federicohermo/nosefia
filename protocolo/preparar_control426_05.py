from pathlib import Path
p=Path(__file__).parent/'426'
s=(p/'diagnostico426_04.gd').read_text(encoding='utf-8')
helper='''func _apuntar(punto: Vector3) -> void:
	var vector := punto - _vista.global_position
	var plano := Vector3(vector.x, 0, vector.z)
	var control: ControlDelJugador = _jugador.get("_control")
	var mirada: Mirada = control.get("_mirada")
	control.orientar(Basis.looking_at(plano, Vector3.UP).get_euler().y)
	var pitch := atan2(vector.y, plano.length())
	control.girar(Vector2(0, -pitch / float(mirada.get("_sensibilidad"))))
	await _cuadros(20)
	_jugador.call("_aplicar_la_rotacion")


'''
s=s.replace('func _mirar(',helper+'func _mirar(',1)
s=s.replace('_vista.look_at(', 'await _apuntar(')
(p/'diagnostico426_05.gd').write_bytes(s.encode('utf-8'))
s=(p/'control_ciclo426_04.py').read_text(encoding='utf-8').replace('diagnostico426_04.gd','diagnostico426_05.gd').replace('nativo-04','nativo-05')
s=s.replace('Control04: antes de la primera escena espera un process_frame/frame_post_draw de raiz; captura arranque y registra identidad de camara real. No cambia fuente, luz, GI ni colliders.', 'Control05: conserva04 pero todas las rotaciones pasan por ControlDelJugador.orientar/girar; no Camera3D.look_at directo. Fuente, luz, GI y colliders intactos. No atribuye causa antes del resultado.')
(p/'control_mirada426_05.py').write_bytes(s.encode('utf-8'))
