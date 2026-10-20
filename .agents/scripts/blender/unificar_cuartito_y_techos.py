"""Unificar el cuerpo fijo y sustituir las ondas geométricas por una normal CC0.

Edición de una sola aplicación sobre la sesión vigente: importar y llamar aplicar().
No abre archivos, no guarda el blend y no exporta. El integrador conserva esas decisiones.
La geometría anterior y sus huellas quedan en el reporte antes de empezar a modificarla.
"""

import hashlib
import json
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
REPORTE = RAIZ / "reports/cuartito-mejoras/unificacion-geometria.json"
MARCA = "cuartito_y_techos_unificados_v1"
CUERPO = "cuartito_cuerpo-col"
PAREDES = ("cuartito_pared_fondo-convcol", "cuartito_pared_norte-convcol",
           "cuartito_pared_sur-convcol")
RETIRADOS = (*PAREDES, "cuartito_techo-convcol", "cuartito_chapa")
DEPOSITO = "deposito_techo_chapa"
TEXTURAS = RAIZ / "assets/source/textures/warehouse/polyhaven/corrugated-iron-02/1K"
TEXTURAS_CUARTITO = RAIZ / "assets/source/textures/warehouse/final"
ESPESOR = .006
MATERIAL_CUBIERTA = "cuartito_cubierta_corrugada_cc0"
MATERIAL_DEPOSITO = "deposito_cubierta_corrugada_cc0"


def _datos(objeto):
    m = objeto.data
    return {
        "vertices": [tuple(v.co) for v in m.vertices],
        "aristas": [tuple(e.vertices) for e in m.edges],
        "caras": [tuple(p.vertices) for p in m.polygons],
        "suave": [p.use_smooth for p in m.polygons],
        "material_por_cara": [p.material_index for p in m.polygons],
        "materiales": [m.name if m else None for m in m.materials],
        "uv": {c.name: [tuple(v.uv) for v in c.data] for c in m.uv_layers},
        "matriz": [tuple(f) for f in objeto.matrix_world],
        "malla": m.name,
    }


def _huella(datos):
    return hashlib.sha256(json.dumps(datos, sort_keys=True).encode("utf-8")).hexdigest()


def _matriz(objeto):
    return [tuple(f) for f in objeto.matrix_world]


def _es_fijo_del_cuartito(objeto):
    return objeto.name.startswith("cuartito_") and any(
        texto in objeto.name for texto in
        ("marco", "revestimiento", "lampara", "luminaria", "tubo_soporte"))


def _parentar(objeto, cuerpo):
    """La inversa del padre conserva la base local sin descomponer otra vez sus giros."""
    if objeto.parent == cuerpo:
        return
    pose = objeto.matrix_world.copy()
    inversa = cuerpo.matrix_world.inverted() @ pose @ objeto.matrix_basis.inverted()
    objeto.parent = cuerpo
    objeto.matrix_parent_inverse = inversa


