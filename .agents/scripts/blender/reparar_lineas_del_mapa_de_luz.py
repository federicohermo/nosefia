"""Repara las líneas de un texel a media luz que el horneador deja en el mapa de luz.

    blender --background --python-exit-code 1 \
        --python .claude/scripts/blender/reparar_lineas_del_mapa_de_luz.py -- [--aplicar] [EXR ...]

Sin archivos, revisa `src/escenas/almacen.exr` y `src/escenas/almacen_sin_luz.exr`. Sin `--aplicar`
sólo informa. Con `--aplicar` reescribe cada archivo en su lugar.

## Qué defecto es

Cada horneado deja, en una fila o una columna del atlas, texeles con otra luz que la de sus dos
vecinos: la mitad en la capa de color, y otra dirección en las tres capas de dirección. En el
local se ven como una raya oscura de 5 cm: sobre una pared, del piso al cielorraso, o cruzando el
cielorraso. Medido el 2026-11-16:

- **Está en la textura horneada.** No es una costura de UV2 (las aristas de esa pared comparten su
  UV2), ni un objeto, ni cómo se dibuja.
- **Lo tiene también el horneado de antes de tocar la pared de la ventanilla**, en otra columna y
  sobre tramos más cortos: nadie lo había visto.
- **Cambia de lugar con el reparto del atlas.** Cualquier cambio en la malla del edificio lo muda
  a otra pared. Volver a hornear no lo saca.

**La causa no está identificada.** La documentación del motor no lo describe. Esto corrige el
resultado, no el origen: si un horneado deja de producir líneas, el script no encuentra nada y no
escribe.

## Qué repara

El horneado es direccional: el archivo trae cuatro capas apiladas, la de color y tres de dirección.
La línea está en las cuatro, y con reparar sólo el color la raya queda, más tenue.

1. **La línea se reconoce por su huella en el color.** Un tramo recto de `LARGO_MINIMO` texeles o
   más donde el texel vale la mitad de sus dos vecinos de al lado, entre `MITAD[0]` y `MITAD[1]`,
   y esos vecinos son parejos entre sí y tienen luz. Eso da la fila o la columna defectuosa.
2. **Sólo en esa fila o columna se corrigen las cuatro capas.** Cada texel que, en alguna capa, se
   aparta del promedio de sus dos vecinos parejos pasa a valer ese promedio en las cuatro.

El segundo criterio, suelto por todo el atlas, marca más de veinte tramos por archivo que no son
este defecto: detalle real de un texel en las capas de dirección de otros muebles. Por eso no se
usa sin la huella. Un tramo del defecto que cae sobre una superficie sin luz no tiene huella y no
se repara: tampoco se ve.

Cada corrida imprime qué reparó.

## Cómo se guarda

Como lo escribe el motor: RGB de 32 bits, sin transformación de color. Después de guardar se vuelve
a leer el archivo y se compara: fuera de los texeles reparados no puede cambiar ningún valor. Si
cambia uno, el script falla y deja el original.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

RAIZ = Path(__file__).resolve().parents[3]
MAPAS = (RAIZ / "src/escenas/almacen.exr", RAIZ / "src/escenas/almacen_sin_luz.exr")

#: Cuántos texeles seguidos hacen una línea: 12 son 60 cm a 5 cm por texel.
LARGO_MINIMO = 12
#: Entre qué partes de sus vecinos vale el color de un texel de la línea: la mitad.
MITAD = (0.47, 0.53)
#: Por debajo de qué parte de sus vecinos el color de un texel se aparta de ellos.
UMBRAL = 0.7
#: Cuánto pueden diferir entre sí los dos vecinos, en parte de su promedio.
PAREJOS = 0.2
#: La luz mínima de los vecinos: en lo negro no hay línea que ver.
LUZ_MINIMA = 0.01
#: Las capas de un horneado direccional: la de color y las tres de dirección.
CAPAS = 4
#: Cuánto se aparta del promedio de sus vecinos un texel apagado de una capa de dirección.
DESVIO = 0.03
#: Cuánto pueden diferir entre sí los dos vecinos en una capa de dirección.
PAREJOS_DE_DIRECCION = 0.02


def leer(ruta: Path) -> np.ndarray:
    """Los valores del archivo, con la fila de arriba primero."""
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    imagen.colorspace_settings.name = "Non-Color"
    ancho, alto = imagen.size
    datos = np.empty(ancho * alto * imagen.channels, dtype=np.float32)
    imagen.pixels.foreach_get(datos)
    datos = datos.reshape(alto, ancho, imagen.channels)[::-1, :, :3].copy()
    bpy.data.images.remove(imagen)
    return datos


def guardar(datos: np.ndarray, ruta: Path) -> None:
    alto, ancho, _ = datos.shape
    imagen = bpy.data.images.new("mapa_de_luz", ancho, alto, alpha=True, float_buffer=True)
    imagen.colorspace_settings.name = "Non-Color"
    con_alfa = np.ones((alto, ancho, 4), dtype=np.float32)
    con_alfa[..., :3] = datos[::-1]
    imagen.pixels.foreach_set(con_alfa.ravel())
    escena = bpy.context.scene
    ajustes = escena.render.image_settings
    ajustes.file_format = "OPEN_EXR"
    ajustes.color_mode = "RGB"
    ajustes.color_depth = "32"
    ajustes.exr_codec = "ZIP"
    escena.view_settings.view_transform = "Raw"
    escena.view_settings.look = "None"
    escena.view_settings.exposure = 0.0
    escena.view_settings.gamma = 1.0
    imagen.save_render(str(ruta), scene=escena)
    bpy.data.images.remove(imagen)


def _vecinos(capas: np.ndarray) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """El promedio de los dos vecinos de al lado, el texel del medio y los dos vecinos."""
    izquierda, derecha = capas[:, :, :-2], capas[:, :, 2:]
    return (izquierda + derecha) / 2, capas[:, :, 1:-1], np.abs(izquierda - derecha)


def _color(capas: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Dónde los dos vecinos tienen luz pareja, y cuánto vale el texel contra su promedio."""
    medio, centro, salto = _vecinos(capas[:1])
    lum = (0.2126, 0.7152, 0.0722)
    luz = (medio[0] * lum).sum(axis=-1)
    parejos = (salto[0] * lum).sum(axis=-1) < PAREJOS * np.maximum(luz, 1e-6)
    razon = (centro[0] * lum).sum(axis=-1) / np.maximum(luz, 1e-6)
    return (luz > LUZ_MINIMA) & parejos, razon


