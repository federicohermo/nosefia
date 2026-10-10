import collections
import json
import re
from pathlib import Path

scratch = Path(__file__).parent
ansi = re.compile(r'\x1b\[[0-9;]*m')


def diagnosticos(nombre):
    texto = ansi.sub('', (scratch / nombre).read_text(encoding='utf8'))
    return collections.Counter(linea for linea in texto.splitlines()
                               if linea.startswith(('ERROR:', 'SCRIPT ERROR:', 'WARNING:')))


base = diagnosticos('369-final-2-tests.log')
actual = diagnosticos('370-final-1-tests.log')
resultado = dict(base=dict(base), actual=dict(actual), agregados=dict(actual-base), retirados=dict(base-actual))
(scratch / '370-diagnosticos-full1.json').write_text(json.dumps(resultado, ensure_ascii=False, indent=2)+'\n', encoding='utf8')
print(json.dumps(resultado, ensure_ascii=False, indent=2))
