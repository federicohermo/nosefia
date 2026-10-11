"""Reúne evidencia de #374 sin modificar el checkout ni sus artefactos originales."""

from collections import Counter
from pathlib import Path
import hashlib
import json
import re
import shutil
import subprocess
import zipfile

s = Path(__file__).parent
w = Path.cwd()
e = s / 'capturas374'
d = s / '374-web-4b589ec6'
head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip()


def copiar(origen, destino):
    destino.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(origen, destino)


def texto(p):
    return re.sub(r'\x1b\[[0-9;]*m', '', p.read_text(encoding='utf-8', errors='replace'))


def diagnosticos(p):
    return Counter(re.sub(r'@(StaticBody3D|RigidBody3D|AnimatableBody3D)@\d+', r'@\1@<id>', line)
                   for line in texto(p).splitlines()
                   if line.startswith(('ERROR:', 'SCRIPT ERROR:', 'WARNING:')))


final = texto(s / '374-final-3.log')
assert '7/7 nodos en verde' in final
crudo = texto(s / '374-final-3-tests.log')
archivos = len(list((w / 'test').rglob('*_test.gd')))
assert archivos == 239 and 'Executed test suites: (239/239)' in crudo
assert 'Executed test cases : (1823/1823)' in crudo
assert 'SCRIPT ERROR:' not in crudo
assert re.search(r'Overall Summary:.*1823 test cases \| 0 errors \| 0 failures \| 0 flaky \| 0 skipped \| 0 orphans', crudo)
producto = '4b589ec60b56c3b21c0145aa826d7881dbd5be2e'
escritos = subprocess.check_output(['git', 'diff', '--name-only', producto, head], text=True).splitlines()
assert escritos == ['test/dominio/empleo/instrucciones_del_jefe_test.gd',
                    'test/escenas/carga_del_almacen_test.gd'], escritos
subprocess.run(['git', 'diff', '--quiet', producto, head, '--', 'src', 'assets',
                'project.godot', 'export_presets.cfg'], check=True)
(e / 'diff-producto-a-final.patch').write_bytes(subprocess.check_output(['git', 'diff', producto, head]))
base = diagnosticos(s / '373-final-2-tests.log')
actual = diagnosticos(s / '374-final-3-tests.log')
comparacion = {'base': dict(base), 'final': dict(actual),
              'nuevos': dict(actual-base), 'retirados': dict(base-actual),
              'normalizacion': 'Sólo IDs numéricos autogenerados de los tres tipos de cuerpo.'}
(e / 'comparacion-diagnosticos.json').write_text(json.dumps(comparacion, ensure_ascii=False, indent=2), encoding='utf-8')

for nombre in ['374-rojo-dominio.log', '374-focal-dominio-1.log', '374-focal-2.log',
               '374-fotos-finales.log', '374-fotos-finales-encuadres.json',
               '374-fotos-finales-sha.json', '374-fotos-finales-aprobacion-padre.json',
               '374-native-1.log', '374-web-2.log', '374-export-2.log',
               '374-import-warm-2.log', '374-auditoria-contratos.json', '374-alcance-final.json',
               '374-focal-carga.log', '374-focal-guion.log', 'issue-374.md',
               '374-retencion-comprobacion-padre.json']:
    copiar(s / nombre, e / 'verificacion' / nombre)
for p in s.glob('374-final-*.log'):
    copiar(p, e / 'verificacion' / p.name)
for p in s.glob('374-final-*comparacion*.json'):
    copiar(p, e / 'verificacion' / p.name)
for p in s.glob('374-*aprobacion-padre*'):
    copiar(p, e / 'verificacion' / p.name)
for patron in ['374-retencion-*.log', '374-discovery-*.log', '374-cache-*.log',
               '374-base373-*.log', '374-control-*.log', '374-variante*.log',
               '374-*comando.json', '374-discovery-*.json', '374-cache-resolver.json',
               '374-control-equivalente.json', '374-variantes-*.json',
               '374-variante-guion-resultados.json']:
    for p in s.glob(patron):
        copiar(p, e / 'diagnostico-discovery' / p.name)
reporte = re.search(r'reports/report_\d+', final)[0]
copiar(w / reporte / 'results.xml', e / 'verificacion' / 'results.xml')
(e / 'verificacion' / 'suites-en-el-checkout.txt').write_text(
    '\n'.join(sorted(p.relative_to(w).as_posix() for p in (w / 'test').rglob('*_test.gd'))), encoding='utf-8')
