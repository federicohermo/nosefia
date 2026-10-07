"""Convertir los tableros del deposito en madera apoyada sobre bastidores verdes.

El largo util aumenta a 2.55 m. Se conservan matrices, cotas superiores y secciones
de columnas. Importar este modulo no abre ni guarda
archivos: aplicar() trabaja sobre la escena que ya tiene Blender abierta.
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
OBJETOS = ("gondola_deposito03-col", "gondola_deposito03-col.001")
TEXTURA = RAIZ / "assets/source/third-party/128x128/Wood/Wood_02-128x128.png"
MARCA = "deposito_listones_v2"
LARGO_UTIL = 2.55


def _materiales():
    verde = bpy.data.materials.get("deposito_acero_verde")
    if verde is None:
        verde = bpy.data.materials.new("deposito_acero_verde")
    verde.use_nodes = True
    verde.diffuse_color = (.027, .084, .049, 1)
    shader = verde.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = verde.diffuse_color
    shader.inputs["Roughness"].default_value = .68
    shader.inputs["Metallic"].default_value = .05
    madera = bpy.data.materials.get("deposito_madera_listones")
    if madera is None:
        madera = bpy.data.materials.new("deposito_madera_listones")
    madera.use_nodes = True
    madera.diffuse_color = (.28, .13, .055, 1)
    shader = madera.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = .82
    textura = madera.node_tree.nodes.get("Madera existente")
    if textura is None:
        textura = madera.node_tree.nodes.new("ShaderNodeTexImage")
        textura.name = "Madera existente"
    imagen = bpy.data.images.load(str(TEXTURA), check_existing=True)
    # Solo se configura la imagen nueva; las dependencias del resto del modelo no cambian.
    if imagen.users == 0:
        imagen.filepath = bpy.path.relpath(str(TEXTURA), start=str(FUENTE.parent))
    textura.image = imagen
    textura.interpolation = "Closest"
    madera.node_tree.links.new(textura.outputs["Color"], shader.inputs["Base Color"])
    return verde, madera


def _huella(objeto):
    malla = objeto.data
    datos = {
        "vertices": [list(v.co) for v in malla.vertices],
        "caras": [list(p.vertices) for p in malla.polygons],
        "uv": [[capa.name, [list(l.uv) for l in capa.data]] for capa in malla.uv_layers],
        "materiales": [m.name if m else None for m in malla.materials],
        "indices": [p.material_index for p in malla.polygons],
        "matriz": [list(f) for f in objeto.matrix_world],
    }
    return hashlib.sha256(json.dumps(datos).encode()).hexdigest()


def _limites(objeto):
    puntos = [objeto.matrix_world @ v.co for v in objeto.data.vertices]
    return [[min(p[k] for p in puntos) for k in range(3)],
            [max(p[k] for p in puntos) for k in range(3)]]


def _editar(objeto, verde, madera):
    original = objeto.data
    cantidad_original = len(original.polygons)
    assert cantidad_original in (42, 204), "La estanteria cambio: revisar los tableros."
    if cantidad_original == 204:
        assert objeto.get("deposito_listones_v1"), "Los listones no son la version conocida."
    escala = objeto.matrix_world.to_scale().z
    niveles = []
    for nivel in range(3):
        inicio = nivel * 6 if cantidad_original == 42 else 24 + nivel * 60
        cantidad = 6 if cantidad_original == 42 else 60
        puntos = [original.vertices[i].co for p in list(original.polygons)[inicio:inicio + cantidad]
                  for i in p.vertices]
        niveles.append(([min(v[k] for v in puntos) for k in range(3)],
                        [max(v[k] for v in puntos) for k in range(3)]))
    crecimiento = LARGO_UTIL / escala - (niveles[0][1][0] - niveles[0][0][0])
    postes = (list(original.polygons)[18:] if cantidad_original == 42
              else list(original.polygons)[:24])
    materiales = list(original.materials)
    for material in (verde, madera):
        if material not in materiales:
            materiales.append(material)
    indice_verde, indice_madera = materiales.index(verde), materiales.index(madera)
    capas = [c.name for c in original.uv_layers]
    activa = original.uv_layers.active.name if original.uv_layers.active else None
    vertices, caras, indices, uv = [], [], [], {nombre: [] for nombre in capas}
    mapa = {}
    # El extremo negativo queda anclado; solo los dos postes positivos se trasladan.
    for poligono in postes:
        cara = []
        for indice in poligono.vertices:
            if indice not in mapa:
                mapa[indice] = len(vertices)
                punto = original.vertices[indice].co.copy()
                if punto.x > 0:
                    punto.x += crecimiento
                vertices.append(tuple(punto))
            cara.append(mapa[indice])
        caras.append(tuple(cara))
        indices.append(indice_verde)
        for capa in original.uv_layers:
            uv[capa.name].append([tuple(capa.data[i].uv) for i in poligono.loop_indices])

    def caja(inferior, superior, material, variante=0):
        x0, y0, z0 = inferior
        x1, y1, z1 = superior
        puntos = [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                  (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)]
        offset = len(vertices)
        vertices.extend(puntos)
        for cara in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
                     (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            caras.append(tuple(offset + i for i in cara))
            indices.append(material)
            normal_z = cara in ((0, 3, 2, 1), (4, 5, 6, 7))
            normal_y = cara in ((0, 1, 5, 4), (2, 3, 7, 6))
            for nombre in capas:
                coords = []
                for i in cara:
                    x, y, z = puntos[i]
                    if normal_z:
                        coords.append(((y - y0) / (y1 - y0),
                                       (x - x0) / .75 + variante * .173))
                    elif normal_y:
                        coords.append(((z - z0) / .15,
                                       (x - x0) / .75 + variante * .173))
                    else:
                        coords.append(((y - y0) / .15, (z - z0) / .15))
                uv[nombre].append(coords)

    espesor_madera = .025 / escala
    ancho_riel = .032 / escala
    junta = .008 / escala
    for nivel in range(3):
        (x0, y0, z0), (x1, y1, z1) = niveles[nivel]
        x1 = x0 + LARGO_UTIL / escala
        corte = z1 - espesor_madera
        assert corte > z0, "La madera no cabe en el espesor existente."
        # Largueros bajo las tablas: conservan el canto y el volumen del apoyo original.
        for inicio, fin in ((y0, y0 + ancho_riel), (y1 - ancho_riel, y1)):
            caja((x0, inicio, z0), (x1, fin, corte), indice_verde)
        for centro in (x0 + ancho_riel / 2, (x0 + x1) / 2, x1 - ancho_riel / 2):
            caja((centro - ancho_riel / 2, y0 + ancho_riel, z0),
                 (centro + ancho_riel / 2, y1 - ancho_riel, corte),
                 indice_verde)
        ancho = (y1 - y0 - 4 * junta) / 5
        for i in range(5):
            inicio = y0 + i * (ancho + junta)
            caja((x0, inicio, corte), (x1, inicio + ancho, z1),
                 indice_madera, nivel * 5 + i)

    malla = bpy.data.meshes.new(original.name + "_listones")
    malla.from_pydata(vertices, [], caras)
    for material in materiales:
        malla.materials.append(material)
    for p, indice in zip(malla.polygons, indices):
        p.material_index = indice
    for nombre in capas:
        capa = malla.uv_layers.new(name=nombre)
        for p, coords in zip(malla.polygons, uv[nombre]):
            for i, coord in zip(p.loop_indices, coords):
                capa.data[i].uv = coord
    if activa:
        malla.uv_layers.active = malla.uv_layers[activa]
    malla.update()
    for vieja, nueva in zip(postes, list(malla.polygons)[:24]):
        for vi, vn in zip(vieja.vertices, nueva.vertices):
            punto = original.vertices[vi].co.copy()
            if punto.x > 0:
                punto.x += crecimiento
            assert (punto - malla.vertices[vn].co).length < 1e-6
        for capa in original.uv_layers:
            assert [tuple(capa.data[i].uv) for i in vieja.loop_indices] == [
                tuple(malla.uv_layers[capa.name].data[i].uv) for i in nueva.loop_indices]
    objeto.data = malla
    objeto[MARCA] = True
    return {"caras_antes": cantidad_original, "caras_despues": len(caras),
            "caras_postes_con_uv_conservadas": 24, "tableros_sustituidos": 3,
            "listones_por_nivel": 5, "espesor_madera_m": .025, "junta_m": .008,
            "largo_util_m": LARGO_UTIL, "crecimiento_local_x": crecimiento,
            "desplazamiento_centro_tablero_local_x": crecimiento / 2}


def aplicar():
    configurar()
    vecinos = {o.name: _huella(o) for o in bpy.data.objects
               if o.type == "MESH" and o.name not in OBJETOS}
    verde, madera = _materiales()
    informe = {}
    for nombre in OBJETOS:
        objeto = bpy.data.objects[nombre]
        if objeto.get(MARCA):
            informe[nombre] = {"ya_aplicado": True}
            continue
        matriz = objeto.matrix_world.copy()
        limites = _limites(objeto)
        matriz_padre = objeto.matrix_parent_inverse.copy()
        padre = objeto.parent
        modificadores = [(m.name, m.type, m.show_viewport, m.show_render)
                         for m in objeto.modifiers]
        if len(objeto.data.polygons) == 42:
            soportes = sorted((objeto.matrix_world @ p.center).z
                              for p in objeto.data.polygons if p.normal.z > .99 and p.index < 18)
        else:
            soportes = sorted({round((objeto.matrix_world @ p.center).z, 7)
                               for p in objeto.data.polygons if p.normal.z > .99
                               and objeto.data.materials[p.material_index] == madera})
        detalles = _editar(objeto, verde, madera)
        assert objeto.matrix_world == matriz and objeto.matrix_parent_inverse == matriz_padre
        assert objeto.parent == padre
        assert modificadores == [(m.name, m.type, m.show_viewport, m.show_render)
                                 for m in objeto.modifiers]
        despues = _limites(objeto)
        for antes, nuevo in zip(limites, despues):
            assert abs(antes[2] - nuevo[2]) < 1e-6
        eje = 1 if nombre == OBJETOS[0] else 0
        fijo = 0 if eje == 1 else 1
        assert abs(limites[fijo][eje] - despues[fijo][eje]) < 1e-6
        assert all(abs(limites[i][1 - eje] - despues[i][1 - eje]) < 1e-6
                   for i in range(2))
        superiores = [(objeto.matrix_world @ p.center).z for p in objeto.data.polygons
                      if objeto.data.materials[p.material_index] == madera
                      and p.normal.z > .99]
        assert all(min(abs(z - c) for c in superiores) < 1e-6 for z in soportes)
        detalles.update({"bounds_antes": limites, "bounds_despues": despues,
                         "cotas_superiores_m": soportes, "matriz_conservada": True,
                         "modificadores_conservados": modificadores})
        informe[nombre] = detalles
    assert all(_huella(bpy.data.objects[n]) == h for n, h in vecinos.items())
    informe["objetos_ajenos_verificados"] = len(vecinos)
    informe["colision"] = "Listones y bastidores dentro de las mallas originales -col."
    return informe


def main():
    configurar()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    parser.add_argument("--salida", type=Path, default=RAIZ / "reports/estanterias-deposito.blend")
    argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    informe = aplicar()
    salida = FUENTE if opciones.aplicar else opciones.salida
    salida.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(salida), check_existing=False)
    reporte = RAIZ / "reports/estanterias-conservacion.json"
    reporte.write_text(json.dumps(informe, indent=2), encoding="utf-8")
    print(json.dumps({"salida": str(salida), "informe": str(reporte)}))


if __name__ == "__main__":
    main()
