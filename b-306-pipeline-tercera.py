from pathlib import Path

s = Path('C:/Users/fede_/orca/workspaces/nosefia/darter/.claude/scratch/batch-64-309')
out = Path(__file__).parent
for filename in ['b-306-archivar.py', 'b-306-publicar-proof.py']:
    p = s / filename
    text = p.read_text(encoding='utf-8').replace('b-306-full2', 'b-306-full3').replace("'formal_final_full': 2", "'formal_final_full': 3").replace('FULL2 formal final', 'FULL3 formal final (tercera corrida)')
    if filename == 'b-306-archivar.py':
        text = text.replace("'diagnostic_copies_not_final_proof': True", "'second_formal_full_failed': {'suites': 214, 'cases': 1671, 'assertions': 1, 'errors': 0, 'xml_sha256': '29a93f2a58e321771d51187e706b344458a521d74ff06409123fc836e0ce20e9'}, 'diagnostic_copies_not_final_proof': True")
        text = text.replace("paths += list(s.glob('padre-306-whole-*.md'))", "paths += list(out.glob('b-306-whole-*.md'))\npaths += list(s.glob('padre-306-whole-*.md'))")
    p.write_text(text, encoding='utf-8')
p = out / 'b-306-cerrar-issue.py'
p.write_text(p.read_text(encoding='utf-8').replace('b-306-full2', 'b-306-full3').replace('padre-306-whole-cabinas.md', 'padre-306-whole-carga-recorrido.md'), encoding='utf-8')
p = s / 'b-306-pr-preparado.md'
text = p.read_text(encoding='utf-8').replace('FULL2 formal final', 'FULL3 formal final (tercera corrida)').replace('Alcance47archivos', 'Alcance48archivos')
text = text.replace('- PENDIENTE_FULL', '- FULL2 formal fallido: 214 suites/1671 casos, una aserción y cero errores. El único fallo fue la carga física del contenedor; XML `29a93f2a58e321771d51187e706b344458a521d74ff06409123fc836e0ce20e9` preservado. GREEN4 y diagnósticos geométricos fallidos se conservan sin contarlos como convergencia.\n- PENDIENTE_FULL')
text += '\nEl montaje de carga del contenedor movía un marcador que el gesto normal recolocaba al borde delantero: 27/28 cuerpos salían de otra pose. La prueba ahora conserva cada orientación y obtiene la boca con rayos a sus cuatro paredes, erosiona sus límites por la forma real, elige una pose libre y comprueba un recorrido vertical con máscara original y sólo exclusión propia. La gravedad, las 28 unidades y tiempos, más de seis cuerpos dentro, bloqueo del cierre y ausencia de penetración permanecen exigidos. El issue completo se publicó antes de ampliar a la ruta 48 y antes de variar XZ.\n'
p.write_text(text, encoding='utf-8')
for directory in [out, Path('D:/temporales/nosefia-batch-64-309/empleo-307')]:
    for p in directory.glob('b-307-preparar.py'):
        p.write_text(p.read_text(encoding='utf-8').replace('b-306-full2-resultados.json', 'b-306-full3-resultados.json'), encoding='utf-8')
