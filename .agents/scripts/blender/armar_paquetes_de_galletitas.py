"""Arma Oremos y Pepito como el paquete que dibuja su propio desplegado.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/armar_paquetes_de_galletitas.py -- [--aplicar]

Sin `--aplicar` no guarda el `.blend`: deja seis vistas de cada paquete en
`reports/paquetes-de-galletitas/`. Con `--aplicar` guarda la fuente. Después van `armar_atlas.py`,
`exportar_modelo.py`, `extraer_mallas.gd` y el resto de la cadena.

## Por qué

El arte de cada paquete ya es el desplegado de un envase de film: un FRONT con sus dos cierres
prensados pintados a los costados, un BACK, un TOP y un BOTTOM. La caja de 27 × 27 cm estiraba
ese frente apaisado sobre una cara cuadrada.

**La textura no se toca: la malla toma sus medidas de los paneles.** El frente de la malla tiene
la proporción del FRONT y lo lee entero. Los cierres del arte caen sobre las aletas, el TOP sobre
el canto de arriba y el BOTTOM sobre el de abajo. No hay textura nueva, ni pieza movida, ni cara
estirada.

## Lo que no entra entero

- **El dorso.** El BACK es más apaisado que el frente. Llena el dorso entero, estirado en alto:
  es la única cara que se estira, y sólo se ve con el paquete en la mano y dado vuelta.
- **Las esquinas del FRONT.** Vienen redondeadas sobre negro. Las aletas saltean esas filas.
- **Los dientes de los cierres pintados.** El panel se recorta hasta la primera columna llena:
  el cierre queda recto.

## Lo que conserva

El centro de la unidad, su apoyo y su ancho a lo largo del estante. Las copias comparten la
malla, así que no hay que acomodar de nuevo. Es idempotente: el ancho se lee de `ANCHO`, no de
la malla que encuentra.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import bpy  # type: ignore[import-not-found]
import numpy as np  # type: ignore[import-not-found]  # el que trae Blender
from mathutils import Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

FUENTES = RAIZ / "assets/source/products-textured/galletitas"
REPORTES = RAIZ / "reports/paquetes-de-galletitas"

#: Un punto adentro de cada panel del desplegado, en píxeles con el origen arriba a la izquierda.
PAQUETES = {
    "oremos": {
        "objeto": "oremos-col",
        "imagen": "oremos.png",
        "semillas": {
            "frente": (630, 450), "dorso": (630, 890), "tapa": (630, 100), "base": (630, 1146),
        },
    },
    "pepito": {
        "objeto": "pepitos2-col.025",
        "imagen": "pepito.png",
        "semillas": {
            "frente": (627, 520), "dorso": (627, 940), "tapa": (627, 115), "base": (627, 1160),
        },
    },
}
#: El ancho del paquete a lo largo del estante, con los cierres adentro, en metros. Las columnas
#: de su tanda están a 32 cm: con 30 queda 1 cm de aire a cada lado.
ANCHO = 0.30
#: Lo que mide cada cierre pintado, como fracción del ancho del panel del frente.
ALETA = 0.07
#: El espesor del cuerpo en su centro, en metros.
FONDO = 0.036
#: Lo mínimo que sube el lomo de arriba y baja el de abajo, en metros.
LOMO_MINIMO = 0.008
#: En cuántas costillas se parte el cuerpo de una costura a la otra.
SEGMENTOS = 12
#: Cuántos píxeles se deja adentro del borde de cada panel, para que el filtro no lea el negro.
BORDE = 2.0
#: Por debajo de este brillo un píxel es el fondo negro del desplegado.
NEGRO = 0.10


def cargar(ruta: Path):
    """Los píxeles de la imagen, con la fila 0 arriba."""
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    ancho, alto = imagen.size
    pixeles = np.array(imagen.pixels[:], dtype=np.float32).reshape(alto, ancho, 4)[::-1]
    bpy.data.images.remove(imagen)
    return pixeles


def panel(mascara, semilla: tuple[int, int]) -> tuple[int, int, int, int]:
    """La caja del panel que contiene a la semilla: crece hasta una fila o columna negra."""
    sx, sy = semilla
    banda = slice(sx - 40, sx + 40)
    y0 = y1 = sy
    while y0 > 0 and mascara[y0 - 1, banda].any():
        y0 -= 1
    while y1 < mascara.shape[0] - 1 and mascara[y1 + 1, banda].any():
        y1 += 1
    x0 = x1 = sx
    while x0 > 0 and mascara[y0:y1 + 1, x0 - 1].any():
        x0 -= 1
    while x1 < mascara.shape[1] - 1 and mascara[y0:y1 + 1, x1 + 1].any():
        x1 += 1
    x1, y1 = x1 + 1, y1 + 1
    # Los bordes del panel vienen dentados: se recorta hasta la primera columna que el arte llena
    # casi entera, y el cierre queda recto.
    while mascara[y0 + 6:y1 - 6, x0].mean() < 0.98:
        x0 += 1
    while mascara[y0 + 6:y1 - 6, x1 - 1].mean() < 0.98:
        x1 -= 1
    while mascara[y0, x0:x1].mean() < 0.9:
        y0 += 1
    while mascara[y1 - 1, x0:x1].mean() < 0.9:
        y1 -= 1
    return (x0, y0, x1, y1)


def esquinas(mascara, caja: tuple[int, int, int, int]) -> tuple[int, int]:
    """Cuántas filas de arriba y de abajo traen negro en los dos cierres pintados del panel.

    Las esquinas del panel vienen redondeadas. El cuerpo no las lee, y las aletas las saltean.
    """
    x0, y0, x1, y1 = caja
    franja = max(8, int((x1 - x0) * ALETA) + 2)

    def llena(y: int) -> bool:
        return bool(mascara[y, x0:x0 + franja].all() and mascara[y, x1 - franja:x1].all())

    arriba = abajo = 0
    while not llena(y0 + arriba):
        arriba += 1
    while not llena(y1 - 1 - abajo):
        abajo += 1
    return arriba + 1, abajo + 1


def punto_del_borde(pixeles, caja: tuple[int, int, int, int], fila: int) -> tuple[float, float]:
    """El píxel de una fila del panel que más se parece al color medio de esa fila.

    De ahí sale el color liso del canto de cada aleta.
    """
    x0, _, x1, _ = caja
    margen = int((x1 - x0) * (ALETA + 0.03))
    tramo = pixeles[fila, x0 + margen:x1 - margen, :3]
    medio = np.median(tramo, axis=0)
    cerca = int(np.abs(tramo - medio).sum(axis=1).argmin())
    return (x0 + margen + cerca + 0.5, fila + 0.5)


def armar(nombre: str, datos: dict):
    objeto = bpy.data.objects.get(datos["objeto"])
    if objeto is None:
        raise SystemExit(f"falta el objeto {datos['objeto']}")
    pixeles = cargar(FUENTES / datos["imagen"])
    lado = pixeles.shape[0]
    mascara = pixeles[:, :, :3].max(axis=2) > NEGRO
    frente, dorso, tapa, base = (
        panel(mascara, datos["semillas"][clave]) for clave in ("frente", "dorso", "tapa", "base")
    )

    escala = objeto.matrix_world.to_scale()
    viejos = [Vector(v.co) for v in objeto.data.vertices]
    centro_x = (max(v.x for v in viejos) + min(v.x for v in viejos)) / 2
    centro_y = (max(v.y for v in viejos) + min(v.y for v in viejos)) / 2
    piso = min(v.z for v in viejos)

    alto = ANCHO * (frente[3] - frente[1]) / (frente[2] - frente[0])
    fondo = FONDO
    cuerpo = ANCHO * (1 - 2 * ALETA)

    def lomo(caja) -> float:
        """Cuánto sale el lomo para que el panel del canto lo cubra entero sin estirarse."""
        faldon = ANCHO * (caja[3] - caja[1]) / (caja[2] - caja[0]) / 2
        return max(LOMO_MINIMO, math.sqrt(max(0.0, faldon ** 2 - (fondo / 2) ** 2)))

    lomo_de_arriba, lomo_de_abajo = lomo(tapa), lomo(base)
    cima, quilla = alto + lomo_de_arriba, -lomo_de_abajo

    liso_x, liso_y = punto_del_borde(pixeles, dorso, dorso[1] + 3)
    color = (liso_x / lado, 1 - liso_y / lado)
    de_arriba, de_abajo = esquinas(mascara, frente)

    def uv(caja, u: float, v: float, espejo: bool = False) -> tuple[float, float]:
        """`u` de izquierda a derecha y `v` de abajo hacia arriba, de 0 a 1, adentro del panel."""
        x0, y0, x1, y1 = caja
        if espejo:
            u = 1 - u
        x = x0 + BORDE + u * (x1 - x0 - 2 * BORDE)
        y = y1 - BORDE - v * (y1 - y0 - 2 * BORDE)
        return (x / lado, 1 - y / lado)

    def uv_de_aleta(u: float, v: float, espejo: bool = False) -> tuple[float, float]:
        x0, y0, x1, y1 = frente
        return uv((x0, y0 + de_arriba, x1, y1 - de_abajo), u, v, espejo)

    bm = bmesh.new()
    capa = bm.loops.layers.uv.new("UVMap")
    vertices: dict[tuple[float, float, float], object] = {}

    def vertice(x: float, y: float, z: float):
        clave = (round(x, 6), round(y, 6), round(z, 6))
        if clave not in vertices:
            vertices[clave] = bm.verts.new((
                centro_x + x / escala.x,
                centro_y + y / escala.y,
                piso + (z + lomo_de_abajo) / escala.z,
            ))
        return vertices[clave]

    def cara(puntos, uvs) -> None:
        nueva = bm.faces.new([vertice(*p) for p in puntos])
        nueva.smooth = True
        for lazo, par in zip(nueva.loops, uvs):
            lazo[capa].uv = par

    def medio(i: int) -> float:
        """Medio espesor del cuerpo en la costilla `i`: máximo al centro, casi nada en la costura."""
        s = 2 * i / SEGMENTOS - 1
        return max(0.0012, (fondo / 2) * (1 - abs(s) ** 3) ** 0.7)

    ys = [-cuerpo / 2 + cuerpo * i / SEGMENTOS for i in range(SEGMENTOS + 1)]
    us = [(y + ANCHO / 2) / ANCHO for y in ys]
    for i in range(SEGMENTOS):
        a, c = medio(i), medio(i + 1)
        ya, yc, ua, uc = ys[i], ys[i + 1], us[i], us[i + 1]
        cara(
            [(a, ya, 0), (c, yc, 0), (c, yc, alto), (a, ya, alto)],
            [uv(frente, ua, 0), uv(frente, uc, 0), uv(frente, uc, 1), uv(frente, ua, 1)],
        )
        cara(
            [(-c, yc, 0), (-a, ya, 0), (-a, ya, alto), (-c, yc, alto)],
            [uv(dorso, uc, 0, True), uv(dorso, ua, 0, True), uv(dorso, ua, 1, True),
             uv(dorso, uc, 1, True)],
        )
        # Cada canto es un lomo de dos faldones: el del frente lee la mitad del panel que da al
        # frente, y el del dorso la otra.
        cara(
            [(a, ya, alto), (c, yc, alto), (0, yc, cima), (0, ya, cima)],
            [uv(tapa, ua, 0), uv(tapa, uc, 0), uv(tapa, uc, 0.5), uv(tapa, ua, 0.5)],
        )
        cara(
            [(0, ya, cima), (0, yc, cima), (-c, yc, alto), (-a, ya, alto)],
            [uv(tapa, ua, 0.5), uv(tapa, uc, 0.5), uv(tapa, uc, 1), uv(tapa, ua, 1)],
        )
        cara(
            [(c, yc, 0), (a, ya, 0), (0, ya, quilla), (0, yc, quilla)],
            [uv(base, uc, 1), uv(base, ua, 1), uv(base, ua, 0.5), uv(base, uc, 0.5)],
        )
        cara(
            [(0, yc, quilla), (0, ya, quilla), (-a, ya, 0), (-c, yc, 0)],
            [uv(base, uc, 0.5), uv(base, ua, 0.5), uv(base, ua, 0), uv(base, uc, 0)],
        )
    fino = medio(0)
    for adentro, afuera in ((-cuerpo / 2, -ANCHO / 2), (cuerpo / 2, ANCHO / 2)):
        ya, yc = sorted((adentro, afuera))
        ua, uc = (ya + ANCHO / 2) / ANCHO, (yc + ANCHO / 2) / ANCHO
        # La aleta llega de la quilla a la cima.
        cara(
            [(fino, ya, quilla), (fino, yc, quilla), (fino, yc, cima), (fino, ya, cima)],
            [uv_de_aleta(ua, 0), uv_de_aleta(uc, 0), uv_de_aleta(uc, 1), uv_de_aleta(ua, 1)],
        )
        cara(
            [(-fino, yc, quilla), (-fino, ya, quilla), (-fino, ya, cima), (-fino, yc, cima)],
            [uv_de_aleta(uc, 0, True), uv_de_aleta(ua, 0, True), uv_de_aleta(ua, 1, True),
             uv_de_aleta(uc, 1, True)],
        )
        canto = [
            (fino, afuera, quilla), (-fino, afuera, quilla),
            (-fino, afuera, cima), (fino, afuera, cima),
        ]
        cara(canto if afuera > 0 else canto[::-1], [color] * 4)
    bm.normal_update()

    malla = objeto.data
    for modificador in list(objeto.modifiers):
        objeto.modifiers.remove(modificador)
    materiales = list(malla.materials)
    bm.to_mesh(malla)
    bm.free()
    malla.materials.clear()
    malla.materials.append(materiales[0])
    malla.set_sharp_from_angle(angle=math.radians(35))
    malla.update()
    for nodo in materiales[0].node_tree.nodes:
        if nodo.type == "TEX_IMAGE" and nodo.image is not None:
            nodo.image.filepath = "//..\\source\\products-textured\\galletitas\\" + datos["imagen"]
            nodo.image.reload()
    triangulos = sum(len(p.vertices) - 2 for p in malla.polygons)
    print(
        f"{nombre}: {ANCHO:.3f} de ancho, {cima - quilla:.4f} de alto ({alto:.4f} de frente), "
        f"{fondo:.4f} de fondo, "
        f"{triangulos} triángulos, {malla.users} unidades"
    )
    return objeto


def fotografiar(objetos: dict) -> None:
    escena = bpy.context.scene
    escena.render.engine = "BLENDER_WORKBENCH"
    escena.display.shading.light = "STUDIO"
    escena.display.shading.color_type = "TEXTURE"
    escena.render.resolution_x, escena.render.resolution_y = 1000, 720
    lente = bpy.data.cameras.new("foto")
    lente.lens = 70
    camara = bpy.data.objects.new("foto", lente)
    escena.collection.objects.link(camara)
    escena.camera = camara
    REPORTES.mkdir(parents=True, exist_ok=True)
    for nombre, objeto in objetos.items():
        for otro in bpy.data.objects:
            otro.hide_render = otro.name != objeto.name
        mundo = [objeto.matrix_world @ v.co for v in objeto.data.vertices]
        centro = Vector(
            [(max(p[i] for p in mundo) + min(p[i] for p in mundo)) / 2 for i in range(3)]
        )
        giro = objeto.matrix_world.to_3x3()
        adelante, derecha, arriba = [
            (giro @ Vector(eje)).normalized() for eje in ((1, 0, 0), (0, 1, 0), (0, 0, 1))
        ]
        vistas = {
            "frente": adelante,
            "tres_cuartos": adelante + derecha * 0.9 + arriba * 0.6,
            "desde_arriba": adelante * 0.7 + arriba - derecha * 0.4,
            "dorso": -adelante + derecha * 0.3 + arriba * 0.25,
            "desde_abajo": adelante * 0.6 - arriba,
            "canto": derecha + adelante * 0.35 + arriba * 0.2,
        }
        for vista, direccion in vistas.items():
            camara.location = centro + direccion.normalized() * 0.75
            camara.rotation_euler = (centro - camara.location).to_track_quat("-Z", "Y").to_euler()
            escena.render.filepath = str(REPORTES / f"{nombre}_{vista}.png")
            bpy.ops.render.render(write_still=True)


def main() -> None:
    configurar()
    objetos = {nombre: armar(nombre, datos) for nombre, datos in PAQUETES.items()}
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        fotografiar(objetos)
        print(f"vistas en {REPORTES}")


if __name__ == "__main__":
    main()
