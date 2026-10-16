"""Reutiliza sólo caché importada con entradas y parámetros byteidénticos; no importa escenas."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import sys

origen, destino, informe = map(Path, sys.argv[1:])
permitidas = {".png", ".jpg", ".jpeg", ".webp", ".exr", ".svg", ".ttf", ".otf", ".ogg", ".mp3", ".wav"}

def huella(archivo, tipo="sha256"):
    return hashlib.new(tipo, archivo.read_bytes()).hexdigest()

copiados = []
omitidos = []
for parametros in sorted(destino.rglob("*.import")):
    if ".godot" in parametros.parts:
        continue
    relativo = parametros.relative_to(destino)
    otros_parametros = origen / relativo
    fuente = parametros.with_suffix("")
    otra_fuente = origen / fuente.relative_to(destino)
    if fuente.suffix.lower() not in permitidas:
        continue
    if not (otra_fuente.is_file() and otros_parametros.is_file()):
        omitidos.append({"fuente": str(fuente.relative_to(destino)), "motivo": "sin entrada original"})
        continue
    if huella(parametros) != huella(otros_parametros) or huella(fuente) != huella(otra_fuente):
        omitidos.append({"fuente": str(fuente.relative_to(destino)), "motivo": "entrada o parámetros distintos"})
        continue
    salidas = re.findall(r'"res://(\.godot/imported/[^"\n]+)"', parametros.read_text(encoding="utf-8"))
    salidas = sorted(set(salidas))
    if not salidas:
        raise ValueError(f"Sin salidas: {relativo}")
    prefijo = re.match(r"(.+?-[0-9a-f]{32})\.", Path(salidas[0]).name).group(1)
    marcador = origen / ".godot/imported" / (prefijo + ".md5")
    if not marcador.is_file() or f'source_md5="{huella(fuente, "md5")}"' not in marcador.read_text():
        omitidos.append({"fuente": str(fuente.relative_to(destino)), "motivo": "sin marcador fuente válido"})
        continue
    rutas = [Path(r) for r in salidas] + [marcador.relative_to(origen)]
    if not all((origen / r).is_file() for r in rutas):
        omitidos.append({"fuente": str(fuente.relative_to(destino)), "motivo": "caché incompleta"})
        continue
    archivos = []
    for ruta in rutas:
        original = origen / ruta
        salida = destino / ruta
        salida.parent.mkdir(parents=True, exist_ok=True)
        anterior = huella(salida) if salida.is_file() else None
        shutil.copy2(original, salida)
        digest = huella(original)
        if huella(salida) != digest:
            raise ValueError(f"Copia distinta: {ruta}")
        archivos.append({"ruta": ruta.as_posix(), "sha256": digest, "sha256_anterior": anterior,
                         "bytes": salida.stat().st_size})
    copiados.append({"fuente": str(fuente.relative_to(destino)), "sha256_fuente": huella(fuente),
                     "sha256_parametros": huella(parametros), "archivos": archivos})
informe.write_text(json.dumps({"origen": str(origen), "destino": str(destino),
                               "copiados": copiados, "omitidos": omitidos}, indent=2), encoding="utf-8")
print(f"Entradas verificadas: {len(copiados)}; omitidas: {len(omitidos)}; bytes copiados: "
      f"{sum(a['bytes'] for c in copiados for a in c['archivos'])}")
