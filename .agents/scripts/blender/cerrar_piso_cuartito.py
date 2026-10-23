"""Cerrar la extensión del piso por debajo sin cambiar su superficie ni el umbral.

Edición única de la sesión abierta. No guarda ni exporta. Las caras nuevas se unen
al espesor existente del edificio; se retiran únicamente las divisiones internas.
"""

import json
from pathlib import Path

import bpy
from mathutils import Vector


def aplicar():
    objeto = bpy.data.objects['almacen-col']
    original = objeto.data
    assert len(original.vertices) == 384 and len(original.polygons) == 285
    vertices = [tuple(v.co) for v in original.vertices]
    caras = [list(f.vertices) for f in original.polygons]
    materiales = [f.material_index for f in original.polygons]
    capas = {
        u.name: [[tuple(u.data[i].uv) for i in f.loop_indices]
                 for f in original.polygons]
        for u in original.uv_layers
    }
    assert caras[280] == [380, 381, 382, 383, 379, 378]
    assert caras[275] == [369, 371, 379, 378]
    assert caras[276] == [371, 355, 377, 379]
    assert caras[277] == [58, 369, 378, 376]
    base = vertices[369][2]
    for i in (380, 381, 382, 383):
        x, y, _ = vertices[i]
        vertices.append((x, y, base))

    # Insertar sobre las aristas vecinas mantiene los vértices compartidos.
    inserciones = {273: [(379, 377, 383)], 274: [(376, 378, 380)],
                   258: [(355, 371, 387), (369, 58, 384)]}
    reemplazos = {276: [387, 355, 377, 383], 277: [58, 384, 380, 376]}
    nuevas_caras, nuevos_materiales = [], []
    nuevas_uv = {n: [] for n in capas}
    for indice, cara in enumerate(caras):
        if indice == 275:
            continue
        nueva = reemplazos.get(indice, cara.copy())
        for a, b, nuevo in inserciones.get(indice, []):
            for j, v in enumerate(nueva):
                if {v, nueva[(j + 1) % len(nueva)]} == {a, b}:
                    nueva.insert(j + 1, nuevo)
                    break
            else:
                raise AssertionError((indice, a, b))
        nuevas_caras.append(nueva)
        nuevos_materiales.append(materiales[indice])
        for nombre, por_cara in capas.items():
            existentes = dict(zip(cara, por_cara[indice]))
            uv = []
            for v in nueva:
                if v in existentes:
                    uv.append(existentes[v])
                    continue
                # Proyectar sobre la arista original más próxima, sin tocar sus UV.
                punto = Vector(vertices[v])
                candidatos = []
                for j, a in enumerate(cara):
                    b = cara[(j + 1) % len(cara)]
                    inicio, fin = Vector(vertices[a]), Vector(vertices[b])
                    if (fin - inicio).length_squared == 0:
                        continue
                    t = max(0, min(1, (punto - inicio).dot(fin - inicio)
                                   / (fin - inicio).length_squared))
                    distancia = (punto - inicio.lerp(fin, t)).length
                    valor = Vector(existentes[a]).lerp(Vector(existentes[b]), t)
                    candidatos.append((distancia, tuple(valor)))
                uv.append(min(candidatos)[1])
            nuevas_uv[nombre].append(uv)
    agregadas = [[384, 369, 371, 387, 386, 385],
                 [380, 384, 385, 381], [381, 385, 386, 382],
                 [382, 386, 387, 383]]
    for cara in agregadas:
        nuevas_caras.append(cara)
        nuevos_materiales.append(materiales[258])
        a, b, c = (Vector(vertices[i]) for i in cara[:3])
        normal = (b - a).cross(c - a)
        descartado = max(range(3), key=lambda i: abs(normal[i]))
        ejes = [i for i in range(3) if i != descartado]
        for nombre in nuevas_uv:
            nuevas_uv[nombre].append([
                (vertices[i][ejes[0]], vertices[i][ejes[1]]) for i in cara
            ])
    nueva = bpy.data.meshes.new(original.name + '_cerrado')
    nueva.from_pydata(vertices, [], nuevas_caras)
    for m in original.materials:
        nueva.materials.append(m)
    for f, mi in zip(nueva.polygons, nuevos_materiales):
        f.material_index = mi
    for nombre, por_cara in nuevas_uv.items():
        capa = nueva.uv_layers.new(name=nombre)
        for f, uv in zip(nueva.polygons, por_cara):
            for i, valor in zip(f.loop_indices, uv):
                capa.data[i].uv = valor
    nueva.update()
    # La superficie del piso y todas sus UV se conservan exactamente.
    superior = nueva.polygons[279]
    assert list(superior.vertices) == caras[280]
    for nombre in capas:
        assert [tuple(nueva.uv_layers[nombre].data[i].uv)
                for i in superior.loop_indices] == capas[nombre][280]
    for i, v in enumerate(original.vertices):
        assert tuple(nueva.vertices[i].co) == tuple(v.co)
    nombre = original.name
    objeto.data = nueva
    if original.users == 0:
        bpy.data.meshes.remove(original)
    nueva.name = nombre
    reporte = {'vertices_antes': 384, 'vertices_despues': len(nueva.vertices),
               'caras_antes': 285, 'caras_despues': len(nueva.polygons),
               'superficie_y_uv_del_piso_identicas': True,
               'caras_vecinas_adaptadas': [258, 273, 274, 276, 277],
               'division_interna_retirada': 275, 'caras_nuevas': agregadas}
    ruta = Path(__file__).resolve().parents[3] / 'reports/cuartito-mejoras/piso-cerrado.json'
    ruta.write_text(json.dumps(reporte, indent=2), encoding='utf-8')
    return reporte


def reparar_uv_laterales_existentes():
    """Completar los cantos de la primera aplicación sin repetir su geometría."""
    malla = bpy.data.objects['almacen-col'].data
    assert len(malla.vertices) == 388 and len(malla.polygons) == 288
    for cara in list(malla.polygons)[284:]:
        descartado = max(range(3), key=lambda i: abs(cara.normal[i]))
        ejes = [i for i in range(3) if i != descartado]
        for capa in malla.uv_layers:
            for indice in cara.loop_indices:
                punto = malla.vertices[malla.loops[indice].vertex_index].co
                capa.data[indice].uv = (punto[ejes[0]], punto[ejes[1]])
    malla.update()
    return {'caras_con_uv_proyectadas': list(range(284, 288))}
