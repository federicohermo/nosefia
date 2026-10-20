"""El cuartito de limpieza detrás de la puerta del fondo del depósito.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/cuartito_de_limpieza.py -- [--aplicar]

Sin `--aplicar` deja el resultado en `reports/cuartito-de-limpieza.blend` para mirarlo. Con él
reescribe el `.blend` del repo. Se corre una sola vez sobre el modelo sin cuartito: la marca de la
escena lo frena si ya se aplicó, porque el hueco de la pared y la mudanza no se pueden repetir.

Hace cinco cosas, todas desde lo que ya trae el modelo:

1. Le da a `puerta_limpieza-col` la hoja de «Solo empleados», con un cartel que dice PRODUCTOS DE
   LIMPIEZA, y le copia el marco con la misma pose relativa. La pose de la hoja ya la puso el
   artista: es la de la otra puerta, girada.
2. Abre el hueco del marco en la pared del depósito, con sus jambas y el umbral.
3. Levanta el cuarto: piso, tres paredes, techo de chapa a la altura del cielorraso del baño y el
   revestimiento de bloques del lado de adentro de la pared del depósito. Piso y bloques siguen
   la UV del depósito, así el umbral no marca junta.
4. Muda la mopa, el balde, los bidones y las dos notas de limpieza del fondo del baño a la pared
   del fondo del cuartito, con la misma disposición.
5. Cuelga sobre las notas una luminaria tubular como la del tablero, más larga.

El cartel usa el atlas artístico de `assets/source/`, con el mismo estilo de las otras puertas.
Su procedencia acompaña la imagen; la receta del cuarto no vuelve a dibujar la tipografía.
"""

import argparse
import importlib.util
import json
import math
import shutil
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
CARPETA_DEL_CARTEL = RAIZ / "assets/source/textures/furniture/Puerta"
CARTEL = CARPETA_DEL_CARTEL / "puerta_productos_de_limpieza.png"
PREFIJO = "cuartito_"
MARCA = "cuartito_de_limpieza"
COLECCION = "Cuartito de limpieza"

HOJA = "puerta_limpieza-col"
MODELO_DE_HOJA = "puerta-col"
MODELO_DE_MARCO = "marco_puerta_deposito-col"
EDIFICIO = "almacen-col"
CIELORRASO_DEL_BANO = "bano_cielorraso-convcol"
MUDANZA = ("mopa-col", "balde-col", "bidón jabon01-col", "bidón jabon01-col.001",
           "bidón jabon01-col.002", "nota productos-col", "nota instrucciones-col")
NOTAS = ("nota productos-col", "nota instrucciones-col")

# Medidas del cuarto, en metros. El fondo deja la mopa y los bidones fuera del barrido de la
# hoja; el ancho deja entrar la fila del baño entera.
FONDO = 2.72
ANCHO = 3.0
ESPESOR = 0.15
LOSA = 0.2
CHAPA = 0.12
# El acanalado del techo del depósito: una onda de 1,5 cm cada 30 cm, en chapa de 6 mm.
PASO_DE_LA_ONDA = 0.297
ALTO_DE_LA_ONDA = 0.015
ESPESOR_DE_LA_CHAPA = 0.006
PASOS_POR_ONDA = 6
# Una sola caída, de la puerta a la pared del fondo: unos 5° en el fondo del cuarto.
CAIDA_DE_LA_CHAPA = 0.25
# Las dos notas de limpieza van juntas bajo la luminaria, con este hueco entre ellas.
HUECO_ENTRE_LAS_NOTAS = 0.12
# El revestimiento va apenas adentro de la cara exterior de la pared, para no pelear con ella.
SEPARACION_DEL_REVESTIMIENTO = 0.003
# La pared del fondo del baño queda a esta distancia detrás de las notas.
DETRAS_DE_LAS_NOTAS = 0.005


def _receta(nombre):
    ruta = Path(__file__).with_name(nombre + ".py")
    spec = importlib.util.spec_from_file_location(nombre, ruta)
    modulo = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(modulo)
    return modulo