copiar(s / '373-final-2-tests.log', e / 'base' / '373-final-2-tests.log')
for nombre in ['374-focal-1.log', '374-export-1.log', '374-import-warm.log',
               '374-web-1.log', '374-servidor-web-invalido-1.log',
               'bootstrap374-import-invalido.gd', 'navegador374-puerto-invalido.cjs',
               'pantalla_de_instrucciones_test374.gd', 'instrucciones_en_el_almacen_test374.gd']:
    copiar(s / nombre, e / 'historico' / nombre)
for nombre in ['importar-frio-invalido.log', 'importar-warm-invalido.log']:
    copiar(d / nombre, e / 'historico' / nombre)
for nombre in ['huellas.json', 'importar.log', 'exportar-reintento.log', 'dialogos.log', 'instrucciones.log']:
    copiar(d / nombre, e / 'paquete' / nombre)
for nombre in ['bootstrap374.gd', 'capturar374.gd', 'capturar_native_final374.py',
               'exportar374.py', 'reexportar374.py', 'importar374_warm2.py',
               'navegador374.cjs', 'ejecutar_web374.py',
               'verificar_instrucciones_exportadas374.gd', 'verificar_con_crudo.py',
               'focal374.py', 'preparar_evidencia374.py', 'manifiesto374.py', 'textos374.json']:
    copiar(s / nombre, e / 'arnes' / nombre)
for nombre in ['diagnosticar_retencion374.py', 'diagnosticar_discovery374.py',
               'observar_cache_gdunit374.gd', 'observar_cache374.py',
               'diagnosticar_base373.py', 'bisecar_discovery374.py', 'bisecar_dominios374.py',
               'bisecar_almacen374.py', 'control_equivalente374.py',
               'preparar_variantes374.py', 'ejecutar_variantes374.py',
               'ejecutar_variante_guion374.py']:
    copiar(s / nombre, e / 'arnes' / nombre)
copiar(s / '374-cache-observador' / 'GdUnitCmdTool.gd',
       e / 'arnes' / 'cache-observador' / 'GdUnitCmdTool.gd')
for p in (w / 'assets/ui/manada/fotos').glob('*.png'):
    copiar(p, e / 'fotos' / p.name)
copiar(w / 'assets/models/generar_fotos_del_jefe.gd', e / 'arnes' / 'generar_fotos_del_jefe.gd')

# ZIP conserva las fuentes y huellas byte por byte aunque Git normalice texto al publicar.
with zipfile.ZipFile(e / 'fuentes-TDD-originales.zip', 'w', zipfile.ZIP_DEFLATED) as z:
    for carpeta in ['374-rojo-dominio-fuentes', '374-verde-dominio-fuentes']:
        for p in sorted((s / carpeta).rglob('*')):
            if p.is_file():
                z.write(p, carpeta + '/' + p.relative_to(s / carpeta).as_posix())

resumen = {'head': head, 'base_fija': 'f0c37482a315972d4de58020e6a247e78d7a55f3',
           'producto_exportado_y_renderizado': producto,
           'full_intentos': 3, 'primer_full': '6/7; tres aserciones de fixture de carga previo al fade',
           'segundo_full': '7/7, pero retención adicional164/123 en discovery; no fue el cierre final',
           'correccion_discovery': 'Sólo GUION ruta String y load dentro del caso de dominio; mismas aserciones.',
           'verificador': final, 'suites': archivos, 'casos': 1823,
           'script_errors': 0, 'nuevos_diagnosticos': dict(actual-base),
           'retirados_diagnosticos': dict(base-actual),
           'dominio_rojo': '3 casos, 17 fallos de aserción, cero SCRIPT ERROR',
           'dominio_minimo_verde': '3/3', 'ui_verde': '4/4', 'escena_verde': '7/7',
           'fotos': '7/7 con rayos/poses y aprobación visual de las siete imágenes finales',
           'web': 'Dos resoluciones, consola completa sin errores, RAF120/110, flujo nuevo y continuar3/7',
           'export': 'Preset versionado exacto; import/export/PCK limpios tras corregir referencias estáticas del fixture'}
