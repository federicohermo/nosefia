import re
import os
import subprocess
import sys
import time
from pathlib import Path


sys.stdout.reconfigure(encoding="utf-8", errors="replace")
scratch = Path(__file__).parent
destino = Path(sys.argv[1]).resolve()
web = Path((destino / "paquete-ruta.txt").read_text(encoding="utf-8")) / "web"
principal = Path("D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia")
salida = destino / "web"
salida.mkdir(exist_ok=True)
entorno = dict(os.environ)
temporal_chrome = Path("D:/nosefia-carril-C-429-444/chrome-431-temp")
temporal_chrome.mkdir(exist_ok=True)
entorno["TEMP"] = str(temporal_chrome)
entorno["TMP"] = str(temporal_chrome)
with (salida / "servidor.log").open("wb") as log_servidor:
    servidor = subprocess.Popen([sys.executable, str(scratch / "servir431.py"), "0", str(web)], stdout=log_servidor, stderr=subprocess.STDOUT)
    try:
        url = None
        for _ in range(100):
            assert servidor.poll() is None, "El servidor propio terminó al arrancar"
            texto = (salida / "servidor.log").read_text(encoding="utf-8", errors="replace")
            enlace = re.search(r"http://127\.0\.0\.1:\d+/index\.html", texto)
            if enlace:
                url = enlace.group(0)
                break
            time.sleep(0.1)
        assert url, "No se anunció el puerto asignado al servidor"
        print("CHROME431", url, str(salida), flush=True)
        with (salida / "runner.log").open("wb") as log:
            resultado = subprocess.run(["node", str(scratch / "recorrer_archivos431.mjs"), str(principal), url, str(salida), str(destino / "checkpoint-jornada-2.guardado")], env=entorno, stdout=log, stderr=subprocess.STDOUT, timeout=400)
        print((salida / "runner.log").read_text(encoding="utf-8", errors="replace"), flush=True)
        assert resultado.returncode == 0, "Falló el recorrido Web"
    finally:
        servidor.terminate()
        servidor.wait(timeout=10)
print("CHROME431_FINAL", flush=True)
