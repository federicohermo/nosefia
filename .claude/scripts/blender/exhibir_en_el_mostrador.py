"""Llena el exhibidor de golosinas y el estante de la mesada. Se aplica una sola vez.

    blender --background --python-exit-code 1 --python \\
        .claude/scripts/blender/exhibir_en_el_mostrador.py -- --aplicar

Sin `--aplicar` guarda en `reports/exhibir-en-el-mostrador.blend` y el `.blend` del repo queda como
estaba.

Es decoración, como lo exhibido en el freezer: no son productos del catálogo y no se agarran. Cada
mueble lleva **una sola malla**, con un material por producto: en la web cada objeto suelto es un
dibujo más. Las golosinas son Chocolocas, Cofloco y Masticul, en un bloque por producto en cada
escalón. Las medialunas y los croissants son modelos inventados: la imagen sale de este script.
"""

import math
import random
import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import bpy  # type: ignore[import-not-found]
from mathutils import Euler, Matrix, Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
MODELOS = RAIZ / "assets/source/products-cam"
MATERIAL_MODELO = "EXHIBIDO | gringo"
AVISO_QUE_SALE = "exhibidor_aviso_sin_stock"

EXHIBIDOR = "exhibidor_golosinas-col"
#: Altura y medio hacia el fondo de cada escalón; el ancho del mueble, de punta a punta.
ESCALONES = ((0.682, -2.2555), (0.802, -2.4365), (0.922, -2.618), (1.042, -2.7995))
ANCHO_DEL_EXHIBIDOR = (-1.129, 0.377)
#: Cuánto se echa cada golosina hacia atrás, para que se lea desde el salón.
ECHADA = math.radians(20)
#: Nombre, ancho, alto y espesor de cada golosina, y su imagen: frente y dorso, uno al lado del otro.
GOLOSINAS = (
    ("masticul", 0.14, 0.148, 0.03, "MASTICUL/masticul.png"),
    ("chocolocas", 0.15, 0.102, 0.015, "CHOCOLOCAS/chocolocas.png"),
    ("cofloco", 0.15, 0.0625, 0.02, "COFLOCO/cofloco.png"),
)
ENTRE_GOLOSINAS = 0.012
#: Cada escalón lleva dos filas: hacia el fondo y cuánto sube la de atrás, para que se vea.
FILAS_POR_ESCALON = ((0.045, 0.0), (-0.045, 0.03))

ESTANTE = "estante_mesada"
#: Los estantes con facturas, y hasta dónde llegan sin tocar los parantes.
PLANOS_DEL_ESTANTE = (1.16, 1.33, 1.48)
LUGAR_DEL_ESTANTE = ((1.125, 1.475), (-3.515, -3.155))
FACTURAS_POR_LADO = (3, 3)
IMAGEN_DE_FACTURA = MODELOS / "MEDIALUNAS/factura.png"


def _material(nombre, imagen):
    material = bpy.data.materials[MATERIAL_MODELO].copy()
    material.name = f"EXHIBIDO | {nombre}"
    cargada = bpy.data.images.load(str(imagen), check_existing=True)
    cargada.filepath = "//../source/" + imagen.relative_to(RAIZ / "assets/source").as_posix()
    nodo = next(n for n in material.node_tree.nodes if n.bl_idname == "ShaderNodeTexImage")
    nodo.image = cargada
    return material


def _caja(bm, capa, ancho, alto, espesor, matriz, indice):
    """Una golosina: el frente mira a +Y y la imagen trae el frente en su mitad izquierda."""
    x, y, z = ancho / 2, espesor / 2, alto / 2
    esquinas = ((-x, -y, -z), (x, -y, -z), (x, y, -z), (-x, y, -z),
                (-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z))
    v = [bm.verts.new(matriz @ Vector(c)) for c in esquinas]
    borde = ((0.0, 0.0), (0.02, 0.0), (0.02, 1.0), (0.0, 1.0))
    caras = (
        ((2, 3, 7, 6), ((0.0, 0.0), (0.5, 0.0), (0.5, 1.0), (0.0, 1.0))),
        ((0, 1, 5, 4), ((0.5, 0.0), (1.0, 0.0), (1.0, 1.0), (0.5, 1.0))),
        ((1, 2, 6, 5), borde), ((3, 0, 4, 7), borde), ((4, 5, 6, 7), borde), ((3, 2, 1, 0), borde),
    )
    for indices, uvs in caras:
        cara = bm.faces.new([v[i] for i in indices])
        cara.material_index = indice
        for lazo, uv in zip(cara.loops, uvs):
            lazo[capa].uv = uv


