"""Contrasta proyecciones con vértices originales ya medidos, sin otra sonda de motor."""
import hashlib
import json
from pathlib import Path

scratch = Path("C:/Users/fede_/AppData/Local/Temp/nosefia-batch-425-435")
archivos = ("434-cierre-geometrico.json", "434-chapas.json", "434-intersecciones.json")
datos = {p: json.loads((scratch / p).read_text(encoding="utf-8")) for p in archivos}
cara = next(o for u in datos["434-intersecciones.json"]["propuestas"]["N.sur.3"]
            for o in u["obstaculos"] if o["indice"] == 42)
assert "Panel" in cara["material"]
salida = {"fuentes_sha256": {p: hashlib.sha256((scratch / p).read_bytes()).hexdigest()
                            for p in archivos}, "casos": {}}
for clave, parcial in datos["434-cierre-geometrico.json"]["poetico_parcial_detras_panel"].items():
    # N.sur es plano horizontal y mira −Y; su v hacia adentro es +Y. No se usa la normal
    # BMesh del panel, que quedó en ejes locales tras transform: se proyectan sus vértices.
    e = datos["434-chapas.json"]["N"]["estantes_detectados"][clave]
    panel_v = [v[1] - e["origen"][1] for v in cara["vertices"]]
    panel_z = [v[2] for v in cara["vertices"]]
    posterior = [v for v in parcial["filas"] if v["fila"] == "atras"]
    assert len(posterior) == 14
    detras = all(v["cuerpo_v"][0] > max(panel_v) for v in posterior)
    dentro_alto = all(min(panel_z) <= v["cuerpo_z"][0] <= v["cuerpo_z"][1] <= max(panel_z)
                     for v in posterior)
    salida["casos"][clave] = {
        "cara_panel": cara["indice"], "material": cara["material"],
        "panel_v": [min(panel_v), max(panel_v)], "panel_z": [min(panel_z), max(panel_z)],
        "posteriores": len(posterior), "contactos_fuera": sum(v["contactos_fuera"] for v in posterior),
        "fila_posterior_detras_panel_en_profundidad": detras,
        "fila_posterior_dentro_altura_panel": dentro_alto,
        "cuerpo_posterior_v": posterior[0]["cuerpo_v"],
        "cuerpo_posterior_z": posterior[0]["cuerpo_z"],
        "maximo_sobresaliente_cuerpo_mm": max(v["cuerpo_v"][1] - e["fondo"] for v in posterior) * 1000,
        "maximo_sobresaliente_contactos_mm": max(v["contactos_v"][1] - e["fondo"] for v in posterior) * 1000,
    }
assert all(v["fila_posterior_detras_panel_en_profundidad"] and
           v["fila_posterior_dentro_altura_panel"] for v in salida["casos"].values())
(scratch / "434-poetico-proyeccion.json").write_text(json.dumps(salida, indent=2), encoding="utf-8")
print(json.dumps(salida, indent=2))
