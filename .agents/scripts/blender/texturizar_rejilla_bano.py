"""Reemplaza cuatro ranuras de la entrada por pintura sólo en su panel exterior.

Por defecto guarda una copia en reports. --aplicar guarda la fuente canónica.
Importar este módulo no abre, transforma, guarda ni exporta ningún archivo.
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

import bmesh
import bpy

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / '.claude/scripts'))
from lib.consola import configurar
from lib.rejilla_bano import png_de_ranuras

configurar()

FUENTE = RAIZ / 'assets/models/SEPT_JUEGOS_PROTOTIPO.blend'
TEXTURA = RAIZ / 'assets/source/textures/furniture/Puerta/rejilla_bano.png'
MATERIAL = 'bano_rejilla_texturizada'


def _estado(objeto):
    malla = objeto.data
    return {
        'matriz': [list(fila) for fila in objeto.matrix_world],
        'local': [list(fila) for fila in objeto.matrix_local],
        'padre': objeto.parent.name if objeto.parent else None,
        'vertices': [tuple(v.co) for v in malla.vertices],
        'aristas': [tuple(a.vertices) for a in malla.edges],
        'caras': [(tuple(c.vertices), c.material_index, c.use_smooth) for c in malla.polygons],
        'materiales': [m.name if m else None for m in malla.materials],
        'uv': {c.name: [tuple(v.uv) for v in c.data] for c in malla.uv_layers},
    }


def _huella(datos):
    return hashlib.sha256(json.dumps(datos, sort_keys=True).encode()).hexdigest()


def _cara_conservada(malla, cara):
    return {
        'puntos': [tuple(malla.vertices[i].co) for i in cara.vertices],
        'material': malla.materials[cara.material_index].name,
        'suave': cara.use_smooth,
        'uv': {c.name: [tuple(c.data[i].uv) for i in cara.loop_indices]
               for c in malla.uv_layers},
    }


def aplicar():
    hoja = bpy.data.objects['puerta2-col']
    malla = hoja.data
    assert malla.users == 1, 'La hoja debe tener una malla propia'
    vecinos = {o.name: _huella(_estado(o)) for o in bpy.data.objects
               if o.type == 'MESH' and o != hoja}
    estado = _estado(hoja)
    paneles = [p for p in malla.polygons if len(p.vertices) == 4
               and p.normal.y < -0.99999
               and abs(p.center.y + .0285) < .00001]
    assert len(paneles) == 1, 'Se requiere el panel exterior existente, no una cara nueva'
    panel = paneles[0]
    panel_original = panel.index
    originales = {p.index: _cara_conservada(malla, p) for p in malla.polygons
                  if p != panel and malla.materials[p.material_index].name
                  != 'bano_marco_pintado'}
    puntos = [malla.vertices[i].co for i in panel.vertices]
    x_min, x_max = min(v.x for v in puntos), max(v.x for v in puntos)
    z_min, z_max = min(v.z for v in puntos), max(v.z for v in puntos)
    pintada = malla.materials[panel.material_index].name == MATERIAL
    caras_rejilla = [p for p in malla.polygons
                    if malla.materials[p.material_index].name == 'bano_marco_pintado']
    if pintada:
        assert not caras_rejilla, 'Una hoja ya pintada no debe conservar cajas de rejilla'
        return {'ya_aplicado': True, 'vecinos_intactos': len(vecinos)}
    assert len(caras_rejilla) == 24, 'Se requieren exactamente cuatro cajas de seis caras'
    ids = {i for p in caras_rejilla for i in p.vertices}
    assert len(ids) == 32
    centros = sorted({round(p.center.z, 6) for p in caras_rejilla
                      if abs(p.normal.y) > .99})
    assert len(centros) == 4
    assert all(abs(malla.vertices[i].co.x) <= .230001 for i in ids)
    assert all(-.032001 <= malla.vertices[i].co.y <= -.028998 for i in ids)
    # La textura sigue el ancho/alto del panel real; no conserva una cámara ni un decal.
    bandas = [(0.5, (z - z_min) / (z_max - z_min),
               .46 / (x_max - x_min), .022 / (z_max - z_min)) for z in centros]
    blanco = malla.materials[0]
    principled = blanco.node_tree.nodes.get('Principled BSDF')
    color = tuple(principled.inputs['Base Color'].default_value[:3])
    metal = malla.materials[caras_rejilla[0].material_index]
    color_interior = tuple(metal.node_tree.nodes.get('Principled BSDF')
                           .inputs['Base Color'].default_value[:3])
    TEXTURA.parent.mkdir(parents=True, exist_ok=True)
    TEXTURA.write_bytes(png_de_ranuras(color, bandas, color_interior=color_interior))
    material = bpy.data.materials.get(MATERIAL)
    if material is None:
        material = blanco.copy()
        material.name = MATERIAL
    assert material != blanco
    imagen = bpy.data.images.load(str(TEXTURA), check_existing=True)
    imagen.filepath = bpy.path.relpath(str(TEXTURA))
    imagen.colorspace_settings.name = 'sRGB'
    nodos = material.node_tree.nodes
    textura = nodos.get('Ranuras medidas') or nodos.new('ShaderNodeTexImage')
    textura.name = 'Ranuras medidas'
    textura.image = imagen
    textura.interpolation = 'Closest'
    material.node_tree.links.new(textura.outputs['Color'],
                                 nodos.get('Principled BSDF').inputs['Base Color'])
    malla.materials.append(material)
    panel.material_index = len(malla.materials) - 1
    uv = malla.uv_layers.active
    assert uv is not None
    for i in panel.loop_indices:
        v = malla.vertices[malla.loops[i].vertex_index].co
        uv.data[i].uv = ((v.x - x_min) / (x_max - x_min),
                         (v.z - z_min) / (z_max - z_min))
    bm = bmesh.new()
    bm.from_mesh(malla)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.index in ids], context='VERTS')
    bm.to_mesh(malla)
    bm.free()
    malla.update()
    bpy.context.view_layer.update()
    assert len(malla.vertices) == len(estado['vertices']) - 32
    assert len(malla.polygons) == len(estado['caras']) - 24
    assert [tuple(v.co) for v in malla.vertices] == [v for i, v in
                                                   enumerate(estado['vertices']) if i not in ids]
    assert [list(fila) for fila in hoja.matrix_world] == estado['matriz']
    assert [list(fila) for fila in hoja.matrix_local] == estado['local']
    assert (hoja.parent.name if hoja.parent else None) == estado['padre']
    for indice, anterior in originales.items():
        assert _cara_conservada(malla, malla.polygons[indice]) == anterior, indice
    cambiados = [o.name for o in bpy.data.objects if o.type == 'MESH' and o != hoja
                 and _huella(_estado(o)) != vecinos[o.name]]
    assert not cambiados, cambiados
    return {
        'cara_exterior': panel_original, 'caras_eliminadas': 24, 'vertices_eliminados': 32,
        'vertices_finales': len(malla.vertices), 'caras_finales': len(malla.polygons),
        'uv_modificadas': 4, 'caras_restantes_conservadas': len(originales),
        'vecinos_intactos': len(vecinos), 'vecinos_modificados': cambiados,
        'panel_ancho': x_max - x_min, 'panel_alto': z_max - z_min, 'bandas_uv': bandas,
        'textura': str(TEXTURA), 'resolucion': [256, 512],
        'ruta_imagen_en_fuente': imagen.filepath,
        'matriz_y_pivote_conservados': True,
    }


def main():
    argumentos = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--aplicar', action='store_true')
    opciones = parser.parse_args(argumentos)
    huella_fuente = hashlib.sha256(FUENTE.read_bytes()).hexdigest()
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    informe = aplicar()
    assert hashlib.sha256(FUENTE.read_bytes()).hexdigest() == huella_fuente
    informe['sha256_fuente_original'] = huella_fuente
    destino = FUENTE if opciones.aplicar else RAIZ / 'reports/puerta-rejilla-textura.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    (RAIZ / 'reports/puerta-rejilla-textura-cambios.json').write_text(
        json.dumps(informe, indent=2), encoding='utf-8'
    )
    print(json.dumps(informe, indent=2))


if __name__ == '__main__':
    main()
