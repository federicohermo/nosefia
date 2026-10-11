"""Bloques cementicios abajo y chapa vertical arriba, solo dentro del deposito.

Los mapas PBR originales CC0 viajan al glTF con sus dimensiones fisicas.
La pared conserva su topologia, huecos y UV de caras ajenas.
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
TEXTURAS = RAIZ / "assets/source/textures/warehouse/ambientcg/bricks-066"
CHAPA = RAIZ / "assets/source/textures/warehouse/polyhaven/corrugated-iron-02/1K"
PREFIJO = "deposito_revestimiento_"
PISO = .10223700106143951
# La altura del revestimiento se conserva; doce hiladas terminan en una junta completa.
BLOQUE_METROS = (.6, .3)
HILADAS = 12
COBERTURA_BLOQUES = (3 * BLOQUE_METROS[0], 9 * BLOQUE_METROS[1])
CORTE = PISO + HILADAS * BLOQUE_METROS[1]
MATERIALES = ("deposito_pared_revoque_gris_claro", PREFIJO + "bloques", PREFIJO + "chapa")
MAPAS = {
    "bloques": {"color": TEXTURAS / "Bricks066_1K-JPG_Color.jpg",
                "normal": TEXTURAS / "Bricks066_1K-JPG_NormalGL.jpg",
                "rough": TEXTURAS / "Bricks066_1K-JPG_Roughness.jpg"},
    "chapa": {"color": CHAPA / "corrugated_iron_02_diff_1k.jpg",
              "normal": CHAPA / "corrugated_iron_02_nor_gl_1k.png",
              "rough": CHAPA / "corrugated_iron_02_rough_1k.jpg",
              "metal": CHAPA / "corrugated_iron_02_metal_1k.jpg"},
}


def _huellas(excluir=()):
    resultado = {}
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        datos = {"vertices": [tuple(v.co) for v in o.data.vertices],
                 "caras": [tuple(p.vertices) for p in o.data.polygons],
                 "matriz": [tuple(f) for f in o.matrix_world],
                 "padre": o.parent.name if o.parent else None,
                 "smooth": [p.use_smooth for p in o.data.polygons],
                 "materiales": [], "uv": []}
        for p in o.data.polygons:
            autorizada = o.name == "almacen-col" and p.index in excluir
            if not autorizada:
                material = o.data.materials[p.material_index] if o.data.materials else None
                datos["materiales"].append((p.index, material.name if material else None))
            for capa in o.data.uv_layers:
                if autorizada and capa == o.data.uv_layers.active:
                    continue
                datos["uv"].append((p.index, capa.name,
                                    [tuple(capa.data[i].uv) for i in p.loop_indices]))
        resultado[o.name] = hashlib.sha256(json.dumps(datos).encode()).hexdigest()
    return resultado


def _caras(objeto):
    seleccion = [p.index for p in objeto.data.polygons
                 if objeto.data.materials[p.material_index].name in MATERIALES]
    if len(seleccion) != 23:
        raise ValueError(f"Se requieren 23 caras interiores; hay {len(seleccion)}")
    puntos = [objeto.matrix_world @ objeto.data.vertices[i].co
              for numero in seleccion for i in objeto.data.polygons[numero].vertices]
    limites = [[min(p[k] for p in puntos) for k in range(3)],
               [max(p[k] for p in puntos) for k in range(3)]]
    centro = (Vector(limites[0]) + Vector(limites[1])) / 2
    normales = objeto.matrix_world.to_3x3().inverted().transposed()
    for numero in seleccion:
        cara = objeto.data.polygons[numero]
        normal = (normales @ cara.normal).normalized()
        adentro = centro - objeto.matrix_world @ cara.center
        assert abs(normal.z) < .0001 and normal.dot(adentro) > 0
        z = [(objeto.matrix_world @ objeto.data.vertices[i].co).z for i in cara.vertices]
        assert max(z) <= CORTE + .0001 or min(z) >= CORTE - .0001
    return seleccion, limites


def _material(tipo):
    nombre = PREFIJO + tipo
    material = bpy.data.materials.get(nombre) or bpy.data.materials.new(nombre)
    material.use_nodes = True
    material.node_tree.nodes.clear()
    salida = material.node_tree.nodes.new("ShaderNodeOutputMaterial")
    pbr = material.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    material.node_tree.links.new(pbr.outputs[0], salida.inputs[0])
    pbr.inputs["Roughness"].default_value = .93 if tipo == "bloques" else .72
    pbr.inputs["Metallic"].default_value = 0 if tipo == "bloques" else .25
    material.diffuse_color = (.29, .305, .32, 1)
    for mapa, ruta in MAPAS[tipo].items():
        imagen = bpy.data.images.load(str(ruta), check_existing=True)
        imagen.colorspace_settings.name = "sRGB" if mapa == "color" else "Non-Color"
        imagen.filepath = bpy.path.relpath(str(ruta), start=str(FUENTE.parent))
        textura = material.node_tree.nodes.new("ShaderNodeTexImage")
        textura.image = imagen
        textura.extension = "REPEAT"
        if mapa == "color":
            if tipo == "bloques":
                # El exportador 5.2 reconoce Mix RGBA Multiply como baseColorFactor.
                mezcla = material.node_tree.nodes.new("ShaderNodeMix")
                mezcla.data_type = "RGBA"
                mezcla.blend_type = "MULTIPLY"
                mezcla.inputs[0].default_value = 1
                mezcla.inputs[7].default_value = (.72, .72, .72, 1)
                material.node_tree.links.new(textura.outputs["Color"], mezcla.inputs[6])
                material.node_tree.links.new(mezcla.outputs[2], pbr.inputs["Base Color"])
            else:
                material.node_tree.links.new(textura.outputs["Color"], pbr.inputs["Base Color"])
        elif mapa == "normal":
            normal = material.node_tree.nodes.new("ShaderNodeNormalMap")
            normal.inputs["Strength"].default_value = .45 if tipo == "bloques" else .65
            material.node_tree.links.new(textura.outputs["Color"], normal.inputs["Color"])
            material.node_tree.links.new(normal.outputs[0], pbr.inputs["Normal"])
        else:
            entrada = "Roughness" if mapa == "rough" else "Metallic"
            material.node_tree.links.new(textura.outputs["Color"], pbr.inputs[entrada])
    return material


def aplicar():
    """Cambiar solo materiales y UV activas de las caras interiores ya separadas."""
    objeto = bpy.data.objects["almacen-col"]
    seleccion, limites = _caras(objeto)
    antes = _huellas(seleccion)
    materiales = {tipo: _material(tipo) for tipo in ("bloques", "chapa")}
    for material in materiales.values():
        if objeto.data.materials.find(material.name) < 0:
            objeto.data.materials.append(material)
    clasificacion = {"bloques": [], "chapa": []}
    capa = objeto.data.uv_layers.active
    normal_mundo = objeto.matrix_world.to_3x3().inverted().transposed()
    for numero in seleccion:
        cara = objeto.data.polygons[numero]
        puntos = [objeto.matrix_world @ objeto.data.vertices[i].co for i in cara.vertices]
        tipo = "bloques" if max(p.z for p in puntos) <= CORTE + .0001 else "chapa"
        # Bricks066 tiene tres bloques por nueve hiladas en su atlas cuadrado.
        cobertura_u, cobertura_v = COBERTURA_BLOQUES if tipo == "bloques" else (5.4, 2.7)
        normal = (normal_mundo @ cara.normal).normalized()
        for bucle, p in zip(cara.loop_indices, puntos):
            if abs(normal.x) > .9:
                u = (p.y - limites[0][1]) * (1 if normal.x > 0 else -1)
            else:
                u = (p.x - limites[0][0]) * (-1 if normal.y > 0 else 1)
            origen_v = PISO if tipo == "bloques" else CORTE
            capa.data[bucle].uv = (u / cobertura_u, (p.z - origen_v) / cobertura_v)
        cara.material_index = objeto.data.materials.find(materiales[tipo].name)
        clasificacion[tipo].append(numero)
    assert antes == _huellas(seleccion), "Se modificaron mallas o caras ajenas"
    return {"caras": clasificacion, "corte_blender": CORTE, "altura_bloques": CORTE - PISO,
            "limites": limites, "bloque_metros": list(BLOQUE_METROS),
            "cobertura_bloques_metros": list(COBERTURA_BLOQUES),
            "factor_gris_bloques": [.72, .72, .72, 1],
            "cobertura_chapa_metros": [5.4, 2.7], "triangulos_agregados": 0,
            "mallas_y_caras_ajenas_conservadas": len(antes),
            "material_exportable": "Principled BSDF + mapas CC0 + normal tangent",
            "mapas": {tipo: {mapa: str(ruta) for mapa, ruta in mapas.items()}
                      for tipo, mapas in MAPAS.items()}}


def main():
    sys.path.insert(0, str(RAIZ / ".claude/scripts"))
    from lib.consola import configurar

    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    parser.add_argument("--destino", type=Path,
                        default=RAIZ / "reports/revestimiento-deposito.blend")
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    resultado = aplicar()
    (RAIZ / "reports/revestimiento-conservacion.json").write_text(
        json.dumps(resultado, indent=2), encoding="utf-8")
    bpy.ops.wm.save_as_mainfile(filepath=str(FUENTE if opciones.aplicar else opciones.destino),
                               check_existing=False)
    print(json.dumps(resultado, indent=2))


if __name__ == "__main__":
    main()
