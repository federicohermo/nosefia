"""Suma uso al plástico de los tres bidones de jabón: marcas, roce y suciedad en los quiebres.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_bidones.py -- [--aplicar]

Sin `--aplicar` escribe las imágenes en `build/plastico/`, para mirarlas. Con `--aplicar` escribe
`jabón liquido.png`, `jabón liquido rosa.png` y `jabón liquido amarillo.png` en
`assets/source/textures/props/`. El `.blend` no cambia. Después van `armar_atlas.py` y
`exportar_modelo.py`.

## Por qué

El plástico del cuerpo quedó liso y de un solo tono, aprobado así: sin estrías verticales y con
las costuras horizontales del hombro. Un bidón de jabón de un almacén no sale así de la caja:
tiene rayones de roce, manchas y suciedad donde la forma cambia y alrededor de la tapa.

## Qué cambia

Sólo el plástico: el cuerpo, el hombro, el pico y el fondo. Se suma encima, como una ganancia
de luz por píxel:

- **Suciedad** en los cambios de forma (el hombro, el pico, el fondo) y alrededor de la tapa.
- **Manchas** anchas y **rayones** finos y casi horizontales, claros y oscuros.
- **Roce** en las aristas.

La suciedad, las manchas y el roce se hornean desde la malla con las coordenadas del objeto, así
que siguen de una franja a la otra por la costura: las dos franjas que se tocan no se cortan.
Los rayones se pintan en la imagen y se apagan cerca del borde de cada franja, así que no dejan
un escalón en la unión. La ganancia se reparte para que el tono medio del plástico no cambie. La
tapa, la etiqueta envolvente y lo que no es plástico no se tocan: la máscara sale de las caras
del plástico.

Las tres imágenes comparten la UV, así que se hornea una vez. Cada una lleva sus propios rayones.

El original vive en `assets/source/textures/props/sin_detalle/` y el script parte siempre de
ahí: corrido dos veces da lo mismo. La primera corrida lo copia.

## Lo que cuesta

Ningún triángulo, material ni textura de más: las imágenes miden lo mismo y viajan en el atlas.
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
    forma,
    hornear,
    leer_png,
    preparar_cycles,
    rayones,
    restaurar,
    salida,
    suave,
    uso,
)
from lib.consola import configurar  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
PROPS = RAIZ / "assets/source/textures/props"
SIN_DETALLE = PROPS / "sin_detalle"
BIDON = "bidón jabon01-col.002"
TEXTURAS = ("jabón liquido.png", "jabón liquido rosa.png", "jabón liquido amarillo.png")
CUERPO = 0
#: Del pico para arriba el material es la tapa. El pico llega a esta altura, en metros.
ALTO_DEL_PICO = 0.3175
MARGEN = 6

#: Los rayones van casi horizontales, a lo ancho del bidón: nunca se leen como estrías verticales.
DISPERSION_DE_RAYONES = 0.30
#: Los rayones se apagan a `SIN_RAYONES` píxeles del borde de una franja y vuelven a `CON_RAYONES`.
SIN_RAYONES, CON_RAYONES = 4, 10
#: Las alturas, en metros, donde la forma cambia: el comienzo del hombro y del pico.
QUIEBRES = (0.057, 0.13, 0.292)

#: Cuánto sube o baja la luz de cada efecto.
SUCIEDAD, MANCHAS, RAYON_CLARO, RAYON_OSCURO, ROCE = 0.20, 0.07, 0.20, 0.14, 0.13


def plastico(objeto) -> set[int]:
    """Las caras del plástico: el material del cuerpo, del pico para abajo."""
    malla = objeto.data
    return {
        cara.index
        for cara in malla.polygons
        if cara.material_index == CUERPO
        and max(malla.vertices[i].co.z for i in cara.vertices) <= ALTO_DEL_PICO
    }


def partir(nombre: str) -> np.ndarray:
    """El original, tal como estaba antes del detalle. La primera vez lo copia a `sin_detalle/`."""
    original = SIN_DETALLE / nombre
    if not original.exists():
        SIN_DETALLE.mkdir(exist_ok=True)
        shutil.copyfile(PROPS / nombre, original)
    return leer_png(original)


def hornear_capas(objeto, lado: int):
    """Máscara del plástico, forma, manchas y altura, todo en la UV del bidón."""
    caras = plastico(objeto)
    fuera = {c.index for c in objeto.data.polygons} - caras
    mascara = cobertura(objeto, caras, lado)
    capas = []
    for armar in (forma, uso, altura_del_mundo(objeto)):
        copia = copia_aparte(objeto, fuera)
        try:
            capas.append(hornear(copia, armar, lado, MARGEN))
        finally:
            descartar(copia)
    return mascara, capas[0], capas[1], capas[2][..., 0]


def ganancia(forma_h, manchas_h, altura, bajo: float, alto: float) -> np.ndarray:
    """La luz que se suma a cada píxel del plástico: 1 no cambia nada."""
    oclusion, canto, _ = (forma_h[..., i] for i in range(3))
    manchas = manchas_h[..., 0]
    metros = bajo + altura * (alto - bajo)

    quiebre = np.zeros_like(metros)
    for z in QUIEBRES:
        quiebre = np.maximum(quiebre, np.exp(-(((metros - z) / 0.018) ** 2)))
    tapa = suave(ALTO_DEL_PICO - 0.020, ALTO_DEL_PICO, metros)
    hueco = np.clip((0.90 - oclusion) / 0.5, 0.0, 1.0)
    modulo = 0.55 + 0.9 * suave(0.35, 0.75, manchas)
    sucio = np.clip(hueco + (quiebre * 0.7 + tapa) * modulo, 0.0, 1.0)

    nube = suave(0.52, 0.72, desenfocar(manchas, 2))
    roce = np.clip(canto * 9.0, 0.0, 1.0)
    return 1.0 - SUCIEDAD * sucio - MANCHAS * nube + ROCE * roce


def rayar(mascara: np.ndarray, semilla: int) -> np.ndarray:
    """La ganancia de los rayones: líneas claras largas y marcas oscuras cortas."""
    lado = mascara.shape[0]
    borde = distancia_al_borde(mascara, CON_RAYONES)
    adentro = suave(SIN_RAYONES, CON_RAYONES, borde)
    claros = rayones(lado, lado, 220, 70, semilla, 3, 0.0, DISPERSION_DE_RAYONES)
    oscuros = rayones(lado, lado, 140, 26, semilla + 1, 3, 0.0, DISPERSION_DE_RAYONES)
    return (RAYON_CLARO * claros - RAYON_OSCURO * oscuros) * adentro


def aplicar(base: np.ndarray, mascara: np.ndarray, gan: np.ndarray, rayas: np.ndarray):
    """Multiplica el plástico por la ganancia y devuelve el tono medio a lo que era."""
    peso = np.clip(desenfocar(mascara, 1) * 1.5, 0.0, 1.0)[..., None]
    adentro = mascara > 0.5
    gan = (gan + rayas)[..., None]
    antes = base[adentro].mean(axis=0)
    mezcla = base * (1.0 + (gan - 1.0) * peso)
    media = mezcla[adentro].mean(axis=0)
    ajuste = np.where(adentro[..., None], antes / media, 1.0)
    return np.clip(base + (mezcla * ajuste - base) * peso, 0.0, 1.0)


def main() -> None:
    configurar()
    objeto = bpy.data.objects[BIDON]
    primera = partir(TEXTURAS[0])
    lado = primera.shape[0]
    zs = [v.co.z for v in objeto.data.vertices]
    antes = preparar_cycles()
    try:
        mascara, forma_h, manchas_h, altura = hornear_capas(objeto, lado)
    finally:
        restaurar(antes)
    gan = ganancia(forma_h, manchas_h, altura, min(zs), max(zs))
    for semilla, nombre in enumerate(TEXTURAS, start=1):
        base = partir(nombre)
        color = aplicar(base, mascara, gan, rayar(mascara, 100 * semilla))
        adentro = mascara > 0.5
        antes_medio = base[adentro].mean(axis=0)
        despues_medio = color[adentro].mean(axis=0)
        fuera = ~(desenfocar(mascara, 3) > 0.02)
        cambio = np.abs(color - base)[fuera].max()
        destino = salida(PROPS / nombre)
        escribir_png(color, destino)
        print(
            f"bidón: {destino.name}  media {np.round(antes_medio, 3)} -> "
            f"{np.round(despues_medio, 3)}"
            f"  cambio fuera del plástico {cambio:.4f}"
        )


if __name__ == "__main__":
    main()
