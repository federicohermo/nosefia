"""Cerrar sólo los seis escalones exteriores pendientes de los marcos actuales.

planificar() no modifica la sesión. aplicar(plan) comprueba la huella de ese plan antes
de editar copias de las mallas. No abre archivos, no guarda el blend y no exporta.
Las dos esquinas superiores que corrigió el artista se reconocen y conservan exactas.
"""

from collections import Counter
import hashlib
import json
from pathlib import Path

import bmesh
import bpy

RAIZ = Path(__file__).resolve().parents[3]
REPORTE = RAIZ / "reports/cuartito-mejoras/encuentros-ventanales.json"
OBJETOS = ("local_marco_frente-col", "local_marco_ventanal-col")
MARCA = "encuentros_ventanales_terminados_v1"
TOLERANCIA = 1e-5
MEDIO_PERFIL = .025


def _datos(objeto):
    malla = objeto.data
    return {"v": [tuple(v.co) for v in malla.vertices],
            "e": [tuple(e.vertices) for e in malla.edges],
            "f": [tuple(c.vertices) for c in malla.polygons],
            "m": [c.material_index for c in malla.polygons],
            "suave": [c.use_smooth for c in malla.polygons],
            "mats": [m.name if m else None for m in malla.materials],
            "uv": {c.name: [tuple(l.uv) for l in c.data] for c in malla.uv_layers},
            "matriz": [tuple(f) for f in objeto.matrix_world],
            "malla": malla.name, "padre": objeto.parent.name if objeto.parent else None}


def _huella(datos):
    return hashlib.sha256(json.dumps(datos, sort_keys=True).encode("utf-8")).hexdigest()


def _plan_de(datos):
    """Inferir los escalones de la malla vigente evita regenerar el diseño original."""
    plan = {}
    for nombre in OBJETOS:
        puntos = datos[nombre]["v"]
        eje = 0 if nombre == OBJETOS[0] else 1
        profundidad = 1 - eje
        extremos = min(p[eje] for p in puntos), max(p[eje] for p in puntos)
        alturas = min(p[2] for p in puntos), max(p[2] for p in puntos)
        esquinas = []
        for lado, extremo in zip(("inicio", "fin"), extremos):
            for nivel, altura in zip(("inferior", "superior"), alturas):
                cercanos = [i for i, p in enumerate(puntos)
                            if abs(p[eje] - extremo) < MEDIO_PERFIL + .001
                            and abs(p[2] - altura) < MEDIO_PERFIL + .001]
                etiqueta = lado + "_" + nivel
                if nombre == OBJETOS[0] and nivel == "superior":
                    assert len(cercanos) == 2, (nombre, etiqueta, cercanos)
                    assert all(abs(puntos[i][eje] - extremo) < TOLERANCIA
                               for i in cercanos)
                    esquinas.append({"esquina": etiqueta, "estado": "correccion_del_artista",
                                     "vertices": cercanos,
                                     "coordenadas_exactas": [puntos[i] for i in cercanos]})
                    continue
                assert len(cercanos) == 6, (nombre, etiqueta, cercanos)
                capas = {}
                for i in cercanos:
                    capas.setdefault(puntos[i][profundidad], []).append(i)
                assert len(capas) == 2 and all(len(v) == 3 for v in capas.values())
                grupos = []
                for capa, indices in sorted(capas.items()):
                    destino = list(puntos[indices[0]])
                    destino[eje], destino[2] = extremo, altura
                    # El escalón es una L de 25 mm, no un bisel que deba conservarse.
                    distancias = sorted((abs(puntos[i][eje] - extremo),
                                         abs(puntos[i][2] - altura)) for i in indices)
                    esperadas = ((0, MEDIO_PERFIL), (MEDIO_PERFIL, 0),
                                 (MEDIO_PERFIL, MEDIO_PERFIL))
                    assert all(abs(a - b) < TOLERANCIA for par, esperado in
                               zip(distancias, esperadas) for a, b in zip(par, esperado))
                    grupos.append({"vertices": indices, "destino": destino,
                                   "antes": [puntos[i] for i in indices]})
                esquinas.append({"esquina": etiqueta, "estado": "escalon_pendiente",
                                 "grupos": grupos})
        plan[nombre] = esquinas
    return plan


def planificar():
    assert not bpy.context.scene.get(MARCA), "Los encuentros ya están terminados"
    datos = {n: _datos(bpy.data.objects[n]) for n in OBJETOS}
    plan = {"estado": "planificado_sin_editar", "esquinas": _plan_de(datos),
            "huellas_objetivos": {n: _huella(d) for n, d in datos.items()}}
    REPORTE.parent.mkdir(parents=True, exist_ok=True)
    REPORTE.write_text(json.dumps(plan, indent=2), encoding="utf-8")
    return plan


