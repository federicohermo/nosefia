"""Repara encuentros y bisagras conservando las hojas y sus ejes de apertura.

Guarda una copia por defecto. --aplicar se usa sólo al integrar sobre la fuente fresca.
Los pasadores fijos y los barriles móviles quedan concéntricos con el eje anterior;
la escena debe usar un Marker3D porque el herraje completo amplía el AABB de la hoja.
"""

import hashlib
import importlib.util
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
from lib.cabinas_del_bano import seccion_del_perfil, seccion_del_poste  # noqa: E402
from lib.consola import configurar  # noqa: E402

configurar()
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
PREFIJOS = ("bano_mampara", "bano_puerta_", "bano_riel", "bano_perfil", "bano_anclaje")
bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
COLECCION = bpy.data.collections["Bano publico"]
ACERO = bpy.data.materials["bano_acero"]
REFINAR = "--refinar" in sys.argv
REFINADOS = ("bano_riel_frontal", "bano_anclaje_bisagras_1", "bano_anclaje_bisagras_2")
if not REFINAR and ("eje_de_bisagra_local" in bpy.data.objects["bano_puerta_1"]
                   or bpy.data.objects.get("bano_anclaje_bisagras_1") is not None):
    raise RuntimeError("Las cabinas ya fueron reparadas; no regenerar sobre la malla modificada")
if REFINAR and not all(bpy.data.objects.get(n) is not None for n in REFINADOS):
    raise RuntimeError("--refinar requiere las tres piezas de unas cabinas ya reparadas")


def huellas_ajenas(excluir=PREFIJOS):
    resultado = {}
    for objeto in bpy.data.objects:
        if objeto.type != "MESH" or objeto.name.startswith(excluir):
            continue
        datos = (
            [tuple(v.co) for v in objeto.data.vertices],
            [(tuple(p.vertices), p.material_index, p.use_smooth) for p in objeto.data.polygons],
            [[tuple(d.uv) for d in capa.data] for capa in objeto.data.uv_layers],
            [m.name for m in objeto.data.materials],
            [tuple(fila) for fila in objeto.matrix_world],
        )
        resultado[objeto.name] = hashlib.sha256(repr(datos).encode()).hexdigest()
    return resultado


def corregir_normales(malla):
    editable = bmesh.new()
    editable.from_mesh(malla)
    bmesh.ops.recalc_face_normals(editable, faces=list(editable.faces))
    editable.to_mesh(malla)
    editable.free()
    malla.update()


def asignar_uv(malla):
    capa = malla.uv_layers.new(name="UVMap") if not malla.uv_layers else malla.uv_layers.active
    for cara in malla.polygons:
        eje = max(range(3), key=lambda i: abs(cara.normal[i]))
        plano = [i for i in range(3) if i != eje]
        for bucle in cara.loop_indices:
            punto = malla.vertices[malla.loops[bucle].vertex_index].co
            capa.data[bucle].uv = (punto[plano[0]], punto[plano[1]])


def objeto_de_malla(nombre, vertices, caras, material=ACERO):
    # Herrajes milimétricos cerca de X=13 pierden precisión si sus vértices son mundiales.
    centro = Vector(tuple((min(v[i] for v in vertices) + max(v[i] for v in vertices)) / 2
                          for i in range(3)))
    malla = bpy.data.meshes.new(nombre + "_malla")
    malla.from_pydata([tuple(v[i] - centro[i] for i in range(3)) for v in vertices], [], caras)
    malla.materials.append(material)
    corregir_normales(malla)
    asignar_uv(malla)
    objeto = bpy.data.objects.new(nombre, malla)
    objeto.location = centro
    COLECCION.objects.link(objeto)
    bpy.context.view_layer.update()
    return objeto


def prisma(nombre, seccion, inferior, superior):
    cantidad = len(seccion)
    vertices = [(x, y, z) for z in (inferior, superior) for x, y in seccion]
    caras = [tuple(range(cantidad - 1, -1, -1)), tuple(range(cantidad, cantidad * 2))]
    caras.extend(
        (i, (i + 1) % cantidad, (i + 1) % cantidad + cantidad, i + cantidad)
        for i in range(cantidad)
    )
    return objeto_de_malla(nombre, vertices, caras)


def caja(nombre, minimo, maximo):
    x0, y0, z0 = minimo
    x1, y1, z1 = maximo
    return prisma(nombre, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], z0, z1)