def _caja_mundial(objeto):
    puntos = [objeto.matrix_world @ Vector(c) for c in objeto.bound_box]
    return (Vector([min(p[i] for p in puntos) for i in range(3)]),
            Vector([max(p[i] for p in puntos) for i in range(3)]))


def _material_del_cartel(imagen):
    base = bpy.data.materials["puerta_metal_solo_empleados"]
    material = bpy.data.materials.get("puerta_metal_productos_de_limpieza") or base.copy()
    material.name = "puerta_metal_productos_de_limpieza"
    for nodo in material.node_tree.nodes:
        if nodo.type == "TEX_IMAGE" and nodo.image and nodo.image.name.startswith(
                "puerta_solo_empleados"):
            nodo.image = imagen
    return material


def _puerta(material):
    hoja = bpy.data.objects[HOJA]
    modelo = bpy.data.objects[MODELO_DE_HOJA]
    datos = modelo.data.copy()
    datos.name = "puerta_limpieza_hoja"
    datos.materials.clear()
    datos.materials.append(material)
    for cara in datos.polygons:
        cara.material_index = 0
    viejo = hoja.data
    hoja.data = datos
    for ranura in hoja.material_slots:
        ranura.link = "DATA"
    if viejo.users == 0:
        bpy.data.meshes.remove(viejo)
    marco_modelo = bpy.data.objects[MODELO_DE_MARCO]
    relativo = modelo.matrix_world.inverted() @ marco_modelo.matrix_world
    marco = bpy.data.objects.new(PREFIJO + "marco_puerta", marco_modelo.data.copy())
    marco.matrix_world = hoja.matrix_world @ relativo
    return hoja, marco


def _ajuste_uv(caras, capa, ejes, matriz):
    """La UV de esas caras como función afín de dos ejes del mundo, por cuadrados mínimos."""
    filas, uvs = [], []
    for cara in caras:
        for lazo in cara.loops:
            punto = matriz @ lazo.vert.co
            filas.append([punto[ejes[0]], punto[ejes[1]], 1.0])
            uvs.append(tuple(lazo[capa].uv))
    solucion, *_ = np.linalg.lstsq(np.array(filas), np.array(uvs), rcond=None)
    return solucion


def _uv_desde(ajuste, punto, ejes):
    return tuple(np.array([punto[ejes[0]], punto[ejes[1]], 1.0]) @ ajuste)


def _densidad(ajuste):
    return float(np.linalg.norm(ajuste[0]))


