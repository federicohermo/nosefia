from pathlib import Path
root=Path.cwd()
for name in ['test/dominio/empleo/partida_serializada_test.gd','test/sistemas/marco/guardado_test.gd']:
 p=root/name; t=p.read_text(encoding='utf-8').replace('APERCIBIMIENTOS := "apercibimientos"','MEDIOS := "medios"')
 t=t.replace('[APERCIBIMIENTOS]','[MEDIOS]').replace('APERCIBIMIENTOS:', 'MEDIOS:').replace(', APERCIBIMIENTOS]', ', MEDIOS]').replace('\n\t\tAPERCIBIMIENTOS\n','\n\t\tMEDIOS\n')
 t=t.replace('MEDIOS: Reglas.APERCIBIMIENTOS_POR_AVISO,','MEDIOS: Reglas.APERCIBIMIENTOS_POR_AVISO * Reglas.MEDIOS_POR_APERCIBIMIENTO,')
 t=t.replace('Legajo.new().apercibimientos()', 'Legajo.new().medios()')
 t=t.replace('saneado[MEDIOS]).is_equal(Reglas.APERCIBIMIENTOS_POR_AVISO)','saneado[MEDIOS]).is_equal(Reglas.APERCIBIMIENTOS_POR_AVISO * Reglas.MEDIOS_POR_APERCIBIMIENTO)')
 p.write_text(t,encoding='utf-8')
p=root/'test/dominio/empleo/partida_test.gd';t=p.read_text(encoding='utf-8').replace('Reglas.APERCIBIMIENTOS_POR_AVISO,\n\t\t\t}', 'Reglas.APERCIBIMIENTOS_POR_AVISO * Reglas.MEDIOS_POR_APERCIBIMIENTO,\n\t\t\t}'); p.write_text(t,encoding='utf-8')
# Publicar resultado CI305 sin cambiar fuente.
p=Path(__file__).parent/'b-305-pr-final.md'; t=p.read_text(encoding='utf-8')
if '37913997909' not in t:
 t+='\nCI remota [37913997909](https://github.com/federicohermo/nosefia/actions/runs/37913997909) SUCCESS: 7/7 en707,6s,208suites/1629casos sin fallos,errores,salteos ni inestables. XML SHA256 `41dff73d48fb89586989a519c4fc8e7b136016c28e86412ae6b87dc841690ea2`, descargado y revisado por ROOT.\n'
 p.write_text(t,encoding='utf-8')
