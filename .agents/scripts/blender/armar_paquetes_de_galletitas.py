"""Arma de nuevo los paquetes de Oremos y de Pepito: un flow pack con cierres prensados a los lados.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/armar_paquetes_de_galletitas.py -- [--aplicar] \
        [--oremos <png>] [--pepito <png>]

Sin `--aplicar` no toca el `.blend` del repo: guarda `reports/paquetes-de-galletitas.blend`. Con
`--aplicar` guarda la fuente canónica. La textura de cada paquete sale de `source/`, o de la ruta
que se le dé con `--oremos` y `--pepito`. **Tiene que ser del desplegado nuevo**, de
`LIENZO_ANCHO` x `LIENZO_ALTO`: con otra medida el script se corta, porque la UV caería sobre
arte que no es el suyo. Después van `armar_atlas.py`, `exportar_modelo.py` y
`assets/models/extraer_mallas.gd`.

## Por qué

Los dos paquetes eran un cubo de ocho vértices: una caja lisa con el arte estirado sobre sus caras.
Se leían como una caja de cartón y no como el envase de galletitas que son. La forma de `lib/` es
la del flow pack de tres tubos: cuerpo ancho y bajo, casi plano de frente y apenas abombado, que se
afina hacia cada costura, y un cierre prensado, de borde recto, a la izquierda y a la derecha.

## Qué cambia

Cada malla se rehace entera con **el ancho y el fondo de la caja** que ocupaba el cubo, así que
entran las mismas unidades por estante y por caja, y el paso de la partida de prueba es el mismo.
El alto baja a la proporción apaisada de un flow pack real (`lib/paquete_de_galletitas.py`): el
paquete apoya por la base y queda más bajo. Las unidades que comparten la malla la heredan. La UV
sale del desplegado de `lib/paquete_de_galletitas.py`, y los cierres son los de
`lib/cierre_de_envases.py`, los mismos de las bolsas.

La caja del cubo se guarda en la malla la primera vez: correrlo de nuevo rehace el mismo paquete.
"""

import math
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
    "oremos-col": ("OREMOS", "oremos_paquete.png"),
    "pepitos2-col.025": ("PEPITO", "pepito_paquete.png"),
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


def caja_del_paquete(objeto, producto: str) -> "forma.Caja":
    """El ancho y el fondo son los del cubo; el alto, el de la proporción del producto."""
    x0, x1, y0, y1, _, _ = caja_del_cubo(objeto)
    escala = objeto.scale
    ancho = (y1 - y0) * escala.y
    return forma.Caja(
        ancho=ancho, fondo=(x1 - x0) * escala.x, alto=forma.alto_del_paquete(producto, ancho)
    )


def armar(objeto, producto: str) -> tuple[int, int]:
    """Rehace la malla del objeto. Devuelve los triángulos de antes y de después."""
    malla = objeto.data
    antes = sum(len(p.vertices) - 2 for p in malla.polygons)
    x0, x1, y0, y1, z0, z1 = caja_del_cubo(objeto)
    escala = objeto.scale
    caja = caja_del_paquete(objeto, producto)
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

    def recorridos_del_anillo(g: float) -> list[tuple[float, float]]:
        """Dónde cae cada gajo de un anillo en el recorrido de su panel, medido sobre ese anillo:
        donde el cuerpo se afina el techo y el piso se angostan, y la `v` los sigue."""
        puntos = [(x * g, z) for x, z in secc.puntos]
        salida = []
        acumulado = 0.0
        for k in range(len(puntos)):
            if k == 0 or secc.tramos[k] != secc.tramos[k - 1]:
                acumulado = 0.0
            m = (k + 1) % len(puntos)
            paso = math.hypot(puntos[m][0] - puntos[k][0], puntos[m][1] - puntos[k][1])
            largo = secc.largo_de_cada_panel[secc.tramos[k]]
            salida.append((acumulado / largo, (acumulado + paso) / largo))
            acumulado += paso
        return salida

    recorridos = [
        recorridos_del_anillo(forma.grosor_en(y, caja, espesor)) for y in ys
    ]

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
            ids = [anillos[i][k], anillos[i][m], anillos[i + 1][m], anillos[i + 1][k]]
            fk = abs(secc.puntos[k][0]) / (caja.fondo / 2)
            fm = abs(secc.puntos[m][0]) / (caja.fondo / 2)
            esquinas = [
                (ys[i], recorridos[i][k][0], fk),
                (ys[i], recorridos[i][k][1], fm),
                (ys[i + 1], recorridos[i + 1][k][1], fm),
                (ys[i + 1], recorridos[i + 1][k][0], fk),
            ]
            uvs = [
                forma.uv_en_el_panel(
                    rects[panel],
                    forma.u_del_cuerpo(panel, y, caja, f),
                    forma.v_del_cuerpo(panel, r),
                )
                for y, r, f in esquinas
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


def apuntar_la_textura(objeto, ruta: Path) -> Path:
    """Cambia la imagen del material del paquete por la del desplegado nuevo."""
    if not ruta.is_file():
        raise SystemExit(f"falta la textura {ruta}")
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    medida = tuple(imagen.size)
    if medida != (forma.LIENZO_ANCHO, forma.LIENZO_ALTO):
        bpy.data.images.remove(imagen)
        raise SystemExit(
            f"{ruta.name} mide {medida[0]}x{medida[1]} y el desplegado pide "
            f"{forma.LIENZO_ANCHO}x{forma.LIENZO_ALTO}: no es la textura de este desplegado"
        )
    bpy.data.images.remove(imagen)
    material = objeto.material_slots[0].material
    for nodo in material.node_tree.nodes:
        if nodo.type != "TEX_IMAGE":
            continue
        actual = Path(bpy.path.abspath(nodo.image.filepath)) if nodo.image else None
        if actual is not None and actual.resolve() == ruta.resolve():
            continue
        viejo = nodo.image
        nueva = bpy.data.images.load(str(ruta), check_existing=False)
        nueva.filepath = bpy.path.relpath(str(ruta))
        nueva.colorspace_settings.name = "sRGB"
        nodo.image = nueva
        # La imagen conserva el nombre de la anterior: es el que lleva el `.glb`, y de él salen el
        # nombre de la textura extraída y las rutas de los `.res`.
        if viejo is not None and viejo.users == 0:
            nombre = viejo.name
            bpy.data.images.remove(viejo)
            nueva.name = nombre
    return ruta


def argumento(nombre: str) -> Path | None:
    if nombre in sys.argv:
        return Path(sys.argv[sys.argv.index(nombre) + 1]).resolve()
    return None


def main() -> None:
    configurar()
    aplicar = "--aplicar" in sys.argv
    elegidas = {"OREMOS": argumento("--oremos"), "PEPITO": argumento("--pepito")}
    for nombre, (producto, archivo) in PAQUETES.items():
        objeto = bpy.data.objects[nombre]
        print(f"{nombre}: {objeto.data.users} unidades")
        ruta = elegidas[producto] or CARPETA_DE_TEXTURAS / archivo
        apuntar_la_textura(objeto, ruta)
        antes, despues = armar(objeto, producto)
        caja = caja_del_paquete(objeto, producto)
        print(
            f"  {antes} -> {despues} triángulos, textura {ruta.name}, paquete de "
            f"{caja.ancho:.3f} x {caja.alto:.3f} x {caja.fondo:.3f} m (ancho, alto, fondo)"
        )
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