def _validar_y_cerrar(estado, reparentados, matrices_antes, tope_error_matriz):
    bpy.context.view_layer.update()
    antes = estado["huellas_antes"]
    datos_despues = {o.name: _datos(o) for o in bpy.data.objects if o.type == "MESH"}
    despues = {n: _huella(d) for n, d in datos_despues.items()}
    ajenos = set(antes) - set(RETIRADOS) - {DEPOSITO}
    deltas = {}
    for nombre in sorted(set(reparentados)):
        if nombre not in matrices_antes:
            continue
        actual = _matriz(bpy.data.objects[nombre])
        original = matrices_antes[nombre]
        delta = [[actual[i][j] - original[i][j] for j in range(4)] for i in range(4)]
        maximo = max(abs(v) for fila in delta for v in fila)
        deltas[nombre] = {"matriz_antes": original, "matriz_despues": actual,
                          "delta": delta, "maximo_absoluto": maximo}
        assert maximo <= tope_error_matriz, ("Cambió una pose mundial", nombre, maximo)
    alterados = []
    for nombre in sorted(ajenos):
        if despues.get(nombre) == antes[nombre]:
            continue
        if nombre not in reparentados or nombre not in matrices_antes:
            alterados.append(nombre)
            continue
        # Se autoriza el parentesco, nunca un cambio en geometría, UV o materiales.
        datos = dict(datos_despues[nombre])
        datos["matriz"] = matrices_antes[nombre]
        if _huella(datos) != antes[nombre]:
            alterados.append(nombre)
    assert not alterados, ("Cambios ajenos o geometría alterada", alterados)
    assert despues["almacen-col"] == antes["almacen-col"], "Cambió el piso o sus UV"
    estado.update({"estado": "aplicado_sin_guardar",
                   "reparentados_con_pose_mundial": sorted(set(reparentados)),
                   "deltas_de_matrices": deltas,
                   "tope_de_error_de_pose_autorizado": tope_error_matriz,
                   "objetos_ajenos_identicos": sum(antes[n] == despues[n] for n in ajenos),
                   "objetos_reparentados_con_geometria_identica": len(ajenos) - sum(
                       antes[n] == despues[n] for n in ajenos),
                   "huellas_despues": despues,
                   "estadisticas_despues": {n: _estadisticas(bpy.data.objects[n])
                                            for n in (CUERPO, DEPOSITO)}})
    bpy.context.scene[MARCA] = True
    REPORTE.write_text(json.dumps(estado, indent=2), encoding="utf-8")
    return estado


def finalizar_aplicacion_pendiente(matrices_antes, tope_error_matriz):
    """Completar sólo la validación de una edición aplicada; nunca repetir la geometría.

    Las matrices originales y el tope salen de una medición del integrador. Sustituirlas
    en el hash previo prueba que sólo cambió la representación de la pose del marco.
    """
    assert not bpy.context.scene.get(MARCA), "La aplicación ya está validada"
    assert CUERPO in bpy.data.objects and not any(n in bpy.data.objects for n in RETIRADOS)
    estado = json.loads(REPORTE.read_text(encoding="utf-8"))
    assert estado["estado"] == "antes", "El reporte no corresponde a una edición pendiente"
    originales = dict(estado.get("matrices_antes", {}))
    originales.update(matrices_antes)
    cuerpo = bpy.data.objects[CUERPO]
    reparentados = []
    for objeto in list(bpy.data.objects):
        if not _es_fijo_del_cuartito(objeto):
            continue
        if objeto.parent != cuerpo:
            originales.setdefault(objeto.name, _matriz(objeto))
            _parentar(objeto, cuerpo)
        reparentados.append(objeto.name)
    estado["cuartito"] = {"limites_finales": _limites(cuerpo)}
    estado["deposito"] = {"limites_finales": _limites(bpy.data.objects[DEPOSITO]),
                           "nombre_malla_conservado": bpy.data.objects[DEPOSITO].data.name}
    return _validar_y_cerrar(estado, reparentados, originales, tope_error_matriz)


def _estadisticas(objeto):
    objeto.data.calc_loop_triangles()
    return {"vertices": len(objeto.data.vertices), "caras": len(objeto.data.polygons),
            "triangulos": len(objeto.data.loop_triangles)}


def _limites(objeto):
    puntos = [objeto.matrix_world @ v.co for v in objeto.data.vertices]
    return tuple(tuple(f(p[i] for p in puntos) for i in range(3)) for f in (min, max))


