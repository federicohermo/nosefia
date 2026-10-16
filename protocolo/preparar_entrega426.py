"""Empaqueta evidencia existente de #426 después de la aceptación visual de nativo06.

No ejecuta motores, tests ni publicaciones. No modifica fuentes, fixtures o worktrees.
Normaliza a LF solamente las copias de texto; conserva ambos hashes en el manifiesto.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

SCRATCH = Path(__file__).resolve().parent
ORIGEN = SCRATCH / "426"
RAIZ = Path("D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/"
            ".claude/worktrees/batch-426-visibilidad")
HEAD = "e3f9aafcc2fdf65757b2ecd9da18126518f4322c"
BASE = "bc26e68435b03298bcd8fb07524b73f3671cd7cf"
TEXTOS = {".gd", ".py", ".json", ".log", ".md", ".xml", ".txt", ".uid"}
ANSI = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")


def sha(datos):
    return hashlib.sha256(datos).hexdigest()


def texto(ruta):
    return ANSI.sub("", ruta.read_text(encoding="utf-8", errors="replace"))


def verificar_entradas():
    actual = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=RAIZ, text=True).strip()
    if actual != HEAD:
        raise SystemExit(f"La evidencia corresponde a {HEAD}, pero el worktree está en {actual}")
    estado = subprocess.check_output(["git", "status", "--porcelain"], cwd=RAIZ, text=True)
    if estado.strip():
        raise SystemExit("El worktree de426 debe estar limpio antes de reunir la entrega:\n" + estado)
    subprocess.run(["git", "merge-base", "--is-ancestor", BASE, HEAD], cwd=RAIZ, check=True)
    capturas = ORIGEN / "nativo-06"
    if not capturas.is_dir():
        raise SystemExit("Todavía no existe nativo-06: no se prepara una entrega anticipada")
    obligatorias = (
        "gj23-mano", "gj23-quieto", "gj23-costado", "gj23-giro",
        "gj24-mano", "gj24-caida", "gj24-enfocado", "gj24-recogido", "gj24-devuelto",
        "gj25-mano", "gj25-1", "gj25-6", "gj25-7", "gj25-8",
        "gj25-intermedia-enfocada", "gj25-intermedia-retirada",
    )
    for nombre in obligatorias:
        ruta = capturas / (nombre + ".png")
        if not ruta.is_file() or ruta.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
            raise SystemExit(f"Falta una captura PNG del recorrido: {ruta}")
    recorrido = json.loads((capturas / "recorrido.json").read_text(encoding="utf-8"))
    if recorrido.get("fallo") is not False or not recorrido.get("recorrido_de_diagnostico"):
        raise SystemExit("El recorrido06 no declara diagnóstico funcional completado sin fallo")
    log_nativo = texto(ORIGEN / "nativo-06.log")
    if "DIAGNOSTICO426_FINAL fallo=false" not in log_nativo:
        raise SystemExit("Falta el marcador final de nativo06")
    if re.search(r"SCRIPT ERROR|Parse Error|(^|\s)ERROR:|leaked at exit|Resources still in use", log_nativo):
        raise SystemExit("El log nativo06 tiene errores o fugas; no empaquetar como entrega aceptada")
    if "OpenGL" not in log_nativo or "RTX 4050" not in log_nativo:
        raise SystemExit("El log06 no acredita el renderizador/plataforma previstos")
    crudo = SCRATCH / "426-crudo-02"
    for nodo in ("capas", "formato", "harness", "lint", "specs", "tdd", "tests", "tests-import"):
        if not (crudo / (nodo + ".log")).is_file():
            raise SystemExit(f"Falta crudo completo del nodo {nodo}")
    if "7/7 nodos en verde" not in texto(SCRATCH / "426-verificar-02.log"):
        raise SystemExit("Falta el resultado de los siete nodos")
    log_tests = texto(crudo / "tests.log")
    for nombre, esperado in (("suites", 267), ("cases", 2044)):
        conteos = re.findall(r"Executed test " + nombre + r"\s*:\s*\((\d+)/(\d+)\)", log_tests)
        if not conteos or tuple(map(int, conteos[-1])) != (esperado, esperado):
            raise SystemExit(f"El conteo crudo de {nombre} no coincide con la corrida aceptada")
    xml = RAIZ / "reports/report_1/results.xml"
    arbol = ET.parse(xml)
    if (len(list(arbol.iter("testsuite"))) != 267 or len(list(arbol.iter("testcase"))) != 2044
            or arbol.getroot().get("failures") != "0" or arbol.getroot().get("skipped") != "0"
            or list(arbol.iter("error")) or list(arbol.iter("failure"))):
        raise SystemExit("El XML no coincide con 267 suites/2044 casos sin fallos ni salteos")
    revision = json.loads((ORIGEN / "revision-root-vs-base425.json").read_text(encoding="utf-8"))
    if (revision.get("base") != 67 or revision.get("actual") != 67 or revision.get("nuevos")
            or revision.get("ausentes") != [] or revision.get("aborto_o_fugas") != {}):
        raise SystemExit("La revisión contra425 no coincide con los diagnósticos revisados")
    return log_nativo, xml


def recolectar(xml):
    archivos = {}

    def agregar(ruta, destino):
        if not ruta.is_file() or ruta.is_symlink():
            raise SystemExit(f"Falta una entrada regular del paquete: {ruta}")
        if destino in archivos:
            raise SystemExit(f"Ruta de entrega repetida: {destino}")
        archivos[destino] = ruta

    def carpeta(ruta, destino):
        if not ruta.is_dir():
            raise SystemExit(f"Falta un directorio esperado: {ruta}")
        for archivo in sorted(ruta.rglob("*")):
            if archivo.is_file() and "__pycache__" not in archivo.parts:
                agregar(archivo, str(Path(destino) / archivo.relative_to(ruta)).replace("\\", "/"))

    carpeta(ORIGEN / "nativo-06", "nativo-06")
    carpeta(SCRATCH / "426-crudo-02", "crudo-02")
    agregar(xml, "crudo-02/results.xml")
    agregar(SCRATCH / "426-verificar-02.log", "crudo-02/verificar-y-conteo.log")
    agregar(ORIGEN / "revision-root-vs-base425.json", "revisiones/contra-base425.json")
    agregar(ORIGEN / "revision-root-estricta.json", "revisiones/contra-base-anterior.json")
    agregar(SCRATCH / "425/crudo-02/tests.log", "base425/tests.log")
    agregar(SCRATCH / "425/crudo-02/tests-import.log", "base425/tests-import.log")
    agregar(RAIZ / "reports/focal-426/report_1/results.xml", "focal/results.xml")
    agregar(SCRATCH / "426-regresion-01.log", "focal/import-y-regresion.log")
    carpeta(ORIGEN / "geometria-camara", "incidentes/geometria-camara")
    for intento in ("02", "03", "04", "05"):
        carpeta(ORIGEN / ("nativo-" + intento), "incidentes/nativo-" + intento)
    for archivo in sorted(ORIGEN.iterdir()):
        if not archivo.is_file():
            continue
        if archivo.suffix.lower() in (".py", ".gd"):
            agregar(archivo, "protocolo/" + archivo.name)
        elif archivo.name.startswith("nativo-") and archivo.suffix.lower() in (".log", ".json"):
            subcarpeta = "nativo-06" if archivo.name.startswith("nativo-06") else "incidentes"
            agregar(archivo, subcarpeta + "/" + archivo.name)
    for archivo in sorted(SCRATCH.glob("preparar_control426_*.py")):
        agregar(archivo, "protocolo/" + archivo.name)
    for nombre in ("426-verificar-01.log", "426-control-03.log", "426-control-04.log",
                   "426-control-05.log", "426-control-06.log"):
        archivo = SCRATCH / nombre
        if archivo.is_file():
            agregar(archivo, "incidentes/turnos/" + nombre)
    agregar(SCRATCH / "verificar_crudo.py", "protocolo/verificar_crudo.py")
    agregar(Path(__file__), "protocolo/preparar_entrega426.py")
    for ruta in (".claude/scripts/verificar.py", ".claude/skills/implement-batch/scripts/turno.py",
                 ".claude/skills/implement-batch/scripts/conteo.py",
                 "test/escenas/objetos/productos_extraidos_visibles_test.gd"):
        agregar(RAIZ / ruta, "protocolo/versionado/" + ruta)
    return archivos


def preparar(aceptacion):
    log_nativo, xml = verificar_entradas()
    archivos = recolectar(xml)
    destino = (SCRATCH / "426-entrega").resolve()
    if destino.parent != SCRATCH.resolve() or destino.exists():
        raise SystemExit("426-entrega debe ser un directorio nuevo dentro del scratch; no se sobreescribe")
    plataforma = next(l for l in log_nativo.splitlines() if "OpenGL" in l and "RTX 4050" in l)
    readme = f"""# #426 — productos extraídos visibles