def _hueco(edificio, marco):
    """Abre la pared del depósito con la silueta del marco y la cierra con jambas y umbral."""
    matriz = edificio.matrix_world
    inversa = matriz.inverted()
    minimo, maximo = _caja_mundial(marco)
    bm = bmesh.new()
    bm.from_mesh(edificio.data)
    capa = bm.loops.layers.uv.active
    materiales = [m.name for m in edificio.data.materials]

    def material(nombre):
        return materiales.index(nombre)

    def mundial(v):
        return matriz @ v.co

    piso = [c for c in bm.faces if c.material_index == material("deposito_concreto")
            and c.normal.z > 0.9]
    paredes = [c for c in bm.faces if abs(c.normal.x) > 0.9
               and min(mundial(v).z for v in c.verts) <= minimo.z + 0.01
               and max(mundial(v).z for v in c.verts) >= maximo.z
               and min(mundial(v).y for v in c.verts) < minimo.y
               and max(mundial(v).y for v in c.verts) > maximo.y
               and abs(sum(mundial(v).x for v in c.verts) / len(c.verts)
                       - (minimo.x + maximo.x) / 2) < 0.2]
    assert len(piso) == 1 and len(paredes) == 2, (len(piso), len(paredes))
    interior = min(paredes, key=lambda c: mundial(c.verts[0]).x)
    exterior = max(paredes, key=lambda c: mundial(c.verts[0]).x)
    x_adentro = mundial(interior.verts[0]).x
    x_afuera = mundial(exterior.verts[0]).x
    z_piso = mundial(piso[0].verts[0]).z
    ajuste_piso = _ajuste_uv(piso, capa, (0, 1), matriz)
    ajuste_bloques = _ajuste_uv([interior], capa, (1, 2), matriz)
    bloques = interior.material_index
    y0, y1, z1 = minimo.y, maximo.y, maximo.z
    for cara in (interior, exterior):
        geometria = [cara, *cara.edges, *cara.verts]
        for plano, normal in ((Vector((0, y0, 0)), Vector((0, 1, 0))),
                              (Vector((0, y1, 0)), Vector((0, 1, 0))),
                              (Vector((0, 0, z1)), Vector((0, 0, 1))),
                              (Vector((0, 0, z_piso)), Vector((0, 0, 1)))):
            local = inversa @ plano
            direccion = (inversa.to_3x3() @ normal).normalized()
            nueva = bmesh.ops.bisect_plane(bm, geom=geometria, plane_co=local,
                                           plane_no=direccion)
            geometria = [e for e in nueva["geom"] if isinstance(
                e, (bmesh.types.BMFace, bmesh.types.BMEdge, bmesh.types.BMVert))]
            geometria = [e for e in geometria if e.is_valid]
    tolerancia = 0.0005
    sobran = []
    for cara in bm.faces:
        centro = matriz @ cara.calc_center_median()
        if (abs(cara.normal.x) > 0.9 and x_adentro - tolerancia < centro.x
                < x_afuera + tolerancia and y0 < centro.y < y1 and z_piso < centro.z < z1):
            sobran.append(cara)
    assert len(sobran) == 2, len(sobran)
    bmesh.ops.delete(bm, geom=sobran, context="FACES_ONLY")
    bm.verts.ensure_lookup_table()

    def vertice(x, y, z):
        punto = Vector((x, y, z))
        cercano = min(bm.verts, key=lambda v: (mundial(v) - punto).length)
        assert (mundial(cercano) - punto).length < 0.002, punto
        return cercano

    esquinas = {(x, y, z): vertice(x, y, z) for x in (x_adentro, x_afuera)
                for y in (y0, y1) for z in (z_piso, z1)}
    jambas = (
        ((y0, z_piso), (y0, z1), Vector((0, 1, 0)), bloques, (0, 2)),
        ((y1, z_piso), (y1, z1), Vector((0, -1, 0)), bloques, (0, 2)),
        ((y0, z1), (y1, z1), Vector((0, 0, -1)), bloques, (0, 1)),
        ((y0, z_piso), (y1, z_piso), Vector((0, 0, 1)), material("deposito_concreto"), (0, 1)),
    )
    for (ya, za), (yb, zb), normal, indice, ejes in jambas:
        verts = [esquinas[(x_adentro, ya, za)], esquinas[(x_adentro, yb, zb)],
                 esquinas[(x_afuera, yb, zb)], esquinas[(x_afuera, ya, za)]]
        cara = bm.faces.new(verts)
        cara.normal_update()
        if (matriz.to_3x3() @ cara.normal).dot(normal) < 0:
            cara.normal_flip()
        cara.material_index = indice
        ajuste = ajuste_piso if indice != bloques else None
        for lazo in cara.loops:
            punto = mundial(lazo.vert)
            if ajuste is not None:
                lazo[capa].uv = _uv_desde(ajuste, punto, (0, 1))
            else:
                densidad = _densidad(ajuste_bloques)
                lazo[capa].uv = (punto[ejes[0]] * densidad, punto[ejes[1]] * densidad)
    bm.normal_update()
    bm.to_mesh(edificio.data)
    bm.free()
    edificio.data.update()
    return {"x_adentro": x_adentro, "x_afuera": x_afuera, "z_piso": z_piso,
            "y_hueco": (y0, y1), "z_hueco": z1, "ajuste_piso": ajuste_piso,
            "ajuste_bloques": ajuste_bloques}


