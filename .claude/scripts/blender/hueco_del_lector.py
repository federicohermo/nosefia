"""El hueco que deja el lector arrancado: el marco roto, el fondo y los cables cortados.

blender --background --factory-startup --python-exit-code 1 --python hueco_del_lector.py

Arma la fuente desde cero, la guarda en assets/source/puestos/hueco_del_lector.blend y la
exporta a assets/models/hueco_del_lector.glb. El origen es el centro de la caja de choque del
hueco en lector.tscn, y Z de Blender es Y de Godot. Todo cae adentro de su planta.
"""

import math
import random
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

RAIZ = Path(__file__).resolve().parents[3]
FUENTE = RAIZ / "assets/source/puestos/hueco_del_lector.blend"
SALIDA = RAIZ / "assets/models/hueco_del_lector.glb"
NOMBRE = "hueco_del_lector"

# La caja de choque mide 0,1615 de lado y 0,025 de alto; el escritorio queda 2,5 mm abajo
# de su centro. Los cables caen hacia -Y, que en Godot es +Z: el lado del empleado.
MITAD = 0.080
ESCRITORIO = -0.0025
PARED = 0.012
FONDO = ESCRITORIO + 0.0005

# Una celda de 4 px por color. Todo vértice de una pieza cae en el centro de su celda, y la
# paleta lleva el mismo filtro que el resto del modelo.
PALETA = {
    "fondo": (12, 12, 13),
    "marco": (34, 34, 36),
    "rotura": (78, 78, 80),
    "negro": (54, 54, 58),
    "gris": (128, 130, 133),
    "azul": (38, 78, 168),
    "rojo": (168, 34, 30),
    "amarillo": (205, 172, 40),
    "blanco": (214, 214, 204),
    "verde": (40, 138, 62),
    "cobre": (190, 112, 52),
    "metal": (150, 152, 156),
    "boca": (4, 4, 4),
    "naranja": (204, 104, 32),
    "marron": (104, 62, 34),
    "goma": (52, 52, 54),
}
CELDAS = 4
LADO = 16


def _uv(color):
    indice = list(PALETA).index(color)
    columna, fila = indice % CELDAS, indice // CELDAS
    return ((columna + 0.5) / CELDAS, 1 - (fila + 0.5) / CELDAS)


def _paleta():
    imagen = bpy.data.images.new("paleta", LADO, LADO, alpha=False)
    pixeles = [0.0] * (LADO * LADO * 4)
    paso = LADO // CELDAS
    for indice, rgb in enumerate(PALETA.values()):
        columna, fila = indice % CELDAS, indice // CELDAS
        for y in range(LADO - (fila + 1) * paso, LADO - fila * paso):
            for x in range(columna * paso, (columna + 1) * paso):
                inicio = (y * LADO + x) * 4
                pixeles[inicio:inicio + 4] = [c / 255 for c in rgb] + [1.0]
    imagen.pixels = pixeles
    imagen.pack()
    return imagen