def anillo(nombre, x, y, inferior, superior, exterior=0.009, interior=0.0043):
    lados = 24
    vertices = []
    for z in (inferior, superior):
        for radio in (exterior, interior):
            vertices.extend(
                (x + radio * math.cos(i * math.tau / lados),
                 y + radio * math.sin(i * math.tau / lados), z)
                for i in range(lados)
            )
    caras = []
    for i in range(lados):
        j = (i + 1) % lados
        caras.extend([
            (i, j, j + lados * 2, i + lados * 2),
            (i + lados, i + lados * 3, j + lados * 3, j + lados),
            (i, i + lados, j + lados, j),
            (i + lados * 2, j + lados * 2, j + lados * 3, i + lados * 3),
        ])
    objeto = objeto_de_malla(nombre, vertices, caras)
    for cara in objeto.data.polygons:
        cara.use_smooth = abs(cara.normal.z) < 0.1
    return objeto


def cilindro(nombre, x, y, inferior, superior, radio):
    seccion = [(x + radio * math.cos(i * math.tau / 24),
                y + radio * math.sin(i * math.tau / 24)) for i in range(24)]
    objeto = prisma(nombre, seccion, inferior, superior)
    for cara in objeto.data.polygons:
        cara.use_smooth = abs(cara.normal.z) < 0.1
    return objeto


def fusionar(destino, pieza):
    # Aplicar la unión elimina caras internas; agrupar islas no resuelve el encuentro.
    bpy.ops.object.select_all(action="DESELECT")
    destino.select_set(True)
    bpy.context.view_layer.objects.active = destino
    modificador = destino.modifiers.new("Encuentro continuo", "BOOLEAN")
    modificador.operation = "UNION"
    modificador.solver = "EXACT"
    modificador.object = pieza
    bpy.ops.object.modifier_apply(modifier=modificador.name)
    bpy.data.objects.remove(pieza, do_unlink=True)


def bandera(nombre, x, y, inferior, superior, fija=False):
    pieza = anillo(nombre, x, y, inferior, superior)
    signo = 1 if fija else -1
    x0, x1 = sorted((x + signo * 0.080, x + signo * 0.009))
    y0, y1 = sorted((y + signo * 0.036, y + signo * 0.022))
    fusionar(pieza, caja(nombre + "_placa", (x0, y0, inferior), (x1, y1, superior)))
    x0, x1 = sorted((x + signo * 0.024, x + signo * 0.007))
    y0, y1 = sorted((y + signo * 0.030, y - signo * 0.006))
    fusionar(pieza, caja(nombre + "_cuello", (x0, y0, inferior), (x1, y1, superior)))
    return pieza


def quitar_bisagras_viejas(hoja):
    original = hoja.data
    caras = []
    for cara in original.polygons:
        puntos = [hoja.matrix_world @ original.vertices[i].co for i in cara.vertices]
        centro_z = sum(p.z for p in puntos) / len(puntos)
        if (max(p.z for p in puntos) - min(p.z for p in puntos) < 0.12
                and any(abs(centro_z - z) <= 0.056 for z in (0.59, 1.95))):
            continue
        caras.append(cara)
    indices = sorted({i for cara in caras for i in cara.vertices})
    nuevos = {indice: i for i, indice in enumerate(indices)}
    malla = bpy.data.meshes.new(hoja.name + "_editable")
    malla.from_pydata([tuple(original.vertices[i].co) for i in indices], [],
                      [tuple(nuevos[i] for i in cara.vertices) for cara in caras])
    for material in original.materials:
        malla.materials.append(material)
    for cara, vieja in zip(malla.polygons, caras):
        cara.material_index = vieja.material_index
        cara.use_smooth = vieja.use_smooth
    for capa_vieja in original.uv_layers:
        capa = malla.uv_layers.new(name=capa_vieja.name)
        for cara, vieja in zip(malla.polygons, caras):
            for indice, previo in zip(cara.loop_indices, vieja.loop_indices):
                capa.data[indice].uv = capa_vieja.data[previo].uv
    hoja.data = malla


