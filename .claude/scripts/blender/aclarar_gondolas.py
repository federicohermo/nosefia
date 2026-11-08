"""Lleva el cuerpo de la góndola al tono de `lib/gondolas.py`. Corre en Blender.

    blender --background assets/models/SEPT_JUEGOS_PROTOTIPO.blend --python-exit-code 1 \
        --python .claude/scripts/blender/aclarar_gondolas.py -- [--sin-guardar]

Lo lanza `aclarar_gondolas.py` de la raíz. **No se corre a mano.**

## Lo que muerde

- **Son imágenes empaquetadas** con la ruta de otra máquina. Se leen de los píxeles, y el material
  apunta al PNG nuevo. La original queda sin usuarios y se pierde al guardar: para repetir hay
  que restaurar el `.blend` con git. La herramienta se niega a aplicarse dos veces.
- **El color base de Blender es lineal y la imagen no.** Aquí todo se hace sobre valores de imagen.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib import gondolas  # noqa: E402


def _pixeles(imagen: "bpy.types.Image") -> np.ndarray:
    ancho, alto = imagen.size
    datos = np.empty(ancho * alto * 4, dtype=np.float32)
    imagen.pixels.foreach_get(datos)
    return datos.reshape(alto, ancho, 4)


def aclarar(rgba: np.ndarray, tono: tuple[float, float, float] = gondolas.TONO) -> np.ndarray:
    """La imagen con cada canal multiplicado para llegar al tono, sin pasar de 1."""
    medias = tuple(float(rgba[..., c].mean()) for c in range(3))
    nuevo = rgba.copy()
    for canal, factor in enumerate(gondolas.factores(medias, tono)):
        nuevo[..., canal] = np.clip(rgba[..., canal] * factor, 0.0, 1.0)
    return nuevo


def elevar(rgba: np.ndarray, piso: tuple[float, float, float]) -> np.ndarray:
    """La imagen con su negro subido hasta el piso. El blanco queda en 1."""
    nuevo = rgba.copy()
    for canal, nivel in enumerate(piso):
        nuevo[..., canal] = nivel + rgba[..., canal] * (1.0 - nivel)
    return nuevo


def _escribir(rgba: np.ndarray, destino: Path) -> None:
    """Escribe el PNG con `Image.save`, que no aplica la transformación de vista de la escena."""
    alto, ancho = rgba.shape[:2]
    imagen = bpy.data.images.new(destino.stem, ancho, alto, alpha=False)
    try:
        imagen.colorspace_settings.name = "sRGB"
        imagen.pixels.foreach_set(np.ascontiguousarray(rgba[::-1]).reshape(-1))
        imagen.file_format = "PNG"
        imagen.filepath_raw = str(destino)
        destino.parent.mkdir(parents=True, exist_ok=True)
        imagen.save()
    finally:
        bpy.data.images.remove(imagen)


def aplicar(
    nombre: str, nivel: tuple[float, float, float], transformar=aclarar
) -> str:
    original = bpy.data.images.get(nombre)
    if original is None:
        raise SystemExit(f"el modelo no tiene la imagen {nombre}")
    nodos = [
        (m, n) for m in bpy.data.materials if m.use_nodes for n in m.node_tree.nodes
        if n.type == "TEX_IMAGE" and n.image == original
    ]
    if not nodos:
        raise SystemExit(f"{nombre} ya no la usa ningún material: ¿ya está aplicada? Restaurá el .blend")
    rgba = _pixeles(original)
    antes = [round(float(rgba[..., c].mean()), 3) for c in range(3)]
    nuevo = transformar(rgba, nivel)
    destino = gondolas.ruta_de_la_textura(nombre)
    _escribir(nuevo, destino)
    imagen = bpy.data.images.load(str(destino), check_existing=False)
    imagen.colorspace_settings.name = "sRGB"
    for _, nodo in nodos:
        nodo.image = imagen
    despues = [round(float(nuevo[..., c].mean()), 3) for c in range(3)]
    return f"gondola: {nombre} {antes} -> {despues} en {len(nodos)} nodos"


def paleta() -> str:
    """Los píxeles grises de la paleta pasan a `TONO`, y la imagen se guarda como PNG."""
    original = bpy.data.images.get(gondolas.PALETA)
    if original is None:
        raise SystemExit(f"el modelo no tiene la imagen {gondolas.PALETA}")
    nodos = [
        n for m in bpy.data.materials if m.use_nodes for n in m.node_tree.nodes
        if n.type == "TEX_IMAGE" and n.image == original
    ]
    if not nodos:
        raise SystemExit(f"{gondolas.PALETA} ya no la usa ningún material: ¿ya está aplicada?")
    rgba = _pixeles(original).copy()
    for columna in gondolas.PIXELES_GRISES:
        rgba[0, columna, :3] = gondolas.TONO
    rgba[0, gondolas.PIXEL_ROJO, :3] = gondolas.ROJO
    destino = gondolas.ruta_de_la_textura(gondolas.PALETA)
    _escribir(rgba, destino)
    imagen = bpy.data.images.load(str(destino), check_existing=False)
    imagen.colorspace_settings.name = "sRGB"
    for nodo in nodos:
        nodo.image = imagen
        nodo.interpolation = "Closest"
    return f"gondola: paleta, grises {gondolas.PIXELES_GRISES} y rojo {gondolas.PIXEL_ROJO} en {len(nodos)} nodos"


def colores_lisos() -> list[str]:
    informe = []
    for nombre, tono in gondolas.COLORES_LISOS.items():
        lineal = tuple(gondolas.a_lineal(c) for c in tono) + (1.0,)
        material = bpy.data.materials.get(nombre)
        if material is None:
            raise SystemExit(f"el modelo no tiene el material {nombre}")
        principal = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        antes = tuple(round(x, 3) for x in principal.inputs["Base Color"].default_value[:3])
        principal.inputs["Base Color"].default_value = lineal
        informe.append(f"gondola: {nombre} {antes} -> {tuple(round(x, 3) for x in lineal[:3])}")
    return informe


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    for nombre, tono in gondolas.TEXTURAS.items():
        print(aplicar(nombre, tono))
    for nombre, piso in gondolas.PISOS.items():
        print(aplicar(nombre, piso, elevar))
    for nombre in gondolas.SIN_TINTE:
        material = bpy.data.materials.get(nombre)
        if material is None:
            raise SystemExit(f"el modelo no tiene el material {nombre}")
        next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs[
            "Base Color"
        ].default_value = (1.0, 1.0, 1.0, 1.0)
        print(f"gondola: {nombre} sin tinte")
    print(paleta())
    for linea in colores_lisos():
        print(linea)
    if "--sin-guardar" not in sys.argv:
        bpy.ops.file.make_paths_relative()
        bpy.ops.wm.save_mainfile()
        print("guardado:", bpy.data.filepath)


if __name__ == "__main__":
    main()