def con_huella(capas: np.ndarray) -> np.ndarray:
    """Dónde el color de un texel vale la mitad del de sus dos vecinos parejos."""
    parejos, razon = _color(capas)
    return parejos & (razon > MITAD[0]) & (razon < MITAD[1])


def apartados(capas: np.ndarray) -> np.ndarray:
    """Dónde un texel se aparta de sus dos vecinos parejos, en alguna de las capas."""
    parejos, razon = _color(capas)
    marca = parejos & (razon < UMBRAL)
    medio, centro, salto = _vecinos(capas[1:])
    for capa in range(CAPAS - 1):
        vecinos = salto[capa].max(axis=-1) < PAREJOS_DE_DIRECCION
        marca |= vecinos & (np.abs(centro[capa] - medio[capa]).max(axis=-1) > DESVIO)
    return marca


def tramos(columna: np.ndarray, minimo: int) -> list[tuple[int, int]]:
    """Los tramos seguidos de una columna de la máscara: `(primera fila, última fila)`."""
    # Los cambios de estado de la columna: donde empieza y donde termina cada tramo.
    bordes = np.flatnonzero(np.diff(np.concatenate(([0], columna.view(np.int8), [0]))))
    return [
        (int(desde), int(hasta) - 1)
        for desde, hasta in zip(bordes[::2], bordes[1::2]) if hasta - desde >= minimo
    ]


def reparar(datos: np.ndarray) -> list[str]:
    """Repara las líneas en su lugar y devuelve una línea de informe por cada una."""
    alto, ancho, _ = datos.shape
    if alto != CAPAS * ancho:
        raise SystemExit(
            f"el mapa trae {alto / ancho:g} capas y se esperaban {CAPAS}: revisar si el horneado "
            "sigue siendo direccional y de una sola porción"
        )
    capas = datos.reshape(CAPAS, ancho, ancho, 3)
    informe = []
    # Una fila es una columna de las capas traspuestas: la vista comparte los datos.
    for nombre, vista in (("columna", capas), ("fila", capas.transpose(0, 2, 1, 3))):
        huella = con_huella(vista)
        defectuosas = [
            int(x) for x in np.nonzero(huella.any(axis=0))[0] if tramos(huella[:, x], LARGO_MINIMO)
        ]
        if not defectuosas:
            continue
        marca = apartados(vista)
        for x in defectuosas:
            reparados = 0
            for desde, hasta in tramos(marca[:, x], 1):
                vista[:, desde:hasta + 1, x + 1] = (
                    vista[:, desde:hasta + 1, x] + vista[:, desde:hasta + 1, x + 2]
                ) / 2
                reparados += hasta - desde + 1
            huellas = ", ".join(f"{a} a {b}" for a, b in tramos(huella[:, x], LARGO_MINIMO))
            informe.append(
                f"{nombre} {x + 1}: huella de media luz de {huellas}; "
                f"{reparados} texeles reparados en las {CAPAS} capas"
            )
    return informe


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    argumentos = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    aplicar = "--aplicar" in argumentos
    rutas = [Path(a) for a in argumentos if not a.startswith("--")] or list(MAPAS)
    for ruta in rutas:
        original = leer(ruta)
        reparado = original.copy()
        informe = reparar(reparado)
        print(f"{ruta.name}: {len(informe)} líneas")
        for linea in informe:
            print(f"   {linea}")
        if not informe or not aplicar:
            continue
        tocados = np.abs(reparado - original).max(axis=2) > 0
        respaldo = ruta.with_suffix(".exr.antes")
        shutil.copyfile(ruta, respaldo)
        guardar(reparado, ruta)
        escrito = leer(ruta)
        de_mas = int((np.abs(escrito - original).max(axis=2)[~tocados] > 0).sum())
        mal = float(np.abs(escrito - reparado).max())
        if de_mas or mal > 0:
            shutil.copyfile(respaldo, ruta)
            respaldo.unlink()
            raise SystemExit(
                f"{ruta.name}: al guardar cambiaron {de_mas} texeles ajenos y la reparación "
                f"difiere en {mal}; queda el original"
            )
        respaldo.unlink()
        print(f"   guardado: {int(tocados.sum())} texeles reparados, ninguno más cambió")


if __name__ == "__main__":
    main()
