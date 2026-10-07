"""Tres reflectores cuadrados colgantes con un panel luminoso plano.

Importar no abre ni guarda archivos. aplicar() reemplaza solamente las lámparas
propias; la CLI prepara una copia en reports o escribe la fuente con --aplicar.
"""

import argparse
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
PREFIJO = "deposito_lampara_"
POSICIONES = ((-2.5, 12.0), (1.7, 12.0), (5.9, 12.0))


def _material(nombre, color, metal, rugosidad, emision=0.0):
    material = bpy.data.materials.get(nombre) or bpy.data.materials.new(nombre)
    material.use_nodes = True
    material.diffuse_color = (*color, 1.0)
    material.node_tree.nodes.clear()
    salida = material.node_tree.nodes.new("ShaderNodeOutputMaterial")
    pbr = material.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    pbr.inputs["Base Color"].default_value = (*color, 1.0)
    pbr.inputs["Metallic"].default_value = metal
    pbr.inputs["Roughness"].default_value = rugosidad
    pbr.inputs["Emission Color"].default_value = (*color, 1.0)
    pbr.inputs["Emission Strength"].default_value = emision
    material.node_tree.links.new(pbr.outputs["BSDF"], salida.inputs["Surface"])
    return material


def _uv(objeto):
    bpy.ops.object.select_all(action="DESELECT")
    objeto.select_set(True)
    bpy.context.view_layer.objects.active = objeto
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(65), island_margin=0.025)
    bpy.ops.object.mode_set(mode="OBJECT")


def _malla(nombre, vertices, caras, materiales, coleccion, padre):
    malla = bpy.data.meshes.new(nombre)
    malla.from_pydata(vertices, [], caras)
    for material in materiales:
        malla.materials.append(material)
    bm = bmesh.new()
    bm.from_mesh(malla)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(malla)
    bm.free()
    objeto = bpy.data.objects.new(nombre, malla)
    coleccion.objects.link(objeto)
    objeto.parent = padre
    _uv(objeto)
    return objeto


def _caja(nombre, medidas, altura, material, coleccion, padre):
    x, y, z = (v / 2 for v in medidas)
    vertices = [(a * x, b * y, altura + c * z)
                for c in (-1, 1) for b in (-1, 1) for a in (-1, 1)]
    caras = ((0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4),
             (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5))
    return _malla(nombre, vertices, caras, (material,), coleccion, padre)


def _reflector(nombre, metal, interior, luminoso, coleccion, padre):
    # Cuatro anillos forman la chapa cerrada, con un canto de 8 mm.
    perfil = ((0.280, 0.000), (0.105, 0.180),
              (0.097, 0.172), (0.272, 0.008))
    vertices = [(x * radio, y * radio, z) for radio, z in perfil
                for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    caras = [(j * 4 + i, j * 4 + (i + 1) % 4,
              ((j + 1) % 4) * 4 + (i + 1) % 4, ((j + 1) % 4) * 4 + i)
             for j in range(4) for i in range(4)]
    campana = _malla(nombre + "_reflector", vertices, caras,
                    (metal, interior), coleccion, padre)
    for cara in campana.data.polygons:
        if 8 <= cara.index < 12:
            cara.material_index = 1
    # El panel encaja en la apertura a esta altura. Sólo su cara inferior emite.
    panel = _caja(nombre + "_panel_luminoso", (0.496, 0.496, 0.006), 0.027,
                  interior, coleccion, padre)
    panel.data.materials.append(luminoso)
    for cara in panel.data.polygons:
        if cara.normal.z < -0.5:
            cara.material_index = 1


def _techo(x, y):
    bpy.context.view_layer.update()
    acierto, punto, _, _, objeto, _ = bpy.context.scene.ray_cast(
        bpy.context.evaluated_depsgraph_get(), Vector((x, y, 3.0)), Vector((0, 0, 1)),
        distance=6.0,
    )
    if not acierto or punto.z < 3.95:
        raise ValueError(f"Revisar techo u obstáculo en {(x, y)}: {objeto}, {punto}")
    return punto.z, objeto.name


def aplicar():
    """Rehacer tres lámparas sin modificar otros objetos ni las luces de la escena."""
    for objeto in list(bpy.data.objects):
        if objeto.name.startswith(PREFIJO):
            bpy.data.objects.remove(objeto, do_unlink=True)
    for malla in list(bpy.data.meshes):
        if malla.name.startswith(PREFIJO) and malla.users == 0:
            bpy.data.meshes.remove(malla)
    coleccion = bpy.data.collections.get("Deposito lamparas")
    if coleccion is None:
        coleccion = bpy.data.collections.new("Deposito lamparas")
        bpy.context.scene.collection.children.link(coleccion)
    metal = _material(PREFIJO + "metal", (0.22, 0.24, 0.25), 0.55, 0.50)
    interior = _material(PREFIJO + "interior", (0.72, 0.72, 0.69), 0.0, 0.60)
    cable = _material(PREFIJO + "cable", (0.012, 0.014, 0.015), 0.0, 0.82)
    luminoso = _material(PREFIJO + "panel", (1.0, 0.96, 0.88), 0.0, 0.45, 2.0)
    resultados = []
    for numero, (x, y) in enumerate(POSICIONES, 1):
        techo, soporte = _techo(x, y)
        base = min(techo - 0.90, 3.60)
        nombre = f"{PREFIJO}{numero:02d}"
        padre = bpy.data.objects.new(nombre, None)
        coleccion.objects.link(padre)
        padre.location = (x, y, base)
        padre.empty_display_type = "PLAIN_AXES"
        padre.empty_display_size = 0.12
        _reflector(nombre, metal, interior, luminoso, coleccion, padre)
        _caja(nombre + "_sujecion", (0.080, 0.080, 0.060), 0.208,
              metal, coleccion, padre)
        inicio, fin = 0.233, techo - base - 0.016
        _caja(nombre + "_cable", (0.008, 0.008, fin - inicio), (inicio + fin) / 2,
              cable, coleccion, padre)
        _caja(nombre + "_anclaje", (0.120, 0.120, 0.020), techo - base - 0.008,
              metal, coleccion, padre)
        resultados.append({
            "nombre": nombre, "techo_blender": techo, "soporte": soporte,
            "base_blender": [x, y, base], "foco_godot": [x, base - 0.030, -y],
            "direccion_godot": [0, -1, 0], "ancho": 0.56, "espesor_chapa": 0.008,
            "spot_angulo_grados": 68, "spot_rango": 7.0, "spot_energia_inicial": 2.0,
        })
    bpy.context.view_layer.update()
    return resultados


def main():
    sys.path.insert(0, str(RAIZ / ".claude/scripts"))
    from lib.consola import configurar

    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    parser.add_argument("--destino", type=Path, default=RAIZ / "reports/lamparas-deposito.blend")
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    resultado = aplicar()
    reporte = RAIZ / "reports/lamparas-posiciones.json"
    reporte.parent.mkdir(parents=True, exist_ok=True)
    reporte.write_text(json.dumps(resultado, indent=2), encoding="utf-8")
    destino = FUENTE if opciones.aplicar else opciones.destino
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    print(json.dumps(resultado, indent=2))
    print(f"Tres reflectores guardados en {destino}")


if __name__ == "__main__":
    main()