def _material(nombre, imagen, rugosidad, metal):
    material = bpy.data.materials.new(nombre)
    nodos = material.node_tree.nodes
    bsdf = nodos["Principled BSDF"]
    textura = nodos.new("ShaderNodeTexImage")
    textura.image = imagen
    textura.interpolation = "Closest"
    # Sin repetir, como el frente del lector: así comparten el mismo programa del shader.
    textura.extension = "EXTEND"
    material.node_tree.links.new(textura.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = rugosidad
    bsdf.inputs["Metallic"].default_value = metal
    return material


class Pieza:
    """Una malla que junta las piezas con su material y la celda de su color."""

    def __init__(self):
        self.malla = bmesh.new()
        self.uv = self.malla.loops.layers.uv.new("UVMap")

    def agregar(self, vertices, caras, color, material=0, suave=False):
        nuevos = [self.malla.verts.new(v) for v in vertices]
        for cara in caras:
            poligono = self.malla.faces.new([nuevos[i] for i in cara])
            poligono.material_index = material
            poligono.smooth = suave
            for esquina in poligono.loops:
                esquina[self.uv].uv = _uv(color)


def _curva(puntos, pasos):
    """Catmull-Rom por los puntos de control, con los extremos repetidos."""
    control = [puntos[0]] + list(puntos) + [puntos[-1]]
    salida = []
    for i in range(1, len(control) - 2):
        p0, p1, p2, p3 = control[i - 1:i + 3]
        for paso in range(pasos):
            t = paso / pasos
            salida.append(0.5 * ((2 * p1) + (-p0 + p2) * t
                                 + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                                 + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    salida.append(control[-2])
    return salida


def _marcos(camino):
    """Tangente, normal y binormal de cada punto, por transporte paralelo."""
    tangentes = []
    for i in range(len(camino)):
        anterior = camino[max(i - 1, 0)]
        siguiente = camino[min(i + 1, len(camino) - 1)]
        tangentes.append((siguiente - anterior).normalized())
    referencia = Vector((0, 0, 1)) if abs(tangentes[0].z) < 0.9 else Vector((1, 0, 0))
    normal = tangentes[0].cross(referencia).normalized()
    marcos = []
    for i, tangente in enumerate(tangentes):
        if i:
            eje = tangentes[i - 1].cross(tangente)
            if eje.length > 1e-9:
                angulo = tangentes[i - 1].angle(tangente)
                normal = (Matrix.Rotation(angulo, 3, eje.normalized()) @ normal).normalized()
        marcos.append((tangente, normal, tangente.cross(normal)))
    return marcos


def _tubo(pieza, puntos, radio, color, lados=8, pasos=6, tapa=None):
    """Un cable por los puntos. Devuelve la punta y su marco, para lo que sale del corte."""
    camino = _curva([Vector(p) for p in puntos], pasos) if len(puntos) > 2 else [
        Vector(p) for p in puntos]
    marcos = _marcos(camino)
    vertices, caras = [], []
    for centro, (_, normal, binormal) in zip(camino, marcos):
        for lado in range(lados):
            angulo = 2 * math.pi * lado / lados
            vertices.append(centro + radio * (math.cos(angulo) * normal
                                              + math.sin(angulo) * binormal))
    for anillo in range(len(camino) - 1):
        for lado in range(lados):
            a = anillo * lados + lado
            b = anillo * lados + (lado + 1) % lados
            caras.append((a, b, b + lados, a + lados))
    pieza.agregar(vertices, caras, color, suave=True)
    ultimo = len(camino) - 1
    pieza.agregar(vertices[:lados], [tuple(reversed(range(lados)))], color)
    pieza.agregar(vertices[ultimo * lados:], [tuple(range(lados))], tapa or color)
    return camino[-1], marcos[-1]


def _cobre(pieza, punta, direccion, radio, largo, azar):
    """Los hilos de cobre deshilachados que asoman de un corte."""
    tangente = direccion.normalized()
    auxiliar = Vector((0, 0, 1)) if abs(tangente.z) < 0.9 else Vector((1, 0, 0))
    normal = tangente.cross(auxiliar).normalized()
    binormal = tangente.cross(normal)
    for hilo in range(3):
        angulo = 2 * math.pi * hilo / 3 + azar.uniform(-0.4, 0.4)
        lado = math.cos(angulo) * normal + math.sin(angulo) * binormal
        inicio = punta + lado * radio * 0.5
        fin = inicio + (tangente + lado * azar.uniform(0.25, 0.6)).normalized() * largo * \
            azar.uniform(0.7, 1.0)
        _tubo(pieza, [inicio, fin], 0.00035, "cobre", lados=4, pasos=1)


def _hilos(pieza, punta, marco, radio, colores, azar):
    """Los conductores con su aislante, abiertos en abanico, y el cobre en cada punta."""
    tangente, normal, binormal = marco
    for indice, color in enumerate(colores):
        angulo = 2 * math.pi * indice / len(colores)
        lado = math.cos(angulo) * normal + math.sin(angulo) * binormal
        inicio = punta + lado * radio * 0.45 - tangente * 0.0005
        largo = azar.uniform(0.006, 0.011)
        medio = inicio + tangente * largo * 0.5 + lado * largo * 0.15
        fin = inicio + (tangente + lado * azar.uniform(0.35, 0.7)).normalized() * largo
        _, (final, _, _) = _tubo(pieza, [inicio, medio, fin], radio * 0.28, color, lados=6,
                                 pasos=3)
        _cobre(pieza, fin, final, radio * 0.28, 0.003, azar)


def _ficha_usb(pieza, punta, marco):
    """Una ficha USB que quedó colgando del cable gris."""
    tangente, normal, binormal = marco

    def caja(centro, ancho, alto, largo, color):
        vertices = [centro + tangente * t * largo / 2 + normal * n * ancho / 2
                    + binormal * b * alto / 2
                    for t in (-1, 1) for n in (-1, 1) for b in (-1, 1)]
        caras = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4),
                 (1, 5, 7, 3)]
        pieza.agregar(vertices, caras, color, material=1 if color == "metal" else 0)

    caja(punta + tangente * 0.008, 0.016, 0.008, 0.016, "gris")
    caja(punta + tangente * 0.0215, 0.012, 0.0045, 0.011, "metal")


def _marco(pieza, azar):
    """El borde que quedó del lector: roto arriba, con el plástico claro en la rotura."""
    por_lado = 10
    perimetro = []
    for lado in range(4):
        for paso in range(por_lado):
            t = -1 + 2 * paso / por_lado
            perimetro.append([(t, -1), (1, t), (-t, 1), (-1, -t)][lado])
    adentro = (MITAD - PARED) / MITAD
    alturas = []
    for indice in range(len(perimetro)):
        altura = 0.0118 - azar.uniform(0.0, 0.006)
        if indice % 13 == 4:
            altura = 0.0118 + azar.uniform(0.004, 0.009)
        alturas.append(altura)
    vertices, caras = [], []
    for (x, y), altura in zip(perimetro, alturas):
        vertices += [(x * MITAD, y * MITAD, ESCRITORIO - 0.001), (x * MITAD, y * MITAD, altura),
                     (x * MITAD * adentro, y * MITAD * adentro, altura - 0.001),
                     (x * MITAD * adentro, y * MITAD * adentro, FONDO)]
    total = len(perimetro)
    paredes, bordes = [], []
    for i in range(total):
        a, b = i * 4, ((i + 1) % total) * 4
        paredes += [(a, b, b + 1, a + 1), (a + 2, b + 2, b + 3, a + 3)]
        bordes.append((a + 1, b + 1, b + 2, a + 2))
    pieza.agregar(vertices, paredes, "marco")
    pieza.agregar(vertices, bordes, "rotura")
    interior = MITAD - PARED
    pieza.agregar([(-interior, -interior, FONDO), (interior, -interior, FONDO),
                   (interior, interior, FONDO), (-interior, interior, FONDO)],
                  [(0, 1, 2, 3)], "fondo")


def _boca(pieza, centro, radio):
    """El pasacables del fondo, por donde suben los cables."""
    lados = 16
    vertices = []
    for lado in range(lados):
        angulo = 2 * math.pi * lado / lados
        direccion = Vector((math.cos(angulo), math.sin(angulo), 0))
        vertices += [centro + direccion * radio + Vector((0, 0, 0.0006)),
                     centro + direccion * radio * 1.35 + Vector((0, 0, 0.0003))]
    anillo = [(2 * i, 2 * ((i + 1) % lados), 2 * ((i + 1) % lados) + 1, 2 * i + 1)
              for i in range(lados)]
    pieza.agregar(vertices, anillo, "goma")
    pieza.agregar([v + Vector((0, 0, -0.0001)) for v in vertices[::2]],
                  [tuple(range(lados))], "boca")


def _tornillos(pieza, azar):
    """Los soportes del lector, cortados a distintas alturas."""
    for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        centro = Vector((x * (MITAD - PARED - 0.006), y * (MITAD - PARED - 0.006), FONDO))
        alto = azar.uniform(0.003, 0.008)
        lados = 8
        vertices = []
        for z in (0.0, alto):
            for lado in range(lados):
                angulo = 2 * math.pi * lado / lados
                inclinacion = z * 0.35 * math.cos(angulo)
                vertices.append(centro + Vector((0.0035 * math.cos(angulo),
                                                 0.0035 * math.sin(angulo),
                                                 z + inclinacion)))
        caras = [(i, (i + 1) % lados, (i + 1) % lados + lados, i + lados) for i in range(lados)]
        caras.append(tuple(range(lados, 2 * lados)))
        pieza.agregar(vertices, caras, "metal", material=1)


def _cables(pieza, boca, azar):
    """Seis cables que suben por el pasacables y quedaron cortados al arrancar el lector.

    Entran desde adentro del mostrador. Así el centro de la malla queda en la caja de choque, y
    la mira que apunta a ese centro encuentra el hueco.
    """
    abajo = boca + Vector((0, 0, -0.04))

    def desde(*puntos):
        return [abajo, boca + Vector((0, 0, 0.002))] + [boca + Vector(p) for p in puntos]

    punta, marco = _tubo(pieza, desde((0.0, -0.004, 0.016), (-0.012, -0.02, 0.03),
                                      (-0.034, -0.044, 0.026), (-0.05, -0.062, 0.014),
                                      (-0.058, -0.072, 0.009)),
                         0.004, "negro", tapa="goma")
    _hilos(pieza, punta, marco, 0.004, ["marron", "azul", "verde"], azar)
    punta, marco = _tubo(pieza, desde((0.006, 0.004, 0.022), (0.018, -0.006, 0.042),
                                      (0.032, -0.026, 0.046), (0.044, -0.044, 0.034),
                                      (0.048, -0.054, 0.024)),
                         0.003, "gris")
    _ficha_usb(pieza, punta, marco)
    punta, marco = _tubo(pieza, desde((-0.004, 0.008, 0.012), (-0.026, 0.016, 0.022),
                                      (-0.048, 0.02, 0.016), (-0.062, 0.024, 0.01)),
                         0.0032, "azul", tapa="goma")
    _hilos(pieza, punta, marco, 0.0032, ["naranja", "verde", "azul", "marron"], azar)
    for color, radio, puntos in (
        ("rojo", 0.0018, ((0.008, 0.004, 0.01), (0.024, 0.012, 0.026), (0.04, 0.016, 0.024),
                          (0.05, 0.016, 0.018))),
        ("amarillo", 0.0018, ((0.004, -0.008, 0.008), (0.014, -0.03, 0.016),
                              (0.02, -0.056, 0.012), (0.022, -0.07, 0.006))),
        ("blanco", 0.002, ((-0.004, -0.002, 0.008), (-0.01, -0.004, 0.018),
                            (-0.012, -0.002, 0.024))),
    ):
        punta, (tangente, _, _) = _tubo(pieza, desde(*puntos), radio, color, tapa="cobre")
        _cobre(pieza, punta, tangente, radio, 0.004, azar)


def construir():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    azar = random.Random(384)
    imagen = _paleta()
    pieza = Pieza()
    boca = Vector((0.006, 0.02, FONDO))
    _marco(pieza, azar)
    _boca(pieza, boca, 0.013)
    _tornillos(pieza, azar)
    _cables(pieza, boca, azar)
    bmesh.ops.remove_doubles(pieza.malla, verts=pieza.malla.verts, dist=1e-6)
    malla = bpy.data.meshes.new(NOMBRE)
    pieza.malla.to_mesh(malla)
    pieza.malla.free()
    malla.materials.append(_material(NOMBRE + "_plastico", imagen, 0.7, 0.0))
    malla.materials.append(_material(NOMBRE + "_metal", imagen, 0.4, 1.0))
    objeto = bpy.data.objects.new(NOMBRE, malla)
    bpy.context.scene.collection.objects.link(objeto)
    return objeto


def exportar(objeto):
    FUENTE.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(FUENTE), compress=True)
    bpy.ops.object.select_all(action="DESELECT")
    objeto.select_set(True)
    bpy.context.view_layer.objects.active = objeto
    bpy.ops.export_scene.gltf(
        filepath=str(SALIDA),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
    )
    puntos = [v.co for v in objeto.data.vertices]
    minimo = [round(min(p[i] for p in puntos), 4) for i in range(3)]
    maximo = [round(max(p[i] for p in puntos), 4) for i in range(3)]
    print(f"{NOMBRE}: {len(objeto.data.polygons)} caras, de {minimo} a {maximo}")
    assert all(abs(c) <= MITAD for c in minimo[:2] + maximo[:2]), "Sale de la planta del hueco"


if __name__ == "__main__":
    import sys

    sys.path.insert(0, str(RAIZ / ".claude/scripts"))
    from lib.consola import configurar

    configurar()
    exportar(construir())
