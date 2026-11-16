"""Mide sobre la malla que el desplegado de Oremos y de Pepito no estira y es parejo.

    blender <archivo>.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/verificar_paquetes_de_galletitas.py

No guarda nada. Arma en memoria cada paquete con su forma y su UV, y en cada panel mide, sobre los
triángulos de su zona segura del arte, la transformación de la UV a metros:

- **Si estira:** la relación entre los dos valores singulares. Con 1, un píxel mide lo mismo en x
  que en y. Falla si el peor triángulo se desvía más del 2 %.
- **Cuántos píxeles por metro lleva:** la media geométrica de los dos. Tiene que ser la del
  desplegado en todos los paneles, con 2 % de tolerancia: la misma densidad en todas las caras.

Además comprueba que la UV de la malla cae dentro del rectángulo de su panel.
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
from lib.consola import configurar  # noqa: E402

TOLERANCIA = 0.02


def triangulos_por_panel(objeto, rects):
    """Los triángulos de cada panel: sus tres UV en píxeles de la hoja y sus tres puntos en
    metros."""
    malla = objeto.data
    escala = objeto.scale
    capa = malla.uv_layers[0].data
    por_panel = {panel: [] for panel in rects}
    for poligono in malla.polygons:
        lazos = list(poligono.loop_indices)
        uvs = [
            (capa[i].uv.x * forma.LIENZO_ANCHO, (1.0 - capa[i].uv.y) * forma.LIENZO_ALTO)
            for i in lazos
        ]
        puntos = []
        for i in lazos:
            c = malla.vertices[malla.loops[i].vertex_index].co
            puntos.append(Vector((c.x * escala.x, c.y * escala.y, c.z * escala.z)))
        centro = (sum(u[0] for u in uvs) / len(uvs), sum(u[1] for u in uvs) / len(uvs))
        panel = next(
            (
                n
                for n, (x, y, w, h) in rects.items()
                if x <= centro[0] <= x + w and y <= centro[1] <= y + h
            ),
            None,
        )
        if panel is None:
            continue
        for k in range(1, len(lazos) - 1):
            triangulo = ((uvs[0], uvs[k], uvs[k + 1]), (puntos[0], puntos[k], puntos[k + 1]))
            por_panel[panel].append(triangulo)
    return por_panel


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


def main() -> None:
    configurar()
    fallas = []
    for nombre, (clave, _) in armado.PAQUETES.items():
        objeto = bpy.data.objects[nombre]
        armado.armar(objeto, clave)
        caja = armado.caja_del_paquete(objeto, clave)
        zonas = forma.zonas(caja)
        rects = forma.desplegado(caja)
        esperada = forma.densidad(caja)
        triangulos = triangulos_por_panel(objeto, rects)
        print(f"\n{clave}: paquete de {caja.ancho:.3f} x {caja.alto:.3f} x {caja.fondo:.3f} m")
        print(f"  densidad del desplegado: {esperada:.0f} px por metro")
        for panel in forma.PANELES:
            x0, y0, w, h = zonas[panel]["zona_segura"]
            bajo_el_arte = []
            for par in triangulos[panel]:
                cx = sum(u[0] for u in par[0]) / 3
                cy = sum(u[1] for u in par[0]) / 3
                if x0 <= cx <= x0 + w and y0 <= cy <= y0 + h:
                    s = valores_singulares(par)
                    if s is not None:
                        bajo_el_arte.append(s)
            if not bajo_el_arte:
                fallas.append(f"{clave} {panel}: ningún triángulo bajo su zona segura")
                continue
            desvios = [max(a, b) / min(a, b) - 1 for a, b in bajo_el_arte]
            densidades = [1 / math.sqrt(a * b) for a, b in bajo_el_arte]
            peor, media = max(desvios), sum(densidades) / len(densidades)
            diferencia = media / esperada - 1
            marca = ""
            if peor > TOLERANCIA or abs(diferencia) > TOLERANCIA:
                marca = "  <-- FALLA"
                fallas.append(
                    f"{clave} {panel}: estiramiento {peor * 100:.1f} %, "
                    f"densidad {diferencia * 100:+.1f} %"
                )
            print(
                f"  {panel:7} {len(bajo_el_arte):3} triángulos bajo la zona segura: estiramiento "
                f"{peor * 100:4.1f} %, {media:6.0f} px por metro ({diferencia * 100:+.1f} %){marca}"
            )
        for panel, (x, y, w, h) in rects.items():
            for uvs, _ in triangulos[panel]:
                for u, v in uvs:
                    if not (x - 0.5 <= u <= x + w + 0.5 and y - 0.5 <= v <= y + h + 0.5):
                        fallas.append(f"{clave} {panel}: una UV cae fuera de su panel")
                        break
                else:
                    continue
                break
    if fallas:
        print("\nFALLAS:\n  " + "\n  ".join(sorted(set(fallas))))
        raise SystemExit(1)
    print("\nsin estiramiento y con la misma densidad en todas las caras, dentro del 2 %")


if __name__ == "__main__":
    main()
