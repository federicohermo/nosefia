"""Mide sobre la malla que el arte de Oremos y de Pepito no queda estirado. Corre en Blender.

    blender <archivo>.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/verificar_paquetes_de_galletitas.py

No guarda nada. Arma en memoria cada paquete con su forma y su UV y mide, sobre los triángulos
cuya UV cae dentro del recorte del frente y del dorso, la transformación de la UV a metros:

- **Si estira:** la relación entre los dos valores singulares. Con 1, un píxel mide lo mismo en x
  que en y. Falla si el peor triángulo se desvía más del 1 %.
- **Cuántos píxeles por metro lleva** a lo ancho y a lo alto, y que sea la del recorte sobre la zona
  que cubre.

Además mide **la proporción del frente**: el ancho y el alto de la zona que cubre el recorte del
frente, sobre la malla, contra la relación de aspecto del recorte. Y que el recorte del frente
cubra su zona **de borde a borde**: la UV del frente llega a los cuatro bordes del recorte.
"""

import math
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import armar_paquetes_de_galletitas as armado  # noqa: E402
from lib import paquete_de_galletitas as forma  # noqa: E402
from lib import recortes_de_paquetes as recortes  # noqa: E402
from lib.consola import configurar  # noqa: E402

TOLERANCIA = 0.01


def triangulos(objeto, atlas):
    """Los triángulos de la malla: sus tres UV en píxeles del atlas y sus tres puntos en metros."""
    malla = objeto.data
    escala = objeto.scale
    capa = malla.uv_layers[0].data
    salida = []
    for poligono in malla.polygons:
        lazos = list(poligono.loop_indices)
        uvs = [(capa[i].uv.x * atlas.ancho, (1.0 - capa[i].uv.y) * atlas.alto) for i in lazos]
        puntos = []
        for i in lazos:
            c = malla.vertices[malla.loops[i].vertex_index].co
            puntos.append(Vector((c.x * escala.x, c.y * escala.y, c.z * escala.z)))
        for k in range(1, len(lazos) - 1):
            salida.append(((uvs[0], uvs[k], uvs[k + 1]), (puntos[0], puntos[k], puntos[k + 1])))
    return salida


def valores_singulares(par):
    """Los valores singulares, en metros por píxel, de la transformación en un triángulo."""
    (uvs, pts) = par
    e1, e2 = pts[1] - pts[0], pts[2] - pts[0]
    a = (uvs[1][0] - uvs[0][0], uvs[1][1] - uvs[0][1])
    b = (uvs[2][0] - uvs[0][0], uvs[2][1] - uvs[0][1])
    det = a[0] * b[1] - a[1] * b[0]
    if abs(det) < 1e-12:
        return None
    ix = (e1 * b[1] - e2 * a[1]) / det
    iy = (e2 * a[0] - e1 * b[0]) / det
    g11, g22, g12 = ix.dot(ix), iy.dot(iy), ix.dot(iy)
    media, resto = (g11 + g22) / 2, math.sqrt(((g11 - g22) / 2) ** 2 + g12**2)
    return math.sqrt(media + resto), math.sqrt(max(media - resto, 1e-18))


def dentro(par, rect, margen=1.0):
    x, y, ancho, alto = rect
    uvs = par[0]
    return all(
        x + margen <= u <= x + ancho - margen and y + margen <= v <= y + alto - margen
        for u, v in uvs
    )


def main() -> None:
    configurar()
    fallas = []
    for nombre, (clave, _) in armado.PAQUETES.items():
        objeto = bpy.data.objects[nombre]
        armado.armar(objeto, clave)
        caja = armado.caja_del_paquete(objeto, clave)
        atlas = recortes.disposicion(clave)
        todos = triangulos(objeto, atlas)
        print(f"\n{clave}: paquete de {caja.ancho:.3f} x {caja.alto:.4f} x {caja.fondo:.3f} m")
        ancho_f, alto_f = recortes.medida(recortes.RECORTES[clave][recortes.FRENTE])
        arte = 2 * caja.semiancho_de_arte
        largo_frente = forma.seccion(caja).largo_de_cada_panel[forma.FRENTE]
        relacion = recortes.relacion_del_frente(clave)
        desvio = (arte / largo_frente) / relacion - 1
        print(
            f"  frente del envase: {arte:.4f} x {largo_frente:.4f} m, "
            f"relación {arte / largo_frente:.4f}; "
            f"la del arte es {relacion:.4f} ({desvio * 100:+.2f} %)"
        )
        if abs(desvio) > TOLERANCIA:
            fallas.append(
                f"{clave}: el frente no tiene la proporción del arte ({desvio * 100:+.2f} %)"
            )
        for zona in (recortes.FRENTE, recortes.DORSO):
            rect = atlas.rects[zona]
            bajo_el_arte = [valores_singulares(p) for p in todos if dentro(p, rect)]
            bajo_el_arte = [s for s in bajo_el_arte if s is not None]
            if not bajo_el_arte:
                fallas.append(f"{clave} {zona}: ningún triángulo bajo el recorte")
                continue
            desvios = [max(a, b) / min(a, b) - 1 for a, b in bajo_el_arte]
            ancho_px, alto_px = rect[2], rect[3]
            esperada = ancho_px / arte
            densidades = [1 / math.sqrt(a * b) for a, b in bajo_el_arte]
            peor = max(desvios)
            media = sum(densidades) / len(densidades)
            bien = peor <= TOLERANCIA and abs(media / esperada - 1) <= TOLERANCIA
            marca = "" if bien else "  <-- FALLA"
            print(
                f"  {zona:7} {len(bajo_el_arte):3} triángulos bajo el recorte: estiramiento "
                f"{peor * 100:5.2f} %, {media:6.0f} px por metro "
                f"(el recorte da {esperada:.0f}){marca}"
            )
            if marca:
                fallas.append(f"{clave} {zona}: estiramiento {peor * 100:.2f} %")
        rect = atlas.rects[recortes.FRENTE]
        us = [u for p in todos if dentro(p, rect, -0.01) for u, _ in p[0]]
        vs = [v for p in todos if dentro(p, rect, -0.01) for _, v in p[0]]
        x, y, w, h = rect
        bordes = (min(us) - x, x + w - max(us), min(vs) - y, y + h - max(vs))
        print(
            "  el frente llega a los bordes de su recorte (píxeles que faltan: izquierda, derecha, "
            f"arriba, abajo): {tuple(round(b, 2) for b in bordes)}"
        )
        if max(abs(b) for b in bordes) > 1.0:
            fallas.append(f"{clave}: el arte del frente no llega a todos los bordes de su recorte")
    if fallas:
        print("\nFALLAS:\n  " + "\n  ".join(sorted(set(fallas))))
        raise SystemExit(1)
    print("\nsin estiramiento (menos del 1 %), con la proporción del arte y de borde a borde")


if __name__ == "__main__":
    main()
