"""Edición puntual de la entrada sobre el modelo actual; --aplicar guarda la fuente."""

import sys

import bpy
from mathutils import Vector


FRENTE = -6.28
IZQUIERDA = 3.25
DERECHA = 6.57
CENTRO = 4.85


def reemplazar_malla(objeto, vertices, caras):
    """Conserva el objeto, su transformación, su padre y sus materiales."""
    anterior = objeto.data
    inversa = objeto.matrix_world.inverted()
    malla = bpy.data.meshes.new(anterior.name + "_doble")
    malla.from_pydata([inversa @ Vector(punto) for punto in vertices], [], caras)
    for material in anterior.materials:
        malla.materials.append(material)
    uv = malla.uv_layers.new(name="UVMap")
    for cara in malla.polygons:
        for indice, esquina in zip(cara.loop_indices, [(0, 0), (1, 0), (1, 1), (0, 1)]):
            uv.data[indice].uv = esquina
    malla.update()
    objeto.data = malla
    if anterior.users == 0:
        bpy.data.meshes.remove(anterior)


def caja(vertices, caras, minimo, maximo):
    inicio = len(vertices)
    x0, y0, z0 = minimo
    x1, y1, z1 = maximo
    vertices.extend([
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1),
    ])
    for cara in [(3, 2, 1, 0), (0, 1, 5, 4), (1, 2, 6, 5),
                 (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7)]:
        caras.append(tuple(inicio + indice for indice in cara))


def editar():
    puerta = bpy.data.objects["puertaentrada-col"]
    vidrio = bpy.data.objects["local_vidrio_puerta_entrada"]
    vertices, caras = [], []
    # Las hojas comparten el objeto interactuable original de la entrada cerrada.
    hojas = [(IZQUIERDA, CENTRO - 0.006, 0.05, 0.018),
             (CENTRO + 0.006, DERECHA, 0.018, 0.05)]
    cristales = []
    for izquierda, derecha, borde_izquierdo, borde_derecho in hojas:
        for x0, x1, z0, z1 in [
            (izquierda, izquierda + borde_izquierdo, 0.102, 2.886),
            (derecha - borde_derecho, derecha, 0.102, 2.886),
            (izquierda, derecha, 0.102, 0.18),
            (izquierda, derecha, 2.82, 2.886),
        ]:
            caja(vertices, caras, (x0, FRENTE - 0.04, z0),
                 (x1, FRENTE + 0.04, z1))
        cristales.append((izquierda + borde_izquierdo, derecha - borde_derecho))
    for x in [CENTRO - 0.15, CENTRO + 0.15]:
        caja(vertices, caras, (x - 0.02, FRENTE - 0.14, 1.12),
             (x + 0.02, FRENTE - 0.11, 1.63))
    reemplazar_malla(puerta, vertices, caras)

    vertices, caras = [], []
    for izquierda, derecha in cristales:
        inicio = len(vertices)
        vertices.extend([(izquierda, FRENTE - 0.02, 0.18),
                         (derecha, FRENTE - 0.02, 0.18),
                         (derecha, FRENTE - 0.02, 2.82),
                         (izquierda, FRENTE - 0.02, 2.82)])
        caras.append(tuple(range(inicio, inicio + 4)))
    reemplazar_malla(vidrio, vertices, caras)

    # El vidrio fijo termina donde comienza el nuevo vano de dos ventanales.
    reemplazar_malla(bpy.data.objects["local_vidrio_frente_0"],
                     [(1.65, FRENTE - 0.045, 0.10223747),
                      (IZQUIERDA, FRENTE - 0.045, 0.10223747),
                      (IZQUIERDA, FRENTE - 0.045, 4.14),
                      (1.65, FRENTE - 0.045, 4.14)], [(0, 1, 2, 3)])
    reemplazar_malla(bpy.data.objects["local_vidrio_sobre_entrada"],
                     [(IZQUIERDA, FRENTE - 0.045, 2.886),
                      (DERECHA, FRENTE - 0.045, 2.886),
                      (DERECHA, FRENTE - 0.045, 4.14),
                      (IZQUIERDA, FRENTE - 0.045, 4.14)], [(0, 1, 2, 3)])

    # El antiguo divisor de los ventanales queda sólo encima de las hojas.
    montante_superior = bpy.data.objects["local_marco_frente_4.85-col"]
    vertices, caras = [], []
    caja(vertices, caras, (CENTRO - 0.025, FRENTE - 0.09, 2.886),
         (CENTRO + 0.025, FRENTE + 0.02, 4.16))
    reemplazar_malla(montante_superior, vertices, caras)

    montante = bpy.data.objects.get("local_marco_frente_5.71-col")
    if montante is not None:
        bpy.data.objects.remove(montante, do_unlink=True)

    alfombra = bpy.data.objects["local_alfombra_entrada-col"]
    inversa = alfombra.matrix_world.inverted()
    puntos = [alfombra.matrix_world @ vertice.co for vertice in alfombra.data.vertices]
    x0, x1 = min(p.x for p in puntos), max(p.x for p in puntos)
    y0, y1 = min(p.y for p in puntos), max(p.y for p in puntos)
    for vertice, punto in zip(alfombra.data.vertices, puntos):
        punto.x = CENTRO - 1.1 + (punto.x - x0) / (x1 - x0) * 2.2
        punto.y = FRENTE + 0.12 + (punto.y - y0) / (y1 - y0) * 0.9
        vertice.co = inversa @ punto
    alfombra.data.update()

    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    print("Entrada doble de 3,32 m; dos ventanales completos; alfombra de 2,20 x 0,90 m.")


editar()