def _caja(nombre, minimo, maximo, materiales, por_cara, coleccion):
    """Una caja con un material y una UV por cara. `por_cara` va de la normal a (indice, uv)."""
    malla = bpy.data.meshes.new(nombre)
    for material in materiales:
        malla.materials.append(material)
    bm = bmesh.new()
    capa = bm.loops.layers.uv.new("UVMap")
    x = (minimo.x, maximo.x)
    y = (minimo.y, maximo.y)
    z = (minimo.z, maximo.z)
    v = {(i, j, k): bm.verts.new((x[i], y[j], z[k]))
         for i in (0, 1) for j in (0, 1) for k in (0, 1)}
    lados = {
        (-1, 0, 0): [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)],
        (1, 0, 0): [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)],
        (0, -1, 0): [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)],
        (0, 1, 0): [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)],
        (0, 0, -1): [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)],
        (0, 0, 1): [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)],
    }
    for normal, indices in lados.items():
        cara = bm.faces.new([v[i] for i in indices])
        indice, uv = por_cara(normal)
        cara.material_index = indice
        for lazo in cara.loops:
            lazo[capa].uv = uv(lazo.vert.co)
    bm.normal_update()
    bm.to_mesh(malla)
    bm.free()
    objeto = bpy.data.objects.new(nombre, malla)
    coleccion.objects.link(objeto)
    return objeto


def _piso_en_el_edificio(pared, x1, y0, y1):
    """El piso del cuartito es una cara más del edificio, pegada al umbral.

    Como pieza aparte se horneaba en otra isla del lightmap, y la puerta marcaba una raya: el
    piso del depósito tiene texeles muy grandes. Unido al umbral, se despliega con él.
    """
    edificio = bpy.data.objects[EDIFICIO]
    matriz = edificio.matrix_world
    inversa = matriz.inverted()
    bm = bmesh.new()
    bm.from_mesh(edificio.data)
    capa = bm.loops.layers.uv.active
    x0, z = pared["x_afuera"], pared["z_piso"]

    def del_umbral(y):
        punto = Vector((x0, y, z))
        cercano = min(bm.verts, key=lambda v: (matriz @ v.co - punto).length)
        assert (matriz @ cercano.co - punto).length < 0.002, punto
        return cercano

    esquinas = [bm.verts.new(inversa @ Vector(p))
                for p in ((x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z))]
    hy0, hy1 = pared["y_hueco"]
    cara = bm.faces.new(esquinas + [del_umbral(hy1), del_umbral(hy0)])
    cara.normal_update()
    if (matriz.to_3x3() @ cara.normal).z < 0:
        cara.normal_flip()
    cara.material_index = [m.name for m in edificio.data.materials].index("deposito_concreto")
    for lazo in cara.loops:
        lazo[capa].uv = _uv_desde(pared["ajuste_piso"], matriz @ lazo.vert.co, (0, 1))
    bm.to_mesh(edificio.data)
    bm.free()
    edificio.data.update()


def _plana(ejes, densidad=1.0):
    return lambda punto: (punto[ejes[0]] * densidad, punto[ejes[1]] * densidad)


def _ejes_de(normal):
    return tuple(i for i in range(3) if normal[i] == 0)


