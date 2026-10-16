"""Lee GLB y recorrido existentes; no importa, ejecuta ni modifica Godot o Blender."""
import hashlib
import json
from pathlib import Path
import re
import struct

DIRECTORIO = Path(__file__).resolve().parent
SCRATCH = DIRECTORIO.parent
RAIZ = Path("D:/Usuarios/fede/Documentos/Catedra Videojuegos FADU/manada/repo/nosefia/"
            ".claude/worktrees/batch-426-visibilidad")
FUENTES = {
    "glb": RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.glb",
    "estructura": RAIZ / "src/escenas/puestos/estructura_del_almacen.tscn",
    "fixture_04": SCRATCH / "diagnostico426_04.gd",
    "recorrido_04": SCRATCH / "nativo-04/recorrido.json",
}
datos = FUENTES["glb"].read_bytes()
assert datos[:4] == b"glTF"
largo_json, tipo = struct.unpack_from("<II", datos, 12)
assert tipo == 0x4E4F534A
modelo = json.loads(datos[20:20 + largo_json])
largo_binario, tipo = struct.unpack_from("<II", datos, 20 + largo_json)
assert tipo == 0x004E4942
binario = memoryview(datos)[28 + largo_json:28 + largo_json + largo_binario]


def multiplicar(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def matriz(nodo):
    if "matrix" in nodo:
        return [[nodo["matrix"][j * 4 + i] for j in range(4)] for i in range(4)]
    x, y, z, w = nodo.get("rotation", [0, 0, 0, 1])
    escala = nodo.get("scale", [1, 1, 1])
    traslacion = nodo.get("translation", [0, 0, 0])
    salida = [
        [1 - 2*y*y - 2*z*z, 2*x*y - 2*z*w, 2*x*z + 2*y*w, traslacion[0]],
        [2*x*y + 2*z*w, 1 - 2*x*x - 2*z*z, 2*y*z - 2*x*w, traslacion[1]],
        [2*x*z - 2*y*w, 2*y*z + 2*x*w, 1 - 2*x*x - 2*y*y, traslacion[2]],
        [0, 0, 0, 1],
    ]
    for i in range(3):
        for j in range(3):
            salida[i][j] *= escala[j]
    return salida


def punto(transformacion, coordenadas):
    return tuple(sum(transformacion[i][j] * coordenadas[j] for j in range(3))
                 + transformacion[i][3] for i in range(3))


mundiales = {}


def recorrer(indice, padre):
    nodo = modelo["nodes"][indice]
    actual = multiplicar(padre, matriz(nodo))
    mundiales[indice] = actual
    for hijo in nodo.get("children", []):
        recorrer(hijo, actual)


identidad = [[int(i == j) for j in range(4)] for i in range(4)]
for indice in modelo["scenes"][modelo.get("scene", 0)]["nodes"]:
    recorrer(indice, identidad)


def accessor(indice):
    dato = modelo["accessors"][indice]
    assert "sparse" not in dato
    vista = modelo["bufferViews"][dato["bufferView"]]
    codigo = {5126: "f", 5125: "I", 5123: "H", 5121: "B"}[dato["componentType"]]
    ancho = {"SCALAR": 1, "VEC3": 3}[dato["type"]]
    formato = "<" + codigo * ancho
    longitud = struct.calcsize(formato)
    inicio = vista.get("byteOffset", 0) + dato.get("byteOffset", 0)
    paso = vista.get("byteStride", longitud)
    return [struct.unpack_from(formato, binario, inicio + j * paso) for j in range(dato["count"])]


def restar(a, b):
    return tuple(x - y for x, y in zip(a, b))


def producto(a, b):
    return sum(x * y for x, y in zip(a, b))


def cruz(a, b):
    return (a[1]*b[2] - a[2]*b[1], a[2]*b[0] - a[0]*b[2], a[0]*b[1] - a[1]*b[0])


def interseccion(ojo, direccion, a, b, c):
    """Möller–Trumbore sin descartar caras: se informa la malla, no un collider físico."""
    e1, e2 = restar(b, a), restar(c, a)
    p = cruz(direccion, e2)
    determinante = producto(e1, p)
    if abs(determinante) < 1e-10:
        return None
    inversa = 1.0 / determinante
    t = restar(ojo, a)
    u = producto(t, p) * inversa
    q = cruz(t, e1)
    v = producto(direccion, q) * inversa
    distancia = producto(e2, q) * inversa
    if u < 0 or v < 0 or u + v > 1 or distancia <= 0:
        return None
    return {"distancia": distancia, "baricentricas": [1 - u - v, u, v]}


def proyeccion_xy(ojo, a, b, c):
    determinante = (b[1]-c[1])*(a[0]-c[0]) + (c[0]-b[0])*(a[1]-c[1])
    if abs(determinante) < 1e-10:
        return None
    u = ((b[1]-c[1])*(ojo[0]-c[0]) + (c[0]-b[0])*(ojo[1]-c[1])) / determinante
    v = ((c[1]-a[1])*(ojo[0]-c[0]) + (a[0]-c[0])*(ojo[1]-c[1])) / determinante
    if min(u, v, 1-u-v) < -1e-8:
        return None
    return [u, v, 1-u-v]


triangulos = []
for indice, transformacion in mundiales.items():
    nodo = modelo["nodes"][indice]
    if nodo.get("name") != "almacen-col":
        continue
    for numero, primitiva in enumerate(modelo["meshes"][nodo["mesh"]]["primitives"]):
        assert primitiva.get("mode", 4) == 4
        vertices = [punto(transformacion, p) for p in accessor(primitiva["attributes"]["POSITION"])]
        indices = [x[0] for x in accessor(primitiva["indices"])]
        material = modelo["materials"][primitiva["material"]]
        for i in range(0, len(indices), 3):
            triangulos.append({
                "nodo": nodo["name"], "primitiva": numero, "triangulo": i // 3,
                "material": material["name"], "doubleSided": material.get("doubleSided", False),
                "alphaMode": material.get("alphaMode", "OPAQUE"),
                "vertices_mundiales": [vertices[j] for j in indices[i:i+3]],
            })


def vector(texto):
    return tuple(map(float, re.findall(r"[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?", texto)))


recorrido = json.loads(FUENTES["recorrido_04"].read_text(encoding="utf-8"))
capturas = {}
for captura in recorrido["registro"]:
    if "captura" not in captura:
        continue
    ojo, direccion = vector(captura["ojo"]), vector(captura["mirada"])
    rayos, caras = [], []
    for triangulo in triangulos:
        a, b, c = triangulo["vertices_mundiales"]
        golpe = interseccion(ojo, direccion, a, b, c)
        if golpe is not None and golpe["distancia"] < 3.0:
            rayos.append(dict(triangulo, **golpe))
        zs = [p[2] for p in (a, b, c)]
        if max(zs)-min(zs) < 1e-5 and -8.3 < zs[0] < -7.8:
            baricentricas = proyeccion_xy(ojo, a, b, c)
            if baricentricas is not None:
                caras.append(dict(triangulo, plano_z=zs[0], baricentricas_xy=baricentricas,
                                  distancia_firmada_z=zs[0]-ojo[2]))
    interior = next((p for p in caras if p["material"] == "deposito_revestimiento_bloques"), None)
    exterior = next((p for p in caras if p["material"] == "local_pared_pintada"), None)
    entre = bool(interior and exterior and interior["plano_z"] < ojo[2] < exterior["plano_z"])
    capturas[captura["captura"]] = {
        "ojo": ojo, "direccion": direccion, "camara_correcta_segun_fixture": captura["camara_correcta"],
        "dentro_espesor_visual_entre_caras": entre, "caras_que_contienen_xy": caras,
        "intersecciones_visuales_hasta_3m": sorted(rayos, key=lambda r: r["distancia"]),
    }

salida = {
    "revision_fuente": "e3f9aafcc2fdf65757b2ecd9da18126518f4322c",
    "metodo": "Lectura binaria GLB, matrices glTF mundiales, baricéntricas XY y rayos contra triángulos",
    "limite": "No ejecuta renderer/colisiones ni atribuye iluminación. No altera entradas de 05.",
    "fuentes": {nombre: {"ruta": str(p), "bytes": p.stat().st_size,
                         "sha256": hashlib.sha256(p.read_bytes()).hexdigest()}
                for nombre, p in FUENTES.items()},
    "triangulos_del_casco": len(triangulos), "capturas": capturas,
}
assert len(triangulos) == 748
assert all(capturas[p]["dentro_espesor_visual_entre_caras"]
           for p in capturas if p.startswith("gj24-"))
assert not capturas["gj25-1"]["dentro_espesor_visual_entre_caras"]
(DIRECTORIO / "lectura.json").write_text(json.dumps(salida, indent=2), encoding="utf-8")
print(json.dumps({k: {"dentro_pared": v["dentro_espesor_visual_entre_caras"],
                       "primer_golpe": [{"distancia": p["distancia"], "material": p["material"]}
                                        for p in v["intersecciones_visuales_hasta_3m"][:1]]}
                  for k, v in capturas.items()}, indent=2))