def _material(nombre, metalizado, factor_rugosidad):
    assert nombre not in bpy.data.materials, "El material nuevo ya existe"
    assert nombre in (MATERIAL_CUBIERTA, MATERIAL_DEPOSITO)
    cuartito = nombre == MATERIAL_CUBIERTA
    rutas = {"Roughness": TEXTURAS / "corrugated_iron_02_rough_1k.jpg",
             "Normal": TEXTURAS / "corrugated_iron_02_nor_gl_1k.png"}
    if cuartito:
        # Los alias pertenecen a EDIFICIO: sólo este techo conserva relieve de 1024 px.
        rutas.update({"Base Color": TEXTURAS / "corrugated_iron_02_diff_1k.jpg",
                      "Roughness": TEXTURAS_CUARTITO / "cuartito_chapa_rough_1k.jpg",
                      "Normal": TEXTURAS_CUARTITO / "cuartito_chapa_normal_1k.png"})
    for ruta in rutas.values():
        assert ruta.is_file(), ruta
    m = bpy.data.materials.new(nombre)
    m.use_nodes = True
    m.node_tree.nodes.clear()
    nodos, enlaces = m.node_tree.nodes, m.node_tree.links
    salida = nodos.new("ShaderNodeOutputMaterial")
    pbr = nodos.new("ShaderNodeBsdfPrincipled")
    pbr.inputs["Metallic"].default_value = metalizado
    if not cuartito:
        # El tono intermedio conserva las ondas sin aclarar el techo frente a los laterales.
        pbr.inputs["Base Color"].default_value = (.16, .17, .18, 1)
    enlaces.new(pbr.outputs["BSDF"], salida.inputs["Surface"])
    for entrada, ruta in rutas.items():
        imagen = bpy.data.images.load(str(ruta), check_existing=True)
        imagen.colorspace_settings.name = "sRGB" if entrada == "Base Color" else "Non-Color"
        imagen.filepath = bpy.path.relpath(str(ruta), start=str(RAIZ / "assets/models"))
        textura = nodos.new("ShaderNodeTexImage")
        textura.image, textura.extension = imagen, "REPEAT"
        if entrada == "Normal":
            normal = nodos.new("ShaderNodeNormalMap")
            normal.inputs["Strength"].default_value = 1.35
            enlaces.new(textura.outputs["Color"], normal.inputs["Color"])
            enlaces.new(normal.outputs["Normal"], pbr.inputs["Normal"])
        elif entrada == "Roughness":
            rugosidad = nodos.new("ShaderNodeMath")
            rugosidad.name = "RugosidadDeLaChapa"
            rugosidad.operation = "MULTIPLY"
            rugosidad.inputs[1].default_value = factor_rugosidad
            enlaces.new(textura.outputs["Color"], rugosidad.inputs[0])
            enlaces.new(rugosidad.outputs[0], pbr.inputs[entrada])
        else:
            enlaces.new(textura.outputs["Color"], pbr.inputs[entrada])
    return m


def _uv_cubierta(normal, punto):
    """Los cantos necesitan su altura UV; la proyección XY los aplastaría a una línea."""
    dominante = max(range(3), key=lambda i: abs(normal[i]))
    if dominante == 0:
        return punto.y / (.3 * 28), punto.z / 2.7
    if dominante == 1:
        return punto.x / (.3 * 28), punto.z / 2.7
    return punto.y / (.3 * 28), punto.x / 2.7


def _uv_exterior(normal, punto):
    dominante = max(range(3), key=lambda i: abs(normal[i]))
    ejes = [i for i in range(3) if i != dominante]
    return punto[ejes[0]], punto[ejes[1]]


def _triangulos_uv_colapsados(malla):
    malla.calc_loop_triangles()
    capa = malla.uv_layers.active
    assert capa is not None, "La malla nueva no tiene UV activa"
    resultado = []
    for triangulo in malla.loop_triangles:
        a, b, c = (capa.data[i].uv for i in triangulo.loops)
        area_doble = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        if abs(area_doble) <= 1e-12:
            resultado.append(triangulo.polygon_index)
    return resultado


