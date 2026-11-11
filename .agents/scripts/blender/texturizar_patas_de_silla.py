"""Texturizar las patas de madera de las sillas del salón: UV a lo largo y veta.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_patas_de_silla.py -- [--aplicar]

Sin `--aplicar` escribe la imagen en `build/madera/` y cambia sólo la sesión de Blender. Con
`--aplicar` escribe `assets/source/textures/store/silla_patas_madera.png` y guarda el `.blend`.
Va después de `moldear_silla_del_salon.py`, y otra vez cada vez que ese script rehace la malla:
las UV de las patas se rehacen acá. Después va `exportar_modelo.py`.

## Por qué

Las patas eran un color plano. La silla de plástico ya tiene uso en la carcasa, y al lado las
patas parecían de juguete. Una pata de madera torneada tiene veta a lo largo, algún nudo, el pie
gastado de arrastrarla por el piso y más oscura bajo el asiento.

## Qué cambia

- **Una imagen de 128×512** con la veta en vertical, un nudo y mugre. La parte de abajo es el
  pie: se aclara por el roce y termina en una línea oscura de suciedad. La franja de arriba, de
  la fila 497 a la 511, es el testero oscuro de los cortes.
- **Las UV** de las caras de `SILLA | Patas de madera` se rehacen con la `v` a lo largo de la
  pieza —en las patas, desde el pie— y la `u` alrededor, una vuelta por tile en los conos. Cada
  pata y cada travesaño toma su tramo de la imagen. Los tablones del bastidor llevan la `v` a lo
  largo del tablón. Las tapas de los conos y los extremos de los tablones leen el testero.
- **El material** `SILLA | Patas de madera` toma la imagen como color base.

## Lo que cuesta

Ningún triángulo ni material de más: la imagen es una textura nueva de 52 KB. Es determinista
e idempotente. Las seis sillas comparten una malla.
"""

import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from detalle_de_madera import (  # noqa: E402
    a_srgb,
    desenfocar,
    rayones,
    ruido,
    suave,
    tabla,
)

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / "assets/source/textures/store/silla_patas_madera.png"
PRUEBA = RAIZ / "build" / "madera" / DESTINO.name
MATERIAL = "SILLA | Patas de madera"
MALLA = "salon_silla"

ANCHO, ALTO = 128, 512
SEMILLA = 20261112
#: El color de siempre de las patas, en lineal, como lo guarda el material.
BASE_LINEAL = (0.2633, 0.1193, 0.0397)
#: Cuántos metros de pieza entran en la altura de la imagen, y en su ancho.
METROS_EN_V = 0.65
METROS_EN_U = 0.125
#: Desde esta fila hasta el tope de la imagen está el testero.
FILA_DEL_TESTERO = 497
V_DEL_TESTERO = (FILA_DEL_TESTERO + 7) / ALTO


def pintar() -> np.ndarray:
    """La imagen entera, (ALTO, ANCHO, 3) en sRGB 0..1, con la fila 0 abajo."""
    azar = np.random.default_rng(SEMILLA)
    base = a_srgb(BASE_LINEAL)
    claro, oscuro = np.clip(base * 1.22, 0, 1), np.clip(base * 0.74, 0, 1)
    imagen = tabla(ALTO, ANCHO, azar, claro, oscuro, nudos=1, contraste=0.9, anillos=3)
    filas = np.arange(ALTO, dtype=np.float32)[:, None] * np.ones((1, ANCHO), dtype=np.float32)

    # El pie: el roce lo aclara, y la línea del piso deja mugre.
    roce = suave(70, 4, filas) * (0.5 + 0.7 * ruido(ALTO, ANCHO, 6, 8, azar, 2))
    imagen = imagen + (np.array([0.93, 0.78, 0.55]) - imagen) * (0.26 * np.clip(roce, 0, 1))[..., None]
    imagen = imagen * (1 - 0.65 * suave(7, 0.5, filas))[..., None]
    # Más oscura bajo el asiento y manchada por las manos al arrastrar la silla.
    imagen = imagen * (1 - 0.22 * suave(380, 470, filas))[..., None]
    manchas = suave(0.6, 0.9, ruido(ALTO, ANCHO, 4, 4, azar, 3))
    imagen = imagen * (1 - 0.16 * manchas)[..., None]
    # Rayones a lo largo y unos golpes cruzados cerca del pie.
    largos = rayones(ALTO, ANCHO, 36, 120, azar, angulo=np.pi / 2, dispersion=0.05)
    golpes = rayones(ALTO, ANCHO, 18, 20, azar, peso=suave(260, 0, filas))
    imagen = imagen * (1 - 0.2 * largos)[..., None]
    imagen = imagen * (1 - 0.34 * golpes)[..., None]
    imagen = imagen + (np.array([0.96, 0.82, 0.6]) - imagen) * (0.16 * rayones(ALTO, ANCHO, 18, 80, azar, angulo=np.pi / 2, dispersion=0.08))[..., None]
    imagen = imagen * (0.96 + 0.08 * desenfocar(ruido(ALTO, ANCHO, 8, 4, azar, 2), 2))[..., None]

    # El testero de los cortes: oscuro, con anillos de crecimiento.
    anillos = 0.5 + 0.5 * np.sin(np.abs(np.arange(ANCHO)[None, :] - ANCHO / 2) / 12.0 * 2 * math.pi)
    alto_t = ALTO - FILA_DEL_TESTERO
    testero = (oscuro * 0.7)[None, None, :] * (0.8 + 0.3 * anillos)[..., None]
    imagen[FILA_DEL_TESTERO:] = np.broadcast_to(testero, (alto_t, ANCHO, 3))
    return np.clip(imagen, 0.0, 1.0)


