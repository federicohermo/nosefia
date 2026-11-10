"""Pinta el uso del plástico de los tachos de basura del salón: polvo abajo, roce en los cantos.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_tachos_del_salon.py -- [--aplicar]

Sin `--aplicar` escribe las imágenes en `build/plastico/`, para mirarlas. Con `--aplicar` escribe
`deposito_contenedor_cuerpo_color.png` y `deposito_contenedor_tapa_color.png` en
`assets/source/textures/props/`. El `.blend` no cambia. Después va `exportar_modelo.py`.

## Por qué

Los tachos eran un gris casi negro de un solo tono. Un tacho de calle no es parejo: tiene rayas
verticales de suciedad, el borde más claro por el roce, polvo abajo y marcas en la tapa.

## Qué cambia

Sólo las dos imágenes de color, que pasan de 256 a 512 píxeles: el detalle no entra en 256, y
las dos tienen lugar de sobra en el límite de 1024 de los muebles. El arte de 256 se agranda por
vecino más cercano, así que el pictograma y el pixel siguen siendo los mismos. Encima suma:

- **Polvo** que sube desde el piso, con la altura que cada punto tiene en el mundo.
- **Rayas verticales** de suciedad y de lavado, y manchas anchas.
- **Roce**: los bordes de cada panel se aclaran y se pican.
- **Rayones y marcas**, más en la tapa.

El pictograma recibe un tercio del efecto, para que se siga leyendo.

El original de 256 vive en `assets/source/textures/props/sin_detalle/`, y el script parte
siempre de ahí: así corrido dos veces da lo mismo. La primera corrida lo copia.

## Lo que cuesta

Ningún triángulo ni material de más. Las imágenes pasan de 256 a 512: cuatro veces los píxeles
de dos texturas.
"""

import shutil
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from detalle_de_plastico import (  # noqa: E402
    altura_del_mundo,
    cobertura,
    copia_aparte,
    descartar,
    desenfocar,
    distancia_al_borde,
    escribir_png,
    hornear,
    leer_png,
    preparar_cycles,
    rayones,
    restaurar,
    ruido,
    salida,
    suave,
)
from lib.consola import configurar  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
PROPS = RAIZ / "assets/source/textures/props"
SIN_DETALLE = PROPS / "sin_detalle"
LADO = 512
CUERPO = "tachitobasura-col"
TAPA = "tachitobasura-col_tapa.001"

POLVO = np.array([0.40, 0.39, 0.36], dtype=np.float32)
ROCE = np.array([0.46, 0.47, 0.49], dtype=np.float32)
LAVADO = np.array([0.30, 0.31, 0.33], dtype=np.float32)
RAYON = np.array([0.52, 0.52, 0.52], dtype=np.float32)

#: Qué tanto de cada efecto lleva cada imagen: `(polvo, rayas, roce, rayones, manchas)`.
CUERPO_USO = (0.55, 0.50, 0.55, 0.50, 0.30)
TAPA_USO = (0.15, 0.10, 0.55, 0.60, 0.55)


def partir(nombre: str) -> np.ndarray:
    """El original de 256 agrandado a 512 por vecino más cercano.

    La primera vez copia el original a `sin_detalle/`, antes de que se pise.
    """
    original = SIN_DETALLE / nombre
    if not original.exists():
        SIN_DETALLE.mkdir(exist_ok=True)
        shutil.copyfile(PROPS / nombre, original)
    chico = leer_png(original)
    return np.repeat(np.repeat(chico, 2, axis=0), 2, axis=1)


def mezclar(color: np.ndarray, tono: np.ndarray, cuanto: np.ndarray) -> np.ndarray:
    return color + (tono[None, None, :] - color) * np.clip(cuanto, 0.0, 1.0)[..., None]