def sustituir_poste(nombre, eje_x, extremo_x, y):
    viejo = bpy.data.objects[nombre]
    pieza = prisma("poste_temporal", seccion_del_poste(eje_x, extremo_x, y - 0.0275,
                                                       y + 0.0275), 0.30, 2.30)
    pieza.data.transform(viejo.matrix_world.inverted() @ pieza.matrix_world)
    pieza.data.materials.clear()
    for material in viejo.data.materials:
        pieza.data.materials.append(material)
    viejo.data = pieza.data
    bpy.data.objects.remove(pieza, do_unlink=True)


def arbol(objeto, giro=None):
    matriz = objeto.matrix_world if giro is None else giro @ objeto.matrix_world
    vertices = [matriz @ v.co for v in objeto.data.vertices]
    return BVHTree.FromPolygons(vertices, [tuple(p.vertices) for p in objeto.data.polygons],
                               all_triangles=False, epsilon=0.000001)


def auditar(objeto):
    editable = bmesh.new()
    editable.from_mesh(objeto.data)
    pendientes = set(editable.verts)
    islas = 0
    while pendientes:
        islas += 1
        visitar = [pendientes.pop()]
        while visitar:
            vertice = visitar.pop()
            for arista in vertice.link_edges:
                otro = arista.other_vert(vertice)
                if otro in pendientes:
                    pendientes.remove(otro)
                    visitar.append(otro)
    puntos = [objeto.matrix_world @ v.co for v in editable.verts]
    datos = {
        "vertices": len(editable.verts), "caras": len(editable.faces),
        "bordes_abiertos": sum(e.is_boundary for e in editable.edges),
        "bordes_no_manifold": sum(not e.is_manifold for e in editable.edges),
        "caras_nulas": sum(f.calc_area() <= 0 for f in editable.faces),
        "uv": [c.name for c in objeto.data.uv_layers],
        "islas": islas,
        "limite_inferior": [min(v[i] for v in puntos) for i in range(3)],
        "limite_superior": [max(v[i] for v in puntos) for i in range(3)],
    }
    editable.free()
    if datos["bordes_no_manifold"] or datos["caras_nulas"]:
        raise RuntimeError(f"Geometría inválida {objeto.name}: {datos}")
    return datos


def refinar_riel():
    objeto = bpy.data.objects["bano_riel_frontal"]
    puntos = [objeto.matrix_world @ v.co for v in objeto.data.vertices]
    y0, y1 = min(p.y for p in puntos), max(p.y for p in puntos)
    x0, x1 = min(p.x for p in puntos), max(p.x for p in puntos)
    z0, z1 = min(p.z for p in puntos), max(p.z for p in puntos)
    ramas = sorted({p.x for p in puntos if p.y == y0})
    frente = min(p.y for p in puntos if p.x == x0)
    xs, ys = sorted({x0, x1, *ramas}), [y0, frente, y1]
    vertices, caras, indices = [], [], {}

    def vertice(i, j, k):
        clave = (i, j, k)
        if clave not in indices:
            indices[clave] = len(vertices)
            vertices.append((xs[i], ys[j], z0 if k == 0 else z1))
        return indices[clave]

    celdas = {(i, j) for i in range(len(xs) - 1) for j in (0, 1)
              if j == 1 or any(a < (xs[i] + xs[i + 1]) / 2 < b
                              for a, b in zip(ramas[::2], ramas[1::2]))}
    for i, j in sorted(celdas):
        caras.extend([
            (vertice(i, j, 0), vertice(i, j + 1, 0), vertice(i + 1, j + 1, 0),
             vertice(i + 1, j, 0)),
            (vertice(i, j, 1), vertice(i + 1, j, 1), vertice(i + 1, j + 1, 1),
             vertice(i, j + 1, 1)),
        ])
        for vecino, extremos in (
            ((i, j - 1), ((i, j), (i + 1, j))),
            ((i + 1, j), ((i + 1, j), (i + 1, j + 1))),
            ((i, j + 1), ((i + 1, j + 1), (i, j + 1))),
            ((i - 1, j), ((i, j + 1), (i, j))),
        ):
            if vecino not in celdas:
                a, b = extremos
                caras.append((vertice(*a, 0), vertice(*b, 0),
                              vertice(*b, 1), vertice(*a, 1)))
    malla = bpy.data.meshes.new("bano_riel_frontal_quads")
    # Calcular en double antes de convertir a float evita otra cancelación en Z=2.34.
    matriz = objeto.matrix_world
    if any(abs(matriz[i][j] - (1 if i == j else 0)) > 1e-7
           for i in range(3) for j in range(3)):
        raise RuntimeError("El riel cambió orientación; revisar el refinado antes de aplicar")
    malla.from_pydata([tuple(p[i] - matriz[i][3] for i in range(3)) for p in vertices],
                      [], caras)
    for material in objeto.data.materials:
        malla.materials.append(material)
    objeto.data = malla
    corregir_normales(malla)
    asignar_uv(malla)


