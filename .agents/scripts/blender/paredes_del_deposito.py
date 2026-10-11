"""Aclarar solo el revoque interior del deposito sin cambiar mallas ni luz.

El material independiente evita modificar las paredes compartidas con el almacen.
Importar este modulo no abre ni guarda archivos; aplicar() edita la escena abierta.
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
NOMBRE_MATERIAL = "deposito_pared_revoque_gris_claro"
X0, X1 = -6.803772926330566, 7.925535678863525
Y0, Y1 = 8.253290176391602, 14.466056823730469
Z0, Z1 = .10223700106143951, 4.872666358947754


def _geometria_uv(objeto):
    datos = {
        "vertices": [tuple(v.co) for v in objeto.data.vertices],
        "caras": [tuple(p.vertices) for p in objeto.data.polygons],
        "smooth": [p.use_smooth for p in objeto.data.polygons],
        "uv": [(c.name, [tuple(l.uv) for l in c.data]) for c in objeto.data.uv_layers],
        "matriz": [tuple(f) for f in objeto.matrix_world],
        "padre": objeto.parent.name if objeto.parent else None,
    }
    return hashlib.sha256(json.dumps(datos).encode()).hexdigest()


def _materiales(objeto):
    return {"slots": [m.name if m else None for m in objeto.data.materials],
            "indices": [p.material_index for p in objeto.data.polygons]}


def _seleccionar(objeto):
    seleccion = []
    planos = ((0, X0, Vector((1, 0, 0))), (0, X1, Vector((-1, 0, 0))),
              (1, Y0, Vector((0, 1, 0))), (1, Y1, Vector((0, -1, 0))))
    normal_mundo = objeto.matrix_world.to_3x3().inverted().transposed()
    for cara in objeto.data.polygons:
        puntos = [objeto.matrix_world @ objeto.data.vertices[i].co for i in cara.vertices]
        normal = (normal_mundo @ cara.normal).normalized()
        if not any(all(abs(p[eje] - cota) < .0001 for p in puntos)
                   and normal.dot(interior) > .999 for eje, cota, interior in planos):
            continue
        if not all(X0 - .0001 <= p.x <= X1 + .0001
                   and Y0 - .0001 <= p.y <= Y1 + .0001
                   and Z0 - .0001 <= p.z <= Z1 + .0001 for p in puntos):
            raise ValueError(f"Pared {cara.index} excede el deposito; requiere recorte local")
        nombre = objeto.data.materials[cara.material_index].name
        if nombre not in ("pared nueva", "paredes", NOMBRE_MATERIAL):
            raise ValueError(f"Material inesperado en pared {cara.index}: {nombre}")
        seleccion.append(cara.index)
    if len(seleccion) != 15:
        raise ValueError(f"Se midieron 15 caras interiores; ahora hay {len(seleccion)}")
    return seleccion


def _revoque():
    material = bpy.data.materials.get(NOMBRE_MATERIAL)
    if material is None:
        material = bpy.data.materials.new(NOMBRE_MATERIAL)
    material.use_nodes = True
    material.diffuse_color = (.65, .65, .65, 1)
    material.node_tree.nodes.clear()
    salida = material.node_tree.nodes.new("ShaderNodeOutputMaterial")
    pbr = material.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    pbr.inputs["Base Color"].default_value = material.diffuse_color
    pbr.inputs["Roughness"].default_value = .9
    pbr.inputs["Metallic"].default_value = 0
    material.node_tree.links.new(pbr.outputs["BSDF"], salida.inputs["Surface"])
    return material


def aplicar():
    """Reasignar material por cara conserva geometria, UV, huecos y colisiones."""
    edificio = bpy.data.objects["almacen-col"]
    seleccion = _seleccionar(edificio)
    geometria = {o.name: _geometria_uv(o) for o in bpy.data.objects if o.type == "MESH"}
    materiales = {o.name: _materiales(o) for o in bpy.data.objects if o.type == "MESH"}
    imagenes = [(i.name, i.filepath) for i in bpy.data.images]
    antes = materiales[edificio.name]
    nombres = [m.name if m else None for m in edificio.data.materials]
    material = _revoque()
    if NOMBRE_MATERIAL not in nombres:
        edificio.data.materials.append(material)
    indice = edificio.data.materials.find(NOMBRE_MATERIAL)
    areas = []
    for numero in seleccion:
        cara = edificio.data.polygons[numero]
        areas.append(cara.area)
        cara.material_index = indice
    assert imagenes == [(i.name, i.filepath) for i in bpy.data.images]
    assert all(_geometria_uv(bpy.data.objects[n]) == h for n, h in geometria.items())
    assert all(_materiales(bpy.data.objects[n]) == m for n, m in materiales.items()
               if n != edificio.name)
    assert all(p.material_index == antes["indices"][p.index]
               for p in edificio.data.polygons if p.index not in seleccion)
    assert [m.name if m else None for m in edificio.data.materials][:len(antes["slots"])] \
        == antes["slots"]
    return {"objeto": edificio.name, "caras_interiores": seleccion,
            "material": NOMBRE_MATERIAL, "albedo_lineal": [.65, .65, .65],
            "rugosidad": .9, "metallic": 0, "caras_recortadas": [],
            "geometria_uv_transformaciones_identicas": len(geometria),
            "caras_ajenas_conservadas": len(edificio.data.polygons) - len(seleccion),
            "materiales_objetos_ajenos_identicos": len(materiales) - 1,
            "rutas_imagenes_identicas": len(imagenes),
            "area_local_caras": sum(areas)}


def main():
    sys.path.insert(0, str(RAIZ / ".claude/scripts"))
    from lib.consola import configurar

    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    parser.add_argument("--destino", type=Path, default=RAIZ / "reports/paredes-deposito.blend")
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    resultado = aplicar()
    reporte = RAIZ / "reports/paredes-conservacion.json"
    reporte.parent.mkdir(parents=True, exist_ok=True)
    reporte.write_text(json.dumps(resultado, indent=2), encoding="utf-8")
    destino = FUENTE if opciones.aplicar else opciones.destino
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    print(json.dumps(resultado, indent=2))


if __name__ == "__main__":
    main()