def pintar(base: np.ndarray, dentro: np.ndarray, altura: np.ndarray, uso: tuple, semilla: int):
    polvo_k, rayas_k, roce_k, rayones_k, manchas_k = uso
    luz = base.mean(axis=2)
    # El plástico oscuro recibe todo el efecto; lo claro, el pictograma, recibe un tercio.
    protegido = (1.0 - suave(0.22, 0.50, luz) * 0.67) * (desenfocar(dentro, 3) > 0.05)
    borde = np.where(dentro > 0.5, distancia_al_borde(dentro, 12), 0.0)
    cerca = np.exp(-borde / 2.4) * np.minimum(dentro, 1.0)

    nubes = ruido(LADO, LADO, 90, semilla)
    vetas = ruido(LADO, LADO, 7, semilla + 1, octavas=3, estirado=14.0)
    lavado = ruido(LADO, LADO, 16, semilla + 2, octavas=3, estirado=9.0)
    grano = ruido(LADO, LADO, 2, semilla + 3, octavas=2)

    color = base.copy()
    # La variación de tono se suma, porque multiplicar por un casi negro no mueve nada.
    color += ((nubes - 0.5) * 0.07)[..., None] * protegido[..., None]

    suelo = (1.0 - altura) ** 2.2
    mugre = suelo * (0.35 + 0.65 * suave(0.30, 0.70, nubes)) * polvo_k
    color = mezclar(color, POLVO, mugre * 0.8 * protegido)

    seca = suave(0.55, 0.80, vetas) * rayas_k * (0.30 + 0.70 * altura)
    color = mezclar(color, POLVO, seca * 0.55 * protegido)
    limpia = suave(0.62, 0.84, lavado) * rayas_k
    color = mezclar(color, LAVADO, limpia * 0.45 * protegido)

    manchas = suave(0.52, 0.72, ruido(LADO, LADO, 26, semilla + 4)) * manchas_k
    color = mezclar(color, POLVO, manchas * 0.30 * protegido)

    roce = cerca * (0.55 + 0.45 * suave(0.35, 0.75, grano)) * roce_k
    color = mezclar(color, ROCE, roce * 0.55 * protegido)

    largos = rayones(LADO, LADO, 130, 46, semilla + 5, grosor=1) * rayones_k
    cortos = rayones(LADO, LADO, 110, 11, semilla + 6, grosor=2) * rayones_k
    color = mezclar(color, RAYON, largos * 0.55 * protegido)
    color = mezclar(color, RAYON, cortos * 0.50 * protegido)
    return color


def hornear_cuerpo(objeto) -> tuple[np.ndarray, np.ndarray]:
    todas = {c.index for c in objeto.data.polygons}
    dentro = cobertura(objeto, todas, LADO)
    copia = copia_aparte(objeto, set())
    try:
        altura = hornear(copia, altura_del_mundo(objeto), LADO, 4)[..., 0]
    finally:
        descartar(copia)
    return dentro, altura


def main() -> None:
    configurar()
    antes = preparar_cycles()
    try:
        cuerpo = bpy.data.objects[CUERPO]
        dentro_cuerpo, altura = hornear_cuerpo(cuerpo)
        tapa = bpy.data.objects[TAPA]
        dentro_tapa = cobertura(tapa, {c.index for c in tapa.data.polygons}, LADO)
    finally:
        restaurar(antes)
    media_altura = np.full((LADO, LADO), 0.5)
    piezas = (
        ("deposito_contenedor_cuerpo_color.png", dentro_cuerpo, altura, CUERPO_USO, 31),
        ("deposito_contenedor_tapa_color.png", dentro_tapa, media_altura, TAPA_USO, 41),
    )
    for nombre, dentro, alto, uso, semilla in piezas:
        color = pintar(partir(nombre), dentro, alto, uso, semilla)
        destino = salida(PROPS / nombre)
        escribir_png(color, destino)
        print(f"tacho: {destino}  media {np.round(color.reshape(-1, 3).mean(0), 3)}")


if __name__ == "__main__":
    main()
