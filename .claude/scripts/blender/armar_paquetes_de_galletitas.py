"""Arma de nuevo los paquetes de Oremos y de Pepito: un flow pack con cierres prensados a los lados.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/armar_paquetes_de_galletitas.py -- [--aplicar]

Sin `--aplicar` no toca el `.blend` del repo: guarda `reports/paquetes-de-galletitas.blend`, con la
textura de `reports/paquetes-de-galletitas/` si existe. Con `--aplicar` guarda la fuente canónica,
con la textura de `source/`. Antes va `texturizar_paquetes_de_galletitas.py`. Después van
`armar_atlas.py`, `exportar_modelo.py` y `assets/models/extraer_mallas.gd`.

## Por qué

Los dos paquetes eran un cubo de ocho vértices: una caja lisa con el arte estirado sobre sus caras.
Se leían como una caja de cartón y no como el envase de galletitas que son. La forma de `lib/` es
la del flow pack de tres tubos: cuerpo ancho y bajo, casi plano de frente y apenas abombado, que se
afina hacia cada costura, y un cierre prensado y dentado a la izquierda y a la derecha.

## Qué cambia

Cada malla se rehace entera **dentro de la misma caja** que ocupaba el cubo: ancho, alto y fondo no
cambian, así que entran las mismas unidades por estante y por caja, y el paso de la partida de
prueba es el mismo. Las unidades que comparten la malla la heredan. La UV sale del desplegado de
`lib/paquete_de_galletitas.py`, y los cierres son los de `lib/cierre_de_envases.py`, los mismos
de las bolsas.

La caja del cubo se guarda en la malla la primera vez: correrlo de nuevo rehace el mismo paquete.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import paquete_de_galletitas as forma  # noqa: E402
from lib.cierre_de_envases import cierre  # noqa: E402
from lib.consola import configurar  # noqa: E402
from lib.repo import RAIZ  # noqa: E402

#: Una unidad de cada paquete, que comparte la malla con las demás, y la textura que lleva.
PAQUETES = {
    "oremos-col": "oremos_paquete.png",
    "pepitos2-col.025": "pepito_paquete.png",
}

CARPETA_DE_TEXTURAS = RAIZ / "assets/source/products-textured/galletitas"
CARPETA_DEL_REPORTE = RAIZ / "reports/paquetes-de-galletitas"
MARCA = "caja_del_paquete"


def caja_del_cubo(objeto) -> tuple[float, ...]:
    """Los límites locales que ocupaba el cubo. Se guardan la primera vez."""
    malla = objeto.data
    if MARCA not in malla:
        coordenadas = [tuple(v.co) for v in malla.vertices]
        malla[MARCA] = [f(c[i] for c in coordenadas) for i in range(3) for f in (min, max)]
    return tuple(malla[MARCA])


def armar(objeto) -> tuple[int, int]:
    """Rehace la malla del objeto. Devuelve los triángulos de antes y de después."""
    malla = objeto.data
    antes = sum(len(p.vertices) - 2 for p in malla.polygons)
    x0, x1, y0, y1, z0, z1 = caja_del_cubo(objeto)
    escala = objeto.scale
    caja = forma.Caja(
        ancho=(y1 - y0) * escala.y, fondo=(x1 - x0) * escala.x, alto=(z1 - z0) * escala.z
    )
    centro = ((x0 + x1) / 2, (y0 + y1) / 2)

    def a_local(x: float, y: float, z: float) -> tuple[float, float, float]:
        return (x / escala.x + centro[0], y / escala.y + centro[1], z / escala.z + z0)

    rects = forma.desplegado(caja)
    secc = forma.seccion(caja)
    ys = forma.alturas_de_los_anillos(caja)
    espesor = 0.002 / (caja.fondo / 2)
    zc = caja.alto / 2

    vertices: list[tuple[float, float, float]] = []
    caras: list[tuple[list[int], list[tuple[float, float]], bool]] = []

    anillos = []
    for y in ys:
        g = forma.grosor_en(y, caja, espesor)
        fila = []
        for x, z in secc.puntos:
            fila.append(len(vertices))
            vertices.append((x * g, y, z))
        anillos.append(fila)

    def hacia_afuera(ids: list[int], uvs: list[tuple[float, float]]):
        p = [vertices[i] for i in ids]
        normal = [0.0, 0.0, 0.0]
        for a, b in zip(p, p[1:] + p[:1]):
            normal[0] += (a[1] - b[1]) * (a[2] + b[2])
            normal[1] += (a[2] - b[2]) * (a[0] + b[0])
            normal[2] += (a[0] - b[0]) * (a[1] + b[1])
        medio = [sum(q[j] for q in p) / len(p) for j in range(3)]
        afuera = (medio[0], 0.0, medio[2] - zc)
        if sum(normal[j] * afuera[j] for j in range(3)) < 0:
            return ids[::-1], uvs[::-1]
        return ids, uvs

    n = len(secc.puntos)
    for i in range(len(ys) - 1):
        for k in range(n):
            m = (k + 1) % n
            panel = secc.tramos[k]
            r0, r1 = secc.recorrido[k]
            ids = [anillos[i][k], anillos[i][m], anillos[i + 1][m], anillos[i + 1][k]]
            esquinas = [(ys[i], r0), (ys[i], r1), (ys[i + 1], r1), (ys[i + 1], r0)]
            uvs = [
                forma.uv_en_el_panel(
                    rects[panel], forma.u_del_cuerpo(panel, y, caja), forma.v_del_cuerpo(panel, r)
                )
                for y, r in esquinas
            ]
            ids, uvs = hacia_afuera(ids, uvs)
            caras.append((ids, uvs, True))

    cuerpo = len(caras)
    semi = caja.semiancho_del_cuerpo
    for lado_de_y in (-1, 1):
        c = cierre(
            (0.0, lado_de_y * semi, 0.0), (0.0, 0.0, 1.0), caja.alto,
            (0.0, float(lado_de_y), 0.0), caja.salida_del_cierre, (1.0, 0.0, 0.0),
        )
        base = len(vertices)
        vertices.extend(c.vertices)
        for cara in c.caras:
            ids = [base + i for i in cara.vertices]
            uvs = [forma.uv_del_cierre(cara.lado, c.vertices[i][1], c.vertices[i][2], caja, rects)
                   for i in cara.vertices]
            caras.append((ids, uvs, False))

    malla.clear_geometry()
    malla.from_pydata([a_local(*v) for v in vertices], [], [ids for ids, _, _ in caras])
    malla.update()
    capa = malla.uv_layers.new(name="UVMap")
    for indice, (poligono, (_, uvs, suave)) in enumerate(zip(malla.polygons, caras)):
        poligono.use_smooth = suave
        for lazo, valor in zip(poligono.loop_indices, uvs):
            capa.data[lazo].uv = valor
    despues = sum(len(p.vertices) - 2 for p in malla.polygons)
    print(f"  cuerpo: {cuerpo} caras, cierres: {len(caras) - cuerpo} caras")
    return antes, despues


def apuntar_la_textura(objeto, archivo: str, aplicar: bool) -> Path:
    """Cambia la imagen del material del paquete por la del nuevo desplegado."""
    carpeta = CARPETA_DE_TEXTURAS if aplicar else CARPETA_DEL_REPORTE
    ruta = carpeta / archivo
    if not ruta.is_file():
        ruta = CARPETA_DE_TEXTURAS / archivo
    if not ruta.is_file():
        raise SystemExit(f"falta la textura {ruta}: corré texturizar_paquetes_de_galletitas.py")
    material = objeto.material_slots[0].material
    for nodo in material.node_tree.nodes:
        if nodo.type != "TEX_IMAGE":
            continue
        actual = Path(bpy.path.abspath(nodo.image.filepath)) if nodo.image else None
        if actual is not None and actual.resolve() == ruta.resolve():
            continue
        viejo = nodo.image
        imagen = bpy.data.images.load(str(ruta), check_existing=False)
        imagen.filepath = bpy.path.relpath(str(ruta))
        imagen.colorspace_settings.name = "sRGB"
        nodo.image = imagen
        # La imagen conserva el nombre de la anterior: es el que lleva el `.glb`, y de él salen el
        # nombre de la textura extraída y las rutas de los `.res`.
        if viejo is not None and viejo.users == 0:
            nombre = viejo.name
            bpy.data.images.remove(viejo)
            imagen.name = nombre
    return ruta


def main() -> None:
    configurar()
    aplicar = "--aplicar" in sys.argv
    for nombre, archivo in PAQUETES.items():
        objeto = bpy.data.objects[nombre]
        print(f"{nombre}: {objeto.data.users} unidades")
        antes, despues = armar(objeto)
        ruta = apuntar_la_textura(objeto, archivo, aplicar)
        print(f"  {antes} -> {despues} triángulos, textura {ruta.name}")
    if aplicar:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        destino = RAIZ / "reports/paquetes-de-galletitas.blend"
        destino.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
        print(f"prueba guardada en {destino}")


if __name__ == "__main__":
    main()
