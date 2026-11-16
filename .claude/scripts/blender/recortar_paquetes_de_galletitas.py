"""Arma el atlas de Oremos y de Pepito con recortes rectangulares de su arte. Corre en Blender.

    blender --background --python-exit-code 1 \
        --python .claude/scripts/blender/recortar_paquetes_de_galletitas.py -- [--aplicar]

Sin `--aplicar` escribe en `reports/paquetes-de-galletitas/`. Con `--aplicar`, en
`assets/source/products-textured/galletitas/`, donde lo lee el atlas del juego, con el nombre de
siempre: `oremos_paquete.png` y `pepito_paquete.png`. Es determinista: las mismas fuentes dan los
mismos píxeles. **No toca el arte del artista**: `oremos.png` y `pepito.png` son la entrada.

## Qué hace

Nada más que copiar. Los recortes salen de `lib/recortes_de_paquetes.py`, que dice de qué rectángulo
del arte sale cada uno y dónde cae en el atlas. Se copian píxel por píxel, **sin escalar, sin
componer y sin pintar**, con `RELLENO` píxeles repetidos alrededor de cada uno para que el filtro no
los mezcle. Lo que el arte no cubre no lleva píxeles: la UV se queda en el borde del recorte
(`lib/paquete_de_galletitas.py`).

Deja también `recortes_<producto>.json` en `reports/paquetes-de-galletitas/`, con cada recorte, de
dónde sale y a qué zona va.
"""

import json
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import recortes_de_paquetes as recortes  # noqa: E402
from lib.consola import configurar  # noqa: E402
from lib.repo import RAIZ  # noqa: E402

ORIGINALES = RAIZ / "assets/source/products-textured/galletitas"
REPORTE = RAIZ / "reports/paquetes-de-galletitas"

#: Los píxeles del atlas que ningún recorte cubre: nunca se muestrean.
SIN_USO = (0.0, 0.0, 0.0)

DESTINO_DE_CADA_ZONA = {
    recortes.FRENTE: "frente del envase, de un afinado al otro y de hombro a hombro",
    recortes.DORSO: "dorso del envase, a lo ancho y centrado a lo alto; arriba y abajo, su borde",
    recortes.ALETA_FRENTE_IZQUIERDA: "cara del frente de la aleta del lado de y negativo",
    recortes.ALETA_FRENTE_DERECHA: "cara del frente de la aleta del lado de y positivo",
    recortes.ALETA_DORSO_IZQUIERDA: "cara del dorso de la aleta del lado de y positivo",
    recortes.ALETA_DORSO_DERECHA: "cara del dorso de la aleta del lado de y negativo",
}


def leer(ruta: Path) -> np.ndarray:
    """Los píxeles RGBA de un PNG, de arriba a abajo, en 0..1."""
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    try:
        ancho, alto = imagen.size
        datos = np.empty(ancho * alto * 4, dtype=np.float32)
        imagen.pixels.foreach_get(datos)
        return np.ascontiguousarray(datos.reshape(alto, ancho, 4)[::-1])
    finally:
        bpy.data.images.remove(imagen)


def escribir(matriz: np.ndarray, ruta: Path) -> None:
    """Escribe con `Image.save`, que no aplica la transformación de vista de la escena."""
    alto, ancho = matriz.shape[:2]
    imagen = bpy.data.images.new(ruta.name, ancho, alto, alpha=True)
    try:
        imagen.colorspace_settings.name = "sRGB"
        imagen.alpha_mode = "STRAIGHT"
        imagen.pixels.foreach_set(np.ascontiguousarray(matriz[::-1]).reshape(-1))
        imagen.file_format = "PNG"
        imagen.filepath_raw = str(ruta)
        imagen.save()
    finally:
        bpy.data.images.remove(imagen)


def armar(clave: str) -> tuple[np.ndarray, list[dict]]:
    """El atlas de un paquete y el registro de sus recortes."""
    fuente = leer(ORIGINALES / recortes.FUENTES[clave])
    disposicion = recortes.disposicion(clave)
    atlas = np.ones((disposicion.alto, disposicion.ancho, 4), dtype=np.float32)
    atlas[..., :3] = SIN_USO
    registro = []
    relleno = recortes.RELLENO
    for zona in recortes.ZONAS:
        x0, y0, x1, y1 = recortes.RECORTES[clave][zona]
        x, y, ancho, alto = disposicion.rects[zona]
        recorte = fuente[y0:y1, x0:x1].copy()
        recorte[..., 3] = 1.0
        atlas[y : y + alto, x : x + ancho] = recorte
        con_borde = np.pad(recorte, ((relleno, relleno), (relleno, relleno), (0, 0)), mode="edge")
        marco = atlas[y - relleno : y + alto + relleno, x - relleno : x + ancho + relleno]
        mascara = np.ones(marco.shape[:2], bool)
        mascara[relleno:-relleno, relleno:-relleno] = False
        marco[mascara] = con_borde[mascara]
        registro.append(
            {
                "zona": zona,
                "va_a": DESTINO_DE_CADA_ZONA[zona],
                "fuente": f"assets/source/products-textured/galletitas/{recortes.FUENTES[clave]}",
                "recorte_en_la_fuente": [x0, y0, x1, y1],
                "medida_px": [ancho, alto],
                "relacion_ancho_sobre_alto": round(ancho / alto, 4),
                "lugar_en_el_atlas": [x, y, ancho, alto],
            }
        )
    return atlas, registro


def main() -> None:
    configurar()
    aplicar = "--aplicar" in sys.argv
    carpeta = ORIGINALES if aplicar else REPORTE
    carpeta.mkdir(parents=True, exist_ok=True)
    REPORTE.mkdir(parents=True, exist_ok=True)
    for clave in recortes.FUENTES:
        atlas, registro = armar(clave)
        archivo = f"{'oremos' if clave == 'OREMOS' else 'pepito'}_paquete.png"
        escribir(atlas, carpeta / archivo)
        (REPORTE / f"recortes_{archivo.removesuffix('.png')}.json").write_text(
            json.dumps(
                {
                    "producto": clave,
                    "atlas_px": [atlas.shape[1], atlas.shape[0]],
                    "recortes": registro,
                },
                indent=1,
                ensure_ascii=False,
            ),
            encoding="utf-8",
        )
        medida = f"{atlas.shape[1]}x{atlas.shape[0]}"
        print(f"{archivo}: {medida} con {len(registro)} recortes en {carpeta}")


if __name__ == "__main__":
    main()
