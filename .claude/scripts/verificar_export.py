"""El veredicto del export, que NO es el código de salida de Godot.

    python .claude/scripts/verificar_export.py export/web

Está medido: `--export-release "Web"` termina con `Program crashed with signal 11` y **devuelve
0**. O sea que un paso de CI que mire el `$?` sale verde con un directorio a medio escribir, y
lo que se publica es una web que no arranca. Por eso el workflow corre el export con `|| true`
y llama a esto, que mira lo que quedó en el disco.

Lo que decide vive en `lib/despliegue.py` —y ahí están los tests—; acá está el disco y el
código de salida.
"""

import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from lib.consola import configurar  # noqa: E402

configurar()

from lib.despliegue import CODIFICADOS, desajustes_del_pck, veredicto_del_export  # noqa: E402


def pesos(directorio: Path) -> dict[str, int]:
    """Cada archivo del export con su tamaño, con el nombre relativo al directorio.

    Baja recursivamente porque el techo del directorio es del **directorio**: un subdirectorio
    que se colara con medio giga adentro pasaría un conteo plano sin que nadie lo viera.
    """
    return {
        str(archivo.relative_to(directorio)).replace(os.sep, "/"): archivo.stat().st_size
        for archivo in directorio.rglob("*")
        if archivo.is_file()
    }


def problemas_del_pck(directorio: Path) -> list[str]:
    """El `.pck` comprimido: que sea lo que el header promete y mida lo que la barra declara.

    Un `.pck` comprimido servido sin su `Content-Encoding` —o al revés— deja el juego en negro
    con el deploy en verde. El header vive en `vercel.json`; el cuerpo, acá. Por eso el veredicto
    del export mira el cuerpo, y su test cruza los dos archivos.
    """
    html = directorio / "index.html"
    if not html.is_file():
        return []  # Sin HTML ya lo dice `veredicto_del_export`; no se repite con otro texto.
    cuerpos = {
        nombre: (directorio / nombre).read_bytes()
        for nombre in CODIFICADOS
        if (directorio / nombre).is_file()
    }
    return desajustes_del_pck(html.read_text(encoding="utf-8", errors="replace"), cuerpos)


def main() -> None:
    if len(sys.argv) != 2:
        print("uso: verificar_export.py <directorio>", file=sys.stderr)
        sys.exit(2)

    directorio = Path(sys.argv[1])
    if not directorio.is_dir():
        # Que el directorio no exista es el caso extremo del bug que este script cierra: Godot
        # devolvió 0 y no escribió nada. Decirlo así, y no con un stack de `rglob`.
        print(
            f"`{directorio}` no existe: el export no dejó ni el directorio, y aun así Godot "
            "devolvió 0."
        )
        sys.exit(1)

    # Un solo barrido del disco, y no uno por rama: dos `rglob` son dos fotos distintas del
    # directorio, y la que se imprime no sería la que se juzgó.
    archivos = pesos(directorio)
    problemas = veredicto_del_export(archivos) + problemas_del_pck(directorio)
    if not problemas:
        total = sum(archivos.values()) / (1024 * 1024)
        print(f"export completo: {len(archivos)} archivos, {total:.1f} MB en `{directorio}`.")
        sys.exit(0)

    for problema in problemas:
        print(problema)
    print(
        f"\n{len(problemas)} {'motivo' if len(problemas) == 1 else 'motivos'} para no publicar "
        "esto. El código de salida del export no los ve: devuelve 0 igual."
    )
    sys.exit(1)


if __name__ == "__main__":
    main()
