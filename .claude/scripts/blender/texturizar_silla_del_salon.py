"""Pinta el uso de la carcasa de la silla del salón: suciedad en el pliegue, roce en los cantos.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_silla_del_salon.py -- [--aplicar]

Sin `--aplicar` escribe la imagen en `build/plastico/`, para mirarla. Con `--aplicar` escribe
`assets/source/textures/store/silla_plastico_blanco.png`. El `.blend` no cambia. Después van
`armar_atlas.py` y `exportar_modelo.py`.

## Por qué

La carcasa era un blanco liso de punta a punta. Una silla de plástico blanco no es lisa: se
ensucia en los huecos y en el pliegue entre asiento y respaldo, se gasta donde se sienta y se
apoya la espalda, y el roce deja los cantos más limpios que el resto.

## Qué cambia

Sólo la imagen. Parte del blanco hueso de siempre, que se reescribe en cada corrida, y suma:

- **Pliegue**: mugre gris parda en el encuentro de asiento y respaldo, donde se junta el polvo.
- **Cantos**: el borde se aclara por el roce y se le pican unos puntos de suciedad. La cara de
  abajo guarda más mugre en el borde.
- **Uso**: manchas anchas, rayones finos y roces cortos, más marcados donde se sienta y donde se
  apoya la espalda, más una pinta de suciedad fina.
- **Tono**: una variación suave de blanco a hueso.

La malla sólo aporta dónde pinta la UV (`cobertura`) y el largo del asiento (`PERFIL`). La
carcasa es una superficie suave y abierta: su oclusión horneada sale casi plana, y no sirve para
marcar el pliegue.

La cara de arriba va en la mitad izquierda de la imagen y la de abajo en la derecha.

## Lo que cuesta

Ningún triángulo, ningún material ni textura de más. La imagen mide lo mismo.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from detalle_de_plastico import (  # noqa: E402
    cobertura,
    distancia_al_borde,
    escribir_png,
    preparar_cycles,
    rayones,
    restaurar,
    ruido,
    salida,
    suave,
)
from lib.consola import configurar  # noqa: E402
from moldear_silla_del_salon import PERFIL  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
TEXTURA = RAIZ / "assets/source/textures/store/silla_plastico_blanco.png"
OBJETO = "salon_silla_1a-col"
CARCASA = 0
LADO = 1024
#: El punto del perfil donde el asiento termina y el respaldo empieza a subir.
PUNTO_DEL_PLIEGUE = 6.5

#: El blanco hueso de partida, y los tonos que se le mezclan encima.
BASE = np.array([0.82, 0.81, 0.76], dtype=np.float32)
POLVO = np.array([0.66, 0.63, 0.55], dtype=np.float32)
MUGRE = np.array([0.40, 0.37, 0.30], dtype=np.float32)
GRIS_DEL_ROCE = np.array([0.58, 0.58, 0.54], dtype=np.float32)
LIMPIO = np.array([0.93, 0.93, 0.89], dtype=np.float32)


def fraccion_del_pliegue() -> float:
    """Dónde cae el pliegue sobre la v de la UV: el largo del perfil hasta ese punto."""
    largos = [0.0]
    for (y0, z0), (y1, z1) in zip(PERFIL, PERFIL[1:]):
        largos.append(largos[-1] + ((y1 - y0) ** 2 + (z1 - z0) ** 2) ** 0.5)
    k = int(PUNTO_DEL_PLIEGUE)
    punto = largos[k] + (largos[k + 1] - largos[k]) * (PUNTO_DEL_PLIEGUE - k)
    return punto / largos[-1]


def zona_de_uso(u: np.ndarray, v: np.ndarray, pliegue: float) -> np.ndarray:
    """Dónde se sienta y dónde se apoya la espalda, 0..1."""
    centro = np.exp(-(((u - 0.5) / 0.30) ** 2))
    asiento = np.exp(-(((v - pliegue * 0.5) / (pliegue * 0.35)) ** 2))
    espalda = np.exp(-(((v - (pliegue + 1.0) / 2 + 0.05) / 0.14) ** 2))
    return centro * np.maximum(asiento, espalda * 0.85)


def mezclar(color: np.ndarray, tono: np.ndarray, cuanto: np.ndarray) -> np.ndarray:
    return color + (tono[None, None, :] - color) * np.clip(cuanto, 0.0, 1.0)[..., None]


def pintar(dentro: np.ndarray) -> np.ndarray:
    pliegue = fraccion_del_pliegue()
    filas = np.arange(LADO, dtype=np.float32)[:, None] / (LADO - 1)
    columnas = np.arange(LADO, dtype=np.float32)[None, :] / (LADO - 1)
    de_abajo = np.broadcast_to(columnas >= 0.5, (LADO, LADO))
    u = np.broadcast_to(np.where(columnas >= 0.5, columnas - 0.5, columnas) * 2.0, (LADO, LADO))
    v = np.broadcast_to(filas, (LADO, LADO))
    uso = zona_de_uso(u, v, pliegue)
    abajo = de_abajo.astype(np.float32)

    borde = distancia_al_borde(dentro, 40)
    borde = np.where(dentro > 0.5, borde, 0.0)
    cerca = np.exp(-borde / 14.0) * 0.999

    nubes = ruido(LADO, LADO, 190, 11)
    manchas = ruido(LADO, LADO, 70, 12)
    vetas = ruido(LADO, LADO, 22, 13, octavas=3)
    polvo_fino = ruido(LADO, LADO, 3, 14, octavas=2)

    color = np.broadcast_to(BASE, (LADO, LADO, 3)).copy()
    color *= (1.0 + (nubes - 0.5) * 0.12)[..., None]

    # Polvo en parches anchos, más en lo que se usa.
    polvo = suave(0.45, 0.68, manchas) * (0.10 + 0.32 * uso) + abajo * 0.10
    color = mezclar(color, POLVO, polvo)

    # El pliegue entre asiento y respaldo junta mugre, con vetas hacia los lados.
    banda = np.exp(-(((v - pliegue) / 0.045) ** 2))
    pegado = banda * (0.55 + 0.9 * (vetas - 0.5)) * (0.55 + 0.45 * suave(0.25, 0.75, vetas))
    color = mezclar(color, MUGRE, pegado * 0.95)

    # El borde de abajo guarda mugre; el de arriba se pule.
    color = mezclar(color, MUGRE, abajo * cerca * 0.30 * (0.6 + 0.8 * vetas))
    roce = (1 - abajo) * np.clip(cerca * 1.5 - 0.15, 0.0, 1.0) * dentro
    color = mezclar(color, LIMPIO, roce * 0.65)

    # Rayones largos y roces cortos, donde se usa.
    mapa = 0.18 + 0.82 * np.maximum(uso, banda)
    largos = rayones(LADO, LADO, 300, 80, 21, grosor=2, peso=mapa)
    cortos = rayones(LADO, LADO, 240, 20, 22, grosor=3, peso=mapa)
    color = mezclar(color, GRIS_DEL_ROCE, largos * 0.62)
    color = mezclar(color, GRIS_DEL_ROCE, cortos * 0.45)
    claros = rayones(LADO, LADO, 130, 50, 23, grosor=2, peso=1 - abajo * 0.5)
    color = mezclar(color, LIMPIO, claros * 0.55)

    # Puntos de suciedad finos y picado del borde.
    puntos = suave(0.74, 0.86, polvo_fino) * (0.25 + 0.75 * np.maximum(uso, cerca))
    color = mezclar(color, MUGRE, puntos * 0.40)
    picado = cerca**2 * suave(0.62, 0.74, polvo_fino)
    color = mezclar(color, MUGRE, picado * 0.35)
    return color


def main() -> None:
    configurar()
    objeto = bpy.data.objects[OBJETO]
    carcasa = {c.index for c in objeto.data.polygons if c.material_index == CARCASA}
    antes = preparar_cycles()
    try:
        dentro = cobertura(objeto, carcasa, LADO)
    finally:
        restaurar(antes)
    color = pintar(dentro)
    destino = salida(TEXTURA)
    escribir_png(color, destino)
    print(f"silla: {destino}  media {np.round(color.reshape(-1, 3).mean(0), 3)}")


if __name__ == "__main__":
    main()