def reparar_uv_cantos_existentes():
    """Corregir las UV nuevas colapsadas sin reconstruir ni guardar las mallas aplicadas."""
    objetivos = (CUERPO, DEPOSITO)
    objetos = {o.name: _huella(_datos(o)) for o in bpy.data.objects if o.type == "MESH"}
    auditorias = {}
    for nombre in objetivos:
        objeto = bpy.data.objects[nombre]
        malla, esperado = objeto.data, _datos(objeto)
        capa = malla.uv_layers.active
        indices = _triangulos_uv_colapsados(malla)
        caras = sorted(set(indices))
        bucles = []
        for numero in caras:
            cara = malla.polygons[numero]
            material = malla.materials[cara.material_index].name
            assert material in (MATERIAL_CUBIERTA, MATERIAL_DEPOSITO, "paredes"), (
                "No modificar las UV interiores de bloques", nombre, numero, material)
            dominante = max(range(3), key=lambda i: abs(cara.normal[i]))
            if material in (MATERIAL_CUBIERTA, MATERIAL_DEPOSITO):
                assert dominante != 2, "Una cara grande de cubierta no debe reproyectarse"
            for indice in cara.loop_indices:
                punto = malla.vertices[malla.loops[indice].vertex_index].co
                capa.data[indice].uv = (_uv_cubierta(cara.normal, punto)
                                       if material in (MATERIAL_CUBIERTA, MATERIAL_DEPOSITO) else
                                       _uv_exterior(cara.normal, punto))
                esperado["uv"][capa.name][indice] = tuple(capa.data[indice].uv)
                bucles.append(indice)
        malla.update()
        assert _huella(_datos(objeto)) == _huella(esperado), (
            "Cambió algo fuera de los bucles UV autorizados", nombre)
        restantes = _triangulos_uv_colapsados(malla)
        assert not restantes, ("Quedan UV colapsadas en geometría nueva", nombre, restantes)
        auditorias[nombre] = {"triangulos_colapsados_antes": len(indices),
                              "triangulos_colapsados_despues": len(restantes),
                              "caras_corregidas": caras, "bucles_uv_modificados": bucles,
                              "geometria_materiales_matriz_y_uv_restantes_identicos": True}
    ajenos = set(objetos) - set(objetivos)
    assert all(_huella(_datos(bpy.data.objects[n])) == objetos[n] for n in ajenos)
    resultado = {"estado": "uv_corregidas_sin_guardar", "objetos": auditorias,
                 "objetos_ajenos_identicos": len(ajenos)}
    destino = RAIZ / "reports/cuartito-mejoras/reparacion-uv-cubiertas.json"
    destino.write_text(json.dumps(resultado, indent=2), encoding="utf-8")
    return resultado


def _afines_interiores():
    """Recuperar cada proyección original evita cambiar la escala de los bloques."""
    resultado = {}
    for nombre in PAREDES:
        objeto = bpy.data.objects[nombre]
        caras = [p for p in objeto.data.polygons if
                 objeto.data.materials[p.material_index].name == "deposito_revestimiento_bloques"]
        assert len(caras) == 1, (nombre, len(caras))
        cara = caras[0]
        eje = 1 if "fondo" in nombre else 0
        puntos = [objeto.matrix_world @ objeto.data.vertices[
            objeto.data.loops[i].vertex_index].co for i in cara.loop_indices]
        uvs = [objeto.data.uv_layers.active.data[i].uv.copy() for i in cara.loop_indices]
        fila = None
        for j in range(1, len(puntos)):
            for k in range(j + 1, len(puntos)):
                a = Vector((puntos[j][eje] - puntos[0][eje], puntos[j].z - puntos[0].z))
                b = Vector((puntos[k][eje] - puntos[0][eje], puntos[k].z - puntos[0].z))
                det = a.x * b.y - a.y * b.x
                if abs(det) < 1e-8:
                    continue
                du, dv = uvs[j] - uvs[0], uvs[k] - uvs[0]
                horizontal = (du * b.y - dv * a.y) / det
                vertical = (dv * a.x - du * b.x) / det
                origen = uvs[0] - horizontal * puntos[0][eje] - vertical * puntos[0].z
                fila = (eje, horizontal, vertical, origen)
                break
            if fila:
                break
        assert fila is not None, nombre
        resultado[nombre] = fila
    return resultado