Fuente `{HEAD}` sobre la base #425 `{BASE}`. Windows, Godot 4.7.2, {plataforma}.

Aceptación visual del control06 por el padre: {aceptacion}

Estos son **recorridos de diagnóstico**, no reproducciones confirmadas de los reportes
originales: sus fichas no aportaban pasos ni versión. Se documentan por separado, sin causa
común atribuida y sin cambios artificiales en producción.

- GJ-23: tres Marolini, tres Saladik y tres Laysntt; extraer/soltar, caminar de costado y girar,
  conservando dibujo único y cuerpos; el origen de los grupos queda fuera del cuadro.
- GJ-24: Saladik caja→mano→piso; caída, enfoque/pérdida de foco, recogida y devolución. Las
  imágenes aceptadas son las de `nativo-06/`, con cámara fuera del espesor visual de pared.
- GJ-25: Jorgillo hasta sexta, séptima, octava y caja completa; atraviesa la capacidad inicial
  y comprueba cada índice, recogida intermedia y conservación de las otras unidades.

`crudo-02/` conserva todos los nodos, import y XML: 7/7, 267/267 suites y 2044/2044 casos.
La revisión contra #425 conserva 67 diagnósticos deliberados, sin nuevos errores/fugas.
Los controles anteriores están en `incidentes/`: su marcador funcional no acepta por sí
solo las PNG negras de Saladik. La lectura de triángulos ubica aquellas cámaras dentro de
la pared; no demuestra una causa de los reportes GJ-23/24/25 originales. Se conserva también
el incidente de parseo inicial y el control05 de orientación, sin mezclar sus resultados.

