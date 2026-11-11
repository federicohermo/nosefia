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
cantos lisos. El usuario pidió la banda lisa también al pie, sólo en el mueble de las heladeras:
en el mostrador y la compuerta los listones bajan hasta el acero. El usuario no quiere los
listones en geometría: los quiere en la textura. Con la luz horneada, la buña se lee por el
color: una línea oscura, que no es negra, con un filo de luz al lado.

## Qué cambia

- **La imagen** de 1024×1024 sale de la chapa CC0 `oak_veneer_01`, reentonada a `TONO`. Van
  ocho listones por vuelta, cada uno con su tramo de chapa y un tono apenas distinto. Los tres
  muebles se apilan de abajo hacia arriba, cada uno en una franja de su alto. Cada franja lleva
  arriba la banda lisa, con la veta acostada y una junta. La del mueble de las heladeras la
  lleva también al pie. La franja de arriba de todo es madera lisa para los cantos y las caras
  horizontales.
- **La UV** de las caras de `MOSTRADOR | Frente de madera` va en metros. En una cara vertical,
  `u` corre a lo ancho. Cada plano se corta en tramos en los bordes de sus caras, que son los
  bordes de los huecos y las esquinas. Cada tramo lleva listones enteros, y una buña cae en cada
  borde: el usuario no quiere una tira de listón cortada contra un hueco. Una cara lleva una sola
  grilla, que los huecos recortan: la buña sigue derecha arriba, abajo y a los costados de cada
  hueco. Por eso cada cara busca la cuenta de listones con los anchos más parejos, todos entre 9
  y 13 cm, y la diferencia entre tramos no se ve. Una cara toma el tramo por su centro: su borde
  cae a una milésima del borde del tramo, y por ahí puede tomar el vecino. `v` sube
  desde el pie de la madera de cada mueble. La compuerta usa el tope del mostrador, así sus
  bandas de arriba quedan a la misma altura. Una cara angosta (canto) y una cara horizontal van a
  la franja lisa.
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
#: El objeto, de quién toma el tope de la madera y si lleva la banda lisa al pie.
OBJETOS = {MOSTRADOR: (MOSTRADOR, False), "compuerta_mostrador": (MOSTRADOR, False),
           "mueble_continuo": ("mueble_continuo", True)}

# --- La imagen -------------------------------------------------------------------------------
LADO_PX = 1024
#: La chapa mide un metro por lado.
CHAPA_M = 1.0
#: Roble medio y cálido, en sRGB: entre la referencia y la versión que el usuario prefirió.
TONO = np.array([0.64, 0.44, 0.27], dtype=np.float32)
CONTRASTE = 0.85
LISTONES = 8
PERIODO = LADO_PX // LISTONES
#: El ancho de un listón. Un tramo que no es múltiplo lo estira o lo achica, entre el mínimo y el
#: máximo.
ANCHO_LISTON = 0.11
ANCHO_MINIMO = 0.09
ANCHO_MAXIMO = 0.13
#: Una vuelta de `u` en metros, en las caras lisas.
VUELTA_U = LISTONES * ANCHO_LISTON
#: Cada período: la buña, el borde en sombra, el listón y el filo de luz antes de la buña que
#: sigue. La buña se oscurece hacia el borde en sombra.
BUNA = np.array([0.62, 0.48, 0.42, 0.40, 0.40, 0.42, 0.46, 0.52], dtype=np.float32)
#: El borde de un tramo cae en el medio de una buña: media buña de cada lado de la esquina.
MEDIA_BUNA = len(BUNA) / 2 / LADO_PX
SOMBRA = 0.84
FILO = np.array([1.12, 1.22], dtype=np.float32)
VARIACION = 0.035

#: Filas por metro en vertical: los tres muebles suman 5,1 m.
FILAS_POR_M = 184
BANDA_M = 0.065
FILAS_BANDA = round(BANDA_M * FILAS_POR_M)
#: Filas de banda arriba y abajo de cada franja: los chaflanes del mostrador asoman.
MARGEN = 3
#: La junta entre la banda y los listones: la fila de la banda en sombra, dos filas de buña y
#: un filo.
JUNTA = (0.86, 0.45, 0.45, 1.14)
#: Las filas mínimas de la franja lisa de los cantos y las caras horizontales.
FILAS_LISAS = 32
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


def apilar(altos: list[float]) -> tuple[list[int], int]:
    """La fila del pie de cada mueble en la imagen, y la primera fila de la franja lisa."""
    pies, fila = [], 0
    for alto in altos:
        pies.append(fila + MARGEN)
        fila += 2 * MARGEN + round(alto * FILAS_POR_M)
    if fila + FILAS_LISAS > LADO_PX:
        raise ValueError(f"los muebles piden {fila} filas y la imagen tiene {LADO_PX}")
    return pies, fila