def _firma_cara(malla, cara):
    bucles = []
    for indice in cara.loop_indices:
        lazo = malla.loops[indice]
        bucles.append((tuple(malla.vertices[lazo.vertex_index].co),
                       tuple((c.name, tuple(c.data[indice].uv)) for c in malla.uv_layers)))
    rotaciones = [bucles[i:] + bucles[:i] for i in range(len(bucles))]
    return json.dumps((min(rotaciones), cara.material_index, cara.use_smooth))


def _auditar_solido(malla):
    bm = bmesh.new()
    bm.from_mesh(malla)
    assert all(e.is_manifold for e in bm.edges), "Quedó una arista abierta o superpuesta"
    assert not any(len(c.verts) < 3 or c.calc_area() < 1e-10 for c in bm.faces)
    euler = len(bm.verts) - len(bm.edges) + len(bm.faces)
    volumen = abs(bm.calc_volume(signed=True))
    bm.free()
    return {"vertices": len(malla.vertices), "caras": len(malla.polygons),
            "euler": euler, "volumen": volumen}


def _editar_copia(objeto, esquinas):
    original = objeto.data
    assert not original.has_custom_normals, "Hay normales artísticas que requieren otra edición"
    assert original.users == 1, "Otro objeto comparte esta malla"
    grupos = [g for e in esquinas if e["estado"] == "escalon_pendiente"
              for g in e["grupos"]]
    afectados = {i for grupo in grupos for i in grupo["vertices"]}
    protegidas = Counter(_firma_cara(original, cara) for cara in original.polygons
                         if not afectados.intersection(cara.vertices))
    posiciones_ajenas = Counter(tuple(v.co) for v in original.vertices if v.index not in afectados)
    nuevo = original.copy()
    bm = bmesh.new()
    bm.from_mesh(nuevo)
    bm.verts.ensure_lookup_table()
    grupos_bm = []
    for grupo in grupos:
        vertices = [bm.verts[i] for i in grupo["vertices"]]
        for v in vertices:
            v.co = grupo["destino"]
        grupos_bm.append(vertices)
    for vertices in grupos_bm:
        bmesh.ops.remove_doubles(bm, verts=vertices, dist=1e-6)
    bm.normal_update()
    bm.to_mesh(nuevo)
    bm.free()
    nuevo.update()
    finales = Counter(_firma_cara(nuevo, cara) for cara in nuevo.polygons)
    assert all(finales[firma] >= cantidad for firma, cantidad in protegidas.items()), (
        "Cambió una cara o UV fuera de las esquinas", objeto.name)
    posiciones_finales = Counter(tuple(v.co) for v in nuevo.vertices)
    assert all(posiciones_finales[p] >= cantidad for p, cantidad in posiciones_ajenas.items())
    antes, despues = _auditar_solido(original), _auditar_solido(nuevo)
    assert antes["euler"] == despues["euler"], "Cambió la cantidad de huecos del marco"
    assert despues["vertices"] == antes["vertices"] - 2 * len(grupos)
    assert despues["caras"] == antes["caras"] - len(grupos)
    assert despues["volumen"] > antes["volumen"], "El cierre debería agregar sólo las esquinas"
    for esquina in esquinas:
        if esquina["estado"] != "correccion_del_artista":
            continue
        assert all(tuple(p) in posiciones_finales for p in esquina["coordenadas_exactas"])
    return nuevo, {"antes": antes, "despues": despues,
                   "caras_con_uv_protegidas": sum(protegidas.values()),
                   "vertices_ajenos_exactos": sum(posiciones_ajenas.values())}


def aplicar(plan=None):
    assert not bpy.context.scene.get(MARCA), "Los encuentros ya están terminados"
    plan = plan if plan is not None else planificar()
    assert plan["estado"] == "planificado_sin_editar"
    todos = {o.name: _huella(_datos(o)) for o in bpy.data.objects if o.type == "MESH"}
    assert all(todos[n] == plan["huellas_objetivos"][n] for n in OBJETOS), (
        "Los marcos cambiaron después de planificar; volver a inspeccionarlos")
    nuevos, auditorias = {}, {}
    for nombre in OBJETOS:
        nuevos[nombre], auditorias[nombre] = _editar_copia(
            bpy.data.objects[nombre], plan["esquinas"][nombre])
    # Las dos copias ya pasaron auditoría antes de reemplazar datos de la sesión visible.
    for nombre, nuevo in nuevos.items():
        objeto = bpy.data.objects[nombre]
        original, nombre_malla = objeto.data, objeto.data.name
        objeto.data = nuevo
        bpy.data.meshes.remove(original)
        nuevo.name = nombre_malla
    bpy.context.view_layer.update()
    ajenos = {n: h for n, h in todos.items() if n not in OBJETOS}
    assert all(_huella(_datos(bpy.data.objects[n])) == h for n, h in ajenos.items())
    plan.update({"estado": "aplicado_sin_guardar", "auditorias": auditorias,
                 "objetos_ajenos_identicos": len(ajenos)})
    bpy.context.scene[MARCA] = True
    REPORTE.write_text(json.dumps(plan, indent=2), encoding="utf-8")
    return plan
