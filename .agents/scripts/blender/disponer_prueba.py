"""Mide el mapa de prueba sin guardar el blend ni regenerar el mapa completo."""

import argparse
import re
import sys
from collections import Counter
from pathlib import Path
from itertools import combinations

import bmesh
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import acomodar
import disponer
from lib.consola import configurar
from lib.apoyos_del_modelo import mallas_del_glb
from lib.gondola import (
    escribir_disposicion, fondo_del_estante, nombre_en_godot, punto_en_godot, separar_filas,
)
from lib.reparto import PRODUCTOS, partes
from lib.reparto_de_prueba import (
    ESTANTES_DE_PRUEBA, RETIROS_POR_ESTANTE_DE_PRUEBA, bandas_del_nivel, bases_del_contenido,
    validar_identidades_de_prueba,
    validar_reparto_de_prueba,
)

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / "src/escenas/puestos/disposicion_de_prueba.tres"


def malla_evaluada(objeto):
    evaluado = objeto.evaluated_get(bpy.context.evaluated_depsgraph_get())
    malla = evaluado.to_mesh()
    bm = bmesh.new()
    try:
        bm.from_mesh(malla)
    finally:
        evaluado.to_mesh_clear()
    return bm


def comprobar_modelo():
    nombres = [nombre_en_godot(n) for n in acomodar.MUEBLES.values()]
    glb = mallas_del_glb(
        (RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.glb").read_bytes(), nombres
    )
    for nombre, letra in zip(nombres, acomodar.MUEBLES):
        objeto = bpy.data.objects[acomodar.MUEBLES[letra]]
        evaluado = objeto.evaluated_get(bpy.context.evaluated_depsgraph_get())
        malla = evaluado.to_mesh()
        try:
            malla.calc_loop_triangles()
            puntos = [punto_en_godot(tuple(malla.vertices[i].co))
                      for t in malla.loop_triangles for i in t.vertices]
            fuente = Counter(tuple(round(v, 5) for v in p) for p in puntos)
            exportado = Counter(tuple(round(v, 5) for v in p)
                                for cara in glb[nombre] for p in cara)
            if fuente != exportado:
                raise ValueError(f"{nombre}: el apoyo evaluado difiere del GLB")
            print(f"{nombre}: {len(puntos) // 3} triángulos evaluados coinciden con el GLB")
        finally:
            evaluado.to_mesh_clear()


def medir(letra, envases):
    objeto = bpy.data.objects[acomodar.MUEBLES[letra]]
    bm = malla_evaluada(objeto)
    bm.transform(objeto.matrix_world)
    bm.faces.ensure_lookup_table()
    if letra not in ("A", "B"):
        chapas = []
        for isla in acomodar._islas(bm):
            cara = acomodar._cara_de_arriba(isla)
            if cara is None or acomodar._es_panel(isla, objeto):
                continue
            if all("Zocalo" in objeto.material_slots[c.material_index].material.name
                   for c in isla):
                continue
            if (letra in acomodar.HELADERAS
                    and cara.calc_center_median().z > acomodar.TECHO_DE_LA_HELADERA):
                continue
            chapas.append((cara.calc_center_median().z, isla, cara))
        if len(chapas) != 4:
            bm.free()
            raise ValueError(f"{letra}: se esperaban cuatro chapas")
        estantes = {}
        for nivel, (_, isla, cara) in enumerate(sorted(chapas, key=lambda c: c[0])):
            clave = f"{letra}.sur.{nivel}"
            estantes[clave] = acomodar.Estante(clave, isla, cara)
        return objeto, bm, estantes
    lado = bm.faces.layers.int.get("lado_de_estante")
    if lado is None:
        bm.free()
        raise ValueError(f"{letra}: faltan las chapas identificadas de la fuente")
    planos = {}
    for cara in bm.faces:
        if cara[lado] and cara.normal.z > 0.999 and cara.calc_area() > 0.1:
            planos.setdefault(round(cara.calc_center_median().z, 4), []).append(cara)
    if len(planos) != 4:
        bm.free()
        raise ValueError(f"{letra}: se esperaban cuatro planos de apoyo")
    estantes = {}
    for nivel, (_, caras) in enumerate(sorted(planos.items())):
        puntos = [v.co for c in caras for v in c.verts]

        def profundidad(cara):
            tandas = ESTANTES_DE_PRUEBA[f"{letra}.{cara}.{nivel}"]
            return fondo_del_estante(
                [envases[t.producto] for t in tandas], [t.cantidad_de_filas for t in tandas]
            )

        bandas = bandas_del_nivel(
            min(p.x for p in puntos), max(p.x for p in puntos),
            min(p.y for p in puntos), max(p.y for p in puntos),
            profundidad("norte"), profundidad("sur"),
        )
        z = caras[0].verts[0].co.z
        for cara, banda in bandas.items():
            clave = f"{letra}.{cara}.{nivel}"
            estante = acomodar.Estante.__new__(acomodar.Estante)
            estante.clave = clave
            estante.isla = caras
            estante.caras = {c.index for c in caras}
            estante.normal = Vector((0, 0, 1))
            estante.mira = acomodar.MIRA[cara]
            estante.v = -estante.mira
            estante.u = (-estante.mira).cross(Vector((0, 0, 1))).normalized()
            esquinas = [Vector((x, y, z))
                        for x in (banda.x0, banda.x1) for y in (banda.y0, banda.y1)]
            us = [p.dot(estante.u) for p in esquinas]
            vs = [p.dot(estante.v) for p in esquinas]
            estante.origen = estante.u * min(us) + estante.v * min(vs) + Vector((0, 0, z))
            estante.largo = max(us) - min(us)
            estante.fondo = max(vs) - min(vs)
            estantes[clave] = estante
    return objeto, bm, estantes


def generar():
    comprobar_modelo()
    texto_catalogo = (RAIZ / "src/dominio/almacen/catalogo.gd").read_text(encoding="utf-8")
    declaracion = re.search(
        r"const PRODUCTOS_DE_PRUEBA.*?=\s*\[(.*?)\]", texto_catalogo, re.S
    ).group(1)
    validar_identidades_de_prueba(re.findall(r"Producto\.Id\.(\w+)", declaracion))
    validar_reparto_de_prueba(ESTANTES_DE_PRUEBA)
    fuentes = {p.clave: disponer.en_godot(bpy.data.objects[p.objeto])[0] for p in PRODUCTOS}
    bases = bases_del_contenido(disponer.CONTENIDO.read_text(encoding="utf-8"))
    for producto, base in bases.items():
        delta = max(abs(base[i][j] - fuentes[producto][i][j]) for i in range(3) for j in range(3))
        print(f"{producto}: base horneada contra fuente, diferencia máxima {delta:.9f}")
        if delta > 0.000002:
            raise ValueError(f"{producto}: la base horneada difiere de la fuente actual")
    originales = {p.objeto for p in PRODUCTOS}
    for objeto in list(bpy.context.scene.objects):
        if "tanda" in objeto and objeto.name not in originales:
            bpy.data.objects.remove(objeto, do_unlink=True)
    acomodar.limpiar_guia()
    acomodar.preparar_unidades()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for p in PRODUCTOS:
        unidad = bpy.data.objects[p.objeto]
        unidad.data = bpy.data.meshes.new_from_object(unidad.evaluated_get(depsgraph))
        unidad.modifiers.clear()
    envases = {p.clave: acomodar.envase_de(p, bpy.data.objects[p.objeto]) for p in PRODUCTOS}
    resumen = {"tandas": 0, "unidades": 0, "choques": [], "cortas": [], "entradas": {}}
    for letra in sorted({partes(clave)[0] for clave in ESTANTES_DE_PRUEBA}):
        acomodar.acomodar_mueble(
            letra, envases, resumen, ESTANTES_DE_PRUEBA, lambda letra: medir(letra, envases),
            retiros_por_estante=RETIROS_POR_ESTANTE_DE_PRUEBA,
        )
    if resumen["choques"]:
        raise ValueError(f"No se publica un reparto con choques: {resumen['choques']}")
    bpy.context.view_layer.update()
    tandas = disponer.tandas_del_blend()
    comprobar_intersecciones(tandas)
    esperadas = {f"{e}/{i}" for e, ts in ESTANTES_DE_PRUEBA.items() for i in range(len(ts))}
    if tandas.keys() != esperadas:
        raise ValueError("El acomodador perdió o agregó tandas del mapa de prueba")
    principales = [[] for _ in PRODUCTOS]
    frontales = [0 for _ in PRODUCTOS]
    guias, productos_guias, frontales_guias = [], [], []
    indices = {p.clave: i for i, p in enumerate(PRODUCTOS)}
    for clave, copias in sorted(tandas.items()):
        producto = str(copias[0]["producto"])
        estante, columna = clave.split("/")
        prevista = ESTANTES_DE_PRUEBA[estante][int(columna)]
        if producto != prevista.producto or bool(copias[0]["fija"]) != prevista.fija:
            raise ValueError(
                f"{clave}: {producto}/{bool(copias[0]['fija'])} difiere de "
                f"{prevista.producto}/{prevista.fija}; {[c.name for c in copias]}"
            )
        crudo = PRODUCTOS[indices[producto]]
        frente_esperado = acomodar.MIRA[partes(estante)[1]]
        for copia in copias:
            real = (copia.matrix_world.to_3x3() @ Vector(crudo.frente)).normalized()
            if real.dot(frente_esperado) < 0.98:
                raise ValueError(f"{clave}: {copia.name} tiene el frente {tuple(real)}")
        orden, adelante = separar_filas([str(c["fila"]) for c in copias])
        if adelante <= 0:
            raise ValueError(f"{clave}: falta el frontal interactuable")
        bloque = disponer.bloque([copias[i] for i in orden], bases[producto], clave)
        indice = indices[producto]
        if prevista.fija:
            guias.append(bloque)
            productos_guias.append(indice)
            frontales_guias.append(adelante)
        else:
            principales[indice] = bloque
            frontales[indice] = adelante
    _, uid_del_script = disponer.uids(disponer.DISPOSICION.read_text(encoding="utf-8"))
    texto = escribir_disposicion(
        principales, guias, frontales, "uid://cu2p575prueba", uid_del_script,
        productos_guias, frontales_guias,
    )
    print(f"{len(tandas)} tandas, {resumen['unidades']} unidades, cero choques")
    return texto + "base_de_guias = 1\n"


def comprobar_intersecciones(tandas):
    cuerpos = []
    for copias in tandas.values():
        for copia in copias:
            puntos = [copia.matrix_world @ v.co for v in copia.data.vertices]
            limites = tuple((min(p[i] for p in puntos), max(p[i] for p in puntos))
                            for i in range(3))
            arbol = BVHTree.FromPolygons(puntos, [list(p.vertices) for p in copia.data.polygons])
            cuerpos.append((copia.name, limites, arbol))
    for a, b in combinations(cuerpos, 2):
        if all(min(a[1][i][1], b[1][i][1]) - max(a[1][i][0], b[1][i][0]) > 1e-6
               for i in range(3)) and a[2].overlap(b[2]):
            raise ValueError(f"Se intersecan {a[0]} y {b[0]}")
    print(f"{len(cuerpos)} unidades sin intersecciones entre sí")


def principal():
    configurar()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destino", type=Path, default=DESTINO)
    argumentos = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    texto = generar()
    argumentos.destino.write_text(texto, encoding="utf-8", newline="\n")
    print(f"Escrito {argumentos.destino}")


if __name__ == "__main__":
    principal()