def _malla(nombre, vertices, caras, materiales, indices, uv):
    malla = bpy.data.meshes.new(nombre)
    malla.from_pydata(vertices, [], caras)
    for material in materiales:
        malla.materials.append(material)
    for cara, indice in zip(malla.polygons, indices):
        cara.material_index = indice
    bm = bmesh.new()
    bm.from_mesh(malla)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-7)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    assert all(e.is_manifold for e in bm.edges), "Hay bordes abiertos o caras superpuestas"
    assert bm.calc_volume(signed=True) > 0, "El sólido quedó invertido"
    # Todas las celdas comparten sus vértices: una sola componente, sin paredes como islas.
    pendientes, visitados = [next(iter(bm.verts))], set()
    while pendientes:
        v = pendientes.pop()
        if v in visitados:
            continue
        visitados.add(v)
        pendientes.extend(e.other_vert(v) for e in v.link_edges)
    assert len(visitados) == len(bm.verts), "La cubierta quedó desconectada de las paredes"
    bm.to_mesh(malla)
    bm.free()
    capa = malla.uv_layers.new(name="UVMap")
    for cara in malla.polygons:
        cara.use_smooth = False
        for lazo in cara.loop_indices:
            p = malla.vertices[malla.loops[lazo].vertex_index].co
            capa.data[lazo].uv = uv(cara, p)
    malla.update()
    return malla


def _cuartito(material, afines):
    fondo, norte, sur = (bpy.data.objects[n] for n in PAREDES)
    f0, f1 = _limites(fondo)
    n0, n1 = _limites(norte)
    s0, s1 = _limites(sur)
    x0, x1, x2 = n0[0], f0[0], f1[0]
    y0, y1 = s1[1], n0[1]
    xs, ys = (x0, x1, x2), (s0[1], y0, y1, n1[1])
    z0 = f0[2]
    chapa = bpy.data.objects["cuartito_chapa"]
    puntos = [chapa.matrix_world @ v.co for v in chapa.data.vertices]
    extremos = []
    for x in (x0, x1):
        zs = [p.z for p in puntos if abs(p.x - x) < 1e-4]
        assert zs, x
        extremos.append((min(zs) + max(zs) - ESPESOR) / 2)
    pendiente = (extremos[1] - extremos[0]) / (x1 - x0)

    def altura(x):
        return extremos[0] + pendiente * (x - x0)

    ocupadas = {(i, j, k) for i in range(2) for j in range(3) for k in range(2)
                if k == 1 or i == 1 or j in (0, 2)}
    vertices, caras, indices = [], [], []
    lados = ((-1, 0, 0, (0, 4, 7, 3)), (1, 0, 0, (1, 2, 6, 5)),
             (0, -1, 0, (0, 1, 5, 4)), (0, 1, 0, (3, 7, 6, 2)),
             (0, 0, -1, (0, 3, 2, 1)), (0, 0, 1, (4, 5, 6, 7)))
    for i, j, k in sorted(ocupadas):
        base = len(vertices)
        esquinas = ((i, j, k), (i + 1, j, k), (i + 1, j + 1, k), (i, j + 1, k),
                    (i, j, k + 1), (i + 1, j, k + 1),
                    (i + 1, j + 1, k + 1), (i, j + 1, k + 1))
        for a, b, c in esquinas:
            z = z0 if c == 0 else altura(xs[a]) + (c - 1) * ESPESOR
            vertices.append((xs[a], ys[b], z))
        for di, dj, dk, orden in lados:
            if (i + di, j + dj, k + dk) in ocupadas:
                continue
            indice = 2 if k == 1 else 0
            if k == 0 and ((i == 1 and di == -1) or (j == 0 and dj == 1)
                           or (j == 2 and dj == -1)):
                indice = 1
            caras.append(tuple(base + a for a in orden))
            indices.append(indice)

    def uv(cara, p):
        if cara.material_index == 2:
            return _uv_cubierta(cara.normal, p)
        if cara.material_index == 1:
            clave = PAREDES[0] if cara.normal.x < -.9 else (
                PAREDES[1] if cara.normal.y < -.9 else PAREDES[2])
            eje, h, v, origen = afines[clave]
            return h * p[eje] + v * p.z + origen
        return _uv_exterior(cara.normal, p)

    malla = _malla(CUERPO, vertices, caras,
                   [bpy.data.materials["paredes"],
                    bpy.data.materials["deposito_revestimiento_bloques"], material], indices, uv)
    objeto = bpy.data.objects.new(CUERPO, malla)
    coleccion = fondo.users_collection[0]
    coleccion.objects.link(objeto)
    return objeto, {"x": list(xs), "y": list(ys), "piso_inferior": z0,
                    "altura_cubierta_en_x0": extremos[0], "pendiente": pendiente,
                    "espesor_cubierta": ESPESOR}


