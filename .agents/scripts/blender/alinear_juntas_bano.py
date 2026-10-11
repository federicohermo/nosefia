"""Alinear las juntas del baño con el salón sin cambiar vértices ni caras."""
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
    if bpy.context.scene.get('bano_juntas_v8'):
        raise SystemExit('Las juntas del baño ya están alineadas.')
    # La cerámica diagonal tiene tres módulos por diagonal; el baño cinco por lado.
    lado = 2.4 / (3 * math.sqrt(2))
    cobertura = lado * 5
    edificio = bpy.data.objects['almacen-col']
    material = bpy.data.materials['bano_piso_gris']
    piso = [p for p in edificio.data.polygons
            if edificio.data.materials[p.material_index] == material]
    comienzo = min((edificio.matrix_world @ edificio.data.vertices[i].co).x
                   for p in piso for i in p.vertices)
    altura = .10223747
    for objeto in [edificio, bpy.data.objects['bano_zocalo_perimetral']]:
        capa = objeto.data.uv_layers[0]
        for cara in objeto.data.polygons:
            if objeto.data.materials[cara.material_index] != material:
                continue
            normal = (objeto.matrix_world.to_3x3() @ cara.normal).normalized()
            for i in cara.loop_indices:
                punto = objeto.matrix_world @ objeto.data.vertices[
                    objeto.data.loops[i].vertex_index].co
                if abs(normal.z) > .5:
                    uv = ((punto.x - comienzo) / cobertura, punto.y / cobertura)
                elif abs(normal.x) > .5:
                    uv = (punto.y / cobertura, (punto.z - altura) / cobertura)
                else:
                    uv = ((punto.x - comienzo) / cobertura,
                          (punto.z - altura) / cobertura)
                capa.data[i].uv = uv
    bpy.context.scene['bano_juntas_v8'] = True
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    print(f'Baldosas del baño: {lado:.6f} m, junta en X={comienzo:.6f}. Sólo UV0.')
