from collections import Counter
from pathlib import Path
import re
import sys

scratch = Path(__file__).parent
ansi = re.compile(r'\x1b\[[0-9;]*m')


def diagnosticos(nombre):
    texto = (scratch / nombre).read_text(encoding='utf-8', errors='replace')
    return Counter(linea for linea in ansi.sub('', texto).splitlines()
                   if linea.startswith(('ERROR:', 'WARNING:', 'SCRIPT ERROR:')))


base = diagnosticos('301-final-tests.log')
actual = diagnosticos(sys.argv[1])
print('Diagnósticos adicionales respecto a full301:')
for linea, cantidad in sorted((actual - base).items()):
    print(cantidad, linea)
print('Diagnósticos ausentes respecto a full301:')
for linea, cantidad in sorted((base - actual).items()):
    print(cantidad, linea)