def refinar_anclaje(objeto):
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
        # Sólo equivalencias EXACTAS mundiales del herraje, sin soldar por distancia.
        bmesh.ops.weld_verts(editable, targetmap=objetivos)
    bmesh.ops.recalc_face_normals(editable, faces=list(editable.faces))
    editable.to_mesh(objeto.data)
    editable.free()
    objeto.data.update()
    asignar_uv(objeto.data)
    return len(objetivos)


def inspeccionar_superficies(malla, matriz):
    editable = bmesh.new()
    editable.from_mesh(malla)
    editable.transform(matriz)
    topologia = {
        "bordes_abiertos": sum(e.is_boundary for e in editable.edges),
        "bordes_no_manifold": sum(not e.is_manifold for e in editable.edges),
        "orientacion_inconsistente": sum(e.is_manifold and not e.is_contiguous
                                        for e in editable.edges),
        "caras_nulas_mundiales": sum(not math.isfinite(f.calc_area()) or f.calc_area() <= 0
                                     for f in editable.faces),
        "vertices_sueltos": sum(not v.link_edges for v in editable.verts),
    }
    editable.free()
    malla.calc_loop_triangles()
    colapsadas = 0
    capa = malla.uv_layers.active
    if capa is not None:
        for triangulo in malla.loop_triangles:
            a, b, c = [capa.data[i].uv for i in triangulo.loops]
            u, v = b - a, c - a
            area = abs(u.x * v.y - u.y * v.x) / 2
            colapsadas += not math.isfinite(area) or area <= 0
    topologia["triangulos_uv_colapsados"] = colapsadas
    topologia["uv_activa_ausente"] = capa is None
    return {"topology": topologia, "failures": [k for k, v in topologia.items() if v]}


def auditar_integracion(objeto):
    inspector = inspeccionar_superficies
    if "--auditor" in sys.argv:
        ruta = Path(sys.argv[sys.argv.index("--auditor") + 1])
        modulo_spec = importlib.util.spec_from_file_location("auditor_de_mallas", ruta)
        modulo = importlib.util.module_from_spec(modulo_spec)
        modulo_spec.loader.exec_module(modulo)
        inspector = lambda malla, matriz: modulo.inspect_mesh(malla, matriz, True, True)
    informe = {"source": inspector(objeto.data, objeto.matrix_world)}
    evaluado = objeto.evaluated_get(bpy.context.evaluated_depsgraph_get())
    malla = evaluado.to_mesh()
    try:
        informe["evaluated"] = inspector(malla, evaluado.matrix_world)
    finally:
        evaluado.to_mesh_clear()
    for tipo, datos in informe.items():
        if datos["failures"]:
            raise RuntimeError(f"Auditoría de integración {objeto.name}/{tipo}: {datos['failures']}")
    return informe


antes = huellas_ajenas(REFINADOS if REFINAR else PREFIJOS)
ejes = {}
if REFINAR:
    for numero in (1, 2):
        hoja = bpy.data.objects[f"bano_puerta_{numero}"]
        punto = Vector(hoja["eje_de_bisagra_local"])
        ejes[hoja.name] = {"local": list(punto), "mundial": list(hoja.matrix_world @ punto)}
