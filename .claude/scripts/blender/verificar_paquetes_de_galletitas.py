"""Mide sobre la malla que la textura de Oremos y de Pepito no quedó estirada. Corre en Blender.

    blender <archivo>.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/verificar_paquetes_de_galletitas.py

No guarda nada. Sale con error si algo se estira más del 2 %. Lee
`reports/paquetes-de-galletitas/composicion_*.json`, que escribe
`texturizar_paquetes_de_galletitas.py`, y mide dos cosas:

- **La relación de aspecto de cada pieza**, en metros sobre la malla: el ancho y el alto de su
  rectángulo, recorridos sobre la superficie, contra la relación de aspecto de su recorte en el arte
  original. Un cuerpo curvo y afinado no se mide por su proyección.
- **Los texeles por metro en x y en y** de la UV del frente y del dorso, en cada triángulo: la
  relación entre los dos valores singulares de la transformación de la UV a metros. Con 1 no hay
  estiramiento. Una superficie con doble curvatura no se desarrolla sin corte: en las cuatro
  esquinas del arte, donde el afinado del costado se junta con el hombro, el corte llega a un 6 %.
  Falla si más del 20 % de los triángulos pasa del 2 % o si alguno pasa del 7 %.
"""

import json
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
from lib.repo import RAIZ  # noqa: E402

TOLERANCIA = 0.02
MUESTRAS = 48
REPORTE = RAIZ / "reports/paquetes-de-galletitas"
COMPOSICIONES = {
    "oremos-col": "composicion_oremos_paquete.json",
    "pepitos2-col.025": "composicion_pepito_paquete.json",
}


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


def punto_en_metros(triangulos, px, py):
    for uvs, pts in triangulos:
        (ax, ay), (bx, by), (cx, cy) = uvs
        det = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
        if abs(det) < 1e-12:
            continue
        l1 = ((by - cy) * (px - cx) + (cx - bx) * (py - cy)) / det
        l2 = ((cy - ay) * (px - cx) + (ax - cx) * (py - cy)) / det
        l3 = 1 - l1 - l2
        if min(l1, l2, l3) >= -1e-6:
            return pts[0] * l1 + pts[1] * l2 + pts[2] * l3
    return None


def largo_de_la_linea(triangulos, desde, hasta):
    anterior = None
    total = 0.0
    for i in range(MUESTRAS + 1):
        t = i / MUESTRAS
        px = desde[0] + (hasta[0] - desde[0]) * t
        py = desde[1] + (hasta[1] - desde[1]) * t
        punto = punto_en_metros(triangulos, px, py)
        if punto is None:
            raise ValueError(f"la línea {desde} -> {hasta} sale de la malla")
        if anterior is not None:
            total += (punto - anterior).length
        anterior = punto
    return total


def isotropia(par):
    """Los valores singulares de la transformación de píxeles de la hoja a metros, en un
    triángulo."""
    (uvs, pts) = par
    e1, e2 = pts[1] - pts[0], pts[2] - pts[0]
    a = (uvs[1][0] - uvs[0][0], uvs[1][1] - uvs[0][1])
    b = (uvs[2][0] - uvs[0][0], uvs[2][1] - uvs[0][1])
    det = a[0] * b[1] - a[1] * b[0]
    if abs(det) < 1e-12:
        return None
    # d(metros)/d(px_x) y d(metros)/d(px_y): la inversa de [a b] aplicada a [e1 e2].
    ix = (e1 * b[1] - e2 * a[1]) / det
    iy = (e2 * a[0] - e1 * b[0]) / det
    g11, g22, g12 = ix.dot(ix), iy.dot(iy), ix.dot(iy)
    media, resto = (g11 + g22) / 2, math.sqrt(((g11 - g22) / 2) ** 2 + g12**2)
    mayor, menor = math.sqrt(media + resto), math.sqrt(max(media - resto, 1e-18))
    return mayor / menor