def _cuarto(pared, coleccion):
    m = bpy.data.materials
    bloques = m["deposito_revestimiento_bloques"]
    afuera, chapa, techo = m["paredes"], m["deposito_techo_galvanizado"], m["techo afuera"]
    x0 = pared["x_afuera"]
    z0 = pared["z_piso"]
    alto = _caja_mundial(bpy.data.objects[CIELORRASO_DEL_BANO])[0].z
    hy0, hy1 = pared["y_hueco"]
    centro = (hy0 + hy1) / 2
    y0, y1 = centro - ANCHO / 2, centro + ANCHO / 2
    x1 = x0 + FONDO
    densidad = _densidad(pared["ajuste_bloques"])

    def exterior(normal):
        return 0, _plana(_ejes_de(normal))

    def con_interior(adentro, material_de_adentro, uv_de_adentro):
        def por_cara(normal):
            if normal == adentro:
                return 1, uv_de_adentro
            return exterior(normal)
        return por_cara

    piezas = []
    _piso_en_el_edificio(pared, x1, y0, y1)
    paredes = (
        ("pared_fondo", Vector((x1, y0 - ESPESOR, z0 - LOSA)),
         Vector((x1 + ESPESOR, y1 + ESPESOR, alto)), (-1, 0, 0)),
        ("pared_norte", Vector((x0, y1, z0 - LOSA)), Vector((x1, y1 + ESPESOR, alto)),
         (0, -1, 0)),
        ("pared_sur", Vector((x0, y0 - ESPESOR, z0 - LOSA)), Vector((x1, y0, alto)),
         (0, 1, 0)),
    )
    for nombre, minimo, maximo, adentro in paredes:
        ejes = _ejes_de(adentro)
        piezas.append(_caja(PREFIJO + nombre + "-convcol", minimo, maximo, [afuera, bloques],
                            con_interior(adentro, bloques, _plana(ejes, densidad)), coleccion))

    def por_cara_del_techo(normal):
        if normal == (0, 0, -1):
            return 1, _plana((0, 1))
        if normal == (0, 0, 1):
            return 2, _plana((0, 1), 0.5)
        return exterior(normal)

    piezas.append(_caja(
        PREFIJO + "techo-convcol", Vector((x0, y0 - ESPESOR, alto)),
        Vector((x1 + ESPESOR, y1 + ESPESOR, alto + CHAPA)), [afuera, chapa, techo],
        por_cara_del_techo, coleccion))
    # Los bloques del lado de adentro de la pared del depósito, con el hueco del marco.
    x = x0 + SEPARACION_DEL_REVESTIMIENTO
    zh = pared["z_hueco"]
    franjas = ((y0, hy0, z0, alto), (hy1, y1, z0, alto), (hy0, hy1, zh, alto))
    vertices, caras = [], []
    for ya, yb, za, zb in franjas:
        base = len(vertices)
        vertices += [(x, ya, za), (x, yb, za), (x, yb, zb), (x, ya, zb)]
        caras.append((base, base + 1, base + 2, base + 3))
    malla = bpy.data.meshes.new(PREFIJO + "revestimiento")
    malla.from_pydata(vertices, [], caras)
    malla.materials.append(bloques)
    capa = malla.uv_layers.new(name="UVMap")
    for lazo in malla.loops:
        punto = malla.vertices[lazo.vertex_index].co
        capa.data[lazo.index].uv = (punto.y * densidad, punto.z * densidad)
    for cara in malla.polygons:
        if cara.normal.x < 0:
            cara.flip()
    malla.update()
    revestimiento = bpy.data.objects.new(PREFIJO + "revestimiento", malla)
    coleccion.objects.link(revestimiento)
    piezas.append(revestimiento)
    herramientas = _receta("lamparas_del_deposito")
    metal = herramientas._material(PREFIJO + "chapa_metal", (.62, .64, .67), .8, .5)
    piezas.append(_chapa(x0, x1, y0, y1, alto, metal, coleccion))
    return piezas, {"x": (x0, x1), "y": (y0, y1), "z": (z0, alto)}


def _chapa(x0, x1, y0, y1, alto, material, coleccion):
    """La chapa acanalada bajo el techo, como la del depósito, con una caída hacia el fondo."""
    ondas = max(1, round((y1 - y0) / PASO_DE_LA_ONDA))
    filas = ondas * PASOS_POR_ONDA + 1
    base = alto - ALTO_DE_LA_ONDA - ESPESOR_DE_LA_CHAPA - 0.001
    vertices = []
    for capa in (0, 1):
        for x in (x0, x1):
            for j in range(filas):
                y = y0 + (y1 - y0) * j / (filas - 1)
                onda = ALTO_DE_LA_ONDA * math.sin(math.tau * j / PASOS_POR_ONDA)
                caida = CAIDA_DE_LA_CHAPA * (x - x0) / (x1 - x0)
                vertices.append((x, y, base - caida + onda + capa * ESPESOR_DE_LA_CHAPA))
    superior = 2 * filas
    caras = []
    for j in range(filas - 1):
        a, b = j, filas + j
        caras.append((a, b, b + 1, a + 1))
        caras.append((a + superior, a + superior + 1, b + superior + 1, b + superior))
    borde = list(range(filas)) + list(range(2 * filas - 1, filas - 1, -1))
    for j, a in enumerate(borde):
        b = borde[(j + 1) % len(borde)]
        caras.append((a, b, b + superior, a + superior))
    malla = bpy.data.meshes.new(PREFIJO + "chapa")
    malla.from_pydata(vertices, [], caras)
    malla.materials.append(material)
    bm = bmesh.new()
    bm.from_mesh(malla)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    capa_uv = bm.loops.layers.uv.new("UVMap")
    for cara in bm.faces:
        for lazo in cara.loops:
            lazo[capa_uv].uv = (lazo.vert.co.x, lazo.vert.co.y)
    bm.to_mesh(malla)
    bm.free()
    for cara in malla.polygons:
        cara.use_smooth = abs(cara.normal.z) > 0.5
    objeto = bpy.data.objects.new(PREFIJO + "chapa", malla)
    coleccion.objects.link(objeto)
    return objeto


