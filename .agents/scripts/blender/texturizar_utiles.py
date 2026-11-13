"""Hornea en una sola textura el detalle del balde y de la mopa: oclusión, bordes, uso y hebras.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_utiles.py -- [--aplicar]

Sin `--aplicar` deja la textura en la carpeta temporal y no guarda nada. Con `--aplicar` escribe
`TEXTURA` y guarda la fuente canónica. Después va `exportar_modelo.py`.

## Por qué

El balde y la mopa eran colores lisos: en el cuartito, contra los bloques con relieve, se leían
como juguetes. El detalle va horneado en el color, como el bisel de las etiquetas, porque la luz
del juego no deja brillo que un mapa de relieve pueda mover.

## Qué cambia

- Los dos objetos ganan una UV, la mitad izquierda de la textura para el balde y la derecha para
  la mopa. La geometría no se toca.
- Cada cara guarda su color original en el atributo `ranura_original`, y de ahí se hornea: correrlo de
  nuevo da la misma textura.
- Las ranuras que el juego pinta con el mismo shader se unen. El color ya viaja en la textura, y
  cada ranura es un dibujo más. Los nombres que el juego busca siguen estando.
"""

import sys
import tempfile
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import detalle_horneado as detalle  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

TEXTURA = RAIZ / "assets/source/textures/props/utiles_de_limpieza.png"
LADO = 512
MARGEN = 8

#: El color liso que tenía cada material, en lineal. Es la base de lo que se hornea.
COLORES = {
    "util_plastico_azul": (0.035, 0.16, 0.32),
    "util_plastico_claro": (0.06, 0.23, 0.42),
    "util_borde_crema": (0.68, 0.72, 0.7),
    "util_asa_grafito": (0.08, 0.105, 0.12),
    "util_mango_acero": (0.36, 0.42, 0.45),
    "util_fibra_cruda": (0.72, 0.7, 0.62),
    "util_fibra_sombra": (0.58, 0.57, 0.5),
}
FIBRAS = ("util_fibra_cruda", "util_fibra_sombra")

#: Qué ranura absorbe a cuál en cada objeto, y en qué mitad de la textura cae su UV.
OBJETOS = {
    "balde-col": {"une": {"util_asa_grafito": "util_borde_crema"}, "columna": 0},
    "mopa-col": {
        "une": {"util_asa_grafito": "util_plastico_azul", "util_fibra_sombra": "util_fibra_cruda"},
        "columna": 1,
    },
}


def pintar(base, forma, uso, altura) -> np.ndarray:
    """El color final, en lineal, desde las capas horneadas."""
    oclusion, arista, grano = forma[..., 0:1], forma[..., 1:2], forma[..., 2:3]
    manchas, hebras, rayones = uso[..., 0:1], uso[..., 1:2], uso[..., 2:3]
    alto = altura[..., 2:3]
    es_fibra = np.zeros(base.shape[:2] + (1,), dtype=bool)
    for nombre in FIBRAS:
        es_fibra |= np.abs(base - np.array(COLORES[nombre])).sum(axis=2, keepdims=True) < 0.02

    luz = 0.5 + 0.5 * np.clip(oclusion, 0, 1) ** 1.3
    plastico = base * luz * (0.93 + 0.14 * grano)
    suciedad = np.clip((manchas - 0.48) * 4, 0, 1) * np.clip(1 - alto * 3.2, 0, 1)
    velo = np.clip((manchas - 0.58) * 5, 0, 1) * 0.35
    plastico = plastico * (1 - 0.55 * np.maximum(suciedad, velo))
    raya = np.clip((np.abs(rayones - 0.5) - 0.2) * 25, 0, 1) * np.clip((manchas - 0.4) * 4, 0, 1)
    plastico = plastico + (0.55 - plastico) * raya * 0.35
    canto = np.clip(arista * 5, 0, 1)
    plastico = plastico + (np.minimum(plastico * 1.7 + 0.05, 1) - plastico) * canto * 0.7

    fibra = base * (0.45 + 0.55 * np.clip(oclusion, 0, 1)) * (0.62 + 0.76 * hebras)
    return np.clip(np.where(es_fibra, fibra, plastico), 0, 1)


def main() -> None:
    configurar()
    aplicar = "--aplicar" in sys.argv
    antes = detalle.preparar_cycles()
    color = np.zeros((LADO, LADO, 3), dtype=np.float32)
    for nombre, datos in OBJETOS.items():
        objeto = bpy.data.objects[nombre]
        originales = detalle.guardar_ranuras(objeto.data, COLORES)
        detalle.desplegar(objeto, datos["columna"], len(OBJETOS), LADO, MARGEN)
        copia = detalle.copia_con_color(objeto, [COLORES[nombre_] for nombre_ in originales])
        capas = detalle.capas(copia, LADO, MARGEN)
        detalle.descartar(copia)
        mitad = slice(datos["columna"] * LADO // 2, (datos["columna"] + 1) * LADO // 2)
        color[:, mitad] = pintar(*capas)[:, mitad]
        detalle.unir_ranuras(objeto, originales, datos["une"])
        print(f"{nombre}: {len(originales)} caras horneadas")
    detalle.restaurar(antes)
    destino = TEXTURA if aplicar else Path(tempfile.gettempdir()) / TEXTURA.name
    detalle.escribir(color, destino)
    print(f"textura: {destino}")
    if aplicar:
        detalle.cablear(destino, COLORES)
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
