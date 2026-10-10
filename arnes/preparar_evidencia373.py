"""Reúne evidencia final y separa los intentos inválidos, sin tocar el checkout."""

from collections import Counter
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess

s = Path(__file__).parent
w = Path.cwd()
e = s / 'capturas373'
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()
producto = '33828836d19b8913efbc0c3d2dc09186b5af13f6'


def copiar(origen, destino):
    destino.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(origen, destino)


def texto(ruta):
    return re.sub(r'\x1b\[[0-9;]*m', '', ruta.read_text(encoding='utf-8', errors='replace'))


def diagnosticos(ruta):
    return Counter(re.sub(r'@(StaticBody3D|RigidBody3D|AnimatableBody3D)@\d+', r'@\1@<id>', line)
                   for line in texto(ruta).splitlines()
                   if line.startswith(('ERROR:', 'SCRIPT ERROR:', 'WARNING:')))


final = texto(s / '373-final-2.log')
assert '7/7 nodos en verde' in final, final
crudo = texto(s / '373-final-2-tests.log')
archivos = len(list((w / 'test').rglob('*_test.gd')))
assert f'Executed test suites: ({archivos}/{archivos})' in crudo
assert 'SCRIPT ERROR:' not in crudo
casos = re.search(r'Executed test cases\s*:\s*\((\d+)/(\d+)\)', crudo)
assert casos and casos[1] == casos[2]
base = diagnosticos(s / '370-final-1-tests.log')
actual = diagnosticos(s / '373-final-2-tests.log')
assert not actual - base, actual - base

diff = subprocess.check_output(['git', 'diff', producto, head, '--'], encoding='utf-8')
escritos = subprocess.check_output(['git', 'diff', '--name-only', producto, head], text=True).splitlines()
assert sorted(escritos) == [
    'src/dominio/investigacion/conversacion.gd',
    'test/sistemas/investigacion/celular_del_empleado_test.gd',
], escritos
for nombre in escritos:
    antes = subprocess.check_output(['git', 'show', producto + ':' + nombre]).decode('utf-8')
    despues = subprocess.check_output(['git', 'show', head + ':' + nombre]).decode('utf-8')
    if nombre.endswith('/conversacion.gd'):
        quitar = '@export var imagen: Texture2D = null\n\n'
        assert antes.replace(quitar, '') == despues.replace(quitar, '')
    else:
        assert antes.replace('test_recibir_cerrado_y_en_chat_avisa_una_vez_por_mensaje_valido',
                             'test_recibir_cerrado_y_en_chat_avisa_una_vez') == despues
(e / 'diff-producto-a-final.patch').write_text(diff, encoding='utf-8')

validos = ['373-rojo-dominio.log', '373-rojo-sistema.log', '373-rojo-ui.log',
           '373-rojo-cursor.log', '373-rojo-cursor-2.log',
           '373-native-cursor.log', '373-export-cursor-2.log', '373-web-final-5.log',
           '373-alcance-final.json', '373-trazabilidad-TDD.json', '373-aprobacion-padre.md']
validos += ['373-final-1-comparacion-diagnosticos.json', '373-final-2-comparacion-diagnosticos.json']
validos += [p.name for p in s.glob('373-final-*.log')]
validos += ['373-focal-' + str(i) + '.log' for i in [2, 3, 4, 5, 7, 9, 10]]
for nombre in validos:
    copiar(s / nombre, e / 'verificacion' / nombre)
copiar(s / 'harness-tests.log', e / 'base' / 'harness-tests.log')
copiar(s / '370-final-1-tests.log', e / 'base' / '370-final-1-tests.log')
reporte = re.search(r'reports/report_\d+', final)[0]
copiar(w / reporte / 'results.xml', e / 'verificacion' / 'results.xml')
(e / 'verificacion' / 'suites-en-el-checkout.txt').write_text(
    '\n'.join(sorted(p.relative_to(w).as_posix() for p in (w / 'test').rglob('*_test.gd'))),
    encoding='utf-8')

for nombre in ['373-cursor-rojo-fuentes', '373-cursor-rojo-2-fuentes', '373-rojo-ui-fuentes']:
    for p in (s / nombre).rglob('*'):
        if p.is_file():
            copiar(p, e / 'tdd' / nombre / p.relative_to(s / nombre))

for nombre in ['373-focal-1.log', '373-focal-6.log', '373-focal-8.log',
               '373-preview-nativo.log', '373-preview-nativo-2.log', '373-preview-nativo-3.log',
               '373-preview-verbose.log', '373-export-final.log', '373-export-final-2.log',
               '373-import-verbose.log', '373-export-cursor.log', '373-export-flecha.log',
               '373-web-final.log', '373-web-final-2.log', '373-web-final-3.log',
               '373-web-final-4.log', '373-cursor-diagnostico.log',
               '373-cursor-diagnostico.json', '373-cursor-diagnostico-pasivo.json',
               '373-solicitudes-1920.json', '373-solicitudes-1280.json']:
    copiar(s / nombre, e / 'historico' / nombre)
for nombre in ['373-web-invalido-1', '373-web-invalido-2', '373-web-invalido-3', '373-web-invalido-4']:
    for p in (s / nombre).rglob('*'):
        if p.is_file():
            copiar(p, e / 'historico' / nombre / p.relative_to(s / nombre))

