"""Pasa las barras largas al interior conservando bisagras, pestillos y apertura.

Dos pernos embutidos conectan cada barra interior a las placas cortas exteriores.
Sólo edita los anclajes fijos. Por defecto guarda una copia para revisar el montaje.
"""

import hashlib
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

configurar()
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
ANCLAJES = ("bano_anclaje_bisagras_1", "bano_anclaje_bisagras_2")
bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
COLECCION = bpy.data.collections["Bano publico"]
ACERO = bpy.data.materials["bano_acero"]
if any("barra_interna_instalada" in bpy.data.objects[n] for n in ANCLAJES):
    raise RuntimeError("El montaje interior ya está instalado; no reaplicar sobre la misma malla")


def huellas_ajenas():
    resultado = {}
    for objeto in bpy.data.objects:
        if objeto.type != "MESH" or objeto.name in ANCLAJES:
            continue
        malla = objeto.data
        datos = (
            [tuple(v.co) for v in malla.vertices],
            [(tuple(p.vertices), p.material_index, p.use_smooth) for p in malla.polygons],
            [[tuple(d.uv) for d in capa.data] for capa in malla.uv_layers],
            [m.name for m in malla.materials],
            [tuple(fila) for fila in objeto.matrix_world],
            list(objeto.get("eje_de_bisagra_local", [])),
        )
        resultado[objeto.name] = hashlib.sha256(repr(datos).encode()).hexdigest()
    return resultado


def crear_pieza(nombre, vertices, caras):
    centro = Vector(tuple((min(v[i] for v in vertices) + max(v[i] for v in vertices)) / 2
                          for i in range(3)))
    malla = bpy.data.meshes.new(nombre + "_malla")
    malla.from_pydata([tuple(v[i] - centro[i] for i in range(3)) for v in vertices], [], caras)
    malla.materials.append(ACERO)
    editable = bmesh.new()
    editable.from_mesh(malla)
    bmesh.ops.recalc_face_normals(editable, faces=list(editable.faces))
    editable.to_mesh(malla)
    editable.free()
    objeto = bpy.data.objects.new(nombre, malla)
    COLECCION.objects.link(objeto)
    objeto.location = centro
    bpy.context.view_layer.update()
    return objeto