def main() -> None:
    configurar()
    fallas = []
    for nombre, archivo in COMPOSICIONES.items():
        objeto = bpy.data.objects[nombre]
        x0, x1, y0, y1, z0, z1 = armado.caja_del_cubo(objeto)
        caja = forma.Caja(
            (y1 - y0) * objeto.scale.y, (x1 - x0) * objeto.scale.x, (z1 - z0) * objeto.scale.z
        )
        rects = forma.desplegado(caja)
        triangulos = triangulos_por_panel(objeto, rects)
        composicion = json.loads((REPORTE / archivo).read_text(encoding="utf-8"))["piezas"]
        print(f"\n{nombre}: aspecto de cada pieza, en metros sobre la malla")
        print(
            f"  {'panel':8} {'pieza':22} {'original':>9} {'en la malla':>12} {'error':>7}  "
            "texeles/m x, y"
        )
        for pieza in composicion:
            x, y, ancho, alto = pieza["rect_en_la_hoja"]
            tri = triangulos[pieza["panel"]]
            w_m = largo_de_la_linea(tri, (x, y + alto / 2), (x + ancho, y + alto / 2))
            h_m = largo_de_la_linea(tri, (x + ancho / 2, y), (x + ancho / 2, y + alto))
            original = pieza["tamano_original"][0] / pieza["tamano_original"][1]
            medido = w_m / h_m
            error = medido / original - 1
            marca = "" if abs(error) <= TOLERANCIA else "  <-- SE ESTIRA"
            print(
                f"  {pieza['panel']:8} {pieza['pieza']:22} {original:9.3f} {medido:12.3f} "
                f"{error * 100:+6.1f}%  {ancho / w_m:6.0f}, {alto / h_m:6.0f}{marca}"
            )
            if abs(error) > TOLERANCIA:
                fallas.append(f"{nombre} {pieza['panel']} {pieza['pieza']}: {error * 100:+.1f} %")
        for panel in (forma.FRENTE, forma.DORSO):
            piezas = [p["rect_en_la_hoja"] for p in composicion if p["panel"] == panel]
            ux0 = min(p[0] for p in piezas)
            ux1 = max(p[0] + p[2] for p in piezas)
            uy0 = min(p[1] for p in piezas)
            uy1 = max(p[1] + p[3] for p in piezas)
            razones = []
            lugares = []
            for par in triangulos[panel]:
                uvs = par[0]
                cx = sum(u[0] for u in uvs) / 3
                cy = sum(u[1] for u in uvs) / 3
                if ux0 <= cx <= ux1 and uy0 <= cy <= uy1:
                    r = isotropia(par)
                    if r is not None:
                        razones.append(r)
                        px, py = round(cx - rects[panel][0]), round(cy - rects[panel][1])
                        lugares.append((r, px, py))
            peor = max(razones)
            razones.sort()
            fuera = sum(1 for r in razones if r - 1 > TOLERANCIA)
            print(
                f"  {panel}: {fuera} de {len(razones)} triángulos pasan del 2 %; "
                f"mediana {100 * (razones[len(razones) // 2] - 1):.1f} %; "
                "peores en (x, y del panel): "
                f"{[(x, y, round(100 * (r - 1), 1)) for r, x, y in sorted(lugares)[-4:]]}"
            )
            print(
                f"  {panel}: {len(razones)} triángulos bajo el arte, "
                "texeles por metro en x / en y: "
                f"de {1 / peor:.3f} a {peor:.3f} (peor desvío {100 * (peor - 1):.1f} %)"
            )
            if fuera > 0.2 * len(razones) or peor - 1 > 0.07:
                fallas.append(f"{nombre} {panel}: UV anisótropa, desvío {100 * (peor - 1):.1f} %")
    if fallas:
        print("\nFALLAS:\n  " + "\n  ".join(fallas))
        raise SystemExit(1)
    print("\nninguna pieza pasa del 2 %: la UV queda dentro de lo que admite una superficie curva")


if __name__ == "__main__":
    main()
