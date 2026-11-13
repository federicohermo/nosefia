"""Pinta el tapizado crema del asiento de las sillas del salón con micrograno y marcas suaves.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_silla_del_salon.py -- [--aplicar]

Sin `--aplicar` escribe la imagen en `build/plastico/`, para revisarla sin tocar la fuente. Con
`--aplicar` escribe `assets/source/textures/store/silla_plastico_blanco.png`. El `.blend` no
cambia. Después van `texturizar_patas_de_silla.py` y `exportar_modelo.py`.

## Por qué

El asiento de la referencia (`build/referencias/sillas_referencia.png`) es un almohadón redondo de
cuero sintético crema, limpio y moderno. Bajo las sondas dinámicas del salón la luz tiene dominante
fría; una base crema cálida evita que el asiento vire al verde menta frente a la tapa blanca de las
mesas. Un color plano se lee sintético de cerca, y ensuciarlo contradice la referencia.

## Qué cambia

Reescribe `silla_plastico_blanco.png` a 512×512 (suficiente para un almohadón de 42 cm reales, con
un cuarto de la memoria de textura anterior) combinando:

- **Tono crema cálido** con una caída muy leve de brillo hacia el centro de apoyo y un realce suave
  en el giro superior del canto redondeado.
- **Sombra de encastre** en el labio inferior del canto (`rho > 0,39`), donde el tapizado entra en
  el aro de madera.
- **Micrograno de cuero sintético** a escala milimétrica, apenas perceptible de cerca.
- **Marcas de uso CC0 a escala real** (`Fingerprints005`, 0,30 m × 0,30 m): pasadas suaves de trapo
  y apoyo de manos con amplitud menor al 2,5 %, visibles a un metro sin ensuciar la silla.

## Lo que cuesta

Ningún triángulo, material ni dibujo más. Reduce la imagen de 1024×1024 a 512×512. Es determinista
e idempotente.
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from detalle_de_madera import ruido, suave  # noqa: E402
from detalle_de_plastico import escribir_png, leer_png, salida  # noqa: E402
from lib.consola import configurar  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
TEXTURA = RAIZ / "assets/source/textures/store/silla_plastico_blanco.png"
IMPERFECCIONES = (
    RAIZ
    / "assets/source/textures/third-party/fingerprints_005"
    / "Fingerprints005_2K-JPG_Roughness.jpg"
)

LADO = 512
SEMILLA = 20261112
#: Diámetro físico desplegado que cubre el ancho [0, 1] de la UV del almohadón, en metros reales.
ANCHO_FISICO_UV_M = 0.567
ESCALA_HUELLAS_M = 0.30

#: Crema cálido calibrado para conservar calidez bajo la luz fría de las sondas del salón.
BASE_CREMA = np.array([0.985, 0.870, 0.788], dtype=np.float32)
BRILLO_CANTO = np.array([0.996, 0.912, 0.842], dtype=np.float32)
SOMBRA_ENCASTRE = np.array([0.835, 0.705, 0.602], dtype=np.float32)


def remuestrear_caja(mapa: np.ndarray, alto: int, ancho: int) -> np.ndarray:
    """Promedia por área un canal 2D para cambiar de escala sin aliasing."""
    salida_2d = mapa.astype(np.float32)
    for eje, n in ((0, alto), (1, ancho)):
        largo = salida_2d.shape[eje]
        ceros = np.zeros_like(np.take(salida_2d, [0], axis=eje))
        acumulado = np.concatenate([ceros, np.cumsum(salida_2d, axis=eje)], axis=eje)
        bordes = np.linspace(0.0, largo, n + 1)
        indices = np.arange(largo + 1)
        sumas = np.apply_along_axis(lambda c: np.interp(bordes, indices, c), eje, acumulado)
        salida_2d = np.diff(sumas, axis=eje) / (largo / n)
    return salida_2d.astype(np.float32)


def mosaico_a_escala(
    mapa_cc0: np.ndarray,
    alto: int,
    ancho: int,
    metros_ancho: float,
    metros_alto: float,
    dx: int,
    dy: int,
) -> np.ndarray:
    """Repite el mapa CC0 de 0,30 m respetando su escala física en ambos ejes."""
    px_tile_x = max(16, round(ancho * ESCALA_HUELLAS_M / metros_ancho))
    px_tile_y = max(16, round(alto * ESCALA_HUELLAS_M / metros_alto))
    tile = remuestrear_caja(mapa_cc0, px_tile_y, px_tile_x)
    ys = (np.arange(alto) + dy) % px_tile_y
    xs = (np.arange(ancho) + dx) % px_tile_x
    muestra = tile[np.ix_(ys, xs)]
    centrado = (muestra - float(muestra.mean())) / max(float(muestra.std()), 1e-4)
    return np.clip(centrado, -1.5, 2.5).astype(np.float32)


def mezclar(color: np.ndarray, destino: np.ndarray, peso: np.ndarray) -> np.ndarray:
    return color + (destino[None, None, :] - color) * np.clip(peso, 0.0, 1.0)[..., None]


def pintar(imperfecciones: np.ndarray) -> np.ndarray:
    azar = np.random.default_rng(SEMILLA)
    coords = (np.arange(LADO, dtype=np.float32) + 0.5) / LADO - 0.5
    dy, dx = coords[:, None], coords[None, :]
    rho = np.hypot(dx, dy)

    color = np.broadcast_to(BASE_CREMA, (LADO, LADO, 3)).copy()

    # Variación amplia apenas perceptible y micrograno parejo de cuero sintético liso.
    nube = ruido(LADO, LADO, 3, 3, azar, octavas=2)
    poro_fino = ruido(LADO, LADO, 96, 96, azar, octavas=2)
    color *= (1.0 + (nube - 0.5) * 0.018 + (poro_fino - 0.5) * 0.014)[..., None]

    # El giro superior del canto (`rho ~ 0,34`) recoge un poco más de luz; el labio inferior se
    # oscurece suavemente al meterse en el aro de madera (`rho > 0,39`).
    realce = np.exp(-(((rho - 0.335) / 0.042) ** 2))
    color = mezclar(color, BRILLO_CANTO, realce * 0.30)
    encastre = suave(0.388, 0.455, rho)
    color = mezclar(color, SOMBRA_ENCASTRE, encastre * 0.42)

    # Detalle CC0 (`Fingerprints005`) a escala física real (0,30 m): marcas muy suaves de trapo y
    # manos sobre el borde y la zona de asiento, sin ensuciar el tapizado.
    huellas = mosaico_a_escala(
        imperfecciones, LADO, LADO, ANCHO_FISICO_UV_M, ANCHO_FISICO_UV_M, dx=37, dy=83
    )
    zona_contacto = 0.45 + 0.55 * np.exp(-(((rho - 0.28) / 0.14) ** 2))
    roce_suave = np.clip(huellas, 0.0, 2.2) * zona_contacto * (1.0 - 0.5 * encastre)
    brillo_trapo = np.clip(-huellas, 0.0, 1.2) * zona_contacto
    color *= (1.0 - 0.013 * roce_suave + 0.007 * brillo_trapo)[..., None]

    return np.clip(color, 0.0, 1.0)


def main() -> None:
    configurar()
    imperfecciones = leer_png(IMPERFECCIONES)[..., 0]
    color = pintar(imperfecciones)
    destino = salida(TEXTURA)
    escribir_png(color, destino)
    print(f"tapizado silla: {destino}  media {np.round(color.reshape(-1, 3).mean(0), 3)}")


if __name__ == "__main__":
    main()
