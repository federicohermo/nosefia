"""Reduce el atlas del horneado de la noche del corte a la mitad de lado.

    blender --background --python-exit-code 1 \
        --python .claude/scripts/blender/reducir_mapa_de_luz.py -- --aplicar --lado 1024 EXR ...

Sin `--aplicar` sólo informa. Con `--aplicar` reescribe cada archivo en su lugar. `hornear.py
--sin-luz` lo llama solo, con el lado de `LADO_DEL_ATLAS_SIN_LUZ` de `lib/horneado.py`.

## Por qué

El horneador deja el atlas de la noche del corte en 2048 px de lado por capa. Es una imagen casi
negra: en BC6H pesa 16,8 MB, y con 1024 px, 4,2 MB. El export web de la rama pasaba el techo de
150 MiB por esos 12 MB. El horneado con luz no se reduce.

## Cómo

Cada texel nuevo es el promedio de su bloque de 2 por 2. Las cuatro capas viajan apiladas en una
sola imagen, y como el alto de cada una es par, ningún bloque cruza de una capa a la otra.

**Se reduce después de reparar las líneas, nunca antes** (`reparar_lineas_del_mapa_de_luz.py`). Su
huella es la de un texel a media luz entre dos vecinos parejos, y un promedio de 2 por 2 la
repartiría entre dos texeles: el reparador ya no la reconocería. `hornear.py` los llama en ese
orden. El borde entre dos piezas vecinas del atlas pierde la mitad de su margen.

## Qué no hace

- **Un atlas que ya tiene el lado pedido no cambia.** No se reescribe.
- **Un atlas con otro lado que el pedido o su doble frena y lo dice.** No se estira.
- **Si algo sale mal a mitad de camino, el archivo queda como estaba:** se escribe aparte, se
  vuelve a leer, y sólo entonces reemplaza al original.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import numpy as np

#: Las capas de un horneado direccional: la de color y las tres de dirección, apiladas.
CAPAS = 4
#: Por cuánto se divide el lado en cada pasada: un bloque de 2 por 2 texeles.
FACTOR = 2


def reducir(datos: np.ndarray, lado: int) -> np.ndarray:
    """El atlas llevado a `lado` px por capa: el promedio de cada bloque de 2 por 2."""
    alto, ancho, _ = datos.shape
    if alto != CAPAS * ancho:
        raise SystemExit(
            f"el mapa trae {alto / ancho:g} capas y se esperaban {CAPAS}: revisar si el horneado "
            "sigue siendo direccional y de una sola porción"
        )
    if ancho == lado:
        return datos
    if ancho != lado * FACTOR:
        raise SystemExit(
            f"el mapa mide {ancho} px de lado y sólo se reduce uno de {lado * FACTOR} a {lado}: "
            "no se estira ni se reduce a otra escala"
        )
    bloques = datos.reshape(alto // FACTOR, FACTOR, ancho // FACTOR, FACTOR, datos.shape[2])
    return bloques.mean(axis=(1, 3), dtype=np.float64).astype(np.float32)


def main() -> None:
    # Blender no deja a otro script en el camino de búsqueda: el reparador comparte la lectura y
    # el guardado, y vive al lado.
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import reparar_lineas_del_mapa_de_luz as mapa

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    aplicar = "--aplicar" in argumentos
    if "--lado" not in argumentos:
        raise SystemExit("falta --lado: a cuántos px de lado va cada capa")
    donde = argumentos.index("--lado") + 1
    lado = int(argumentos[donde])
    rutas = [
        Path(a) for i, a in enumerate(argumentos) if i != donde and not a.startswith("--")
    ]
    if not rutas:
        raise SystemExit("faltan los atlas a reducir")
    for ruta in rutas:
        original = mapa.leer(ruta)
        reducido = reducir(original, lado)
        if reducido is original:
            print(f"{ruta.name}: ya mide {lado} px de lado")
            continue
        print(f"{ruta.name}: de {original.shape[1]} a {lado} px de lado")
        if not aplicar:
            continue
        nuevo = ruta.with_name(ruta.stem + ".reducido.exr")
        try:
            mapa.guardar(reducido, nuevo)
            escrito = mapa.leer(nuevo)
            mal = float(np.abs(escrito - reducido).max()) if escrito.shape == reducido.shape else -1
            if mal != 0:
                raise SystemExit(f"{ruta.name}: al guardar cambió la imagen ({mal}); queda el original")
            os.replace(nuevo, ruta)
        finally:
            nuevo.unlink(missing_ok=True)
        print(f"   guardado: {lado} px de lado")


if __name__ == "__main__":
    main()
