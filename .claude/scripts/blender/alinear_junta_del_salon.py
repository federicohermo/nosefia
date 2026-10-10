"""Llevar una junta de la cerámica hasta el encuentro del baño, sólo mediante UV0."""
import math
import sys
from pathlib import Path
import bpy
RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / '.claude/scripts'))
from lib.consola import configurar
configurar()
if __name__ == '__main__':
    if '--aplicar' not in sys.argv:
        raise SystemExit('Pasar --aplicar para guardar la fuente.')
    if bpy.context.scene.get('local_fase_juntas_v9'):
        raise SystemExit('La fase de las juntas ya está ajustada.')
    objeto = bpy.data.objects['almacen-col']
    malla = objeto.data
    inicio = min((objeto.matrix_world @ malla.vertices[i].co).x
                 for cara in malla.polygons
                 if malla.materials[cara.material_index].name == 'bano_piso_gris'
                 for i in cara.vertices)
    lado = 2.4 / (3 * math.sqrt(2))
    fase = inicio % lado
    for cara in malla.polygons:
        if malla.materials[cara.material_index].name != 'local_ceramica':
            continue
        for i in cara.loop_indices:
            punto = objeto.matrix_world @ malla.vertices[malla.loops[i].vertex_index].co
            x, y = punto.x - fase, punto.y
            malla.uv_layers[0].data[i].uv = (
                (x + y) / (2.4 * math.sqrt(2)), (y - x) / (2.4 * math.sqrt(2)))
    bpy.context.scene['local_fase_juntas_v9'] = True
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    print(f'Junta en X={inicio:.6f}; fase {fase:.6f} m. Sólo UV0.')