`protocolo/` conserva fixtures, wrappers y fuentes versionadas para repetir los recorridos.
Las capturas de diagnóstico no sustituyen las pruebas de transferencia ni el conteo crudo.

Sólo las **copias de texto** se normalizaron a LF, sin recodificar ni reemplazar caracteres;
las fuentes originales permanecen intactas. `manifest.json` relaciona hash/bytes originales
y publicados de cada carga, salvo él mismo. El inventario externo `426-entrega-inventario.json`
incluye también los bytes del manifiesto para auditar todos los blobs de la publicación.
""".encode("utf-8")
    destino.mkdir()
    manifiesto = {}

    def escribir(nombre, original, fuente):
        normalizado = Path(nombre).suffix.lower() in TEXTOS
        publicado = original.replace(b"\r\n", b"\n").replace(b"\r", b"\n") if normalizado else original
        archivo = destino / nombre
        archivo.parent.mkdir(parents=True, exist_ok=True)
        archivo.write_bytes(publicado)
        manifiesto[nombre] = {
            "fuente_original": fuente, "bytes_originales": len(original), "sha256_original": sha(original),
            "bytes_publicados": len(publicado), "sha256_publicado": sha(publicado),
            "texto_normalizado_a_lf": normalizado, "bytes_cambiaron": original != publicado,
        }

    for nombre, ruta in sorted(archivos.items()):
        original = ruta.read_bytes()
        escribir(nombre, original, str(ruta))
        if sha(ruta.read_bytes()) != sha(original):
            raise SystemExit(f"Una entrada cambió durante el empaquetado: {ruta}")
    escribir("README.md", readme, "generado por preparar_entrega426.py con aceptación explícita del padre")
    contenido = {"fuente": HEAD, "base425": BASE, "aceptacion_visual": aceptacion,
                 "normalizacion": "Sólo copias de texto: CRLF/CR a LF, bytes restantes conservados",
                 "archivos": manifiesto}
    (destino / "manifest.json").write_bytes(json.dumps(contenido, indent=2, ensure_ascii=False).encode("utf-8"))
    inventario = {str(p.relative_to(destino)).replace("\\", "/"):
                  {"bytes": p.stat().st_size, "sha256": sha(p.read_bytes())}
                  for p in sorted(destino.rglob("*")) if p.is_file()}
    (SCRATCH / "426-entrega-inventario.json").write_bytes(
        json.dumps({"carpeta": str(destino), "archivos": inventario}, indent=2).encode("utf-8"))
    print(json.dumps({"carpeta": str(destino), "archivos": len(inventario),
                      "bytes": sum(v["bytes"] for v in inventario.values()),
                      "inventario_externo": str(SCRATCH / "426-entrega-inventario.json")}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--aceptacion-visual", required=True,
                        help="Constancia del padre después de abrir y aceptar personalmente nativo06")
    opciones = parser.parse_args()
    if not opciones.aceptacion_visual.strip():
        parser.error("la constancia visual no puede estar vacía")
    preparar(opciones.aceptacion_visual.strip())
