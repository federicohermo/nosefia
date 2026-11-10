"""Hornea de nuevo el cuerpo de los tres bidones de jabón: plástico liso con oclusión, bordes y uso.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_bidones.py -- [--aplicar]

Sin `--aplicar` deja las texturas en la carpeta temporal. Con `--aplicar` escribe sobre la textura
del cuerpo de cada bidón. El `.blend` no cambia. Después van `armar_atlas.py` y
`exportar_modelo.py`.

## Por qué

El cuerpo tenía dibujados gajos verticales y manchas, y en el juego se leía como un bidón de
facetas planas aunque la malla es lisa. El detalle nuevo sale de la malla, igual que en el balde.

## Qué cambia

Sólo el dibujo del cuerpo y de la tapa. La UV, la malla y la etiqueta envolvente no se tocan. El
color de la tapa y el del cuerpo se miden en la textura anterior: cada bidón conserva el suyo.
"""

import sys
import tempfile
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import detalle_horneado as detalle  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

BIDONES = ("bidón jabon01-col", "bidón jabon01-col.001", "bidón jabon01-col.002")
LADO = 1024
MARGEN = 16

#: Desde qué saturación un color de la textura anterior es la tapa y no el cuerpo crema, y desde
#: qué fracción del alto del bidón puede haber tapa. Más abajo, un color saturado era el dibujo de
#: la etiqueta vieja.
SATURACION_DE_LA_TAPA = 0.35
ALTURA_DE_LA_TAPA = 0.8
ESTRIAS_DE_LA_TAPA = 18


def _lineal(srgb: np.ndarray) -> np.ndarray:
    return np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)


def colores_del_cuerpo(objeto) -> tuple[list[tuple[float, float, float]], Path]:
    """El color liso de cada cara del cuerpo, medido en la textura anterior, y la ruta de ésta."""
    malla = objeto.data
    material = malla.materials[0]
    imagen = next(n.image for n in material.node_tree.nodes if n.type == "TEX_IMAGE")
    ancho, alto = imagen.size
    pixeles = np.empty(ancho * alto * 4, dtype=np.float32)
    imagen.pixels.foreach_get(pixeles)
    pixeles = pixeles.reshape(alto, ancho, 4)[..., :3]
    capa = malla.uv_layers[0].data
    alturas = [vertice.co.z for vertice in malla.vertices]
    corte = min(alturas) + (max(alturas) - min(alturas)) * ALTURA_DE_LA_TAPA
    muestras, es_tapa = [], []
    for cara in malla.polygons:
        u = sum(capa[i].uv.x for i in cara.loop_indices) / cara.loop_total
        v = sum(capa[i].uv.y for i in cara.loop_indices) / cara.loop_total
        color = pixeles[int(v % 1.0 * (alto - 1)), int(u % 1.0 * (ancho - 1))]
        saturacion = (color.max() - color.min()) / max(float(color.max()), 1e-4)
        muestras.append(color)
        arriba = cara.center.z > corte
        es_tapa.append(cara.material_index == 0 and arriba and saturacion > SATURACION_DE_LA_TAPA)
    del_cuerpo = [m for m, t, c in zip(muestras, es_tapa, malla.polygons) if not t and c.material_index == 0]
    tapa = np.median([m for m, t in zip(muestras, es_tapa) if t], axis=0)
    cuerpo = np.median(del_cuerpo, axis=0)
    # La textura anterior traía el cuerpo manchado: su mediana es más oscura que el plástico limpio.
    cuerpo = np.clip(cuerpo * 1.12, 0, 1)
    colores = [tuple(tapa if t else cuerpo) for t in es_tapa]
    return colores, Path(bpy.path.abspath(imagen.filepath))


def sin_la_etiqueta(copia) -> None:
    """La etiqueta envolvente usa otra textura: sus caras no pueden caer en ésta."""
    malla = bmesh.new()
    malla.from_mesh(copia.data)
    bmesh.ops.delete(malla, geom=[c for c in malla.faces if c.material_index != 0], context="FACES")
    malla.to_mesh(copia.data)
    malla.free()


def pintar(base, forma, uso, altura) -> np.ndarray:
    oclusion, arista, grano = forma[..., 0:1], forma[..., 1:2], forma[..., 2:3]
    manchas, vetas, rayones = uso[..., 0:1], uso[..., 1:2], uso[..., 2:3]
    alto = altura[..., 2:3]
    plastico = base * (0.5 + 0.5 * np.clip(oclusion, 0, 1) ** 1.6) * (0.95 + 0.1 * grano)
    # Las vetas son del soplado del envase: corren a lo alto y apenas cambian el tono.
    plastico = plastico * (0.96 + 0.08 * vetas)
    roce = np.clip((manchas - 0.5) * 4, 0, 1) * np.clip(1 - alto * 4.0, 0, 1)
    plastico = plastico * (1 - 0.14 * roce)
    raya = np.clip((np.abs(rayones - 0.5) - 0.22) * 25, 0, 1) * np.clip((manchas - 0.45) * 4, 0, 1)
    plastico = plastico * (1 - 0.12 * raya)
    canto = np.clip(arista * 5, 0, 1)
    plastico = plastico + (np.minimum(plastico * 1.35 + 0.03, 1) - plastico) * canto * 0.5
    # El estriado de la tapa a rosca: surcos alrededor del eje, sólo donde el color es el de la tapa.
    tope = np.maximum(base.max(axis=2, keepdims=True), 1e-4)
    es_tapa = (tope - base.min(axis=2, keepdims=True)) / tope > 0.6
    angulo = np.arctan2(altura[..., 1:2] - 0.5, altura[..., 0:1] - 0.5)
    surco = 0.5 + 0.5 * np.sin(angulo * ESTRIAS_DE_LA_TAPA)
    plastico = np.where(es_tapa, plastico * (0.6 + 0.55 * surco), plastico)
    return np.clip(plastico, 0, 1)


def main() -> None:
    configurar()
    aplicar = "--aplicar" in sys.argv
    antes = detalle.preparar_cycles()
    for nombre in BIDONES:
        objeto = bpy.data.objects[nombre]
        colores, anterior = colores_del_cuerpo(objeto)
        copia = detalle.copia_con_color(objeto, [tuple(_lineal(np.array(c))) for c in colores])
        # `copia_con_color` deja todo en la ranura 0: la etiqueta se saca por el original.
        for cara, original in zip(copia.data.polygons, objeto.data.polygons):
            cara.material_index = original.material_index
        sin_la_etiqueta(copia)
        color = pintar(*detalle.capas(copia, LADO, MARGEN))
        detalle.descartar(copia)
        destino = anterior if aplicar else Path(tempfile.gettempdir()) / anterior.name
        detalle.escribir(color, destino)
        print(f"{nombre}: {destino}")
    detalle.restaurar(antes)


if __name__ == "__main__":
    main()
