from pathlib import Path
p=Path(__file__).parent/'426'
s=(p/'diagnostico426_02.gd').read_text(encoding='utf-8')
s=s.replace('\tawait _cuadros(20)\n\n\nfunc _destruir', '\tawait _cuadros(20)\n\tawait _captura("arranque-" + str(_registro.size()))\n\n\nfunc _destruir',1)
s=s.replace('\t_registro.append(\n\t\t{\n\t\t\t"captura": nombre,', '\tvar actual := root.get_camera_3d()\n\t_registro.append(\n\t\t{\n\t\t\t"camara_actual": str(actual.get_path()) if actual else "null",\n\t\t\t"camara_esperada": str(_vista.get_path()),\n\t\t\t"camara_correcta": actual == _vista,\n\t\t\t"captura": nombre,',1)
s=s.replace('\tawait _saladik()\n', '\t# Control del ciclo de vida del fixture: dejar dibujar la raiz antes de crear la primera escena.\n\tawait process_frame\n\tawait RenderingServer.frame_post_draw\n\tawait _saladik()\n',1)
(p/'diagnostico426_04.gd').write_bytes(s.encode('utf-8'))
s=(p/'repetir_nativo426_03.py').read_text(encoding='utf-8').replace('diagnostico426_02.gd','diagnostico426_04.gd').replace('nativo-03','nativo-04')
s=s.replace("'control':'Mismo script diagnostico426_04.gd, mismo renderer/entorno/argumentos; solo cambia carpeta de salida.'", "'control':'Control04: antes de la primera escena espera un process_frame/frame_post_draw de raiz; captura arranque y registra identidad de camara real. No cambia fuente, luz, GI ni colliders.'")
(p/'control_ciclo426_04.py').write_bytes(s.encode('utf-8'))