def _golosinas():
    bm = bmesh.new()
    capa = bm.loops.layers.uv.new("UVMap")
    izquierda, derecha = ANCHO_DEL_EXHIBIDOR
    tercio = (derecha - izquierda) / len(GOLOSINAS)
    for indice, (_, ancho, alto, espesor, _) in enumerate(GOLOSINAS):
        cuantas = int((tercio - ENTRE_GOLOSINAS) // (ancho + ENTRE_GOLOSINAS))
        paso = tercio / cuantas
        alza = alto / 2 * math.cos(ECHADA) + espesor / 2 * math.sin(ECHADA)
        lugares = [(y + fondo, z + sube) for z, y in ESCALONES for fondo, sube in FILAS_POR_ESCALON]
        for y, z in lugares:
            for i in range(cuantas):
                x = izquierda + tercio * indice + paso * (i + 0.5)
                matriz = Matrix.Translation((x, y, z + alza)) @ Matrix.Rotation(-ECHADA, 4, "X")
                _caja(bm, capa, ancho, alto, espesor, matriz, indice)
    return bm


def _imagen_de_factura():
    """Dorado arriba, claro abajo, y las franjas de masa arrolladas a lo largo."""
    ancho, alto = 256, 128
    imagen = bpy.data.images.new("factura.png", ancho, alto)
    azar = random.Random(7)
    pixeles = []
    for fila in range(alto):
        v = fila / (alto - 1)
        for columna in range(ancho):
            u = columna / (ancho - 1)
            cocido = max(0.0, math.sin(v * math.pi))
            franja = 0.5 + 0.5 * math.cos(u * math.pi * 12)
            tono = 0.42 + 0.5 * (1 - cocido) + 0.16 * franja * cocido + azar.uniform(-0.03, 0.03)
            pixeles += [min(1.0, 0.9 * tono + 0.2), min(1.0, 0.66 * tono + 0.1),
                        min(1.0, 0.34 * tono + 0.02), 1.0]
    imagen.pixels = pixeles
    IMAGEN_DE_FACTURA.parent.mkdir(exist_ok=True)
    imagen.filepath_raw = str(IMAGEN_DE_FACTURA)
    imagen.file_format = "PNG"
    imagen.save()
    bpy.data.images.remove(imagen)


def _factura(bm, capa, matriz, largo, grueso, curva, indice):
    """Un cuerpo arrollado que se afina en las puntas, doblado sobre un arco."""
    anillos, lados = 13, 8
    radio = largo / (2 * math.sin(curva))
    filas = []
    for i in range(anillos):
        t = i / (anillos - 1) * 2 - 1
        angulo = t * curva
        centro = Vector((radio * math.sin(angulo), radio * (math.cos(angulo) - 1), 0))
        afuera = Vector((math.sin(angulo), math.cos(angulo), 0))
        perfil = (1 - abs(t) ** 2.4) ** 0.7
        r = grueso * (0.12 + 0.88 * perfil) * (1 + 0.05 * math.cos(t * math.pi * 3))
        fila = []
        for j in range(lados):
            a = j / lados * math.tau
            punto = centro + afuera * (math.cos(a) * r)
            punto.z = (math.sin(a) + 1) * r * 0.8
            fila.append(bm.verts.new(matriz @ punto))
        filas.append(fila)
    for i in range(anillos - 1):
        for j in range(lados):
            k = (j + 1) % lados
            cara = bm.faces.new((filas[i][j], filas[i + 1][j], filas[i + 1][k], filas[i][k]))
            cara.material_index = indice
            cara.smooth = True
            uvs = ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))
            for lazo, (a, b) in zip(cara.loops, uvs):
                lazo[capa].uv = (a / (anillos - 1), b / lados)
    for fila in (list(reversed(filas[0])), filas[-1]):
        cara = bm.faces.new(fila)
        cara.material_index = indice
        for lazo in cara.loops:
            lazo[capa].uv = (0.0, 0.0)


def _facturas():
    bm = bmesh.new()
    capa = bm.loops.layers.uv.new("UVMap")
    azar = random.Random(11)
    (x0, x1), (y0, y1) = LUGAR_DEL_ESTANTE
    columnas, filas = FACTURAS_POR_LADO
    for z in PLANOS_DEL_ESTANTE:
        for i in range(columnas):
            for j in range(filas):
                x = x0 + (x1 - x0) * (i + 0.5) / columnas + azar.uniform(-0.008, 0.008)
                y = y0 + (y1 - y0) * (j + 0.5) / filas + azar.uniform(-0.008, 0.008)
                giro = azar.uniform(-0.45, 0.45) + (math.pi if (i + j) % 2 else 0.0)
                matriz = Matrix.Translation((x, y, z)) @ Euler((0, 0, giro)).to_matrix().to_4x4()
                if (i + j) % 3 == 2:
                    _factura(bm, capa, matriz, 0.105, 0.03, 0.18, 0)
                else:
                    _factura(bm, capa, matriz, 0.1, 0.021, 0.85, 0)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def _objeto(nombre, bm, materiales, padre):
    malla = bpy.data.meshes.new(nombre)
    bm.normal_update()
    bm.to_mesh(malla)
    bm.free()
    for material in materiales:
        malla.materials.append(material)
    objeto = bpy.data.objects.new(nombre, malla)
    for coleccion in padre.users_collection:
        coleccion.objects.link(objeto)
    objeto.parent = padre
    objeto.matrix_parent_inverse = padre.matrix_world.inverted()
    return objeto


def principal():
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE))
    if AVISO_QUE_SALE not in bpy.data.objects:
        raise SystemExit("El mostrador ya está lleno; no se tocó nada.")
    bpy.data.objects.remove(bpy.data.objects[AVISO_QUE_SALE], do_unlink=True)
    _imagen_de_factura()
    golosinas = [_material(g[0], MODELOS / g[4]) for g in GOLOSINAS]
    _objeto("exhibido_golosinas", _golosinas(), golosinas, bpy.data.objects[EXHIBIDOR])
    facturas = [_material("facturas", IMAGEN_DE_FACTURA)]
    _objeto("exhibido_facturas", _facturas(), facturas, bpy.data.objects[ESTANTE])
    prueba = RAIZ / "reports/exhibir-en-el-mostrador.blend"
    destino = FUENTE if "--aplicar" in sys.argv else prueba
    destino.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)


principal()
