"""Publica evidencia con bytes literales y manifiesto construido desde el árbol Git."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile


def git(*args, env=None, entrada=None):
    resultado = subprocess.run(["git", *args], input=entrada, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, env=env)
    if resultado.returncode:
        fallo={"cmd":["git",*args],"codigo":resultado.returncode,"stdout":resultado.stdout.decode("utf8",errors="replace"),"stderr":resultado.stderr.decode("utf8",errors="replace")}
        Path(__file__).with_name("publicacion-fallo.json").write_text(json.dumps(fallo,ensure_ascii=False,indent=2),encoding="utf8")
        raise RuntimeError(json.dumps(fallo,ensure_ascii=True))
    return resultado.stdout


def texto(*args, **kwargs):
    return git(*args, **kwargs).decode("utf-8").strip()


def blobs(oids):
    solicitados = list(dict.fromkeys(oids))
    raw = git("cat-file", "--batch", entrada=("\n".join(solicitados) + "\n").encode("ascii"))
    posicion = 0
    resultado = {}
    for oid in solicitados:
        fin = raw.index(b"\n", posicion)
        identidad, tipo, tamano = raw[posicion:fin].split()
        assert identidad.decode("ascii") == oid and tipo == b"blob"
        posicion = fin + 1
        cantidad = int(tamano)
        resultado[oid] = raw[posicion:posicion + cantidad]
        assert len(resultado[oid]) == cantidad and raw[posicion + cantidad:posicion + cantidad + 1] == b"\n"
        posicion += cantidad + 1
    assert posicion == len(raw)
    return resultado


parser = argparse.ArgumentParser()
parser.add_argument("carpeta", type=Path)
parser.add_argument("--sin-push", action="store_true")
args = parser.parse_args()
carpeta = args.carpeta.resolve()
rama = "capturas/22"
remoto = texto("ls-remote", "origin", "refs/heads/" + rama)
padre = remoto.split()[0] if remoto else None
if padre:
    git("fetch", "-q", "origin", rama)
local = json.loads((carpeta / "manifiesto.json").read_text(encoding="utf-8"))
local["procedencia"] = "Huellas de archivos locales previas a publicar; no describen blobs Git."
local["archivos"] = {p.relative_to(carpeta).as_posix(): {"bytes":p.stat().st_size, "sha256":hashlib.sha256(p.read_bytes()).hexdigest()}
                     for p in sorted(carpeta.rglob("*")) if p.is_file() and p.name not in ("manifiesto.json", "manifiesto-local.json")}
with tempfile.TemporaryDirectory(dir="D:/nosefia-carril-C-429-444") as temp:
    env = {**os.environ, "GIT_INDEX_FILE": str(Path(temp) / "index")}
    git("read-tree", *([padre] if padre else ["--empty"]), env=env)
    rutas=[p for p in sorted(carpeta.rglob("*")) if p.is_file() and p.name not in ("manifiesto.json","manifiesto-local.json")]
    lista=("\n".join(p.as_posix() for p in rutas)+"\n").encode("utf8")
    oids=git("hash-object","-w","--no-filters","--stdin-paths",entrada=lista).decode("ascii").splitlines()
    assert len(oids)==len(rutas)
    entradas=b"".join((f"100644 {oid}\t{p.relative_to(carpeta).as_posix()}\0").encode("utf8") for p,oid in zip(rutas,oids))
    if padre:
        for registro in git("ls-tree","-r","-z",padre).split(b"\0"):
            if registro and registro.split(b"\t",1)[1].startswith(b"fisico-rojo-03/usuario-aislado/"):
                entradas+=b"0 "+b"0"*40+b"\t"+registro.split(b"\t",1)[1]+b"\0"
    git("update-index","-z","--index-info",env=env,entrada=entradas)
    blob_local = texto("hash-object", "-w", "--stdin", entrada=json.dumps(local, ensure_ascii=False, indent=2).encode("utf-8"))
    git("update-index", "--add", "--cacheinfo", f"100644,{blob_local},manifiesto-local.json", env=env)
    arbol = texto("write-tree", env=env)
    archivos = {}
    entradas = []
    for registro in git("ls-tree", "-r", "-z", arbol).split(b"\0"):
        if not registro:
            continue
        cabecera, nombre = registro.split(b"\t", 1)
        nombre = nombre.decode("utf-8")
        if nombre == "manifiesto.json":
            continue
        blob = cabecera.split()[2].decode("ascii")
        entradas.append((nombre, blob))
    contenidos = blobs(oid for _nombre, oid in entradas)
    for nombre, blob in entradas:
        datos = contenidos[blob]
        archivos[nombre] = {"bytes": len(datos), "sha256": hashlib.sha256(datos).hexdigest(), "blob": blob}
    canonico = {**local, "procedencia": "Tamaños y SHA256 calculados leyendo git cat-file blob del árbol publicado.",
                "padre_de_evidencia": padre, "procedencia_local": "manifiesto-local.json", "archivos": archivos}
    blob_canonico = texto("hash-object", "-w", "--stdin", entrada=json.dumps(canonico, ensure_ascii=False, indent=2).encode("utf-8"))
    git("update-index", "--add", "--cacheinfo", f"100644,{blob_canonico},manifiesto.json", env=env)
    final = texto("write-tree", env=env)
    commit = texto("commit-tree", final, *(["-p", padre] if padre else []), "-m", "Corrige huellas de evidencia22 desde bytes de blobs publicados")
    publicados = {r.split(b"\t",1)[1].decode("utf-8"):r.split(b"\t",1)[0].split()[2].decode("ascii")
                  for r in git("ls-tree","-r","-z",commit).split(b"\0") if r}
    comprobados = blobs(huella["blob"] for huella in archivos.values())
    for nombre, huella in archivos.items():
        assert publicados[nombre] == huella["blob"], nombre
        datos = comprobados[huella["blob"]]
        assert len(datos) == huella["bytes"] and hashlib.sha256(datos).hexdigest() == huella["sha256"], nombre
    resultado = {"padre": padre, "commit": commit, "archivos": len(archivos), "bytes": sum(x["bytes"] for x in archivos.values()),
                 "verificacion_cat_file": True, "sin_push": args.sin_push}
    if not args.sin_push:
        git("push", "origin", f"{commit}:refs/heads/{rama}")
        assert texto("ls-remote", "origin", "refs/heads/" + rama).split()[0] == commit
        resultado["sha_remoto_contrastado"] = commit
    salida = carpeta.parent / ("publicacion-bytes-dry.json" if args.sin_push else "publicacion-bytes.json")
    salida.write_text(json.dumps(resultado, indent=2), encoding="utf-8")
    print(json.dumps(resultado, indent=2))
