"""Texturizar el frente del mostrador y el friso: enchapado claro de veta fina, en paneles parejos.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_frente_de_madera.py -- [--aplicar]

Sin `--aplicar` escribe la imagen en `build/madera/` y cambia sólo la sesión de Blender. Con
`--aplicar` escribe `assets/source/textures/store/madera_lambrin.png` y guarda el `.blend`.
Antes de este script va `quitar_molduras_del_friso.py`. Después va `exportar_modelo.py`.

## Por qué

El frente del mostrador y el friso de las heladeras eran un lambrín viejo: doce tablas de 15 cm
con nudos oscuros, veta gruesa, roces, manchas y una franja de zócalo. Sobre el friso, además,
corrían marcos en relieve de tres anchos distintos. Un local moderno lleva un enchapado de madera
clara: veta fina y pareja, el mismo tono en todos los paneles y una junta fina y recta.

## Qué cambia

- **Una imagen de 512×1024** que es UN panel: 52,5 cm de ancho por 1,5 m de alto. Lleva una veta
  recta que ondula apenas, sin nudos, y una junta fina en sus dos bordes verticales. Se repite
  hacia arriba sin costura. No lleva roces, manchas ni franjas horizontales.
- **Las UV** de todas las caras de madera de `mueble_continuo`, `compuerta_mostrador` y
  `EscritorioComputadora-col` se rehacen en metros del mundo. Cada cara de frente reparte su ancho
  en paneles iguales de unos 52 cm, y las juntas caen en sus bordes. Con una sola regla, las
  juntas del friso coinciden con los bordes de las heladeras (1,05 m = dos paneles) y el hueco del
  exhibidor queda en cuatro. La compuerta es una sola hoja.
- Las tiras finas, como un canto, y las caras de menos de media hoja no llevan junta: toman una
  franja del centro de un panel.
- **El material** `MOSTRADOR | Frente de madera` apunta a la imagen nueva.

## Lo que cuesta

Ningún triángulo, ningún material ni dibujo más. La textura pasa de 1024×1024 a 512×1024 (la
mitad de píxeles). Es determinista y idempotente.
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from detalle_de_madera import ruido, suave  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / "assets/source/textures/store/madera_lambrin.png"
PRUEBA = RAIZ / "build" / "madera" / DESTINO.name
MATERIAL = "MOSTRADOR | Frente de madera"
OBJETOS = ("mueble_continuo", "compuerta_mostrador", "EscritorioComputadora-col")
#: Los objetos cuyo frente es una sola hoja: no se parten en paneles.
UNA_HOJA = ("compuerta_mostrador",)

ANCHO_PX = 512
ALTO_PX = 1024
#: Lo que mide un panel: dos paneles son una heladera (1,05 m).
PANEL = 0.525
#: Lo que mide la imagen de alto, en metros. La imagen se repite hacia arriba.
ALTO_EN_METROS = 1.5
PISO = 0.1
SEMILLA = 20261111
#: Madera clara: roble pálido, en sRGB.
BASE = np.array([0.80, 0.665, 0.49], dtype=np.float32)
#: Una tira es de canto si es al menos tres veces más larga que alta, y de menos de 9 cm de alto.
ALTO_DE_CANTO = 0.09
VUELTA_DE_CANTO = 2.5
#: Una cara de frente más angosta que esto no lleva junta: toma una franja del panel.
ANCHO_MINIMO = PANEL / 2


def pintar() -> np.ndarray:
    """La imagen entera, (ALTO_PX, ANCHO_PX, 3) en sRGB 0..1, con la fila 0 abajo."""
    azar = np.random.default_rng(SEMILLA)
    alto, ancho = ALTO_PX, ANCHO_PX
    # La veta corre en vertical y se desvía unos píxeles a un lado y a otro.
    desvio = (ruido(alto, 1, 3, 1, azar, 2)[:, 0] - 0.5) * 14.0
    columnas = (np.arange(ancho)[None, :] + np.round(desvio).astype(int)[:, None]) % ancho
    filas = np.arange(alto)[:, None]
    fina = ruido(alto, ancho, 5, ancho // 2, azar, 1)[filas, columnas]
    media = ruido(alto, ancho, 3, ancho // 7, azar, 2)[filas, columnas]
    tono = ruido(alto, ancho, 2, 3, azar, 2)
    mezcla = 0.5 + (fina - 0.5) * 0.34 + (media - 0.5) * 0.30 + (tono - 0.5) * 0.18
    mezcla = np.clip(mezcla, 0.0, 1.0)[..., None]
    claro = np.clip(BASE * 1.045, 0, 1)
    oscuro = BASE * 0.90
    imagen = claro[None, None, :] * mezcla + oscuro[None, None, :] * (1 - mezcla)

    # La junta: un surco fino y recto en cada borde vertical. Cada borde lleva medio surco, y
    # dos paneles lado a lado lo completan.
    distancia = np.minimum(np.arange(ancho), ancho - 1 - np.arange(ancho)).astype(np.float32)
    surco = 1.0 - 0.52 * suave(1.6, 0.0, distancia) - 0.14 * suave(3.2, 0.8, distancia)
    imagen = imagen * surco[None, :, None]
    # La imagen conserva la luz media del color base: el detalle reparte la luz, no la cambia.
    imagen = imagen * (BASE.mean() / imagen.mean())
    return np.clip(imagen, 0.0, 1.0)


# ---------------------------------------------------------------------------------------------
# Lo que sigue necesita Blender.
# ---------------------------------------------------------------------------------------------


def uv_de_cara(puntos, normal, una_hoja: bool):
    """Las UV de las esquinas de una cara, en metros del mundo. Ver el docstring del módulo."""
    zs = [p[2] for p in puntos]
    alto = max(zs) - min(zs)
    if abs(normal[2]) >= 0.8:
        return [(p[0] / PANEL, p[1] / ALTO_EN_METROS) for p in puntos]
    hacia_x = abs(normal[0]) >= abs(normal[1])
    horizontal = [p[1] if hacia_x else p[0] for p in puntos]
    minimo, maximo = min(horizontal), max(horizontal)
    largo = maximo - minimo
    if alto <= ALTO_DE_CANTO and largo >= VUELTA_DE_CANTO * alto:
        centro = (max(zs) + min(zs)) / 2
        return [(0.5 + (p[2] - centro) / PANEL, (h - minimo) / ALTO_EN_METROS)
                for p, h in zip(puntos, horizontal)]
    if largo < ANCHO_MINIMO:
        centro = (maximo + minimo) / 2
        return [(0.5 + (h - centro) / PANEL, (p[2] - PISO) / ALTO_EN_METROS)
                for p, h in zip(puntos, horizontal)]
    paneles = 1 if una_hoja else max(1, round(largo / PANEL))
    ancho_del_panel = largo / paneles
    return [((h - minimo) / ancho_del_panel, (p[2] - PISO) / ALTO_EN_METROS)
            for p, h in zip(puntos, horizontal)]


def reasignar_uv(objeto, material) -> int:
    malla = objeto.data
    capa = malla.uv_layers.active.data
    indices = {i for i, ranura in enumerate(objeto.material_slots) if ranura.material == material}
    una_hoja = objeto.name in UNA_HOJA
    matriz = objeto.matrix_world
    cantidad = 0
    for cara in malla.polygons:
        if cara.material_index not in indices:
            continue
        puntos = [matriz @ malla.vertices[i].co for i in cara.vertices]
        normal = matriz.to_3x3() @ cara.normal
        for lazo, uv in zip(cara.loop_indices, uv_de_cara(puntos, normal, una_hoja)):
            capa[lazo].uv = uv
        cantidad += 1
    return cantidad


def enlazar_imagen(ruta: Path, relativa: bool):
    import bpy  # type: ignore[import-not-found]

    material = bpy.data.materials[MATERIAL]
    nodo = next(n for n in material.node_tree.nodes if n.type == "TEX_IMAGE")
    # Se suelta la imagen del nodo antes de borrar las del mismo nombre, y se borra todo lo que
    # quede sin usuarios: así corre igual la primera vez y las siguientes.
    nodo.image = None
    for imagen in list(bpy.data.images):
        if imagen.filepath and Path(bpy.path.abspath(imagen.filepath)).name == ruta.name:
            bpy.data.images.remove(imagen)
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    if relativa:
        imagen.filepath = "//../source/textures/store/" + ruta.name
    imagen.colorspace_settings.name = "sRGB"
    nodo.image = imagen
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
    material = bpy.data.materials[MATERIAL]
    for nombre in OBJETOS:
        print(nombre, "caras:", reasignar_uv(bpy.data.objects[nombre], material))
    print("imagen:", destino)
    if aplicar:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
