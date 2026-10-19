"""Resuelve un snapshot inmutable y registra su espera y procedencia."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import datetime as dt
import json
import os
from pathlib import Path
import time
import urllib.error
import urllib.request


_RESPUESTAS: dict[str, tuple[str, dict]] = {}
_API_METRICAS = {"consultas": 0, "sin_cambios": 0, "cuota_restante": None}


@dataclass(frozen=True)
class FuenteSnapshot:
    run_id: int
    tipo: str
    previo: bool
    commit: str
    rama: str


def api(ruta: str) -> dict:
    url = f"{os.environ['GITHUB_API_URL']}/repos/{os.environ['GITHUB_REPOSITORY']}/{ruta}"
    cabeceras = {
        "Authorization": f"Bearer {os.environ['GH_TOKEN']}",
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if url in _RESPUESTAS:
        cabeceras["If-None-Match"] = _RESPUESTAS[url][0]
    solicitud = urllib.request.Request(url, headers=cabeceras)
    _API_METRICAS["consultas"] += 1
    try:
        with urllib.request.urlopen(solicitud, timeout=30) as respuesta:
            datos = json.load(respuesta)
            etag = respuesta.headers.get("ETag")
            _API_METRICAS["cuota_restante"] = respuesta.headers.get("X-RateLimit-Remaining")
            if etag:
                _RESPUESTAS[url] = (etag, datos)
            return datos
    except urllib.error.HTTPError as error:
        if error.code == 304 and url in _RESPUESTAS:
            _API_METRICAS["sin_cambios"] += 1
            return _RESPUESTAS[url][1]
        raise


def listar(ruta: str, campo: str) -> list[dict]:
    elementos = []
    pagina = 1
    while True:
        datos = api(f"{ruta}?per_page=100&page={pagina}")
        lote = datos[campo]
        elementos.extend(lote)
        if len(lote) < 100:
            return elementos
        pagina += 1


def validar_corrida(datos: dict, fuente: FuenteSnapshot) -> None:
    if datos["id"] != fuente.run_id:
        raise ValueError("la corrida no coincide con el origen pedido")
    if datos["path"] != ".github/workflows/medir-verificacion.yml":
        raise ValueError("el origen no es el workflow de medición")
    if datos["event"] != "workflow_dispatch":
        raise ValueError("el origen no es una medición manual")
    if datos["head_sha"] != fuente.commit or datos["head_branch"] != fuente.rama:
        raise ValueError("el origen no coincide con la revisión y rama esperadas")
    if fuente.previo:
        if datos["status"] != "completed" or datos["conclusion"] != "success":
            raise ValueError("la corrida anterior debe haber terminado con éxito")
    elif datos["run_attempt"] != int(os.environ["GITHUB_RUN_ATTEMPT"]):
        raise ValueError("el intento de la corrida actual no coincide")
    elif datos["status"] == "completed" and datos["conclusion"] != "success":
        raise ValueError("la corrida actual terminó sin éxito")


def resolver(fuente: FuenteSnapshot, espera_s: float = 600) -> dict:
    inicio = time.monotonic()
    corrida = api(f"actions/runs/{fuente.run_id}")
    validar_corrida(corrida, fuente)
    nombre = f"snapshot-{fuente.tipo}-{corrida['run_attempt']}"
    ultima_comprobacion = float("-inf")
    while True:
        artefactos = [a for a in listar(
            f"actions/runs/{fuente.run_id}/artifacts", "artifacts"
        ) if a["name"] == nombre]
        if len(artefactos) > 1:
            raise ValueError("el origen contiene snapshots duplicados")
        if artefactos:
            artefacto = artefactos[0]
            if artefacto["expired"]:
                raise ValueError("el snapshot expiró")
            if artefacto["size_in_bytes"] <= 0:
                raise ValueError("el snapshot está vacío")
            ahora = dt.datetime.now(dt.timezone.utc)
            creado = dt.datetime.fromisoformat(artefacto["created_at"].replace("Z", "+00:00"))
            return {
                "run_id": fuente.run_id, "run_attempt": corrida["run_attempt"],
                "commit": fuente.commit, "rama": fuente.rama, "tipo": fuente.tipo,
                "previo": fuente.previo, "artefacto_id": artefacto["id"],
                "nombre": nombre, "bytes": artefacto["size_in_bytes"],
                "digest": artefacto.get("digest"), "creado_utc": artefacto["created_at"],
                "resuelto_utc": ahora.isoformat(), "edad_s": (ahora - creado).total_seconds(),
                "espera_s": time.monotonic() - inicio,
            }
        if fuente.previo:
            raise ValueError("la corrida anterior no contiene el snapshot pedido")
        ahora = time.monotonic()
        if ahora - ultima_comprobacion >= 30:
            productores = [j for j in listar(
                f"actions/runs/{fuente.run_id}/jobs", "jobs"
            ) if j["name"] == "Preparación compartida"]
            if any(j["status"] == "completed" for j in productores):
                raise ValueError("el productor terminó sin publicar el snapshot pedido")
            ultima_comprobacion = ahora
        if ahora - inicio >= espera_s:
            raise TimeoutError("se agotó la espera del snapshot")
        time.sleep(min(5, max(0, espera_s - (ahora - inicio))))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_id", type=int)
    parser.add_argument("--tipo", choices=("completo", "importaciones"), required=True)
    parser.add_argument("--previo", action="store_true")
    parser.add_argument("--espera-segundos", type=float, default=600)
    opciones = parser.parse_args()
    if opciones.run_id <= 0 or opciones.espera_segundos <= 0:
        parser.error("la corrida y el límite de espera deben ser positivos")
    fuente = FuenteSnapshot(
        opciones.run_id, opciones.tipo, opciones.previo,
        os.environ["GITHUB_SHA"], os.environ["GITHUB_REF_NAME"],
    )
    inicio = time.monotonic()
    datos = {"run_id": fuente.run_id, "tipo": fuente.tipo, "previo": fuente.previo}
    try:
        datos = resolver(fuente, opciones.espera_segundos)
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as salida:
            salida.write(f"artefacto_id={datos['artefacto_id']}\n")
        return 0
    except Exception as error:
        datos.update(error=str(error), espera_s=time.monotonic() - inicio)
        raise
    finally:
        datos["api"] = dict(_API_METRICAS)
        ruta = Path(os.environ["RUNNER_TEMP"]) / "snapshot-origen.json"
        ruta.write_text(json.dumps(datos, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    raise SystemExit(main())
