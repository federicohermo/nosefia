"""Sustituir el plafon local por chapa a dos aguas y estructura metalica.

La copia de revision se guarda en reports. Importar el modulo no abre ni guarda
archivos; aplicar() permite al integrador terminar geometria antes del horneado.
"""

import argparse
import hashlib
import json
import math
import sys
from collections import Counter
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
PREFIJO = "deposito_techo_"
X0, X1 = -6.803772926330566, 7.925535678863525
Y0, Y1 = 8.253290176391602, 14.466056823730469
ALERO, CUMBRERA = 4.872666358947754, 5.90
CENTRO = (X0 + X1) / 2
LIMITES_ORIGINALES = X0, X1, Y0, Y1


def _dimensiones_actuales():
    """Una regeneracion posterior conserva el ancho elegido para el deposito."""
    global X0, X1, Y0, Y1, CENTRO
    X0, X1, Y0, Y1 = LIMITES_ORIGINALES
    cerchas = [Y0 + .075, 10.38, 12.40, Y1 - .075]
    correas = [X0 + .10, -4.9, -2.6, (X0 + X1) / 2, 2.25, 4.0, 6.1, X1 - .10]
    if bpy.context.scene.get("deposito_proporciones_v1"):
        originales = X0, X1, Y0, Y1
        X0 += (X1 - X0) * .15
        Y1 += (Y1 - Y0) * .15
        cerchas = [Y0 + .075, Y0 + (10.38 - Y0) * 1.15,
                   Y0 + (12.40 - Y0) * 1.15, Y1 - .075]
        correas = [originales[1] + (x - originales[1]) * .85 for x in correas]
    CENTRO = (X0 + X1) / 2
    return cerchas, correas


def _huella(objeto):
    malla = objeto.data
    datos = ([tuple(v.co) for v in malla.vertices],
             [tuple(p.vertices) for p in malla.polygons],
             [[c.name, [tuple(l.uv) for l in c.data]] for c in malla.uv_layers],
             [m.name if m else None for m in malla.materials],
             [p.material_index for p in malla.polygons],
             [tuple(f) for f in objeto.matrix_world])
    return hashlib.sha256(json.dumps(datos).encode()).hexdigest()


def _caras(objeto, excluir=()):
    """Comparar por coordenadas permite ignorar la renumeracion tras borrar caras."""
    datos = []
    for p in objeto.data.polygons:
        if p.index in excluir:
            continue
        datos.append(json.dumps((
            [tuple(objeto.data.vertices[i].co) for i in p.vertices],
            p.material_index, p.use_smooth,
            [[c.name, [tuple(c.data[i].uv) for i in p.loop_indices]]
             for c in objeto.data.uv_layers],
        )))
    return Counter(datos)


def _borrar_caras(objeto, indices):
    antes = _caras(objeto, indices)
    bm = bmesh.new()
    bm.from_mesh(objeto.data)
    bm.faces.ensure_lookup_table()
    seleccion = [bm.faces[i] for i in indices]
    bmesh.ops.delete(bm, geom=seleccion, context="FACES")
    bm.to_mesh(objeto.data)
    bm.free()
    objeto.data.update()
    despues = _caras(objeto)
    assert antes == despues, f"Cambios en caras ajenas de {objeto.name}"
    return {"objeto": objeto.name, "caras_eliminadas": indices,
            "caras_ajenas_conservadas": sum(antes.values()),
            "geometria_uv_material_smooth_ajenos_identicos": True}


def _retirar_plafon():
    edificio = bpy.data.objects["almacen-col"]
    indices = []
    for p in edificio.data.polygons:
        if edificio.data.materials[p.material_index].name != "TECHO | Placa acustica modulada":
            continue
        puntos = [edificio.matrix_world @ edificio.data.vertices[i].co for i in p.vertices]
        if not all(abs(v.z - ALERO) < .002 for v in puntos):
            continue
        if all(X0 - .002 <= v.x <= X1 + .002 and Y0 - .002 <= v.y <= Y1 + .002
               for v in puntos):
            indices.append(p.index)
    reportes = [_borrar_caras(edificio, indices)]
    perfiles = bpy.data.objects.get("Cielorraso perfiles y paneles")
    if perfiles:
        indices = []
        for p in perfiles.data.polygons:
            puntos = [perfiles.matrix_world @ perfiles.data.vertices[i].co for i in p.vertices]
            if all(X0 - .002 <= v.x <= X1 + .002 and Y0 - .002 <= v.y <= Y1 + .002
                   and ALERO - .05 <= v.z <= ALERO + .002 for v in puntos):
                indices.append(p.index)
        reportes.append(_borrar_caras(perfiles, indices))
    return reportes