def _deposito(material):
    objeto = bpy.data.objects[DEPOSITO]
    original = objeto.data
    assert original.users == 1, "La malla del depósito está compartida por otro objeto"
    xs = sorted({round(v.co.x, 5) for v in original.vertices})
    assert len(xs) == 3, ("Se esperaban tres columnas del techo", xs)
    columnas = []
    for x in xs:
        puntos = [v.co for v in original.vertices if abs(v.co.x - x) < 1e-4]
        x_real = sum(p.x for p in puntos) / len(puntos)
        z = (min(p.z for p in puntos) + max(p.z for p in puntos) - ESPESOR) / 2
        columnas.append((x_real, min(p.y for p in puntos), max(p.y for p in puntos), z))
    vertices = [(x, y, z + capa * ESPESOR) for capa in (0, 1)
                for x, ya, yb, z in columnas for y in (ya, yb)]
    caras = []
    for i in range(2):
        a = i * 2
        caras += [(a, a + 1, a + 3, a + 2),
                  (a + 6, a + 8, a + 9, a + 7),
                  (a, a + 2, a + 8, a + 6),
                  (a + 1, a + 7, a + 9, a + 3)]
    caras += [(0, 6, 7, 1), (4, 5, 11, 10)]
    nuevo = _malla(original.name + "_temporal", vertices, caras, [material],
                   [0] * len(caras), lambda cara, p: _uv_cubierta(cara.normal, p))
    nombre_original = original.name
    objeto.data = nuevo
    if original.users == 0:
        bpy.data.meshes.remove(original)
    nuevo.name = nombre_original
    return {"columnas": columnas, "nombre_malla_conservado": nuevo.name}


def aplicar(tope_error_matriz=0.0):
    """Dejar evidencia de conservación y frenar una segunda aplicación accidental."""
    assert not bpy.context.scene.get(MARCA), "La unificación ya se aplicó"
    assert CUERPO not in bpy.data.objects
    assert all(n in bpy.data.objects for n in (*RETIRADOS, DEPOSITO, "almacen-col"))
    datos = {o.name: _datos(o) for o in bpy.data.objects if o.type == "MESH"}
    antes = {n: _huella(d) for n, d in datos.items()}
    matrices = {o.name: _matriz(o) for o in bpy.data.objects}
    estado = {"estado": "antes", "huellas_antes": antes,
              "matrices_antes": matrices,
              "datos_afectados_antes": {n: datos[n] for n in (*RETIRADOS, DEPOSITO)},
              "estadisticas_antes": {n: _estadisticas(bpy.data.objects[n])
                                      for n in (*RETIRADOS, DEPOSITO)}}
    REPORTE.parent.mkdir(parents=True, exist_ok=True)
    REPORTE.write_text(json.dumps(estado, indent=2), encoding="utf-8")
    afines = _afines_interiores()
    metal = _material(MATERIAL_CUBIERTA, .45, .2)
    cuerpo, medidas = _cuartito(metal, afines)
    estado["deposito"] = _deposito(_material(MATERIAL_DEPOSITO, .2, .85))
    reparentados = []
    for o in list(bpy.data.objects):
        if o == cuerpo or o.name in RETIRADOS or o.name == "puerta_limpieza-col":
            continue
        if _es_fijo_del_cuartito(o):
            _parentar(o, cuerpo)
            reparentados.append(o.name)
    for nombre in RETIRADOS:
        objeto = bpy.data.objects[nombre]
        for hijo in list(objeto.children):
            _parentar(hijo, cuerpo)
            reparentados.append(hijo.name)
        bpy.data.objects.remove(objeto, do_unlink=True)
    estado["cuartito"] = medidas
    return _validar_y_cerrar(estado, reparentados, matrices, tope_error_matriz)
