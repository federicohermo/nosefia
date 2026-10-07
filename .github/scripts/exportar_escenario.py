"""Exportar a la web una copia aislada del árbol, con un escenario de medición como escena principal.

    python .github/scripts/exportar_escenario.py <rev> res://test/performance/<escenario>.tscn <destino>

Deja `<destino>/web` (el export) y `<destino>/huellas.json` (el commit, y los bytes y el SHA-256
del PCK y del WASM). `<destino>` tiene que ser una carpeta nueva, fuera del repo.

La copia sale de `git archive <rev>`: lleva sólo lo commiteado en esa revisión. Dos copias de
dos revisiones difieren en lo que cambió entre ellas, y en nada más. El árbol real no se toca.

En la copia, la escena principal es el escenario, no hay autoloads, el directorio de usuario es
propio y `test/*` sale de la exclusión del export. Usa la plantilla web del repo: prepararla
antes con `preparar_plantilla_web.py`.
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
PLANTILLA = "build/templates/web_release.zip"


def ajustar_proyecto(ajustes: str, escena: str, usuario: str) -> str:
    """El `project.godot` de la copia. Falla si el archivo cambió de forma."""
    ajustes, escenas = re.subn(
        r'run/main_scene="[^"]*"',
        f'run/main_scene="{escena}"\nconfig/use_custom_user_dir=true\n'
        f'config/custom_user_dir_name="{usuario}"',
        ajustes,
    )
    ajustes, autoloads = re.subn(r"\[autoload\]\n.*?(?=\n\[)", "", ajustes, flags=re.S)
    if escenas != 1 or autoloads > 1:
        raise ValueError("project.godot cambió de forma: no se pudo ajustar la copia")
    return ajustes


def ajustar_presets(presets: str) -> str:
    """El `export_presets.cfg` de la copia, con `test/*` adentro del export."""
    if "test/*," not in presets:
        raise ValueError("export_presets.cfg ya no excluye `test/*`")
    return presets.replace("test/*,", "")


def sha256(ruta: Path) -> str:
    return hashlib.sha256(ruta.read_bytes()).hexdigest()


def _correr(comando: list[str], log: Path) -> int:
    with log.open("wb") as salida:
        return subprocess.run(comando, stdout=salida, stderr=subprocess.STDOUT).returncode


def exportar(rev: str, escena: str, destino: Path, godot: str) -> dict[str, object]:
    if destino.exists():
        raise ValueError(f"`{destino}` ya existe: usar una carpeta nueva por copia")
    plantilla = RAIZ / PLANTILLA
    if not plantilla.is_file():
        raise ValueError(f"falta `{PLANTILLA}`: correr antes `preparar_plantilla_web.py`")
    commit = subprocess.run(
        ["git", "-C", str(RAIZ), "rev-parse", rev], capture_output=True, text=True, check=True
    ).stdout.strip()
    proyecto, web = destino / "proyecto", destino / "web"
    proyecto.mkdir(parents=True)
    # Sin la carpeta, el export falla y devuelve 0.
    web.mkdir()

    paquete = destino / "arbol.zip"
    subprocess.run(
        ["git", "-C", str(RAIZ), "archive", "--format=zip", "-o", str(paquete), commit],
        check=True,
    )
    with zipfile.ZipFile(paquete) as archivo:
        archivo.extractall(proyecto)
    paquete.unlink()
    if not (proyecto / escena.removeprefix("res://")).is_file():
        raise ValueError(f"`{escena}` no existe en {commit[:8]}")

    # La caché de importación del árbol ahorra reimportar el modelo y las texturas.
    if (RAIZ / ".godot").is_dir():
        shutil.copytree(RAIZ / ".godot", proyecto / ".godot")

    ajustes = (proyecto / "project.godot").read_text(encoding="utf-8")
    (proyecto / "project.godot").write_text(
        ajustar_proyecto(ajustes, escena, f"nosefia-medicion-{commit[:8]}"),
        encoding="utf-8",
        newline="\n",
    )
    presets = (proyecto / "export_presets.cfg").read_text(encoding="utf-8")
    (proyecto / "export_presets.cfg").write_text(
        ajustar_presets(presets), encoding="utf-8", newline="\n"
    )
    (proyecto / PLANTILLA).parent.mkdir(parents=True)
    (proyecto / "build/.gdignore").write_text("", encoding="utf-8")
    shutil.copyfile(plantilla, proyecto / PLANTILLA)

    base = [godot, "--headless", "--path", str(proyecto)]
    codigo = _correr([*base, "--import"], destino / "importar.log")
    if codigo:
        raise ValueError(f"la importación salió con {codigo}: {destino / 'importar.log'}")
    _correr([*base, "--export-release", "Web", str(web / "index.html")], destino / "exportar.log")
    # El export devuelve 0 aunque falle: el veredicto sale de los archivos.
    piezas = {nombre: web / nombre for nombre in ("index.html", "index.pck", "index.wasm")}
    if any(not ruta.is_file() or ruta.stat().st_size == 0 for ruta in piezas.values()):
        raise ValueError(f"el export no dejó sus archivos: {destino / 'exportar.log'}")
    huellas: dict[str, object] = {
        "commit": commit,
        "escena": escena,
        "pck_bytes": piezas["index.pck"].stat().st_size,
        "pck_sha256": sha256(piezas["index.pck"]),
        "wasm_bytes": piezas["index.wasm"].stat().st_size,
        "wasm_sha256": sha256(piezas["index.wasm"]),
    }
    (destino / "huellas.json").write_text(json.dumps(huellas, indent=1), encoding="utf-8")
    return huellas


def main() -> int:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    if len(sys.argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2
    godot = os.environ.get("GODOT_BIN")
    if not godot or not Path(godot).is_file():
        print("GODOT_BIN no está declarada o no existe.", file=sys.stderr)
        return 1
    destino = Path(sys.argv[3]).resolve()
    try:
        huellas = exportar(sys.argv[1], sys.argv[2], destino, godot)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"No se exportó el escenario: {error}", file=sys.stderr)
        return 1
    print(json.dumps(huellas, indent=1))
    print(f'servir con: python .github/scripts/servir_export.py "{destino / "web"}" <puerto>')
    return 0


if __name__ == "__main__":
    sys.exit(main())
