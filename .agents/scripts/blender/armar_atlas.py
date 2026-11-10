"""Arma los atlas de etiquetas y de cajas desde las texturas originales. Corre adentro de Blender.

    blender --background --python-exit-code 1 --python .claude/scripts/blender/armar_atlas.py \
        -- <carpeta de salida | --en-el-arbol> [--sellar]

Lo lanza `armar_atlas.py` de la raíz, o `exportar_modelo.py` en su primer paso. **No se corre a
mano.** Escribe en la carpeta de salida un PNG por atlas y el manifiesto `atlas.json`.

## Qué lee

- Las etiquetas: cada ruta de `lib.atlas.ETIQUETAS`, relativa a `assets/`.
- Las cajas: cada PNG de `assets/boxes/`.

Cada textura se achica **al lado con el que viaja hoy** (`lib.blender.achicada`, con el tope de
su grupo), con el mismo escalado que usa `exportar.achicar_las_imagenes`. El atlas no baja
resolución.

## Cómo arma el borde

Repite el último píxel de cada lado de la textura, `BORDE` píxeles hacia afuera. Con eso el
filtro bilineal y los primeros mips muestrean el color de su propia etiqueta, no el de la vecina.

## `--sellar`

Sólo escribe el manifiesto, tomando como atlas los PNG que ya están en la carpeta. Es para
cuando los PNG los generó otra herramienta con el reparto de este manifiesto y hay que sellarlos.
"""

import hashlib
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib import atlas as lib_atlas  # noqa: E402
from lib.blender import achicada  # noqa: E402

CAJAS = lib_atlas.CAJAS


def _pixeles(ruta: Path, lado_maximo: int) -> tuple[np.ndarray, bool]:
    """Los píxeles RGBA de un archivo, al tamaño con el que viaja, y si tiene algo de alfa."""
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    try:
        ancho, alto = imagen.size
        nuevo = achicada(ancho, alto, lado_maximo)
        if nuevo != (ancho, alto):
            imagen.scale(*nuevo)
        ancho, alto = imagen.size
        datos = np.empty(ancho * alto * 4, dtype=np.float32)
        imagen.pixels.foreach_get(datos)
        matriz = datos.reshape(alto, ancho, 4)[::-1]
        return np.ascontiguousarray(matriz), bool(matriz[..., 3].min() < 0.999)
    finally:
        bpy.data.images.remove(imagen)


def _entradas() -> tuple[list[lib_atlas.Entrada], dict[str, tuple[np.ndarray, bool]]]:
    pixeles: dict[str, tuple[np.ndarray, bool]] = {}
    entradas = []
    for clave in lib_atlas.claves_de_las_fuentes():
        ruta = lib_atlas.ASSETS / clave
        if not ruta.is_file():
            raise SystemExit(f"falta la fuente del atlas: {ruta}")
        datos, con_alfa = _pixeles(ruta, lib_atlas.lado_de(clave))
        pixeles[clave] = (datos, con_alfa)
        alto, ancho = datos.shape[:2]
        formato = lib_atlas.BC3 if con_alfa else lib_atlas.BC1
        entradas.append(
            lib_atlas.Entrada(clave, ancho, alto, formato, lib_atlas.huella_de(ruta))
        )
    return entradas, pixeles


def _componer(atlas: lib_atlas.Atlas, pixeles: dict[str, tuple[np.ndarray, bool]]) -> np.ndarray:
    lienzo = np.zeros((atlas.alto, atlas.ancho, 4), dtype=np.float32)
    lienzo[..., 3] = 1.0
    borde = lib_atlas.BORDE
    for colocada in atlas.colocadas:
        datos, _ = pixeles[colocada.entrada.ruta]
        alto, ancho = datos.shape[:2]
        rellena = np.pad(datos, ((borde, borde), (borde, borde), (0, 0)), mode="edge")
        lienzo[
            colocada.y - borde : colocada.y + alto + borde,
            colocada.x - borde : colocada.x + ancho + borde,
        ] = rellena
    if atlas.formato == lib_atlas.BC1:
        lienzo[..., 3] = 1.0
    return lienzo


def _escribir(atlas: lib_atlas.Atlas, lienzo: np.ndarray, destino: Path) -> str:
    """Escribe el PNG con `Image.save`, que no aplica la transformación de vista de la escena:
    `save_render` sí, y oscurecía todos los colores."""
    con_alfa = atlas.formato == lib_atlas.BC3
    imagen = bpy.data.images.new(atlas.archivo, atlas.ancho, atlas.alto, alpha=con_alfa)
    try:
        imagen.colorspace_settings.name = "sRGB"
        imagen.alpha_mode = "STRAIGHT"
        imagen.pixels.foreach_set(np.ascontiguousarray(lienzo[::-1]).reshape(-1))
        imagen.file_format = "PNG"
        imagen.filepath_raw = str(destino)
        imagen.save()
    finally:
        bpy.data.images.remove(imagen)
    return hashlib.sha256(destino.read_bytes()).hexdigest()


def main() -> None:
    # Su salida la captura `armar_atlas.py`, y el default de Windows no es UTF-8.
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if "--" not in sys.argv:
        raise SystemExit("falta la carpeta de salida: ... --python armar_atlas.py -- <carpeta>")
    argumentos = sys.argv[sys.argv.index("--") + 1 :]
    carpeta = Path(argumentos[0]) if argumentos[0] != "--en-el-arbol" else None
    sellar = "--sellar" in argumentos

    def destino_de(archivo: str) -> Path:
        base = carpeta or lib_atlas.carpeta_del_atlas(archivo)
        base.mkdir(parents=True, exist_ok=True)
        return base

    entradas, pixeles = _entradas()
    grupos = {
        (f"{lib_atlas.PREFIJO_DE_LAS_CAJAS}_{formato}" if tipo == CAJAS else f"{tipo}_{formato}"): [
            e for e in entradas if lib_atlas.es_caja(e.ruta) == (tipo == CAJAS) and e.formato == formato
        ]
        for tipo in lib_atlas.GRUPOS_ACTIVOS
        for formato in (lib_atlas.BC1, lib_atlas.BC3)
    }
    atlas_por_grupo = {n: lib_atlas.acomodar(g, n) for n, g in grupos.items() if g}
    huellas: dict[str, str] = {}
    for lista in atlas_por_grupo.values():
        for atlas in lista:
            if sellar:
                huellas[atlas.archivo] = lib_atlas.huella_de(destino_de(atlas.archivo) / atlas.archivo)
            else:
                huellas[atlas.archivo] = _escribir(
                    atlas, _componer(atlas, pixeles), destino_de(atlas.archivo) / atlas.archivo
                )
            print(f"atlas: {atlas.archivo} {atlas.ancho}x{atlas.alto} {atlas.formato} "
                  f"({len(atlas.colocadas)} texturas)")
    manifiesto = lib_atlas.a_manifiesto(atlas_por_grupo, huellas)
    salida = (carpeta or lib_atlas.CARPETA) / "atlas.json"
    lib_atlas.escribir(manifiesto, salida)
    print(f"manifiesto: {salida}")
    reparto = lib_atlas.reparto_de_las_cajas(manifiesto)
    if reparto["cajas"]:
        lugar = (carpeta / "atlas_de_cajas.json") if carpeta else lib_atlas.REPARTO_DE_LAS_CAJAS
        lib_atlas.escribir(reparto, lugar)
        print(f"reparto de las cajas: {lugar}")


if __name__ == "__main__":
    main()
