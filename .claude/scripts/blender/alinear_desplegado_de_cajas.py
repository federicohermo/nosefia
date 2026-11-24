"""Alinea el desplegado en cruz y la cinta de las etiquetas de cajas en `assets/source/boxes/`.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/alinear_desplegado_de_cajas.py -- [--aplicar]

Sin `--aplicar` verifica la alineación en memoria sin escribir archivos. Con `--aplicar` actualiza
sólo los PNG de `assets/source/boxes/` que todavía estén corridos. Después van
`assets/models/corregir_uv_cajas.gd`, `armar_atlas.py` y `godot --headless --path . --import`.

## Por qué

Las 32 texturas de `assets/source/boxes/*.png` (1254x1254) despliegan cinco caras en cruz sobre
cuartos de `[0, 1]`, pero varias traen la cruz corrida hasta 17 píxeles dejando fondo negro adentro
del panel (`coracola`, `pepitos`, `feel_ricky_fort`, `chisitos`), la cinta descentrada o inclinada
entre la tapa y el frente (`coracola` +14 px, `cosa_de_mani` inclinada, `donsaturados` ahusada,
`duronga` escalonada), y el extremo exterior de la cinta inferior cortado en flecos antes del borde
(`y ~ 1198..1219`). Como la cara `-X` refleja `u` respecto de `+Y` y `-Y` (`u_{-X} = 1 - u_{+Y}`),
cualquier corrimiento respecto de `u = 0,5` duplica el salto de posición al cruzar la arista.

## Qué cambia

- Lleva los cinco paneles de cada PNG exactamente a la grilla de cuartos (`X1 = 314`, `X2 = 939`,
  `Y1 = 314`, `Y2 = 939`) mediante remuestreo por vecino más cercano, sin alisar ni redibujar el
  arte pixelado.
- Centra y endereza la cinta de embalar en `[574, 679]` (106 px simétricos respecto de `626,5`, es
  decir `u = 0,5`) en la tapa, en los dos tramos del frente y en la base, conservando intactos el
  logo, el código de barras, el rótulo lateral y los íconos de fragilidad.
- Extiende el tramo sólido propio de la cinta inferior hasta `y = 1253` dentro de las columnas de
  la cinta para que tampoco se corte antes de cruzar la arista inferior.
- No toca `SEPT_JUEGOS_PROTOTIPO.blend`: las cajas leen sus texturas desde `assets/source/boxes/`.

## Lo que cuesta

0 triángulos, 0 materiales y 0 llamadas de dibujo nuevas. Es idempotente: correrlo una segunda vez
detecta las 32 texturas ya alineadas y no reescribe ningún archivo.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

configurar()

CARPETA_CAJAS = RAIZ / "assets/source/boxes"
LADO = 1254
X1, X2 = 314, 939
Y1, Y2 = 314, 939
CINTA_IZQ, CINTA_DER = 574, 679


def _luminancia(rgb: np.ndarray) -> np.ndarray:
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def _extremos_1d(mascara: np.ndarray) -> tuple[int, int]:
    indices = np.where(mascara)[0]
    return int(indices[0]), int(indices[-1])


def _bordes_cinta(lum: np.ndarray, y0: int, y1: int) -> tuple[int, int]:
    perfil = lum[y0:y1, :].mean(axis=0)
    gradiente = np.diff(perfil)
    izq = 550 + int(np.argmax(gradiente[550:608])) + 1
    der = 662 + int(np.argmin(gradiente[662:712]))
    return izq, der


def medir(rgb: np.ndarray) -> dict:
    """Mide los pliegues, los bordes exteriores de los paneles y la posición de la cinta."""
    maximo = rgb.max(axis=2)
    lum = _luminancia(rgb)

    gy_sup = 305 + int(np.argmin(lum[305:330, 360:550].mean(axis=1)))
    gy_inf = 925 + int(np.argmin(lum[925:955, 360:550].mean(axis=1)))
    gx_izq = 305 + int(np.argmin(lum[360:890, 305:335].mean(axis=0)))
    gx_der = 925 + int(np.argmin(lum[360:890, 925:962].mean(axis=0)))

    tx0, tx1 = _extremos_1d((maximo[20 : gy_sup - 15, :] > 0.04).mean(axis=0) > 0.5)
    bx0, bx1 = _extremos_1d((maximo[gy_inf + 15 : 1235, :] > 0.04).mean(axis=0) > 0.5)
    ty0, _ = _extremos_1d((maximo[:gy_sup, 360:900] > 0.04).mean(axis=1) > 0.5)
    _, by1_rel = _extremos_1d((maximo[gy_inf:, 360:900] > 0.04).mean(axis=1) > 0.5)
    by1 = gy_inf + by1_rel

    lx0, _ = _extremos_1d((maximo[360:890, :gx_izq] > 0.04).mean(axis=0) > 0.5)
    ly0, ly1 = _extremos_1d((maximo[:, 20 : gx_izq - 15] > 0.04).mean(axis=1) > 0.5)
    _, rx1_rel = _extremos_1d((maximo[360:890, gx_der:] > 0.04).mean(axis=0) > 0.5)
    rx1 = gx_der + rx1_rel
    ry0, ry1 = _extremos_1d((maximo[:, gx_der + 15 : 1235] > 0.04).mean(axis=1) > 0.5)

    tramos_sup = [
        _bordes_cinta(lum, ty0 + 8, ty0 + 75),
        _bordes_cinta(lum, ty0 + 75, ty0 + 155),
        _bordes_cinta(lum, ty0 + 155, ty0 + 235),
        _bordes_cinta(lum, gy_sup - 75, gy_sup - 8),
    ]
    tramos_centro_sup = [
        _bordes_cinta(lum, gy_sup + 8, gy_sup + 65),
        _bordes_cinta(lum, gy_sup + 65, gy_sup + 120),
    ]
    tramos_centro_inf = [
        _bordes_cinta(lum, gy_inf - 120, gy_inf - 65),
        _bordes_cinta(lum, gy_inf - 65, gy_inf - 8),
    ]

    muestra_inf = _bordes_cinta(lum, gy_inf + 15, gy_inf + 210)
    centro_x = (muestra_inf[0] + muestra_inf[1]) // 2
    carton = 0.5 * (
        float(np.median(lum[gy_inf + 30 : gy_inf + 200, 430:530]))
        + float(np.median(lum[gy_inf + 30 : gy_inf + 200, 705:735]))
    )
    cinta_media = float(np.median(lum[gy_inf + 30 : gy_inf + 200, centro_x - 30 : centro_x + 30]))
    umbral = carton + 0.5 * (cinta_media - carton)
    inicio_busqueda = gy_inf + 220
    fraccion = (lum[inicio_busqueda : by1 + 1, centro_x - 35 : centro_x + 35] > umbral).mean(
        axis=1
    )
    huecos = np.where(fraccion <= 0.75)[0]
    y_solido = int(inicio_busqueda + huecos[0] - 1) if len(huecos) else by1

    tramos_inf = [
        _bordes_cinta(lum, gy_inf + 8, gy_inf + 90),
        _bordes_cinta(lum, gy_inf + 90, gy_inf + 175),
        _bordes_cinta(lum, max(gy_inf + 150, y_solido - 75), y_solido - 4),
    ]

    return {
        "gy_sup": gy_sup,
        "gy_inf": gy_inf,
        "gx_izq": gx_izq,
        "gx_der": gx_der,
        "tx": (tx0, tx1),
        "ty0": ty0,
        "bx": (bx0, bx1),
        "by1": by1,
        "lx0": lx0,
        "ly": (ly0, ly1),
        "rx1": rx1,
        "ry": (ry0, ry1),
        "tramos_sup": tramos_sup,
        "tramos_centro_sup": tramos_centro_sup,
        "tramos_centro_inf": tramos_centro_inf,
        "tramos_inf": tramos_inf,
        "y_solido": y_solido,
    }


def ya_alineada(medidas: dict) -> bool:
    """Indica si la textura ya cumple la grilla de cuartos y la cinta simétrica en `[574, 679]`."""
    if medidas["tx"] != (X1, X2) or medidas["ty0"] != 0:
        return False
    if medidas["bx"] != (X1, X2) or medidas["by1"] != LADO - 1:
        return False
    if medidas["lx0"] != 0 or medidas["ly"] != (Y1, Y2):
        return False
    if medidas["rx1"] != LADO - 1 or medidas["ry"] != (Y1, Y2):
        return False
    if medidas["gy_sup"] not in (Y1 - 1, Y1) or medidas["gy_inf"] not in (Y2, Y2 + 1):
        return False
    if medidas["gx_izq"] not in (X1 - 1, X1) or medidas["gx_der"] not in (X2, X2 + 1):
        return False
    if medidas["y_solido"] < LADO - 3:
        return False
    tramos = (
        medidas["tramos_sup"]
        + medidas["tramos_centro_sup"]
        + medidas["tramos_centro_inf"]
        + medidas["tramos_inf"]
    )
    return all(abs(izq - CINTA_IZQ) <= 1 and abs(der - CINTA_DER) <= 1 for izq, der in tramos)


def _mapear_fila_4pts(
    x_salida: np.ndarray, p0: float, c0: float, c1: float, p1: float
) -> np.ndarray:
    destino = np.array([X1, CINTA_IZQ, CINTA_DER, X2], dtype=np.float64)
    origen = np.array([p0, c0, c1, p1], dtype=np.float64)
    return np.clip(np.rint(np.interp(x_salida, destino, origen)).astype(np.int32), 0, LADO - 1)


def alinear(rgb: np.ndarray) -> tuple[np.ndarray, bool]:
    """Devuelve la imagen alineada por vecino más cercano e indica si requirió cambios."""
    medidas = medir(rgb)
    if ya_alineada(medidas):
        return rgb, False

    salida = np.zeros_like(rgb)
    gy_sup, gy_inf = medidas["gy_sup"], medidas["gy_inf"]
    gx_izq, gx_der = medidas["gx_izq"], medidas["gx_der"]
    tx0, tx1 = medidas["tx"]
    bx0, bx1 = medidas["bx"]

    # 1. Panel izquierdo (`+Z`): `[0..X1-1] x [Y1..Y2]`
    lx_orig = np.clip(
        np.rint(np.linspace(medidas["lx0"], gx_izq, X1)).astype(np.int32), 0, LADO - 1
    )
    ly_orig = np.clip(
        np.rint(np.linspace(medidas["ly"][0], medidas["ly"][1], Y2 - Y1 + 1)).astype(np.int32),
        0,
        LADO - 1,
    )
    salida[Y1 : Y2 + 1, 0:X1] = rgb[np.ix_(ly_orig, lx_orig)]

    # 2. Panel derecho (`-Z`): `[X2+1..LADO-1] x [Y1..Y2]`
    rx_orig = np.clip(
        np.rint(np.linspace(gx_der, medidas["rx1"], LADO - (X2 + 1))).astype(np.int32), 0, LADO - 1
    )
    ry_orig = np.clip(
        np.rint(np.linspace(medidas["ry"][0], medidas["ry"][1], Y2 - Y1 + 1)).astype(np.int32),
        0,
        LADO - 1,
    )
    salida[Y1 : Y2 + 1, X2 + 1 : LADO] = rgb[np.ix_(ry_orig, rx_orig)]

    columnas = np.arange(X1, X2 + 1, dtype=np.float64)

    # 3. Panel superior (`+Y`): `[X1..X2] x [0..Y1-1]`
    centros_sup = np.array(
        [medidas["ty0"] + 41.5, medidas["ty0"] + 115.0, medidas["ty0"] + 195.0, gy_sup - 41.5]
    )
    coef_sup_izq = np.polyfit(centros_sup, [b[0] for b in medidas["tramos_sup"]], 1)
    coef_sup_der = np.polyfit(centros_sup, [b[1] for b in medidas["tramos_sup"]], 1)
    ty_orig = np.clip(
        np.rint(np.linspace(medidas["ty0"], gy_sup, Y1)).astype(np.int32), 0, LADO - 1
    )
    for y_dest in range(Y1):
        y_fuente = int(ty_orig[y_dest])
        c_izq = float(np.polyval(coef_sup_izq, y_fuente))
        c_der = float(np.polyval(coef_sup_der, y_fuente))
        xs = _mapear_fila_4pts(columnas, tx0, c_izq, c_der, tx1)
        salida[y_dest, X1 : X2 + 1] = rgb[y_fuente, xs]

    # 4. Panel central (`+X` y `-X`): `[X1..X2] x [Y1..Y2]`
    cs_izq = float(np.mean([b[0] for b in medidas["tramos_centro_sup"]]))
    cs_der = float(np.mean([b[1] for b in medidas["tramos_centro_sup"]]))
    ci_izq = float(np.mean([b[0] for b in medidas["tramos_centro_inf"]]))
    ci_der = float(np.mean([b[1] for b in medidas["tramos_centro_inf"]]))
    cy_orig = np.clip(
        np.rint(np.linspace(gy_sup, gy_inf, Y2 - Y1 + 1)).astype(np.int32), 0, LADO - 1
    )
    for idx_y, y_dest in enumerate(range(Y1, Y2 + 1)):
        y_fuente = int(cy_orig[idx_y])
        mezcla = float(np.clip((y_dest - 465.0) / (785.0 - 465.0), 0.0, 1.0))
        c_izq = cs_izq + (ci_izq - cs_izq) * mezcla
        c_der = cs_der + (ci_der - cs_der) * mezcla
        xs = _mapear_fila_4pts(columnas, gx_izq, c_izq, c_der, gx_der)
        salida[y_dest, X1 : X2 + 1] = rgb[y_fuente, xs]

    # 5. Panel inferior (`-Y`): `[X1..X2] x [Y2+1..LADO-1]`
    y_solido = medidas["y_solido"]
    centros_inf = np.array(
        [
            gy_inf + 49.0,
            gy_inf + 132.5,
            0.5 * (max(gy_inf + 150, y_solido - 75) + y_solido - 4),
        ]
    )
    coef_inf_izq = np.polyfit(centros_inf, [b[0] for b in medidas["tramos_inf"]], 1)
    coef_inf_der = np.polyfit(centros_inf, [b[1] for b in medidas["tramos_inf"]], 1)

    alto_inf = LADO - (Y2 + 1)
    by_carton = np.clip(
        np.rint(np.linspace(gy_inf, medidas["by1"], alto_inf)).astype(np.int32), 0, LADO - 1
    )
    by_cinta = np.clip(
        np.rint(np.linspace(gy_inf, y_solido - 4, alto_inf)).astype(np.int32), 0, LADO - 1
    )
    en_cinta = (columnas >= CINTA_IZQ - 1) & (columnas <= CINTA_DER + 1)
    for idx_y, y_dest in enumerate(range(Y2 + 1, LADO)):
        ys_carton = int(by_carton[idx_y])
        ys_cinta = int(by_cinta[idx_y])
        y_eval = min(ys_carton, y_solido - 4)
        xs_carton = _mapear_fila_4pts(
            columnas,
            bx0,
            float(np.polyval(coef_inf_izq, y_eval)),
            float(np.polyval(coef_inf_der, y_eval)),
            bx1,
        )
        xs_cinta = _mapear_fila_4pts(
            columnas,
            bx0,
            float(np.polyval(coef_inf_izq, ys_cinta)),
            float(np.polyval(coef_inf_der, ys_cinta)),
            bx1,
        )
        fila = rgb[ys_carton, xs_carton]
        fila[en_cinta] = rgb[ys_cinta, xs_cinta][en_cinta]
        salida[y_dest, X1 : X2 + 1] = fila

    return salida, True


def _leer_rgb(ruta: Path) -> np.ndarray:
    imagen = bpy.data.images.load(str(ruta.resolve()), check_existing=False)
    try:
        ancho, alto = imagen.size
        if (ancho, alto) != (LADO, LADO):
            raise SystemExit(f"{ruta.name}: se esperaba {LADO}x{LADO}, vino {ancho}x{alto}")
        datos = np.empty(ancho * alto * 4, dtype=np.float32)
        imagen.pixels.foreach_get(datos)
        return np.ascontiguousarray(datos.reshape(alto, ancho, 4)[::-1, :, :3])
    finally:
        bpy.data.images.remove(imagen)


def _escribir_rgb(ruta: Path, rgb: np.ndarray) -> None:
    alto, ancho = rgb.shape[:2]
    imagen = bpy.data.images.new(ruta.stem, ancho, alto, alpha=False)
    try:
        imagen.colorspace_settings.name = "sRGB"
        opaco = np.ones((alto, ancho, 1), dtype=np.float32)
        cuatro = np.concatenate([rgb[::-1], opaco], axis=-1).astype(np.float32)
        imagen.pixels.foreach_set(cuatro.reshape(-1))
        imagen.file_format = "PNG"
        imagen.filepath_raw = str(ruta.resolve())
        imagen.save()
    finally:
        bpy.data.images.remove(imagen)


def main() -> None:
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    aplicar = "--aplicar" in argumentos
    extra = [a for a in argumentos if a != "--aplicar"]
    if extra:
        raise SystemExit(f"argumentos no reconocidos: {extra}")

    archivos = sorted(CARPETA_CAJAS.glob("*.png"))
    if not archivos:
        raise SystemExit(f"no se encontraron texturas en {CARPETA_CAJAS}")

    cambiadas = 0
    for ruta in archivos:
        rgb = _leer_rgb(ruta)
        nuevo, cambio = alinear(rgb)
        if not ya_alineada(medir(nuevo)):
            raise SystemExit(f"{ruta.name}: la salida no quedó alineada")
        if cambio:
            cambiadas += 1
            if aplicar:
                _escribir_rgb(ruta, nuevo)
        print(f"caja: {ruta.stem:16s} {'ajustada' if cambio else 'sin cambios'}")

    modo = "aplicado" if aplicar else "prueba"
    print(f"resumen ({modo}): {cambiadas}/{len(archivos)} texturas ajustadas")


if __name__ == "__main__":
    main()
