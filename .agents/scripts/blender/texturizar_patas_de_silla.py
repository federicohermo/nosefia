"""Pinta el atlas de madera tono miel de las sillas del salón con veta real e imperfecciones CC0.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_patas_de_silla.py -- [--aplicar]

Sin `--aplicar` escribe la imagen en `build/madera/` y cambia sólo la sesión de Blender. Con
`--aplicar` escribe `assets/source/textures/store/silla_patas_madera.png` y guarda el `.blend`.
Va después de `moldear_silla_del_salon.py`, que deja desplegadas las bandas de UV de cada pieza.
Después va `exportar_modelo.py`.

## Por qué

La silla de referencia (`build/referencias/sillas_referencia.png`) es de madera maciza clara en
tono miel barnizado, limpia y moderna: el respaldo curvo muestra tres tablas horizontales encoladas
con veta catedral continua, el aro bajo el asiento recoge la sombra del almohadón y las patas
torneadas llevan veta vertical sin nudos negros ni barro. Como `salon_silla` usa `GI_MODE_DYNAMIC`,
la oclusión fina de los encuentros tiene que viajar en el color base.

## Qué cambia

- **Una imagen de 1024×1024** (`silla_patas_madera.png`) armada desde la chapa CC0 `oak_veneer_01`
  reentonada a miel cálido y el mapa CC0 `Fingerprints005` (0,30 m × 0,30 m) a escala física real:
  - Respaldo delantero y trasero con tres tablas horizontales encoladas, sombra suave detrás de los
    dos montantes en el dorso y marcas leves de manos en el borde superior.
  - Aro del asiento con veta continua sin costura lateral y sombra bajo el vuelo del tapizado.
  - Ocho tiras verticales distintas para las cuatro patas, los tres travesaños y los topes, con dos
    tarugos cubretornillos en el dorso de cada montante trasero y testero en la franja superior.
- **El material** `SILLA | Patas de madera` enlaza la textura en sRGB con rugosidad de barniz
  satinado (`0,34`).

## Lo que cuesta

Ningún triángulo, material ni dibujo más: reutiliza `silla_patas_madera.png` (comprimida en VRAM
con BC1). Es determinista e idempotente.
"""

import math
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from detalle_de_madera import suave  # noqa: E402
from moldear_silla_del_salon import (  # noqa: E402
    ALTO_RESPALDO,
    ARCO_MAXIMO_RESPALDO,
    MALLA,
    MATERIAL_MADERA,
    RADIO_CURVA_RESPALDO,
    RUGOSIDAD_MADERA,
    UV_ARO,
    UV_FONDO_ARO,
    UV_RESPALDO_DORSO,
    UV_RESPALDO_FRENTE,
    UV_TIRAS_V,
    X_MONTANTE_RESPALDO,
    Z_BASE_RESPALDO,
    Z_TOPE_MONTANTE,
)

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / "assets/source/textures/store/silla_patas_madera.png"
PRUEBA = RAIZ / "build" / "madera" / DESTINO.name
CHAPA = RAIZ / "assets/source/textures/third-party/oak_veneer_01/oak_veneer_01_diff_2k.jpg"
IMPERFECCIONES = (
    RAIZ
    / "assets/source/textures/third-party/fingerprints_005"
    / "Fingerprints005_2K-JPG_Roughness.jpg"
)

LADO_PX = 1024
SEMILLA = 20261112
CHAPA_M = 1.0
ESCALA_HUELLAS_M = 0.30

#: Miel en sRGB. El usuario lo pidió un poco más desaturado que el primero, (0.835, 0.440, 0.208).
TONO_MIEL = np.array([0.753, 0.457, 0.283], dtype=np.float32)
CONTRASTE_VETA = 0.74
TABLAS_RESPALDO = 3


