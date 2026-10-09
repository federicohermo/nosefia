from pathlib import Path
import re
root=Path.cwd()
p=root/'src/dominio/empleo/legajo.gd'
t=p.read_text(encoding='utf-8')
t=t.replace('var _apercibimientos: int = 0','var _medios: int = 0')
a=t.index('static func con_medios('); b=t.index('## Anota el cierre',a)
t=t[:a]+'''## Restaura la deuda exacta, incluida la mitad de un apercibimiento.
static func con_medios(medios: int) -> Legajo:
	var legajo := Legajo.new()
	legajo._medios = medios
	return legajo


func medios() -> int:
	return _medios


'''+t[b:]
t=t.replace('_llamados: int = 0','llamados: int = 0')
t=t.replace('\tmatch Consecuencias.consecuencia_de', '\tvar puntos: int = 0\n\tmatch Consecuencias.consecuencia_de')
t=t.replace('_apercibimientos += Reglas.APERCIBIMIENTOS_POR_AVISO','puntos = Reglas.APERCIBIMIENTOS_POR_AVISO')
t=t.replace('_apercibimientos += Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE','puntos = Reglas.APERCIBIMIENTOS_POR_BANDA_GRAVE\n\t_medios += puntos * Reglas.MEDIOS_POR_APERCIBIMIENTO + llamados * Reglas.MEDIOS_POR_LLAMADO')
t=t.replace('func apercibimientos() -> int:\n\treturn _apercibimientos','@warning_ignore("integer_division")\nfunc apercibimientos() -> int:\n\treturn _medios / Reglas.MEDIOS_POR_APERCIBIMIENTO')
t=t.replace('return _apercibimientos >= Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO','return _medios >= Reglas.APERCIBIMIENTOS_HASTA_EL_DESPIDO * Reglas.MEDIOS_POR_APERCIBIMIENTO')
p.write_text(t,encoding='utf-8')
p=root/'src/dominio/empleo/partida.gd'; t=p.read_text(encoding='utf-8')
t=t.replace('var _final: Final = Final.EN_CURSO','var _final: Final = Final.EN_CURSO\nvar _llamados: Array[Llamado] = []')
t=t.replace('func anotar_llamado(_llamado: Llamado) -> void:\n\tpass','func anotar_llamado(llamado: Llamado) -> void:\n\tif not _jornada_abierta or terminada() or _llamados.has(llamado):\n\t\treturn\n\t_llamados.append(llamado)')
t=t.replace('func medios() -> int:\n\treturn 0','func medios() -> int:\n\treturn _legajo.medios()')
t=t.replace('var apercibimientos: int = saneado','var medios: int = saneado').replace('Legajo.con_apercibimientos(apercibimientos)','Legajo.con_medios(medios)')
t=t.replace('Campo.APERCIBIMIENTOS','Campo.MEDIOS')
t=t.replace('\t_obligatorias = Apertura.obligatorias()','\t_llamados.clear()\n\t_obligatorias = Apertura.obligatorias()')
t=t.replace('_legajo.registrar(cumplidas, _obligatorias.size())','_legajo.registrar(cumplidas, _obligatorias.size(), _llamados.size())')
t=t.replace('## Los apercibimientos acumulados, para el parte del jefe y el guardado.','## Los apercibimientos enteros acumulados, para el comentario del jefe.')
p.write_text(t,encoding='utf-8')
for name in ['src/dominio/empleo/partida_serializada.gd','src/dominio/empleo/politica_de_guardado.gd']:
 p=root/name; t=p.read_text(encoding='utf-8').replace('APERCIBIMIENTOS','MEDIOS').replace('partida.apercibimientos()','partida.medios()'); p.write_text(t,encoding='utf-8')
# Migración de lectores existentes: preserva sus puntos enteros expresados en medios.
for p in (root/'test').rglob('*.gd'):
 t=p.read_text(encoding='utf-8')
 if 'con_apercibimientos(' in t:
  t=re.sub(r'con_apercibimientos\(([^()]*)\)',r'con_medios((\1) * Reglas.MEDIOS_POR_APERCIBIMIENTO)',t)
 if 'PartidaSerializada.Campo.APERCIBIMIENTOS' in t:
  t=t.replace('PartidaSerializada.Campo.APERCIBIMIENTOS','PartidaSerializada.Campo.MEDIOS')
 p_old=p.read_text(encoding='utf-8')
 if t!=p_old: p.write_text(t,encoding='utf-8')
