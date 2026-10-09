from pathlib import Path
import subprocess

out = Path(__file__).parent
text = (out / 'b-306-contenedor-geometrico-propuesta.gd').read_text(encoding='utf-8')
text = text.replace('_dejar_caer_en_la_boca(almacen, contenedor, unidad, unidades, boca, indice)', '_dejar_caer_en_la_boca(almacen, unidad, unidades, boca)')
start = text.index('\tassert_float(tapa.get("_tapa").angulo())') if '\tassert_float(tapa.get("_tapa").angulo())' in text else -1
if start >= 0:
    text = text[:start] + text[text.index('\tvar agarre:', start):]
else:
    import re
    text = re.sub(r'\tassert_float\(tapa.get\("_tapa"\).angulo\(\)\)\s*\.is_equal_approx\(TapaDelContenedor.ANGULO_ABIERTA, 0.00001\)\n', '', text)
text = text.replace('\tcontenedor: StaticBody3D,\n\tunidad:', '\tunidad:').replace('\tboca: AABB,\n\tindice: int\n', '\tboca: AABB\n')
start = text.index('\tvar tapa: TapaDelLocal', text.index('func _dejar_caer_en_la_boca('))
end = text.index('\tvar apoyo :=', start)
text = text[:start] + text[end:]
start = text.index('\t\t\tconsulta.motion = (', text.index('func _dejar_caer_en_la_boca('))
end = text.index('\t\t\tunidad.global_position = destino', start)
text = text[:start] + text[end:]
text = text.replace('\tassert_float(hasta.x - desde.x).is_greater(0.0)\n', '').replace('\tassert_float(hasta.z - desde.z).is_greater(0.0)\n', '')
start = text.index('\tconsulta.transform = forma.global_transform\n', text.index('\tunidad.reset_physics_interpolation()', text.index('func _dejar_caer_en_la_boca(')))
text = text[:start]
text = text.replace('\t# Recorre primero el centro y alterna dentro de la boca erosionada por la forma real.', '\t# El gesto recoloca sobre el borde mirado: montar una caída real por la boca prueba\n\t# la contención sin depender de ese ajuste ni cambiar orientación, gravedad o colisiones.')
path = out / 'b-306-contenedor-minimo-propuesta.gd'
path.write_text(text, encoding='utf-8')
subprocess.run(['gdformat', str(path)], check=True)
subprocess.run(['gdlint', str(path)], check=True)