def remuestrear(imagen: np.ndarray, alto: int, ancho: int) -> np.ndarray:
    """Promedia por área en 2D o 3D para escalar sin ruido de muestreo."""
    salida = imagen.astype(np.float32)
    for eje, n in ((0, alto), (1, ancho)):
        largo = salida.shape[eje]
        ceros = np.zeros_like(np.take(salida, [0], axis=eje))
        acumulado = np.concatenate([ceros, np.cumsum(salida, axis=eje)], axis=eje)
        bordes = np.linspace(0.0, largo, n + 1)
        indices = np.arange(largo + 1)
        sumas = np.apply_along_axis(lambda c: np.interp(bordes, indices, c), eje, acumulado)
        salida = np.diff(sumas, axis=eje) / (largo / n)
    return salida.astype(np.float32)


def recorte(chapa: np.ndarray, x: int, y: int, ancho: int, alto: int) -> np.ndarray:
    filas = np.arange(y, y + alto) % chapa.shape[0]
    columnas = np.arange(x, x + ancho) % chapa.shape[1]
    return chapa[np.ix_(filas, columnas)]


def huellas_a_escala(
    mapa: np.ndarray, alto: int, ancho: int, metros_x: float, metros_y: float, dx: int, dy: int
) -> np.ndarray:
    """Mosaico sin costura de `Fingerprints005` respetando su tamaño real de 0,30 m."""
    px_x = max(12, round(ancho * ESCALA_HUELLAS_M / max(metros_x, 0.05)))
    px_y = max(12, round(alto * ESCALA_HUELLAS_M / max(metros_y, 0.05)))
    tile = remuestrear(mapa, px_y, px_x)
    ys = (np.arange(alto) + dy) % px_y
    xs = (np.arange(ancho) + dx) % px_x
    muestra = tile[np.ix_(ys, xs)]
    centrado = (muestra - float(muestra.mean())) / max(float(muestra.std()), 1e-4)
    return np.clip(centrado, -1.5, 2.5).astype(np.float32)


def _tabla_respaldo(
    acostada: np.ndarray,
    px_por_m: float,
    azar: np.random.Generator,
    fila_ini: int,
    fila_fin: int,
) -> np.ndarray:
    """Tres tablas horizontales encoladas que cubren `fila_fin - fila_ini` filas por `LADO_PX`."""
    alto = fila_fin - fila_ini
    lienzo = np.zeros((alto, LADO_PX, 3), dtype=np.float32)
    cortes = [round(alto * k / TABLAS_RESPALDO) for k in range(TABLAS_RESPALDO + 1)]
    ancho_chapa = round((ARCO_MAXIMO_RESPALDO / 0.96) * px_por_m)
    for idx in range(TABLAS_RESPALDO):
        a, b = cortes[idx], cortes[idx + 1]
        alto_tramo = b - a
        alto_chapa = max(24, round((ALTO_RESPALDO / TABLAS_RESPALDO) * px_por_m))
        ox = int(azar.integers(0, acostada.shape[1]))
        oy = int(azar.integers(0, acostada.shape[0]))
        crudo = recorte(acostada, ox, oy, ancho_chapa, alto_chapa)
        madera = remuestrear(crudo, alto_tramo, LADO_PX)
        tono_tabla = (1.0 + float(azar.normal(0.0, 0.022))) * np.array(
            [1.0 + float(azar.normal(0.0, 0.008)) for _ in range(3)], dtype=np.float32
        )
        lienzo[a:b] = madera * tono_tabla[None, None, :]
        if idx > 0:
            # Junta fina de encolado entre tablas macizas, apenas más cálida/oscura que la veta.
            lienzo[a - 1] *= 0.93
            lienzo[a] *= 0.90
            if a + 1 < alto:
                lienzo[a + 1] *= 1.03
    return lienzo


def _rellenar_con_margen(
    imagen: np.ndarray, bloque: np.ndarray, f_uv0: int, f_banda0: int, f_banda1: int
) -> None:
    """Escribe `bloque` en `f_uv0` y repite sus filas extremas hasta `[f_banda0, f_banda1]`."""
    f_uv1 = f_uv0 + bloque.shape[0]
    imagen[f_uv0:f_uv1] = bloque
    if f_banda0 < f_uv0:
        imagen[f_banda0:f_uv0] = bloque[0:1]
    if f_uv1 < f_banda1:
        imagen[f_uv1:f_banda1] = bloque[-1:]


