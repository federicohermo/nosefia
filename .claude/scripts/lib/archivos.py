"""Caminar el repo juntando `.gd`, que es lo que los dos gates de código necesitan.

Vive acá y no adentro de cada gate porque los dos hacen exactamente lo mismo y de eso
depende que sus hallazgos hablen del mismo conjunto de archivos: si uno caminara `addons/` y
el otro no, la mitad de los hallazgos de un gate no existirían para el otro y nadie sabría
cuál de los dos tiene razón.
"""

from pathlib import Path

#: Lo que nunca se camina. `addons/` es la dependencia vendorizada —no la escribimos y no la
#: podemos arreglar— y `.godot/` es la caché del editor.
IGNORADOS = {".git", ".godot", "addons", "reportes", "__pycache__", ".venv"}


def scripts_gd(raiz: Path, subdirectorio: str) -> dict[str, str]:
    """Los `.gd` de `raiz/subdirectorio`, como `ruta relativa a raiz` → contenido.

    Las rutas se devuelven **con barras normales** en las tres plataformas: son las que las
    reglas declaran, y las que se imprimen. Una ruta con barras invertidas no matchea contra
    `src/dominio/` y el gate pasaría en verde en Windows.

    Si el subdirectorio no existe, devuelve `{}` — que acá sí es una respuesta y no un error:
    un repo sin `test/` todavía es un repo sin tests, y quien decide qué significa eso es el
    gate que llama.
    """
    base = raiz / subdirectorio
    if not base.is_dir():
        return {}

    encontrados: dict[str, str] = {}
    for ruta in sorted(base.rglob("*.gd")):
        if any(parte in IGNORADOS for parte in ruta.relative_to(raiz).parts):
            continue
        relativa = ruta.relative_to(raiz).as_posix()
        encontrados[relativa] = ruta.read_text(encoding="utf-8")
    return encontrados