(e / 'resultado-final.json').write_text(json.dumps(resumen, ensure_ascii=False, indent=2), encoding='utf-8')
(e / 'README.md').write_text(f'''Evidencia de #374, cabeza final `{head}`.

Export y capturas corresponden a `{producto}`; el diff hasta final sólo adapta un helper
heredado de tests al fundido decidido y carga el guion dentro del caso de dominio, evitando
la retención de scripts durante discovery. src/assets/project/preset no cambian. El parche exacto
está en diff-producto-a-final.patch. La primera full terminó 6/7 por tres aserciones de esa
suite que aún esperaba carga inmediata; se conserva íntegra. La segunda full pasó7/7 pero
el crudo retuvo164ObjectDB/123recursos. La tercera full, posterior al arreglo del fixture,
es la final. No se presenta la segunda como cierre aprobado.

Verificador completo: 7/7, 239/239 suites y 1823/1823 casos; conteo inmediato al terminar.
Los logs contienen stdout y stderr de todos los nodos. Las advertencias y errores heredados
no se ocultan; comparacion-diagnosticos.json conserva el contraste completo con #373.

diagnostico-discovery/ conserva los controles equivalentes: mismo producto, misma prueba
heredada ejecutada, sólo cambia qué suites nuevas se descubren. Únicamente la suite nueva de
dominio dispara los23scripts heredados adicionales (blobs idénticos a #373, comprobados por
el padre). Cambiar su const preload por ruta y load local dentro del caso devuelve141/100
tanto con el ancla heredada como con los3casos nuevos. Ninguna aserción ni addon se alteró.
No se atribuye a _resolved_user_classes: la lectura al finalizar dio vacío y no localiza
la referencia durante discovery. Se conservan el observador que sólo mostró ayuda por su
basename y el control que abortó antes de motor por una ruta plural inexistente.

Las PNG de la raíz son capturas finales del juego nativo y de Chrome que dibuja, en
1920×1080 y 1280×720. Chrome usa CDP pasivo userGesture:false, física y reloj reales.
NUEVO → 14 pasos/7 fotos → COMENZAR → NOCHE1 → Q/chat/foto real → checkpoint real3/7
→ pausa/menú → CONTINUAR sin instrucciones. Las dos consolas completas no contienen errores.
El paquete exportado conserva el preset exacto; se aíslan únicamente plugins del editor y
main_scene en la copia externa. Las dos sondas PCK comprueban guiones y fotos reales.

fotos/ contiene los siete PNG sin editar que genera el script versionado. La aprobación del
padre corresponde a esos bytes finales. El generador comprueba cada rayo antes de escribir
y restaura las 31 poses de jornada1 antes de Intro13. El retrato original de Enrique se
conserva en producto con SHA256 22375e3b0248f68afc4c2bc215652fe09a01b7aa3a82243709b6989676919b3e.

fuentes-TDD-originales.zip conserva byte por byte los tests, el stub rojo parseable, el
mínimo verde y sus huellas. El rojo precede al mínimo verde (17 aserciones, cero script).
Las pruebas UI/escena son funcionales y no se presentan como test-first.
historico/ conserva dos fixtures sin tipo, puerto web incorrecto y los imports que retuvieron
la cadena de siete scripts por referencias estáticas de la sonda externa; no cuentan como
evidencia aprobada. Cargas dinámicas de las mismas APIs eliminaron esa retención sin tocar
producto. arnes/ conserva las fuentes usadas; paquete/ incluye huellas, no PCK/WASM completos.

procedencia-local.json registra los bytes locales previos a la normalización EOL de Git.
El manifiesto SHA256 publicado se calcula sobre TODOS los blobs remotos y se contrasta
independientemente. Sólo la normalización CRLF→LF de texto puede diferir de la procedencia
local; las PNG y el ZIP deben ser idénticos. El commit final de evidencia se informa en el PR.
''', encoding='utf-8')
local = {p.relative_to(e).as_posix(): {'bytes': p.stat().st_size,
         'sha256': hashlib.sha256(p.read_bytes()).hexdigest()}
         for p in sorted(e.rglob('*')) if p.is_file() and p.name not in ['sha256.json', 'procedencia-local.json']}
(e / 'procedencia-local.json').write_text(json.dumps(local, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(resumen, ensure_ascii=False, indent=2))
print(len(local)+1, 'artefactos antes del manifiesto remoto')
