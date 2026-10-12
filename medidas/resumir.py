"""Mediana de tres corridas por vista: draw calls y p95, base contra propuesta, y el ruido."""

import json
import statistics
import sys
from pathlib import Path

carpeta = Path(sys.argv[1])


def leer(nombre: str) -> dict:
    datos = json.loads((carpeta / f"{nombre}.json").read_text())[0]
    return {r["vista"]: r for r in datos["resultados"]}, datos


corridas = {n: leer(n) for n in ["ruido-a", "ruido-b", "base-1", "base-2", "base-3", "prop-1", "prop-2", "prop-3"]}
_, muestra = corridas["base-1"]
print(f"gpu={muestra['gpu']} renderizador={muestra['renderizador']} resolucion={muestra['resolucion']}")
for vista in ["cara_de_lado", "cabecera", "bandeja_de_heladera"]:
    def col(prefijo: str, campo: str) -> list:
        return [corridas[f"{prefijo}-{i}"][0][vista][campo] for i in (1, 2, 3)]

    ruido = [corridas[n][0][vista]["cuadro_ms_p95"] for n in ("ruido-a", "ruido-b")]
    print(
        f"| {vista} | {statistics.median(col('base', 'dibujos_p50')):.0f} "
        f"| {statistics.median(col('prop', 'dibujos_p50')):.0f} "
        f"| {max(col('base', 'dibujos_max')):.0f} | {max(col('prop', 'dibujos_max')):.0f} "
        f"| {statistics.median(col('base', 'cuadro_ms_p95')):.1f} "
        f"| {statistics.median(col('prop', 'cuadro_ms_p95')):.1f} "
        f"| {abs(ruido[0] - ruido[1]):.1f} ({ruido[0]:.1f} / {ruido[1]:.1f}) "
        f"| base {col('base', 'cuadro_ms_p95')} prop {col('prop', 'cuadro_ms_p95')} "
        f"| pose {all(col('base', 'pose_ok') + col('prop', 'pose_ok'))} "
        f"| muestras {col('base', 'muestras')} |"
    )