def _material(nombre, color, metal, rugosidad):
    material = bpy.data.materials.get(nombre) or bpy.data.materials.new(nombre)
    material.use_nodes = True
    material.diffuse_color = (*color, 1)
    material.node_tree.nodes.clear()
    salida = material.node_tree.nodes.new("ShaderNodeOutputMaterial")
    pbr = material.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    pbr.inputs["Base Color"].default_value = (*color, 1)
    pbr.inputs["Metallic"].default_value = metal
    pbr.inputs["Roughness"].default_value = rugosidad
    material.node_tree.links.new(pbr.outputs["BSDF"], salida.inputs["Surface"])
    return material


def _malla(nombre, vertices, caras, material, coleccion, padre):
    malla = bpy.data.meshes.new(nombre)
    malla.from_pydata(vertices, [], caras)
    malla.materials.append(material)
    bm = bmesh.new()
    bm.from_mesh(malla)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(malla)
    bm.free()
    objeto = bpy.data.objects.new(nombre, malla)
    coleccion.objects.link(objeto)
    objeto.parent = padre
    bpy.ops.object.select_all(action="DESELECT")
    objeto.select_set(True)
    bpy.context.view_layer.objects.active = objeto
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=.015)
    bpy.ops.object.mode_set(mode="OBJECT")
    return objeto


def _altura(x):
    return CUMBRERA - abs(x - CENTRO) * (CUMBRERA - ALERO) / ((X1 - X0) / 2)


def _chapa(material, coleccion, padre):
    """El acanalado y los 6 mm de espesor viajan como geometria al glTF."""
    ondas, pasos = 26, 6
    filas = ondas * pasos + 1
    vertices = []
    for capa in (0, 1):
        for x in (X0, CENTRO, X1):
            for j in range(filas):
                y = Y0 + (Y1 - Y0) * j / (filas - 1)
                onda = .015 * math.sin(math.tau * j / pasos)
                vertices.append((x, y, _altura(x) + onda + capa * .006))
    caras = []
    superior = filas * 3
    for columna in range(2):
        for j in range(filas - 1):
            a = columna * filas + j
            b = a + filas
            caras.append((a, a + 1, b + 1, b))
            caras.append((a + superior, b + superior, b + superior + 1, a + superior + 1))
    borde = list(range(filas))
    borde += [2 * filas - 1, 3 * filas - 1]
    borde += list(range(3 * filas - 2, 2 * filas - 1, -1))
    borde += [filas]
    for j, a in enumerate(borde):
        b = borde[(j + 1) % len(borde)]
        caras.append((a, b, b + superior, a + superior))
    return _malla(PREFIJO + "chapa", vertices, caras, material, coleccion, padre)


def _viga(nombre, inicio, fin, ancho, alto, material, coleccion, padre):
    direccion = Vector(fin) - Vector(inicio)
    largo = direccion.length
    # Vigas de seccion rectangular con ejes locales, UV y espesor reales.
    x, y, z = ancho / 2, alto / 2, largo / 2
    vertices = [(-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z),
                (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z)]
    caras = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    objeto = _malla(PREFIJO + nombre, vertices, caras, material, coleccion, padre)
    objeto.location = (Vector(inicio) + Vector(fin)) / 2
    objeto.rotation_euler = direccion.to_track_quat("Z", "Y").to_euler()
    return objeto


def _cierre(y, nombre, material, coleccion, padre):
    # El triangulo sella el espacio sobre los muros originales sin moverlos.
    puntos = [(X0, y, ALERO), (X1, y, ALERO), (CENTRO, y, CUMBRERA)]
    vertices = [(x, yy + d, z) for d in (-.008, .008) for x, yy, z in puntos]
    caras = [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (2, 0, 3, 5)]
    return _malla(PREFIJO + nombre, vertices, caras, material, coleccion, padre)