def _mudar(cuarto):
    """Gira la fila del fondo del baño y la apoya en la pared del fondo del cuartito."""
    objetos = [bpy.data.objects[n] for n in MUDANZA]
    cajas = [_caja_mundial(o) for o in objetos]
    pared_del_bano = max(_caja_mundial(bpy.data.objects[n])[1].y for n in NOTAS)
    centro_x = (min(c[0].x for c in cajas) + max(c[1].x for c in cajas)) / 2
    x0, x1 = cuarto["x"]
    y0, y1 = cuarto["y"]
    giro = Matrix.Rotation(-math.pi / 2, 4, "Z")
    # El giro lleva el eje y del baño al x del cuartito, y el x del baño al -y.
    traslado = Matrix.Translation((x1 - DETRAS_DE_LAS_NOTAS - pared_del_bano,
                                   (y0 + y1) / 2 + centro_x, 0))
    for objeto in objetos:
        objeto.matrix_world = traslado @ giro @ objeto.matrix_world
    bpy.context.view_layer.update()
    # En el baño las notas iban en los extremos de la fila; acá se juntan en el centro.
    notas = sorted((bpy.data.objects[n] for n in NOTAS), key=lambda o: _caja_mundial(o)[0].y)
    centro = (y0 + y1) / 2
    for lado, nota in zip((-1, 1), notas):
        minimo, maximo = _caja_mundial(nota)
        destino = centro + lado * ((maximo.y - minimo.y) + HUECO_ENTRE_LAS_NOTAS) / 2
        nota.location.y += destino - (minimo.y + maximo.y) / 2
    bpy.context.view_layer.update()
    for objeto in objetos:
        minimo, maximo = _caja_mundial(objeto)
        assert x0 < minimo.x and maximo.x < x1, objeto.name
        assert y0 < minimo.y and maximo.y < y1, objeto.name
    return {o.name: [round(v, 3) for v in o.matrix_world.translation] for o in objetos}


