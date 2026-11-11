"""Pinta los listones del mostrador, su compuerta y el friso de las heladeras en la textura.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/listonar_frente_de_madera.py -- [--aplicar]

Sin `--aplicar` escribe la imagen en `build/madera/` y cambia sólo la sesión de Blender. Con
`--aplicar` escribe `assets/source/textures/store/madera_lambrin.png` y guarda el `.blend`.
Antes va `restaurar_madera_del_artista.py`. Después van `armar_atlas.py`, `exportar_modelo.py`,
`hornear.py` y `hornear.py --sin-luz`.

## Por qué

La referencia del usuario es el mostrador de una tienda de estación de servicio: listones
verticales de roble medio y cálido, una buña fina entre cada uno, una banda lisa arriba y los
cantos lisos. El usuario no quiere los listones en geometría: los quiere en la textura. Con la
luz horneada, la buña se lee por el color: una línea oscura, que no es negra, con un filo de luz
al lado.

## Qué cambia

- **La imagen** de 1024×1024 sale de la chapa CC0 `oak_veneer_01`, reentonada a `TONO`. Abajo
  van los listones: ocho de 11 cm por vuelta, cada uno con su tramo de chapa y un tono apenas
  distinto. Arriba de los listones va la banda lisa, con la veta acostada y una junta. La franja
  de arriba de todo es madera lisa para los cantos y las caras horizontales.
- **La UV** de las caras de `MOSTRADOR | Frente de madera` va en metros. En una cara vertical, `u`
  corre a lo ancho y empieza con un listón entero en el borde izquierdo de su plano. `v` baja
  desde la banda: el tope de la madera de cada mueble cae en la banda. La compuerta usa el tope
  del mostrador, así sus bandas quedan a la misma altura. Una cara angosta (canto) y una cara
  horizontal van a la franja lisa.
- **El material** apunta a la imagen. La malla no cambia.

## Lo que cuesta

Ningún triángulo, material ni dibujo más. La textura mide lo mismo que antes. Es determinista e
idempotente: la imagen y la UV salen sólo de la chapa y de la geometría.
"""

import sys
from collections import defaultdict
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / "assets/source/textures/store/madera_lambrin.png"
PRUEBA = RAIZ / "build" / "madera" / DESTINO.name
CHAPA = RAIZ / "assets/source/textures/third-party/oak_veneer_01/oak_veneer_01_diff_2k.jpg"
MATERIAL = "MOSTRADOR | Frente de madera"
SEMILLA = 20261111
MOSTRADOR = "EscritorioComputadora-col"
#: El objeto y de quién toma el tope de la madera.
OBJETOS = {MOSTRADOR: MOSTRADOR, "compuerta_mostrador": MOSTRADOR,
           "mueble_continuo": "mueble_continuo"}

# --- La imagen -------------------------------------------------------------------------------
LADO_PX = 1024
#: La chapa mide un metro por lado.
CHAPA_M = 1.0
#: Roble medio y cálido, en sRGB: entre la referencia y la versión que el usuario prefirió.
TONO = np.array([0.64, 0.44, 0.27], dtype=np.float32)
CONTRASTE = 0.85
LISTONES = 8
PERIODO = LADO_PX // LISTONES
#: Una vuelta de `u` en metros: ocho listones de 11 cm.
VUELTA_U = 0.88
#: Cada período: la buña, el borde en sombra, el listón y el filo de luz antes de la buña que
#: sigue. La buña se oscurece hacia el borde en sombra.
BUNA = np.array([0.62, 0.48, 0.42, 0.40, 0.40, 0.42, 0.46, 0.52], dtype=np.float32)
SOMBRA = 0.84
FILO = np.array([1.12, 1.22], dtype=np.float32)
VARIACION = 0.035

#: Las filas de los listones, de abajo hacia arriba, y cuántos metros entran: el friso mide 3,4.
FILAS_LISTONES = 896
V_POR_METRO = 0.25
BANDA_M = 0.065
FILAS_BANDA = round(BANDA_M * V_POR_METRO * LADO_PX)
#: La junta bajo la banda: la fila de abajo de la banda en sombra, dos filas de buña y un filo.
JUNTA = (0.86, 0.45, 0.45, 1.14)
#: La franja lisa de los cantos y las caras horizontales, en `v`, con margen a los lados.
V_LISO = (FILAS_LISTONES / LADO_PX + 0.008, 0.992)
#: Una cara vertical más angosta que esto es un canto.
CANTO_M = 0.10