# ---------------------------------------------------------------------------------------------
# Lo que sigue necesita Blender.
# ---------------------------------------------------------------------------------------------


def _componentes(malla, indices_de_material):
    """Los grupos de caras de patas que comparten vértices: cada pata, cada tablón."""
    padre = {}

    def raiz(i):
        while padre.setdefault(i, i) != i:
            padre[i] = padre[padre[i]]
            i = padre[i]
        return i

    caras = [p for p in malla.polygons if p.material_index in indices_de_material]
    for p in caras:
        primero = raiz(p.vertices[0])
        for i in p.vertices[1:]:
            padre[raiz(i)] = primero
    grupos = {}
    for p in caras:
        grupos.setdefault(raiz(p.vertices[0]), []).append(p)
    return sorted(grupos.values(), key=lambda g: (round(g[0].center.z, 3), round(g[0].center.x, 3), round(g[0].center.y, 3)))


def _centro(malla, cara):
    return sum((malla.vertices[i].co for i in cara.vertices), malla.vertices[0].co * 0) / len(cara.vertices)


def uv_del_componente(malla, caras, numero: int) -> dict:
    """Las UV por lazo de cada cara de una pata, de un travesaño o de un tablón."""
    from mathutils import Vector  # type: ignore[import-not-found]

    tapas = [c for c in caras if len(c.vertices) > 4]
    salida = {}
    desplazamiento = (numero * 0.173) % 1.0
    testero = (0.5, 0.985)
    if tapas:
        centros = sorted((_centro(malla, c) for c in tapas), key=lambda p: p.z)
        pie, tope = centros[0], centros[-1]
        eje = (tope - pie).normalized()
        ejes = Vector((1, 0, 0)) if abs(eje.x) < 0.9 else Vector((0, 1, 0))
        e1 = eje.cross(ejes).normalized()
        e2 = eje.cross(e1)
        for cara in caras:
            if len(cara.vertices) > 4:
                salida[cara.index] = [testero] * len(cara.vertices)
                continue
            vueltas, v = [], []
            for i in cara.vertices:
                relativo = malla.vertices[i].co - pie
                a_lo_largo = relativo.dot(eje)
                radial = relativo - eje * a_lo_largo
                vueltas.append(math.atan2(radial.dot(e2), radial.dot(e1)) / (2 * math.pi))
                v.append(a_lo_largo / METROS_EN_V)
            referencia = vueltas[0]
            vueltas = [t - round(t - referencia) for t in vueltas]
            salida[cara.index] = [(t + desplazamiento, vv) for t, vv in zip(vueltas, v)]
        return salida

    # Un tablón: seis caras, el eje va de una punta a la otra.
    extremos = sorted(caras, key=lambda c: c.area)[:2]
    indices_extremos = {c.index for c in extremos}
    inicio, fin = (_centro(malla, c) for c in extremos)
    eje = (fin - inicio).normalized()
    for k, cara in enumerate(caras):
        if cara.index in indices_extremos:
            salida[cara.index] = [testero] * len(cara.vertices)
            continue
        lateral = cara.normal.cross(eje).normalized()
        base = _centro(malla, cara)
        pares = []
        for i in cara.vertices:
            relativo = malla.vertices[i].co - inicio
            pares.append((relativo.dot(lateral) / METROS_EN_U + desplazamiento + 0.31 * k, relativo.dot(eje) / METROS_EN_V))
        salida[cara.index] = pares
    return salida


def reasignar_uv(malla) -> dict:
    material = bpy_material()
    indices = {i for i, m in enumerate(malla.materials) if m == material}
    capa = malla.uv_layers.active.data
    cuentas = {"patas": 0, "tablones": 0}
    for numero, caras in enumerate(_componentes(malla, indices)):
        uv = uv_del_componente(malla, caras, numero)
        for cara in caras:
            for lazo, valor in zip(cara.loop_indices, uv[cara.index]):
                capa[lazo].uv = valor
        cuentas["patas" if any(len(c.vertices) > 4 for c in caras) else "tablones"] += 1
    return cuentas


def bpy_material():
    import bpy  # type: ignore[import-not-found]

    return bpy.data.materials[MATERIAL]


def enlazar_imagen(ruta: Path, relativa: bool):
    import bpy  # type: ignore[import-not-found]

    material = bpy_material()
    arbol = material.node_tree
    principal = next(n for n in arbol.nodes if n.type == "BSDF_PRINCIPLED")
    nodo = next((n for n in arbol.nodes if n.type == "TEX_IMAGE"), None) or arbol.nodes.new("ShaderNodeTexImage")
    for imagen in list(bpy.data.images):
        if imagen.filepath and Path(bpy.path.abspath(imagen.filepath)).name == ruta.name:
            bpy.data.images.remove(imagen)
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    if relativa:
        imagen.filepath = "//../source/textures/store/" + ruta.name
    imagen.colorspace_settings.name = "sRGB"
    nodo.image = imagen
    nodo.interpolation = "Linear"
    arbol.links.new(nodo.outputs["Color"], principal.inputs["Base Color"])
    return imagen


def main() -> None:
    import bpy  # type: ignore[import-not-found]

    from detalle_de_plastico import escribir_png
    from lib.consola import configurar

    configurar()
    aplicar = "--aplicar" in sys.argv
    destino = DESTINO if aplicar else PRUEBA
    destino.parent.mkdir(parents=True, exist_ok=True)
    escribir_png(pintar(), destino)
    enlazar_imagen(destino, relativa=aplicar)
    malla = bpy.data.meshes[MALLA]
    print(MALLA, reasignar_uv(malla), "usuarios:", malla.users)
    malla.update()
    print("imagen:", destino)
    if aplicar:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
