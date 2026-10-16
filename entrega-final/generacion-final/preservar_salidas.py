"""Copia completa de una pasada, antes de compararla o iniciar la siguiente.

Preparado para el próximo pipeline; no ejecuta generadores ni modifica sus salidas.
"""
import hashlib
import json
from pathlib import Path
import shutil


def preservar(raiz: Path, destino: Path) -> dict[str, str]:
    """Exige las 40 salidas; nunca pisa una captura anterior."""
    modelos = raiz / "assets/models"
    recursos = sorted(modelos.glob("producto_*.res"))
    assert len(recursos) == 32, f"Esperados 32 RES, recibidos {len(recursos)}"
    rutas = [
        modelos / ("SEPT_JUEGOS_PROTOTIPO" + sufijo)
        for sufijo in (".blend", ".glb", ".glb.fuente", ".glb.unwrap_cache")
    ]
    rutas += [
        raiz / "src/escenas/puestos" / nombre
        for nombre in (
            "disposicion_de_la_gondola.tres", "contenido_del_estante.tscn",
            "guia_del_estante.tscn", "estructura_del_almacen.tscn",
        )
    ]
    rutas += recursos
    assert all(ruta.is_file() for ruta in rutas)
    destino.mkdir(parents=True, exist_ok=False)
    manifiesto = {}
    for fuente in rutas:
        relativa = fuente.relative_to(raiz)
        copia = destino / relativa
        copia.parent.mkdir(parents=True, exist_ok=True)
        original = fuente.read_bytes()
        sha = hashlib.sha256(original).hexdigest()
        shutil.copy2(fuente, copia)
        assert copia.read_bytes() == original, str(copia)
        manifiesto[relativa.as_posix()] = {
            "sha256": sha, "bytes": len(original),
            "fuente_absoluta": str(fuente),
            "mtime_original_ns": fuente.stat().st_mtime_ns,
        }
    (destino / "manifest.json").write_bytes(
        (json.dumps(manifiesto, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    )
    return {ruta: entrada["sha256"] for ruta, entrada in manifiesto.items()}