def remuestrear(imagen: np.ndarray, alto: int, ancho: int) -> np.ndarray:
    """Promedia por área: achicar mucho una dirección no deja ruido de muestreo."""
    for eje, n in ((0, alto), (1, ancho)):
        largo = imagen.shape[eje]
        acumulado = np.concatenate(
            [np.zeros_like(np.take(imagen, [0], axis=eje)), np.cumsum(imagen, axis=eje)],
            axis=eje,
        )
        bordes = np.linspace(0.0, largo, n + 1)
        indices = np.arange(largo + 1)
        forma = [1] * imagen.ndim
        forma[eje] = n + 1
        sumas = np.apply_along_axis(lambda c: np.interp(bordes, indices, c), eje, acumulado)
        imagen = np.diff(sumas, axis=eje) / (largo / n)
    return imagen.astype(np.float32)


def tramo(chapa: np.ndarray, x: int, y: int, ancho: int, alto: int) -> np.ndarray:
    """Un rectángulo de la chapa que se repite, desde (x, y), en píxeles de la chapa."""
    filas = np.arange(y, y + alto) % chapa.shape[0]
    columnas = np.arange(x, x + ancho) % chapa.shape[1]
    return chapa[filas][:, columnas]


def pintar(chapa: np.ndarray) -> np.ndarray:
    """La imagen entera, (LADO_PX, LADO_PX, 3) en sRGB 0..1, con la fila 0 abajo.

    `chapa` es la foto del enchapado, (alto, ancho, 3) en sRGB, con la veta en vertical y que
    se repite en los dos ejes.
    """
    azar = np.random.default_rng(SEMILLA)
    media = chapa.reshape(-1, 3).mean(axis=0)
    chapa = (media + (chapa - media) * CONTRASTE) * (TONO / media)
    px_por_m = chapa.shape[1] / CHAPA_M
    imagen = np.zeros((LADO_PX, LADO_PX, 3), dtype=np.float32)

    alto_m = FILAS_LISTONES / LADO_PX / V_POR_METRO
    ancho_liston = round(VUELTA_U / LISTONES * px_por_m)
    for k in range(LISTONES):
        x, y = azar.integers(0, chapa.shape[1]), azar.integers(0, chapa.shape[0])
        madera = remuestrear(
            tramo(chapa, x, y, ancho_liston, round(alto_m * px_por_m)), FILAS_LISTONES, PERIODO
        )
        madera *= (1.0 + azar.normal(0.0, VARIACION)) * (
            1.0 + azar.normal(0.0, VARIACION / 3, size=3)
        ).astype(np.float32)
        izquierda = k * PERIODO
        imagen[:FILAS_LISTONES, izquierda:izquierda + PERIODO] = madera
        lisa = madera.mean(axis=1, keepdims=True)
        buna = slice(izquierda, izquierda + len(BUNA))
        imagen[:FILAS_LISTONES, buna] = lisa * BUNA[None, :, None]
        imagen[:FILAS_LISTONES, izquierda + len(BUNA)] *= SOMBRA
        fin = izquierda + PERIODO
        imagen[:FILAS_LISTONES, fin - len(FILO):fin] *= FILO[None, :, None]

    # La banda lleva la veta acostada. Una vuelta de chapa entra entera: se repite en `u`.
    acostada = np.rot90(chapa)
    banda = remuestrear(
        tramo(acostada, 0, 0, acostada.shape[1], round(BANDA_M * px_por_m)),
        FILAS_BANDA,
        LADO_PX,
    )
    imagen[FILAS_LISTONES - FILAS_BANDA:FILAS_LISTONES] = banda
    debajo = FILAS_LISTONES - FILAS_BANDA
    for i, factor in enumerate(JUNTA):
        fila = debajo - i
        imagen[fila] = imagen[fila].mean(axis=0) * factor if 0 < i < 3 else imagen[fila] * factor

    liso = remuestrear(
        tramo(chapa, chapa.shape[1] // 3, 0, chapa.shape[1], chapa.shape[0] // 2),
        LADO_PX - FILAS_LISTONES,
        LADO_PX,
    )
    imagen[FILAS_LISTONES:] = liso
    return np.clip(imagen, 0.0, 1.0)


# ---------------------------------------------------------------------------------------------
# Lo que sigue necesita Blender.
# ---------------------------------------------------------------------------------------------


def caras_de_madera(objeto) -> list:
    """Cada cara del frente: (polígono, puntos en el mundo, normal en el mundo)."""
    malla = objeto.data
    indices = {i for i, m in enumerate(malla.materials) if m is not None and m.name == MATERIAL}
    matriz = objeto.matrix_world
    giro = matriz.to_3x3()
    caras = []
    for p in malla.polygons:
        if p.material_index in indices:
            puntos = [np.array(matriz @ malla.vertices[v].co) for v in p.vertices]
            caras.append((p, puntos, np.array((giro @ p.normal).normalized())))
    return caras


def tope(objeto) -> float:
    return max(q[2] for _, puntos, _ in caras_de_madera(objeto) for q in puntos)


def a_lo_ancho(normal: np.ndarray) -> np.ndarray:
    """La dirección a la derecha de quien mira la cara de frente."""
    derecha = np.array([-normal[1], normal[0], 0.0])
    return derecha / np.linalg.norm(derecha)


def repartir(a: float, b: float, valores) -> list:
    """Lleva `valores` al tramo [a, b] de `v`."""
    bajo, alto = min(valores), max(valores)
    return [a + (x - bajo) / max(alto - bajo, 1e-6) * (b - a) for x in valores]


def uv_de(objeto, z_tope: float) -> int:
    """Escribe la UV de las caras de madera. Devuelve cuántas caras son listones."""
    capa = objeto.data.uv_layers.active.data
    caras = caras_de_madera(objeto)
    inicio_del_plano: dict = defaultdict(lambda: np.inf)
    verticales = []
    for p, puntos, normal in caras:
        if abs(normal[2]) > 0.7:
            continue
        ancho = a_lo_ancho(normal)
        s = [float(q @ ancho) for q in puntos]
        clave = (tuple(np.round(ancho, 2)), round(float(puntos[0] @ np.array(
            [normal[0], normal[1], 0.0])) / np.linalg.norm(normal[:2]), 1))
        verticales.append((p, puntos, s, clave))
        if max(s) - min(s) >= CANTO_M:
            inicio_del_plano[clave] = min(inicio_del_plano[clave], min(s))
    listones = 0
    for p, puntos, s, clave in verticales:
        if max(s) - min(s) < CANTO_M:
            us = [(x - min(s)) / VUELTA_U for x in s]
            vs = repartir(*V_LISO, [q[2] for q in puntos])
        else:
            listones += 1
            us = [(x - inicio_del_plano[clave]) / VUELTA_U + len(BUNA) / LADO_PX for x in s]
            vs = [FILAS_LISTONES / LADO_PX - (z_tope - q[2]) * V_POR_METRO for q in puntos]
        for bucle, u, v in zip(p.loop_indices, us, vs):
            capa[bucle].uv = (u, v)
    for p, puntos, normal in caras:
        if abs(normal[2]) <= 0.7:
            continue
        xs, ys = [q[0] for q in puntos], [q[1] for q in puntos]
        largo, corto = (xs, ys) if max(xs) - min(xs) >= max(ys) - min(ys) else (ys, xs)
        for bucle, u, v in zip(p.loop_indices, largo, repartir(*V_LISO, corto)):
            capa[bucle].uv = ((u - min(largo)) / VUELTA_U, v)
    return listones


def leer_chapa() -> np.ndarray:
    import bpy  # type: ignore[import-not-found]

    imagen = bpy.data.images.load(str(CHAPA), check_existing=False)
    ancho, alto = imagen.size
    pixeles = np.empty(ancho * alto * 4, dtype=np.float32)
    imagen.pixels.foreach_get(pixeles)
    bpy.data.images.remove(imagen)
    return pixeles.reshape(alto, ancho, 4)[..., :3].copy()


def enlazar_imagen(ruta: Path, relativa: bool) -> None:
    import bpy  # type: ignore[import-not-found]

    material = bpy.data.materials[MATERIAL]
    nodo = next(n for n in material.node_tree.nodes if n.type == "TEX_IMAGE")
    nodo.image = None
    for imagen in list(bpy.data.images):
        if imagen.filepath and Path(bpy.path.abspath(imagen.filepath)).name == ruta.name:
            bpy.data.images.remove(imagen)
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    if relativa:
        imagen.filepath = "//../source/textures/store/" + ruta.name
    imagen.colorspace_settings.name = "sRGB"
    nodo.image = imagen


def main() -> None:
    import bpy  # type: ignore[import-not-found]

    from detalle_de_plastico import escribir_png
    from lib.consola import configurar

    configurar()
    aplicar = "--aplicar" in sys.argv
    destino = DESTINO if aplicar else PRUEBA
    destino.parent.mkdir(parents=True, exist_ok=True)
    escribir_png(pintar(leer_chapa()), destino)
    enlazar_imagen(destino, relativa=aplicar)
    for nombre, de_quien in OBJETOS.items():
        objeto = bpy.data.objects[nombre]
        listones = uv_de(objeto, tope(bpy.data.objects[de_quien]))
        print(f"{nombre}: {listones} caras con listones, {len(objeto.data.polygons)} caras")
    print("imagen:", destino)
    if aplicar:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
