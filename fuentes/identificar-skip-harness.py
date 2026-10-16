import io,json,sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path.cwd()/'.claude/scripts'))
nombre='tests.test_mcp.LosAssets.test_un_asset_sin_referencias_miradas_no_se_declara_huerfano_si_hay_comprimidos'
salida=io.StringIO()
resultado=unittest.TextTestRunner(stream=salida,verbosity=2).run(unittest.defaultTestLoader.loadTestsFromName(nombre))
out=Path(__file__).parent/'full-02'
(out/'harness-skip-identificado.log').write_text(salida.getvalue(),encoding='utf8')
assert len(resultado.skipped)==1 and not resultado.errors and not resultado.failures
(out/'harness-skip-identificado.json').write_text(json.dumps({'test':nombre,'motivo':resultado.skipped[0][1],'alcance':'El mismo único skip figura en harness de base, full01 y full02. Esta sonda estática ejerce su condición existente; no modifica ni sustituye ningún nodo.'},ensure_ascii=False,indent=2),encoding='utf8')
print(salida.getvalue())