def caja(nombre, minimo, maximo):
    vertices = [(x, y, z) for z in (minimo[2], maximo[2])
                for y in (minimo[1], maximo[1]) for x in (minimo[0], maximo[0])]
    caras = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4),
             (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    return crear_pieza(nombre, vertices, caras)


def cilindro_y(nombre, x, z, y0, y1, radio):
    lados = 16
    vertices = [(x + radio * math.cos(i * math.tau / lados), y,
                 z + radio * math.sin(i * math.tau / lados))
                for y in (y0, y1) for i in range(lados)]
    caras = [tuple(range(lados - 1, -1, -1)), tuple(range(lados, lados * 2))]
    caras.extend((i, (i + 1) % lados, (i + 1) % lados + lados, i + lados)
                 for i in range(lados))
    objeto = crear_pieza(nombre, vertices, caras)
    for cara in objeto.data.polygons:
        cara.use_smooth = abs(cara.normal.y) < 0.1
    return objeto


def operar(destino, pieza, operacion):
    bpy.ops.object.select_all(action="DESELECT")
    destino.select_set(True)
    bpy.context.view_layer.objects.active = destino
    modificador = destino.modifiers.new("Montaje interno", "BOOLEAN")
    modificador.operation = operacion
    modificador.solver = "EXACT"
    modificador.object = pieza
    bpy.ops.object.modifier_apply(modifier=modificador.name)
    bpy.data.objects.remove(pieza, do_unlink=True)


def finalizar_malla(objeto):
    editable = bmesh.new()
    editable.from_mesh(objeto.data)
    grupos, objetivos = {}, {}
    for vertice in editable.verts:
        punto = tuple(objeto.matrix_world @ vertice.co)
        if punto in grupos:
            objetivos[vertice] = grupos[punto]
        else:
            grupos[punto] = vertice
    if objetivos:
        bmesh.ops.weld_verts(editable, targetmap=objetivos)
    bmesh.ops.recalc_face_normals(editable, faces=list(editable.faces))
    editable.to_mesh(objeto.data)
    editable.free()
    objeto.data.update()
    capa = objeto.data.uv_layers.active or objeto.data.uv_layers.new(name="UVMap")
    for cara in objeto.data.polygons:
        eje = max(range(3), key=lambda i: abs(cara.normal[i]))
        plano = [i for i in range(3) if i != eje]
        for bucle in cara.loop_indices:
            punto = objeto.data.vertices[objeto.data.loops[bucle].vertex_index].co
            capa.data[bucle].uv = (punto[plano[0]], punto[plano[1]])


def auditar(malla, matriz):
    editable = bmesh.new()
    editable.from_mesh(malla)
    editable.transform(matriz)
    fallos = {
        "aristas_no_manifold": sum(not e.is_manifold for e in editable.edges),
        "caras_nulas_mundiales": sum(not math.isfinite(f.calc_area()) or f.calc_area() <= 0
                                     for f in editable.faces),
        "winding_inconsistente": sum(e.is_manifold and not e.is_contiguous
                                    for e in editable.edges),
    }
    pendientes, islas = set(editable.verts), 0
    while pendientes:
        islas += 1
        visitar = [pendientes.pop()]
        while visitar:
            v = visitar.pop()
            for e in v.link_edges:
                otro = e.other_vert(v)
                if otro in pendientes:
                    pendientes.remove(otro)
                    visitar.append(otro)
    editable.free()
    malla.calc_loop_triangles()
    colapsadas = 0
    capa = malla.uv_layers.active
    for triangulo in malla.loop_triangles:
        a, b, c = [capa.data[i].uv for i in triangulo.loops]
        u, v = b - a, c - a
        area = abs(u.x * v.y - u.y * v.x) / 2
        colapsadas += not math.isfinite(area) or area <= 0
    fallos["uv_colapsadas"] = colapsadas
    if any(fallos.values()) or islas != 1:
        raise RuntimeError(f"Anclaje inválido: {fallos}, islas={islas}")
    return {"vertices": len(malla.vertices), "caras": len(malla.polygons),
            "triangulos": len(malla.loop_triangles), "islas": islas, "fallos": fallos}


def arbol(objeto, giro=Matrix.Identity(4)):
    objeto.data.calc_loop_triangles()
    return BVHTree.FromPolygons(
        [giro @ objeto.matrix_world @ v.co for v in objeto.data.vertices],
        [tuple(t.vertices) for t in objeto.data.loop_triangles],
        all_triangles=True, epsilon=0.000001,
    )


antes = huellas_ajenas()
informe = {"anclajes": {}, "contactos_en_19_angulos": []}
for numero, nombre in enumerate(ANCLAJES, 1):
    hoja = bpy.data.objects[f"bano_puerta_{numero}"]
    eje = hoja.matrix_world @ Vector(hoja["eje_de_bisagra_local"])
    x, y = eje.x, eje.y
    anclaje = bpy.data.objects[nombre]
    # Los 0.5 mm restantes evitan cortar sobre la tapa exacta de las placas existentes.
    operar(anclaje, caja("retirar_barra_exterior", (x + .016, y + .0253, .6505),
                         (x + .084, y + .0373, 1.8895)), "DIFFERENCE")
    operar(anclaje, caja("barra_interior", (x + .052, y - .0353, .524),
                         (x + .116, y - .0273, 2.016)), "UNION")
    for z in (.59, 1.95):
        perno = cilindro_y("perno_embutido", x + .070, z, y - .038, y + .038, .003)
        for y0, y1 in ((y - .039, y - .033), (y + .033, y + .039)):
            operar(perno, cilindro_y("cabeza_perno", x + .070, z, y0, y1, .006), "UNION")
        operar(anclaje, perno, "UNION")
    finalizar_malla(anclaje)
    source = auditar(anclaje.data, anclaje.matrix_world)
    evaluado = anclaje.evaluated_get(bpy.context.evaluated_depsgraph_get())
    malla = evaluado.to_mesh()
    try:
        evaluated = auditar(malla, evaluado.matrix_world)
    finally:
        evaluado.to_mesh_clear()
    anclaje["barra_interna_instalada"] = True
    informe["anclajes"][nombre] = {"source": source, "evaluated": evaluated,
                                   "barra_interior_x": [x + .052, x + .116],
                                   "barra_interior_y": [y - .0353, y - .0273]}

despues = huellas_ajenas()
if antes != despues:
    raise RuntimeError("Cambió una hoja, eje, pestillo u otra malla fuera de los anclajes")
fijas = [o for o in COLECCION.objects if o.type == "MESH"
         and o.name.startswith(("bano_mampara", "bano_perfil", "bano_riel", "bano_anclaje"))]
arboles = [(o.name, arbol(o)) for o in fijas]
for numero in (1, 2):
    hoja = bpy.data.objects[f"bano_puerta_{numero}"]
    eje = hoja.matrix_world @ Vector(hoja["eje_de_bisagra_local"])
    for grados in range(0, 91, 5):
        giro = Matrix.Translation(eje) @ Matrix.Rotation(math.radians(grados), 4, "Z")
        movil = arbol(hoja, giro @ Matrix.Translation(-eje))
        for nombre, fijo in arboles:
            if movil.overlap(fijo):
                informe["contactos_en_19_angulos"].append((hoja.name, grados, nombre))
if informe["contactos_en_19_angulos"]:
    raise RuntimeError(f"Barrido interferido: {informe['contactos_en_19_angulos']}")
informe["mallas_ajenas_identicas"] = len(antes)
informes = RAIZ / "reports"
informes.mkdir(exist_ok=True)
(informes / "caras-cabinas-orientadas.json").write_text(json.dumps(informe, indent=2),
                                                      encoding="utf-8")
destino = FUENTE if "--aplicar" in sys.argv else informes / "caras-cabinas-orientadas.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
print(json.dumps(informe, indent=2))