def aplicar():
    """Editar solo el plafon local y crear objetos bajo un padre propio."""
    posiciones_cerchas, posiciones_correas = _dimensiones_actuales()
    afectados = {"almacen-col", "Cielorraso perfiles y paneles"}
    ajenos = {o.name: _huella(o) for o in bpy.data.objects
             if o.type == "MESH" and o.name not in afectados and not o.name.startswith(PREFIJO)}
    for objeto in list(bpy.data.objects):
        if objeto.name.startswith(PREFIJO):
            bpy.data.objects.remove(objeto, do_unlink=True)
    for malla in list(bpy.data.meshes):
        if malla.name.startswith(PREFIJO) and malla.users == 0:
            bpy.data.meshes.remove(malla)
    conservacion = _retirar_plafon()
    coleccion = bpy.data.collections.get("Deposito techo")
    if coleccion is None:
        coleccion = bpy.data.collections.new("Deposito techo")
        bpy.context.scene.collection.children.link(coleccion)
    padre = bpy.data.objects.new(PREFIJO + "industrial", None)
    coleccion.objects.link(padre)
    chapa = _material(PREFIJO + "galvanizado", (.235, .25, .265), .55, .72)
    acero = _material(PREFIJO + "acero", (.045, .057, .062), .40, .65)
    _chapa(chapa, coleccion, padre)
    _cierre(Y0 - .008, "cierre_entrada", chapa, coleccion, padre)
    _cierre(Y1 + .008, "cierre_fondo", chapa, coleccion, padre)
    for numero, y in enumerate(posiciones_cerchas, 1):
        base = 4.70
        pref = f"cercha_{numero:02d}_"
        _viga(pref + "tirante", (X0, y, base), (X1, y, base),
              .105, .14, acero, coleccion, padre)
        for lado, xa, xb in (("izq", X0, CENTRO), ("der", CENTRO, X1)):
            _viga(pref + lado, (xa, y, _altura(xa) - .15),
                  (xb, y, _altura(xb) - .15), .11, .14, acero, coleccion, padre)
            for tramo in range(3):
                a = xa + (xb - xa) * tramo / 3
                b = xa + (xb - xa) * (tramo + 1) / 3
                if lado == "izq":
                    inicio, fin = (a, y, base + .02), (b, y, _altura(b) - .17)
                else:
                    inicio, fin = (a, y, _altura(a) - .17), (b, y, base + .02)
                _viga(pref + lado + f"_diagonal_{tramo}", inicio, fin,
                      .055, .055, acero, coleccion, padre)
    # Las correas sostienen la chapa y los anclajes de las luminarias.
    for numero, x in enumerate(posiciones_correas):
        z = _altura(x) - .07
        _viga(f"correa_{numero:02d}", (x, Y0, z), (x, Y1, z),
              .075, .10, acero, coleccion, padre)
    bpy.context.view_layer.update()
    assert all(_huella(bpy.data.objects[n]) == h for n, h in ajenos.items())
    anclajes = []
    for x, y in ((-2.5, 12.0), (1.7, 12.0), (5.9, 12.0)):
        # Los reflectores se reharan despues: ignorar sus propios cables.
        propios = [o for o in bpy.data.objects if o.name.startswith("deposito_lampara_")]
        visibles = [(o, o.hide_get()) for o in propios]
        for o, _ in visibles:
            o.hide_set(True)
        bpy.context.view_layer.update()
        acierto, punto, normal, indice, obj, _ = bpy.context.scene.ray_cast(
            bpy.context.evaluated_depsgraph_get(), Vector((x, y, 3)), Vector((0, 0, 1)),
            distance=6)
        for o, estado in visibles:
            o.hide_set(estado)
        bpy.context.view_layer.update()
        assert acierto and obj.name.startswith(PREFIJO), "Falta apoyo visible para el reflector"
        anclajes.append({"xy": [x, y], "z": punto.z, "objeto": obj.name})
    return {"alero": ALERO, "cumbrera": CUMBRERA, "limites_xy": [[X0, Y0], [X1, Y1]],
            "paso_acanalado": (Y1 - Y0) / 26, "espesor_chapa": .006,
            "conservacion": conservacion, "objetos_ajenos_identicos": len(ajenos),
            "anclajes_reflectores": anclajes,
            "objetos_nuevos": [o.name for o in coleccion.objects]}


def main():
    sys.path.insert(0, str(RAIZ / ".claude/scripts"))
    from lib.consola import configurar

    configurar()
    argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    parser.add_argument("--destino", type=Path, default=RAIZ / "reports/techo-deposito.blend")
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    resultado = aplicar()
    reporte = RAIZ / "reports/techo-conservacion.json"
    reporte.parent.mkdir(parents=True, exist_ok=True)
    reporte.write_text(json.dumps(resultado, indent=2), encoding="utf-8")
    destino = FUENTE if opciones.aplicar else opciones.destino
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
    print(json.dumps(resultado, indent=2))


if __name__ == "__main__":
    main()