export = s / '373-web-33828836'
for nombre in ['huellas.json', 'importar.log', 'exportar-reintento.log', 'dialogos.log']:
    copiar(export / nombre, e / 'paquete' / nombre)
for nombre in ['bootstrap373.gd', 'capturar373-largo.gd', 'capturar_native_final373.py',
               'navegador373.cjs', 'ejecutar_web373.py', 'medir_pixeles373.py',
               'verificar_alcance373.py', 'verificar_con_crudo.py',
               'exportar373-flecha.py', 'reexportar373-flecha.py',
               'diagnostico_solicitudes373.cjs', 'preparar_evidencia373.py']:
    copiar(s / nombre, e / 'arnes' / nombre)

resumen = {
    'head_final': head, 'producto_renderizado_y_exportado': producto,
    'base_fija': 'cd5f93c38dfc140398759c52431bcece29985fd9',
    'base_apilada': '35009014d90c61bd0d719d7744e134bab99a7519',
    'full_intentos': 2, 'primer_full': '6/7, sólo lint', 'full_final': final,
    'suites': archivos, 'casos': int(casos[1]), 'script_errors': 0,
    'diagnosticos_nuevos': dict(actual - base),
    'diagnosticos_retirados': dict(base - actual),
    'diagnosticos_base_stdout_stderr': dict(base),
    'diagnosticos_final_stdout_stderr': dict(actual),
    'base_diagnosticos': '370-final-1-tests.log: incorpora fixtures reales369/370',
    'normalizacion_diagnosticos': 'Sólo IDs numéricos autogenerados de StaticBody3D/RigidBody3D/AnimatableBody3D',
    'prueba_de_equivalencia': 'diff-producto-a-final.patch: sólo orden de export y nombre de test',
}
(e / 'resultado-final.json').write_text(json.dumps(resumen, ensure_ascii=False, indent=2), encoding='utf-8')
(e / 'README.md').write_text(f'''Evidencia de #373, cabeza final `{head}`.

Producto exportado y renderizado: `{producto}`. `diff-producto-a-final.patch` contiene sólo
el orden de la declaración exportada de imagen y el nombre de un test; sus cuerpos, datos,
callbacks, proyecto, preset y arte se conservan. No se usa una captura de un producto distinto.

Verificación final: 7/7 nodos, {archivos}/{archivos} suites y {casos[1]}/{casos[1]} casos.
El conteo de archivos se ejecutó inmediatamente al terminar el verificador. La primera
convergencia fue 6/7, con gdUnit íntegro verde y sólo lint rojo; se conserva completa.
No hay errores de script ni huérfanos de gdUnit. El diagnóstico completo de motor coincide
con #370 incorporado, normalizando únicamente IDs autogenerados de nodos; todos los warnings
se conservan. `base/harness-tests.log` también conserva la medición anterior de 141 ObjectDB,
100 recursos y PagedAllocator, con stdout y stderr (el antiguo log de motor aislado omitía stderr).

Las PNG de la raíz y sus métricas son las capturas finales aprobadas, a 1920×1080 y 1280×720.
Web usa Chrome que dibuja, CDP pasivo userGesture:false, física/reloj reales y ningún wrapper
de solicitudes; Q es el primer gesto después de la placa. Consolas completas sin errores,
RAF 133/138, seis fases de lock false/false/false/true/false/true. Se observa el lock real del DOM.
La foto de esta prueba usa dos mensajes efímeros, una persiana y el adjunto largo de 292caracteres;
no modifica los tres guiones literales del juego. La flecha geométrica se ve en ambas plataformas.

`paquete/` conserva el import frío, export warm, sonda PCK estrictos limpios y SHA256 de todas
las piezas. El preset es el versionado exacto; sólo se deshabilitan editor_plugins en la copia
externa y se cambia su main_scene para observar el flujo real. `arnes/` conserva sus fuentes.

`verificacion/` contiene rojos por aserción y focales verdes. `tdd/` contiene las huellas y
fuentes conservadas del rojo UI y los dos contrastes de cursor. El segundo rojo de cursor es
posterior al primer mínimo verde y corrige el getter headless del fixture: no se afirma que
esa segunda repetición haya precedido a la implementación. Los rojos de dominio/sistemas
precedieron a sus mínimos verdes; no se inventan hashes de sus fuentes originales no guardados.

`historico/` conserva intentos inválidos: fixtures con scripts/World3D/referencias defectuosas,
cache global no reimportada, primer export frío con 8 recursos, observador activo y recorridos
web que rechazaron el cursor antes de la corrección de cáscara. Sus PNG y logs NO cuentan
como evidencia aprobada. La clasificación y los resúmenes están en 373-trazabilidad-TDD.json.

`sha256.json` lista bytes y SHA256 de cada artefacto previo al manifiesto. La publicación se
contrasta además contra cada blob Git remoto y se informa su commit en el PR.
''', encoding='utf-8')
manifiesto = {p.relative_to(e).as_posix(): {'bytes': p.stat().st_size,
              'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
              for p in sorted(e.rglob('*')) if p.is_file() and p.name != 'sha256.json'}
(e / 'sha256.json').write_text(json.dumps(manifiesto, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(resumen, ensure_ascii=False, indent=2))
print(f'{len(manifiesto)} archivos listos para capturas/373')
