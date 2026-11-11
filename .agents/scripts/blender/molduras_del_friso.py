"""Marcos con volumen sobre el friso de madera que rodea las heladeras del salón.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/molduras_del_friso.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente. Después va
`texturizar_frente_de_madera.py`, que da las UV y la textura a las caras nuevas, y después
`exportar_modelo.py` y `hornear.py`: la malla cambia de forma y su luz horneada ya no sirve.

## Por qué

El friso (`mueble_continuo`) es una pared de madera hecha de planos lisos: las jambas, el
cabezal sobre las heladeras y el fondo del nicho. Ninguna cara sale del plano, así que no
tiene paneles ni molduras. Un friso real tiene un marco por panel, con su canto biselado: el
marco sale de la pared, recibe la luz de un lado y deja sombra del otro.

## Qué cambia

Cada cara frontal del friso que mide 50 cm o más de alto recibe uno o varios marcos. Un panel
de más de 1,1 m se parte en dos o tres, para que ningún marco quede enorme. Un marco es un aro
de 5 cm de ancho que sale 2,4 cm de la pared, con el canto biselado por fuera y por dentro. El
panel de adentro queda a ras de la pared y toma la veta de la textura: el marco es geometría y
el panel es textura.

## Lo que cuesta

Unos 270 triángulos en total, una sola malla, ningún material ni dibujo más. Es idempotente:
una marca en la malla evita repetir los marcos.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import bmesh  # type: ignore[import-not-found]
from mathutils import Matrix, Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

OBJETO = "mueble_continuo"
MARCA = "molduras_del_friso_v1"
#: La cara frontal más baja que recibe marco.
ALTO_MINIMO = 0.5
#: El ancho a partir del cual un panel se parte en varios.
ANCHO_MAXIMO = 1.1
MARGEN = 0.04
ANCHO_DEL_ARO = 0.05
BISEL = 0.014
SALIENTE = 0.024


def _aro(bm, x0, x1, z0, z1, y, vista: float) -> int:
    """Un aro con canto biselado, con su base en el plano `y` y saliendo hacia `vista`."""

    def rectangulo(sangrado: float, profundidad: float):
        puntos = (
            (x0 + sangrado, z0 + sangrado),
            (x1 - sangrado, z0 + sangrado),
            (x1 - sangrado, z1 - sangrado),
            (x0 + sangrado, z1 - sangrado),
        )
        return [bm.verts.new((x, y + vista * profundidad, z)) for x, z in puntos]

    capas = [
        rectangulo(0.0, 0.0),
        rectangulo(BISEL, SALIENTE),
        rectangulo(ANCHO_DEL_ARO - BISEL, SALIENTE),
        rectangulo(ANCHO_DEL_ARO, 0.0),
    ]
    mirando = Vector((0.0, vista, 0.0))
    centro = Vector(((x0 + x1) / 2, y, (z0 + z1) / 2))
    nuevas = 0
    for capa in range(3):
        for lado in range(4):
            cara = bm.faces.new(
                (
                    capas[capa][lado],
                    capas[capa][(lado + 1) % 4],
                    capas[capa + 1][(lado + 1) % 4],
                    capas[capa + 1][lado],
                )
            )
            cara.normal_update()
            radial = cara.calc_center_median() - centro
            radial.y = 0.0
            radial.normalize()
            esperada = (mirando + radial, mirando, mirando - radial)[capa]
            if cara.normal.dot(esperada) < 0:
                cara.normal_flip()
            cara.smooth = False
            nuevas += 1
    return nuevas


def _frentes(malla, matriz):
    """Las caras que miran al salón por el plano más al frente del friso."""
    y_frente = min((matriz @ v.co).y for v in malla.vertices)
    for cara in malla.polygons:
        normal = matriz.to_3x3() @ cara.normal
        puntos = [matriz @ malla.vertices[i].co for i in cara.vertices]
        alto = max(p.z for p in puntos) - min(p.z for p in puntos)
        en_el_frente = all(abs(p.y - y_frente) < 1e-3 for p in puntos)
        if normal.y < -0.99 and en_el_frente and alto >= ALTO_MINIMO:
            yield (
                min(p.x for p in puntos),
                max(p.x for p in puntos),
                min(p.z for p in puntos),
                max(p.z for p in puntos),
                y_frente,
            )


def main() -> None:
    configurar()
    objeto = bpy.data.objects[OBJETO]
    malla = objeto.data
    assert objeto.matrix_world == Matrix.Identity(4), "El friso ya no está en el origen."
    if malla.get(MARCA):
        print("ya aplicado")
        return
    antes = sum(len(p.vertices) - 2 for p in malla.polygons)
    frentes = sorted(_frentes(malla, objeto.matrix_world))
    assert len(frentes) == 8, f"El friso cambió: {len(frentes)} caras frontales en vez de 8."

    bm = bmesh.new()
    bm.from_mesh(malla)
    uv = bm.loops.layers.uv.active
    ya = {f.index for f in bm.faces}
    marcos = 0
    for x0, x1, z0, z1, y in frentes:
        paneles = max(1, round((x1 - x0) / ANCHO_MAXIMO))
        for k in range(paneles):
            a = x0 + (x1 - x0) * k / paneles
            b = x0 + (x1 - x0) * (k + 1) / paneles
            izquierda = MARGEN if k == 0 else MARGEN / 2
            derecha = MARGEN if k == paneles - 1 else MARGEN / 2
            marco = min(MARGEN, (z1 - z0) * 0.12)
            _aro(bm, a + izquierda, b - derecha, z0 + marco, z1 - marco, y, vista=-1.0)
            marcos += 1
    # UV provisionales, en metros del mundo: `texturizar_frente_de_madera.py` las rehace.
    for cara in bm.faces:
        if cara.index in ya:
            continue
        for lazo in cara.loops:
            p = lazo.vert.co
            lazo[uv].uv = (p.x / 1.8, (p.z - 0.1) / 2.49)
    bm.to_mesh(malla)
    bm.free()
    malla[MARCA] = True
    malla.update()
    despues = sum(len(p.vertices) - 2 for p in malla.polygons)
    print(f"{OBJETO}: {marcos} marcos, {antes} -> {despues} triángulos (+{despues - antes})")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