def juntar(imagen: np.ndarray, borde: int, paso: int) -> None:
    """La junta entre una banda y los listones. `borde` es la fila de la banda que toca los
    listones, y `paso` va de la banda hacia los listones."""
    for i, factor in enumerate(JUNTA):
        fila = borde + i * paso
        imagen[fila] = imagen[fila].mean(axis=0) * factor if 0 < i < 3 else imagen[fila] * factor


def pintar(chapa: np.ndarray, altos: list[float], con_pie: list[bool]) -> np.ndarray:
    """La imagen entera, (LADO_PX, LADO_PX, 3) en sRGB 0..1, con la fila 0 abajo.

    `chapa` es la foto del enchapado, (alto, ancho, 3) en sRGB, con la veta en vertical y que
    se repite en los dos ejes. `altos` es el alto en metros de la madera de cada mueble, y
    `con_pie` dice si lleva la banda lisa al pie.
    """
    azar = np.random.default_rng(SEMILLA)
    media = chapa.reshape(-1, 3).mean(axis=0)
    chapa = (media + (chapa - media) * CONTRASTE) * (TONO / media)
    px_por_m = chapa.shape[1] / CHAPA_M
    imagen = np.zeros((LADO_PX, LADO_PX, 3), dtype=np.float32)
    pies, filas = apilar(altos)

    ancho_liston = round(ANCHO_LISTON * px_por_m)
    for k in range(LISTONES):
        x, y = azar.integers(0, chapa.shape[1]), azar.integers(0, chapa.shape[0])
        madera = remuestrear(
            tramo(chapa, x, y, ancho_liston, round(filas / FILAS_POR_M * px_por_m)),
            filas,
            PERIODO,
        )
        madera *= (1.0 + azar.normal(0.0, VARIACION)) * (
            1.0 + azar.normal(0.0, VARIACION / 3, size=3)
        ).astype(np.float32)
        izquierda = k * PERIODO
        imagen[:filas, izquierda:izquierda + PERIODO] = madera
        lisa = madera.mean(axis=1, keepdims=True)
        buna = slice(izquierda, izquierda + len(BUNA))
        imagen[:filas, buna] = lisa * BUNA[None, :, None]
        imagen[:filas, izquierda + len(BUNA)] *= SOMBRA
        fin = izquierda + PERIODO
        imagen[:filas, fin - len(FILO):fin] *= FILO[None, :, None]

    # La banda lleva la veta acostada. Una vuelta de chapa entra entera: se repite en `u`. Cada
    # banda sale de otro tramo de chapa.
    acostada = np.rot90(chapa)
    alto_banda = FILAS_BANDA + MARGEN

    def banda() -> np.ndarray:
        y = azar.integers(0, acostada.shape[0])
        crudo = tramo(acostada, 0, y, acostada.shape[1], round(alto_banda / FILAS_POR_M * px_por_m))
        return remuestrear(crudo, alto_banda, LADO_PX)

    for pie, alto, banda_al_pie in zip(pies, altos, con_pie):
        tope = pie + round(alto * FILAS_POR_M)
        imagen[tope - FILAS_BANDA:tope + MARGEN] = banda()
        juntar(imagen, tope - FILAS_BANDA, -1)
        if banda_al_pie:
            imagen[pie - MARGEN:pie + FILAS_BANDA] = banda()
            juntar(imagen, pie + FILAS_BANDA - 1, 1)

    liso = remuestrear(
        tramo(chapa, chapa.shape[1] // 3, 0, chapa.shape[1], chapa.shape[0] // 2),
        LADO_PX - filas,
        LADO_PX,
    )
    imagen[filas:] = liso
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


def alturas(objeto) -> list[float]:
    return [q[2] for _, puntos, _ in caras_de_madera(objeto) for q in puntos]


def cuantos(largos: list[float]) -> list[int]:
    """Cuántos listones lleva cada tramo de un plano: los anchos más parejos entre el mínimo y el
    máximo, y entre los igual de parejos, los más cerca de `ANCHO_LISTON`."""
    if not largos:
        return []
    mejor, cuenta = None, []
    for ancho in np.arange(ANCHO_MINIMO, ANCHO_MAXIMO + 1e-9, 0.0005):
        n = [max(1, round(largo / ancho)) for largo in largos]
        anchos = [largo / k for largo, k in zip(largos, n)]
        if min(anchos) < ANCHO_MINIMO - 1e-9 or max(anchos) > ANCHO_MAXIMO + 1e-9:
            continue
        costo = (round(max(anchos) / min(anchos), 4), abs(sum(anchos) / len(anchos) - ANCHO_LISTON))
        if mejor is None or costo < mejor:
            mejor, cuenta = costo, n
    if mejor is None:
        raise ValueError(f"ningún ancho entre {ANCHO_MINIMO} y {ANCHO_MAXIMO} m divide {largos}")
    return cuenta


def tramos(caras: list[tuple[float, float]]) -> list[tuple[float, float, float, int]]:
    """Corta un plano en tramos: (inicio, fin, ancho del listón, índice del primer listón).

    `caras` es el alcance a lo ancho de cada cara del plano. Los bordes de los tramos son los de
    las caras, salvo el que cae adentro de otra cara: un chaflán asoma unos milímetros.
    """
    bordes = sorted({round(x, 3) for cara in caras for x in cara})
    bordes = [x for x in bordes if not any(a + 1e-3 < x < b - 1e-3 for a, b in caras)]
    pares = list(zip(bordes, bordes[1:]))
    cortes, indice = [], 0
    for (a, b), n in zip(pares, cuantos([b - a for a, b in pares])):
        cortes.append((a, b, (b - a) / n, indice))
        indice += n
    return cortes


def a_lo_ancho(normal: np.ndarray) -> np.ndarray:
    """La dirección a la derecha de quien mira la cara de frente."""
    derecha = np.array([-normal[1], normal[0], 0.0])
    return derecha / np.linalg.norm(derecha)


def repartir(a: float, b: float, valores) -> list:
    """Lleva `valores` al tramo [a, b] de `v`."""
    bajo, alto = min(valores), max(valores)
    return [a + (x - bajo) / max(alto - bajo, 1e-6) * (b - a) for x in valores]


def uv_de(objeto, z_pie: float, fila_pie: int, v_liso: tuple[float, float]) -> list[str]:
    """Escribe la UV de las caras de madera. Devuelve el ancho de los listones de cada plano."""
    capa = objeto.data.uv_layers.active.data
    caras = caras_de_madera(objeto)
    planos: dict = defaultdict(list)
    for p, puntos, normal in caras:
        if abs(normal[2]) > 0.7:
            continue
        ancho = a_lo_ancho(normal)
        s = [float(q @ ancho) for q in puntos]
        clave = (tuple(np.round(ancho, 2)), round(float(puntos[0] @ np.array(
            [normal[0], normal[1], 0.0])) / np.linalg.norm(normal[:2]), 1))
        planos[clave].append((p, puntos, s))
    anchos = []
    for clave, del_plano in planos.items():
        cortes = tramos([(min(s), max(s)) for _, _, s in del_plano if max(s) - min(s) >= CANTO_M])
        if cortes:
            anchos.append(" ".join(f"{(b - a) * 100:.0f}/{w * 100:.1f}" for a, b, w, _ in cortes))
        for p, puntos, s in del_plano:
            if max(s) - min(s) < CANTO_M:
                us = [(x - min(s)) / VUELTA_U for x in s]
                vs = repartir(*v_liso, [q[2] for q in puntos])
            else:
                centro = (min(s) + max(s)) / 2
                a, _, w, indice = next(c for c in cortes if c[0] <= centro < c[1])
                us = [(indice + (x - a) / w) / LISTONES + MEDIA_BUNA for x in s]
                vs = [(fila_pie + (q[2] - z_pie) * FILAS_POR_M) / LADO_PX for q in puntos]
            for bucle, u, v in zip(p.loop_indices, us, vs):
                capa[bucle].uv = (u, v)
    for p, puntos, normal in caras:
        if abs(normal[2]) <= 0.7:
            continue
        xs, ys = [q[0] for q in puntos], [q[1] for q in puntos]
        largo, corto = (xs, ys) if max(xs) - min(xs) >= max(ys) - min(ys) else (ys, xs)
        for bucle, u, v in zip(p.loop_indices, largo, repartir(*v_liso, corto)):
            capa[bucle].uv = ((u - min(largo)) / VUELTA_U, v)
    return anchos


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
    pies_z = {nombre: min(alturas(bpy.data.objects[nombre])) for nombre in OBJETOS}
    altos = [max(alturas(bpy.data.objects[de_quien])) - pies_z[nombre]
             for nombre, (de_quien, _) in OBJETOS.items()]
    con_pie = [banda_al_pie for _, banda_al_pie in OBJETOS.values()]
    escribir_png(pintar(leer_chapa(), altos, con_pie), destino)
    enlazar_imagen(destino, relativa=aplicar)
    filas_pie, filas = apilar(altos)
    v_liso = (filas / LADO_PX + 0.008, 0.992)
    for nombre, fila_pie in zip(OBJETOS, filas_pie):
        objeto = bpy.data.objects[nombre]
        anchos = uv_de(objeto, pies_z[nombre], fila_pie, v_liso)
        print(f"{nombre}: tramos en cm, largo/listón: {' | '.join(anchos)}")
    print("imagen:", destino)
    if aplicar:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