def _luminaria(cuarto, coleccion):
    herramientas = _receta("lamparas_del_deposito")
    x0, x1 = cuarto["x"]
    y0, y1 = cuarto["y"]
    notas = [_caja_mundial(bpy.data.objects[n]) for n in NOTAS]
    arriba_de_las_notas = max(c[1].z for c in notas)
    # Lo más bajo de la chapa queda sobre la pared del fondo, que es donde va la luminaria.
    techo = (cuarto["z"][1] - CAIDA_DE_LA_CHAPA - 2 * ALTO_DE_LA_ONDA
             - ESPESOR_DE_LA_CHAPA - 0.001)
    padre = bpy.data.objects.new(PREFIJO + "tubo_soporte", None)
    coleccion.objects.link(padre)
    largo = 0.9
    separacion = 0.17
    padre.location = (x1 - separacion - 0.017, (y0 + y1) / 2,
                      (arriba_de_las_notas + techo) / 2)
    padre.rotation_euler.z = math.pi / 2
    metal = herramientas._material(PREFIJO + "tubo_metal", (.23, .245, .25), .45, .65)
    luminoso = herramientas._material(PREFIJO + "tubo_difusor", (1, .96, .88), 0, .5, 1.2)
    placa = herramientas._caja(PREFIJO + "tubo_placa", (largo + .05, .034, .07), 0,
                               metal, coleccion, padre)
    placa.location.y = -separacion
    for lado, x in (("izquierdo", -1), ("derecho", 1)):
        casquillo = herramientas._caja(PREFIJO + "tubo_" + lado, (.028, separacion, .07), 0,
                                       metal, coleccion, padre)
        casquillo.location = (x * (largo / 2 + .012), -separacion / 2, 0)
    segmentos = 10
    radio = .022
    vertices = [(x, radio * math.cos(2 * math.pi * i / segmentos),
                 radio * math.sin(2 * math.pi * i / segmentos))
                for x in (-largo / 2, largo / 2) for i in range(segmentos)]
    caras = [(i, (i + 1) % segmentos, (i + 1) % segmentos + segmentos, i + segmentos)
             for i in range(segmentos)]
    caras += [tuple(range(segmentos)), tuple(range(segmentos, segmentos * 2))]
    tubo = herramientas._malla(PREFIJO + "tubo_luminoso", vertices, caras,
                               (luminoso,), coleccion, padre)
    for cara in tubo.data.polygons:
        cara.use_smooth = len(cara.vertices) == 4
    bpy.context.view_layer.update()
    return [round(v, 4) for v in tubo.matrix_world.translation], largo


def aplicar():
    escena = bpy.context.scene
    assert MARCA not in escena, "El cuartito ya está en el modelo"
    imagen = bpy.data.images.load(str(CARTEL), check_existing=False)
    imagen.filepath = "//../source/textures/furniture/Puerta/puerta_productos_de_limpieza.png"
    material = _material_del_cartel(imagen)
    coleccion = bpy.data.collections.new(COLECCION)
    escena.collection.children.link(coleccion)
    hoja, marco = _puerta(material)
    coleccion.objects.link(marco)
    bpy.context.view_layer.update()
    pared = _hueco(bpy.data.objects[EDIFICIO], marco)
    piezas, cuarto = _cuarto(pared, coleccion)
    mudanza = _mudar(cuarto)
    tubo, largo = _luminaria(cuarto, coleccion)
    escena[MARCA] = 1
    bpy.context.view_layer.update()
    for objeto in piezas:
        bm = bmesh.new()
        bm.from_mesh(objeto.data)
        cerrada = all(arista.is_manifold for arista in bm.edges)
        assert cerrada or objeto.name == PREFIJO + "revestimiento", objeto.name
        bm.free()
    return {
        "cartel": CARTEL.name,
        "hueco": {"x": [pared["x_adentro"], pared["x_afuera"]], "y": list(pared["y_hueco"]),
                  "z": [pared["z_piso"], pared["z_hueco"]]},
        "cuarto": {k: list(v) for k, v in cuarto.items()},
        "piezas": [o.name for o in piezas] + [marco.name],
        "mudanza": mudanza,
        "tubo": {"centro": tubo, "largo": largo},
    }


def main():
    sys.path.insert(0, str(RAIZ / ".claude/scripts"))
    from lib.consola import configurar

    configurar()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aplicar", action="store_true")
    argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    opciones = parser.parse_args(argumentos)
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    resultado = aplicar()
    (RAIZ / "reports").mkdir(exist_ok=True)
    if opciones.aplicar:
        respaldo = RAIZ / "reports/antes-del-cuartito.blend"
        if not respaldo.exists():
            shutil.copy2(FUENTE, respaldo)
    destino = FUENTE if opciones.aplicar else RAIZ / "reports/cuartito-de-limpieza.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False,
                                relative_remap=True)
    (RAIZ / "reports/cuartito-de-limpieza.json").write_text(
        json.dumps(resultado, indent=2, default=float), encoding="utf-8")
    print(json.dumps(resultado, default=float))


if __name__ == "__main__":
    main()
