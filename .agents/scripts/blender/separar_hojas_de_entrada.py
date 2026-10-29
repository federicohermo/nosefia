"""Dos hojas independientes para la entrada; se aplica también al exportar el modelo."""

import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / '.claude/scripts'))
from lib.consola import configurar


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
    # Con las dos hojas y sus vidrios ya separados en el `.blend`, la entrada es la que está ahí:
    # rehacerlas acá pisaba al exportar las medidas que se les ajustaron a mano, y la hoja del
    # juego quedaba corrida de su marco.
    if all(bpy.data.objects.get(n) for n in (
        "puertaentrada-col", "puertaentrada_derecha-col",
        "local_vidrio_puerta_entrada", "local_vidrio_puerta_entrada_derecha",
    )):
        return
    puerta = bpy.data.objects["puertaentrada-col"]
    vidrio = bpy.data.objects["local_vidrio_puerta_entrada"]
    hojas = [(IZQUIERDA, CENTRO - 0.006, 0.05, 0.018),
             (CENTRO + 0.006, DERECHA, 0.018, 0.05)]
    for indice, (izquierda, derecha, borde_izquierdo, borde_derecho) in enumerate(hojas):
        nombre = "puertaentrada-col" if indice == 0 else "puertaentrada_derecha-col"
        hoja = bpy.data.objects.get(nombre)
        if hoja is None:
            hoja = puerta.copy()
            hoja.data = puerta.data.copy()
            hoja.name = nombre
            puerta.users_collection[0].objects.link(hoja)
        # El canto exterior del marco queda en el eje. El frente de la bisagra evita barrer
        # el vidrio fijo al abrir hacia afuera, también con el espesor del marco.
        bisagra = izquierda if indice == 0 else derecha
        hoja.matrix_world = Matrix.Translation((bisagra, FRENTE - 0.04, (0.102 + 2.886) / 2))
        vertices, caras = [], []
        for x0, x1, z0, z1 in [
            (izquierda, izquierda + borde_izquierdo, 0.102, 2.886),
            (derecha - borde_derecho, derecha, 0.102, 2.886),
            (izquierda, derecha, 0.102, 0.18),
            (izquierda, derecha, 2.82, 2.886),
        ]:
            caja(vertices, caras, (x0, FRENTE - 0.04, z0),
                 (x1, FRENTE + 0.04, z1))
        x = CENTRO - 0.15 if indice == 0 else CENTRO + 0.15
        caja(vertices, caras, (x - 0.02, FRENTE - 0.14, 1.12),
             (x + 0.02, FRENTE - 0.11, 1.63))
        reemplazar_malla(hoja, vertices, caras)

        nombre_vidrio = "local_vidrio_puerta_entrada" + ("_derecha" if indice else "")
        cristal = bpy.data.objects.get(nombre_vidrio)
        if cristal is None:
            cristal = vidrio.copy()
            cristal.data = vidrio.data.copy()
            cristal.name = nombre_vidrio
            vidrio.users_collection[0].objects.link(cristal)
        cristal.parent = hoja
        cristal.matrix_parent_inverse = Matrix.Identity(4)
        cristal.matrix_world = hoja.matrix_world.copy()
        x0, x1 = izquierda + borde_izquierdo, derecha - borde_derecho
        reemplazar_malla(cristal,
                         [(x0, FRENTE - 0.02, 0.18), (x1, FRENTE - 0.02, 0.18),
                          (x1, FRENTE - 0.02, 2.82), (x0, FRENTE - 0.02, 2.82)],
                         [(0, 1, 2, 3)])

    if '--aplicar' in sys.argv:
        bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)


if __name__ == '__main__':
    configurar()
    editar()
