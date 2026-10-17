"""Separa vidrio, etiquetas y metal sin cambiar geometría ni mapas de los materiales.

Sin --aplicar imprime el resultado en memoria. --aplicar guarda la fuente canónica.
"""

import argparse
import json
import sys
from pathlib import Path

import bpy

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / '.claude/scripts'))
from lib.consola import configurar

FUENTE = RAIZ / 'assets/models/SEPT_JUEGOS_PROTOTIPO.blend'

MATERIALES = {
    'util_mango_acero': (.30, .85),
    'bano_griferia': (.16, .75),
    'bano_desague': (.20, .75),
    'local_aluminio': (.32, .85),
    'Material.019': (.38, .0),
    'portontext': (.45, .0),
    'puerta_metal_solo_empleados': (.42, .0),
    'cajaluz exterior': (.42, .0),
    'cajaluz interior': (.45, .0),
}

COLORES_DE_REFERENCIA = {
    'bano_griferia': 'bano_acero',
    'bano_desague': 'bano_acero',
}

SUPERFICIES = {
    'Fernetgod-col': {
        'geometria': (40, 34),
        'base': 'Material.007',
        'etiqueta': (.55, .0),
        'grupos': (
            ('fernet_vidrio', (.18, .0),
             (0, 4, 6, 9, 10, 11, 12, 13, 14, 15, 16, 17, 19, 20, 21, 22, 23, 24, 25)),
            ('fernet_tapa_pintada', (.30, .0), (18, 27, 28, 29, 30, 31, 32, 33)),
            ('fernet_tapa_dorada', (.30, .85), (26,)),
        ),
    },
    'atun-col': {
        'geometria': (48, 26),
        'base': 'Material.018',
        'etiqueta': (.50, .0),
        'grupos': (('atun_acero', (.27, .90), (25,)),),
    },
    'lataarvejas-convcol.002': {
        'geometria': (224, 194),
        'base': 'Material.001',
        'etiqueta': (.50, .0),
        'grupos': (('arvejas_acero', (.30, .55), tuple(range(33)) + tuple(range(65, 194))),),
    },
    'pringles3-convcol.001': {
        'geometria': (64, 34),
        'base': 'progres nuevo',
        'etiqueta': (.50, .0),
        'grupos': (
            ('prongles_base_acero', (.27, .90), (29,)),
            ('prongles_tapa_plastica', (.32, .0), (32,)),
        ),
    },
}


def principled(material):
    nodos = [n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED']
    if len(nodos) != 1:
        raise ValueError(f'{material.name} debe tener un único Principled BSDF')
    nodo = nodos[0]
    if any(nodo.inputs[n].is_linked for n in ('Roughness', 'Metallic')):
        raise ValueError(f'{material.name} tiene mapas PBR que no se deben reemplazar')
    return nodo


def ajustar(material, valores):
    nodo = principled(material)
    antes = [nodo.inputs[n].default_value for n in ('Roughness', 'Metallic')]
    for nombre, valor in zip(('Roughness', 'Metallic'), valores):
        nodo.inputs[nombre].default_value = valor
    material.roughness, material.metallic = valores
    return {'material': material.name, 'antes': antes, 'despues': list(valores)}


def aplicar():
    materiales = set(MATERIALES)
    for nombre, datos in SUPERFICIES.items():
        objeto = bpy.data.objects[nombre]
        malla = objeto.data
        if (len(malla.vertices), len(malla.polygons)) != datos['geometria']:
            raise ValueError(f'Cambió la geometría de {nombre}; revisar sus caras antes de aplicar')
        permitidos = {datos['base']} | {grupo[0] for grupo in datos['grupos']}
        if any(m is None or m.name not in permitidos for m in malla.materials):
            raise ValueError(f'{nombre} tiene materiales fuera del ajuste conocido')
        if not malla.materials or malla.materials[0].name != datos['base']:
            raise ValueError(f'Cambió el material base de {nombre}')
        materiales.add(datos['base'])
        materiales.update(m for m in permitidos if m in bpy.data.materials)
    for nombre in sorted(materiales):
        principled(bpy.data.materials[nombre])

    informe = {'materiales': [], 'superficies': []}
    for nombre, valores in MATERIALES.items():
        informe['materiales'].append(ajustar(bpy.data.materials[nombre], valores))

    for nombre, referencia in COLORES_DE_REFERENCIA.items():
        material = bpy.data.materials[nombre]
        origen = principled(bpy.data.materials[referencia]).inputs['Base Color']
        destino = principled(material).inputs['Base Color']
        if origen.is_linked or destino.is_linked:
            raise ValueError(
                f'{nombre} o {referencia} tienen mapas de color que no se deben reemplazar'
            )
        destino.default_value = origen.default_value
        material.diffuse_color = origen.default_value

    for nombre, datos in SUPERFICIES.items():
        malla = bpy.data.objects[nombre].data
        base = bpy.data.materials[datos['base']]
        informe['materiales'].append(ajustar(base, datos['etiqueta']))
        indices = {}
        for nombre_material, valores, caras in datos['grupos']:
            material = bpy.data.materials.get(nombre_material)
            if material is None:
                material = base.copy()
                material.name = nombre_material
            informe['materiales'].append(ajustar(material, valores))
            indice = malla.materials.find(nombre_material)
            if indice == -1:
                malla.materials.append(material)
                indice = len(malla.materials) - 1
            for cara in caras:
                if cara in indices:
                    raise ValueError(f'La cara {cara} de {nombre} aparece en dos grupos')
                indices[cara] = indice
        for cara in malla.polygons:
            cara.material_index = indices.get(cara.index, 0)
        malla.update()
        informe['superficies'].append({
            'objeto': nombre,
            'malla': malla.name,
            'usuarios': malla.users,
            'caras_por_material': {
                material.name: sum(c.material_index == i for c in malla.polygons)
                for i, material in enumerate(malla.materials)
            },
        })
    return informe


def main():
    configurar()
    argumentos = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--aplicar', action='store_true')
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    informe = aplicar()
    informe['guardado'] = opciones.aplicar
    if opciones.aplicar:
        bpy.ops.wm.save_mainfile()
    print(json.dumps(informe, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