else:
    for numero in (1, 2):
        hoja = bpy.data.objects[f"bano_puerta_{numero}"]
        minimo_x = min(v.co.x for v in hoja.data.vertices)
        eje = hoja.matrix_world @ Vector((minimo_x, 0, 0))
        ejes[hoja.name] = {"local": [minimo_x, 0, 0], "mundial": list(eje)}
        quitar_bisagras_viejas(hoja)
        x, y = eje.x, eje.y
        anclaje = caja(f"bano_anclaje_bisagras_{numero}",
                       (x + 0.018, y + 0.0273, 0.524), (x + 0.082, y + 0.0353, 2.016))
        for z in (0.59, 1.95):
            fusionar(hoja, bandera("barril_movil", x, y, z - 0.030, z + 0.030))
            for inferior, superior in ((z - 0.060, z - 0.032), (z + 0.032, z + 0.060)):
                fusionar(anclaje, bandera("barril_fijo", x, y, inferior, superior, fija=True))
            pin = cilindro("pasador_fijo", x, y, z - 0.066, z + 0.066, 0.004)
            fusionar(pin, cilindro("cabeza_pasador", x, y, z + 0.0598, z + 0.066, 0.007))
            fusionar(anclaje, pin)
        hoja["eje_de_bisagra_local"] = [minimo_x, 0, 0]

    sustituir_poste("bano_mampara_frontal-convcol.001",
                    ejes["bano_puerta_1"]["mundial"][0], 12.05, 3.35)
    sustituir_poste("bano_mampara_frontal-convcol.003",
                    ejes["bano_puerta_2"]["mundial"][0], 13.43, 3.35)
    bpy.data.objects.remove(bpy.data.objects["bano_mampara_frontal-convcol.002"], do_unlink=True)

    for numero, x in enumerate((10.20, 11.81), 1):
        prisma(f"bano_perfil_encuentro_{numero}", seccion_del_perfil(x, 3.35, numero == 2),
               0.30, 2.31)

    frontal = bpy.data.objects["bano_riel_frontal"]
    # El larguero alcanza el perfil exterior y recibe los tres travesaños sin tapas internas.
    nuevo = caja("riel_temporal", (10.1647, 3.319, 2.31), (13.435, 3.386, 2.37))
    nuevo.data.transform(frontal.matrix_world.inverted() @ nuevo.matrix_world)
    frontal.data = nuevo.data
    bpy.data.objects.remove(nuevo, do_unlink=True)
    for nombre in ("bano_riel_superior", "bano_riel_superior.001", "bano_riel_superior.002"):
        fusionar(frontal, bpy.data.objects[nombre])


refinar_riel()
soldados = {nombre: refinar_anclaje(bpy.data.objects[nombre]) for nombre in REFINADOS[1:]}

despues = huellas_ajenas(REFINADOS if REFINAR else PREFIJOS)
if antes != despues:
    raise RuntimeError("Cambió geometría, UV, materiales o matrices ajenas a las cabinas")
fijas = [o for o in COLECCION.objects if o.type == "MESH"
         and o.name.startswith(PREFIJOS) and not o.name.startswith("bano_puerta_")]
arboles_fijos = [(o.name, arbol(o)) for o in fijas]
choques = []
for nombre, datos in ejes.items():
    hoja = bpy.data.objects[nombre]
    eje = Vector(datos["mundial"])
    for paso in range(19):
        angulo = math.radians(90 * paso / 18)
        giro = Matrix.Translation(eje) @ Matrix.Rotation(angulo, 4, "Z")
        giro = giro @ Matrix.Translation(-eje)
        movil = arbol(hoja, giro)
        for fijo, bvh in arboles_fijos:
            pares = movil.overlap(bvh)
            if pares:
                choques.append({"hoja": nombre, "angulo": math.degrees(angulo), "fijo": fijo})

informe = {
    "ejes": ejes, "objetos_ajenos_identicos": len(antes), "barrido_19_angulos": choques,
    "geometria": {o.name: auditar(o) for o in COLECCION.objects
                  if o.type == "MESH" and o.name.startswith(PREFIJOS)},
    "radio_pasador": 0.004, "radio_barril": 0.009, "luz_axial": 0.002,
    "colision_hoja_conservada": [1.0, 1.9, 0.048],
    "refinado": {
        "vertices_mundiales_coincidentes_soldados": soldados,
        "auditoria_mundial_y_uv": {nombre: auditar_integracion(bpy.data.objects[nombre])
                                  for nombre in REFINADOS},
    },
}
(RAIZ / "reports/cabinas_reparadas.json").write_text(json.dumps(informe, indent=2),
                                                    encoding="utf-8")
print(json.dumps(informe, indent=2))
if choques:
    raise RuntimeError("El barrido toca piezas fijas; revisar informe antes de guardar")
nombre_copia = "cabinas-refinadas.blend" if REFINAR else "cabinas-reparadas.blend"
destino = FUENTE if "--aplicar" in sys.argv else RAIZ / "reports" / nombre_copia
bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
