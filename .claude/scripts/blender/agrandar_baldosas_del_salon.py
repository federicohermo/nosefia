"""Agranda las baldosas del salón y las hace calzar con las paredes y con el zócalo, sólo por UV.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/agrandar_baldosas_del_salon.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.
Después va `exportar_modelo.py`.

## Qué cambia

- **El piso** lleva `BALDOSAS` baldosas enteras de pared a pared, en cada sentido. El recinto se
  mide en el zócalo, que corre pegado a las paredes. El salón no es múltiplo exacto de un lado,
  así que la baldosa mide 2 milímetros más en un sentido que en el otro.
- **El zócalo** es la baldosa del piso doblada hacia arriba: cada tramo sigue la cuadrícula del
  piso, y sus juntas caen donde caen las del piso.

La textura trae las baldosas a 45 grados y tres por diagonal: el giro las deja paralelas a las
paredes. UV2 y la geometría no se tocan. Es idempotente.
"""

import math
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

EDIFICIO = "almacen-col"
ZOCALO = "local_zocalo_perimetral"
PISO = "local_ceramica"
BALDOSAS = (11, 15)
BALDOSAS_POR_DIAGONAL = 3


def recinto() -> tuple[float, float, float, float, float]:
    """Dónde empieza el salón en x y en y, el lado de la baldosa en cada sentido y el piso."""
    zocalo = bpy.data.objects[ZOCALO]
    puntos = [zocalo.matrix_world @ vertice.co for vertice in zocalo.data.vertices]
    x0, x1 = min(p.x for p in puntos), max(p.x for p in puntos)
    y0, y1 = min(p.y for p in puntos), max(p.y for p in puntos)
    return x0, y0, (x1 - x0) / BALDOSAS[0], (y1 - y0) / BALDOSAS[1], min(p.z for p in puntos)


def uv_de(a: float, b: float) -> tuple[float, float]:
    """La UV de un punto de la cuadrícula, medido en baldosas desde la esquina del salón."""
    repeticion = BALDOSAS_POR_DIAGONAL * math.sqrt(2)
    return (a + b) / repeticion, (b - a) / repeticion


def tender(objeto, x0, y0, lado_x, lado_y, piso, doblar: bool) -> int:
    malla = objeto.data
    mundo = objeto.matrix_world
    giro = mundo.to_3x3()
    nombres = [material.name for material in malla.materials]
    capa = malla.uv_layers[0].data
    caras = 0
    for cara in malla.polygons:
        if nombres[cara.material_index] != PISO:
            continue
        caras += 1
        normal = (giro @ cara.normal).normalized()
        for lazo in cara.loop_indices:
            punto = mundo @ malla.vertices[malla.loops[lazo].vertex_index].co
            a, b = (punto.x - x0) / lado_x, (punto.y - y0) / lado_y
            if doblar and abs(normal.z) < 0.5:
                # Una cara vertical del zócalo sigue el piso hacia afuera de la pared.
                alto = punto.z - piso
                a -= normal.x * alto / lado_x
                b -= normal.y * alto / lado_y
            capa[lazo].uv = uv_de(a, b)
    if caras == 0:
        raise ValueError(f"{objeto.name} no tiene caras con {PISO}")
    return caras


def main() -> None:
    configurar()
    x0, y0, lado_x, lado_y, piso = recinto()
    del_piso = tender(bpy.data.objects[EDIFICIO], x0, y0, lado_x, lado_y, piso, doblar=False)
    del_zocalo = tender(bpy.data.objects[ZOCALO], x0, y0, lado_x, lado_y, piso, doblar=True)
    print(f"baldosa de {lado_x:.3f} x {lado_y:.3f} m: {del_piso} caras de piso, {del_zocalo} de zócalo")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
