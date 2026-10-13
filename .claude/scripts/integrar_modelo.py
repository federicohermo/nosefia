"""Conecta el modelo ya exportado con los puestos, colisiones y objetos del juego.

Después de exportar_modelo.py y blender/disponer.py:
    python .claude/scripts/integrar_modelo.py

No modifica el arte. Regenera el lector separable y las mallas de productos, y adapta las
escenas a la geometría importada. Después corresponde hornear.py y verificar.py.
"""

import json
import os
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib.consola import configurar

configurar()

from lib.godot import resolver, como_declararlo
from lib.blender import resolver as resolver_blender, como_declararlo as declarar_blender
from lib.integracion_modelo import integrar
from lib.volumenes_modelo import reconstruir
from lib.repo import RAIZ


def main() -> int:
    godot, _ = resolver(dict(os.environ))
    if godot is None:
        print(como_declararlo(dict(os.environ)))
        return 1
    blender, _ = resolver_blender(dict(os.environ))
    if blender is None:
        print(declarar_blender(dict(os.environ)))
        return 1
    medicion = subprocess.run([
        blender, str(RAIZ / 'assets/models/SEPT_JUEGOS_PROTOTIPO.blend'),
        '--background', '--python-exit-code', '1', '--python',
        str(RAIZ / '.claude/scripts/blender/medir_volumenes.py'),
    ], capture_output=True, text=True, encoding='utf-8', errors='replace')
    if medicion.returncode != 0:
        print(medicion.stdout + medicion.stderr)
        return medicion.returncode
    for script in ('descomponer_modelo.gd', 'medir_modelo.gd', 'extraer_lector.gd', 'extraer_mallas.gd'):
        proceso = subprocess.run(
            [godot, '--headless', '--path', str(RAIZ), '--script',
             'assets/models/' + script], capture_output=True, text=True,
            encoding='utf-8', errors='replace',
        )
        if proceso.returncode != 0:
            print(proceso.stdout + proceso.stderr)
            return proceso.returncode
    inventario = json.loads((RAIZ / 'build/integracion_modelo.json').read_text(encoding='utf-8'))
    puestos = RAIZ / 'src/escenas/puestos'
    rutas = {nombre: puestos / nombre for nombre in (
        'estructura_del_almacen.tscn', 'lector.tscn', 'objetos_del_almacen.tscn',
        'limpieza_del_almacen.tscn',
    )}
    rutas['almacen.tscn'] = RAIZ / 'src/escenas/almacen.tscn'
    fuentes = {nombre: ruta.read_text(encoding='utf-8') for nombre, ruta in rutas.items()}
    piezas = json.loads((RAIZ / 'build/volumenes_modelo.json').read_text(encoding='utf-8'))
    descompuestas = json.loads(
        (RAIZ / 'build/volumenes_descompuestos.json').read_text(encoding='utf-8')
    )
    integradas = reconstruir(inventario, piezas, descompuestas, integrar(inventario, fuentes))
    for nombre, texto in integradas.items():
        rutas[nombre].write_text(texto.rstrip() + '\n', encoding='utf-8', newline='\n')
        print('integrado:', rutas[nombre].relative_to(RAIZ))
    return 0


if __name__ == '__main__':
    sys.exit(main())
