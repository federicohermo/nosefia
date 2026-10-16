"""Regenera sólo el riel y los contornos A/B desde el GLB, sin escribir arte ni otros nodos.

    python .claude/scripts/actualizar_apoyos.py
    python .claude/scripts/actualizar_apoyos.py --comprobar
"""

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

from lib.consola import configurar

configurar()

from lib.apoyos_del_modelo import actualizar_apoyos, mallas_del_glb
from lib.repo import RAIZ


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--comprobar', action='store_true', help='No escribe; exige idempotencia')
    args = parser.parse_args()
    modelo = RAIZ / 'assets/models/SEPT_JUEGOS_PROTOTIPO.glb'
    escena = RAIZ / 'src/escenas/puestos/estructura_del_almacen.tscn'
    mallas = mallas_del_glb(modelo.read_bytes(),
                           ['bano_riel_frontal', 'gondolanueva', 'gondolanueva2'])
    anterior = escena.read_text(encoding='utf-8')
    nuevo = actualizar_apoyos(anterior, mallas)
    if args.comprobar:
        if nuevo != anterior:
            print('Los apoyos no corresponden a la geometría vigente; '
                  'regenerar antes de verificar.')
            return 1
        print('Apoyos del modelo: regeneración idempotente.')
        return 0
    escena.write_text(nuevo, encoding='utf-8', newline='\n')
    print('Regenerados riel y contornos A/B; arte y demás bloques conservados.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