def pintar(chapa_cruda: np.ndarray, imperfecciones: np.ndarray) -> np.ndarray:
    azar = np.random.default_rng(SEMILLA)
    media = chapa_cruda.reshape(-1, 3).mean(axis=0)
    contraste = media + (chapa_cruda - media) * CONTRASTE_VETA
    chapa = np.clip(contraste * (TONO_MIEL / media), 0.0, 1.0)
    acostada = np.rot90(chapa)
    px_por_m = chapa.shape[1] / CHAPA_M
    imagen = np.zeros((LADO_PX, LADO_PX, 3), dtype=np.float32)

    # --- 1. Respaldo delantero (filas 0..308) ---------------------------------------------------
    f0_frente = round(UV_RESPALDO_FRENTE[2] * LADO_PX)
    f1_frente = round(UV_RESPALDO_FRENTE[3] * LADO_PX)
    frente = _tabla_respaldo(acostada, px_por_m, azar, f0_frente, f1_frente)
    ys_f = np.linspace(0.0, 1.0, frente.shape[0], dtype=np.float32)[:, None]
    xs_f = np.linspace(0.0, 1.0, LADO_PX, dtype=np.float32)[None, :]
    # Realce sutil de barniz hacia el borde superior y concavidad cálida suave al centro.
    luz_frente = (
        0.985 + 0.035 * suave(0.65, 1.0, ys_f) - 0.020 * np.exp(-(((xs_f - 0.5) / 0.28) ** 2))
    )
    frente *= luz_frente[..., None]
    h_frente = huellas_a_escala(
        imperfecciones, frente.shape[0], LADO_PX, ARCO_MAXIMO_RESPALDO / 0.96, ALTO_RESPALDO, 41, 19
    )
    peso_manos_f = 0.35 + 0.65 * np.maximum(suave(0.62, 0.98, ys_f), np.abs(xs_f - 0.5) * 1.4)
    frente *= (1.0 - 0.018 * np.clip(h_frente, 0.0, 2.2) * peso_manos_f)[..., None]
    _rellenar_con_margen(imagen, frente, f0_frente, 0, 308)

    # --- 2. Respaldo trasero (filas 308..620) con oclusión detrás de los montantes --------------
    f0_dorso = round(UV_RESPALDO_DORSO[2] * LADO_PX)
    f1_dorso = round(UV_RESPALDO_DORSO[3] * LADO_PX)
    dorso = _tabla_respaldo(acostada, px_por_m, azar, f0_dorso, f1_dorso)
    ys_d = np.linspace(0.0, 1.0, dorso.shape[0], dtype=np.float32)[:, None]
    xs_d = np.linspace(0.0, 1.0, LADO_PX, dtype=np.float32)[None, :]

    arco_montante = RADIO_CURVA_RESPALDO * math.asin(X_MONTANTE_RESPALDO / RADIO_CURVA_RESPALDO)
    u0_d, u1_d, _, _ = UV_RESPALDO_DORSO
    tope_rel = (Z_TOPE_MONTANTE - Z_BASE_RESPALDO) / ALTO_RESPALDO
    oclusion_montantes = np.zeros_like(ys_d * xs_d)
    for signo in (-1.0, 1.0):
        u_centro = u0_d + (0.5 + signo * arco_montante / ARCO_MAXIMO_RESPALDO) * (u1_d - u0_d)
        ancho_u = (0.019 / ARCO_MAXIMO_RESPALDO) * (u1_d - u0_d)
        lateral = np.exp(-(((xs_d - u_centro) / ancho_u) ** 2))
        vertical = suave(tope_rel + 0.05, tope_rel - 0.03, ys_d)
        oclusion_montantes = np.maximum(oclusion_montantes, lateral * vertical)
    dorso *= (1.0 - 0.14 * oclusion_montantes + 0.03 * suave(0.70, 1.0, ys_d))[..., None]

    h_dorso = huellas_a_escala(
        imperfecciones, dorso.shape[0], LADO_PX, ARCO_MAXIMO_RESPALDO / 0.96, ALTO_RESPALDO, 113, 67
    )
    agarre_dorso = 0.30 + 0.70 * suave(0.55, 0.96, ys_d)
    dorso *= (1.0 - 0.020 * np.clip(h_dorso, 0.0, 2.2) * agarre_dorso)[..., None]
    _rellenar_con_margen(imagen, dorso, f0_dorso, 308, 620)

    # --- 3. Fondo interior y aro circular bajo el asiento (filas 620..742) ----------------------
    f0_fondo = round(UV_FONDO_ARO[2] * LADO_PX)
    f0_aro = round(UV_ARO[2] * LADO_PX)
    f1_aro = round(UV_ARO[3] * LADO_PX)
    crudo_fondo = recorte(acostada, 210, 540, round(0.5 * px_por_m), 80)
    fondo = remuestrear(crudo_fondo, f0_aro - f0_fondo, LADO_PX)
    _rellenar_con_margen(imagen, fondo * 0.76, f0_fondo, 620, f0_aro)

    alto_aro = f1_aro - f0_aro
    crudo_aro = remuestrear(
        recorte(acostada, 0, 920, acostada.shape[1], max(32, round(0.05 * px_por_m))),
        alto_aro,
        LADO_PX,
    )
    # Fundido lateral corto para cerrar la vuelta entera del aro sin costura en u = 0 / 1.
    mezcla_u = suave(0.92, 1.0, np.linspace(0.0, 1.0, LADO_PX, dtype=np.float32))[None, :, None]
    aro = crudo_aro * (1.0 - mezcla_u) + np.roll(crudo_aro, LADO_PX // 2, axis=1) * mezcla_u
    ys_aro = np.linspace(0.0, 1.0, alto_aro, dtype=np.float32)[:, None]
    # Sombra suave bajo el vuelo del almohadón crema en el borde superior del aro.
    sombra_almohadon = (
        0.80 + 0.22 * (1.0 - suave(0.58, 0.98, ys_aro)) - 0.06 * suave(0.18, 0.0, ys_aro)
    )
    aro *= sombra_almohadon[..., None]
    h_aro = huellas_a_escala(imperfecciones, alto_aro, LADO_PX, 1.31, 0.05, 17, 51)
    aro *= (1.0 - 0.015 * np.clip(h_aro, 0.0, 2.0))[..., None]
    _rellenar_con_margen(imagen, aro, f0_aro, f0_aro, 742)

    # --- 4. Ocho tiras verticales para patas, travesaños y topes (filas 742..992) ---------------
    f0_tiras = round(UV_TIRAS_V[0] * LADO_PX)
    f1_tiras = round(UV_TIRAS_V[1] * LADO_PX)
    alto_tiras = f1_tiras - f0_tiras
    ancho_tira = LADO_PX // 8
    largos_m = [0.82, 0.82, 0.41, 0.41, 0.37, 0.37, 0.34, 0.08]
    tiras = np.zeros((alto_tiras, LADO_PX, 3), dtype=np.float32)
    ys_t = np.linspace(0.0, 1.0, alto_tiras, dtype=np.float32)[:, None]

    for k, largo_m in enumerate(largos_m):
        ox = int(azar.integers(0, chapa.shape[1]))
        oy = int(azar.integers(0, chapa.shape[0]))
        ancho_c = max(48, round(0.11 * px_por_m))
        alto_c = max(48, round(largo_m * px_por_m))
        pieza = remuestrear(recorte(chapa, ox, oy, ancho_c, alto_c), alto_tiras, ancho_tira)
        pieza *= (1.0 + float(azar.normal(0.0, 0.018)))
        if k in (0, 1):
            # Montantes traseros: sombra leve en el apoyo del piso y en el paso por el aro.
            sombra = (
                1.0
                - 0.09 * suave(0.035, 0.0, ys_t)
                - 0.07 * np.exp(-(((ys_t - 0.49) / 0.045) ** 2))
            )
            pieza *= sombra[..., None]
            # Dos tarugos de madera cubretornillos en el dorso (`frac = 0,75` del perímetro).
            col_dorso = round((0.10 + 0.75 * 0.80) * ancho_tira)
            xs_p = np.arange(ancho_tira, dtype=np.float32)[None, :]
            ys_p = np.arange(alto_tiras, dtype=np.float32)[:, None]
            for v_tarugo in (0.835, 0.920):
                fila_t = v_tarugo * alto_tiras
                dist = np.hypot((xs_p - col_dorso) / 3.4, (ys_p - fila_t) / 2.8)
                disco = suave(1.15, 0.65, dist)
                anillo = np.exp(-(((dist - 0.92) / 0.22) ** 2))
                pieza *= (1.0 - 0.20 * disco - 0.14 * anillo)[..., None]
        elif k in (2, 3):
            # Patas delanteras: oclusión bajo el aro del asiento y sombra mínima junto al piso.
            sombra = 1.0 - 0.15 * suave(0.86, 1.0, ys_t) - 0.08 * suave(0.04, 0.0, ys_t)
            pieza *= sombra[..., None]
        elif k in (4, 5, 6):
            # Travesaños: sombra suave en ambos encuentros con las patas.
            sombra = 1.0 - 0.13 * suave(0.10, 0.0, ys_t) - 0.13 * suave(0.90, 1.0, ys_t)
            pieza *= sombra[..., None]
        else:
            pieza *= 1.04

        h_pieza = huellas_a_escala(
            imperfecciones, alto_tiras, ancho_tira, 0.11, largo_m, 23 * (k + 1), 31 * (k + 1)
        )
        pieza *= (1.0 - 0.015 * np.clip(h_pieza, 0.0, 2.0))[..., None]
        tiras[:, k * ancho_tira : (k + 1) * ancho_tira] = pieza

    _rellenar_con_margen(imagen, tiras, f0_tiras, 742, 992)

    # --- 5. Testero limpio para el apoyo de las patas (filas 992..1024) -------------------------
    alto_testero = LADO_PX - 992
    anillos = 0.5 + 0.5 * np.sin(
        np.abs(np.arange(LADO_PX, dtype=np.float32)[None, :] - LADO_PX * 0.5) / 14.0 * 2.0 * np.pi
    )
    base_testero = (TONO_MIEL * 0.62)[None, None, :] * (0.90 + 0.18 * anillos)[..., None]
    imagen[992:] = np.broadcast_to(base_testero, (alto_testero, LADO_PX, 3))

    return np.clip(imagen, 0.0, 1.0)


def enlazar_imagen(ruta: Path, relativa: bool) -> None:
    import bpy  # type: ignore[import-not-found]

    material = bpy.data.materials[MATERIAL_MADERA]
    if material.node_tree is None:
        material.use_nodes = True
    arbol = material.node_tree
    principal = next(n for n in arbol.nodes if n.type == "BSDF_PRINCIPLED")
    nodo = next((n for n in arbol.nodes if n.type == "TEX_IMAGE"), None) or arbol.nodes.new(
        "ShaderNodeTexImage"
    )
    nodo.image = None
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
    principal.inputs["Roughness"].default_value = RUGOSIDAD_MADERA
    principal.inputs["Metallic"].default_value = 0.0


def main() -> None:
    import bpy  # type: ignore[import-not-found]

    from detalle_de_plastico import escribir_png, leer_png
    from lib.consola import configurar

    configurar()
    aplicar = "--aplicar" in sys.argv
    destino = DESTINO if aplicar else PRUEBA
    destino.parent.mkdir(parents=True, exist_ok=True)

    chapa_img = bpy.data.images.load(str(CHAPA), check_existing=False)
    ancho, alto = chapa_img.size
    pixeles = np.empty(ancho * alto * 4, dtype=np.float32)
    chapa_img.pixels.foreach_get(pixeles)
    bpy.data.images.remove(chapa_img)
    chapa = pixeles.reshape(alto, ancho, 4)[..., :3].copy()

    imperfecciones = leer_png(IMPERFECCIONES)[..., 0]
    color = pintar(chapa, imperfecciones)
    escribir_png(color, destino)
    enlazar_imagen(destino, relativa=aplicar)

    malla = bpy.data.meshes[MALLA]
    print(
        f"{MALLA}: madera {destino}  media {np.round(color.reshape(-1, 3).mean(0), 3)}  "
        f"sillas: {malla.users}"
    )
    if aplicar:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
