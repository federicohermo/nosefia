"""Escribe el mapa de las jornadas de prueba sobre los estantes del mapa completo. Corre adentro
de Blender y no guarda el `.blend`.

    blender <fuente>.blend --background --python .claude/scripts/blender/disponer_prueba.py

Cada tanda del mapa completo que cae en una cara del mapa de prueba cambia de producto: la que ya
es del producto de prueba queda como está, y las demás se llenan con el producto de prueba en el
mismo tramo, con el mismo frente y a la misma altura. Así el mapa de prueba sigue a la góndola sin
medirla de nuevo: lo que mide el mapa completo vale para los dos.

En cada cara, el producto de prueba toma la columna donde ya está en el mapa completo. Su tanda
principal es la más baja de las que eran principales en el mapa completo: queda a la altura de la
mano.
"""

import argparse
import re
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
from mathutils import Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import acomodar  # noqa: E402
import disponer  # noqa: E402
from lib.consola import configurar  # noqa: E402
from lib.gondola import escribir_disposicion, separar_filas  # noqa: E402
from lib.reparto import PRODUCTOS, partes, producto  # noqa: E402
from lib.reparto_de_prueba import CARAS, bases_del_contenido, validar_identidades_de_prueba  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / "src/escenas/puestos/disposicion_de_prueba.tres"

#: Lo menos que se separan dos unidades vecinas de un producto cambiado, en metros.
SEPARACION_MINIMA = 0.008


class Tramo:
    """El lugar de una tanda: su frente, su base y su largo, en los ejes de su estante."""

    def __init__(self, copias):
        adelante = [c for c in copias if c["fila"] == "adelante"]
        modelo = producto(str(copias[0]["producto"]))
        giro = adelante[0].matrix_world.to_3x3()
        self.normal = (giro @ Vector(modelo.arriba)).normalized()
        self.v = -(giro @ Vector(modelo.frente)).normalized()
        self.u = self.v.cross(self.normal).normalized()
        puntos = [c.matrix_world @ v.co for c in adelante for v in c.data.vertices]
        us = [p.dot(self.u) for p in puntos]
        self.origen = (self.u * min(us) + self.v * min(p.dot(self.v) for p in puntos)
                       + self.normal * min(p.dot(self.normal) for p in puntos))
        self.largo = max(us) - min(us)
        self.lugares = sorted(
            sum((c.matrix_world @ v.co).dot(self.u) for v in c.data.vertices) / len(c.data.vertices)
            - min(us) for c in adelante
        )
        envase = acomodar.envase_de(modelo, bpy.data.objects[modelo.objeto])
        if len(adelante) > 1:
            self.separacion = max(
                SEPARACION_MINIMA, (self.largo - len(adelante) * envase.ancho) / (len(adelante) - 1)
            )
        else:
            self.separacion = SEPARACION_MINIMA

    def punto(self, u, v):
        return self.origen + self.u * u + self.v * v

    def centros(self, ancho):
        """Los mismos lugares que la tanda de antes si entran: los divisores caen entre ellos."""
        entran = all(b - a >= ancho + SEPARACION_MINIMA
                     for a, b in zip(self.lugares, self.lugares[1:]))
        if len(self.lugares) > 1 and entran:
            return self.lugares
        cuantas = max(1, int((self.largo + self.separacion) // (ancho + self.separacion)))
        if cuantas == 1:
            return [self.largo / 2]
        paso = (self.largo - ancho) / (cuantas - 1)
        return [ancho / 2 + paso * i for i in range(cuantas)]


def columnas_de_prueba(cara, tandas):
    """Qué producto de prueba va en cada columna de la cara."""
    productos = CARAS[cara]
    columnas = sorted({int(clave.split("/")[1]) for clave in tandas})
    if len(productos) == 1:
        return {c: productos[0] for c in columnas}
    salida = {}
    for clave, copias in sorted(tandas.items()):
        actual = str(copias[0]["producto"])
        if actual in productos and actual not in salida.values():
            salida.setdefault(int(clave.split("/")[1]), actual)
    libres = [p for p in productos if p not in salida.values()]
    for c in columnas:
        if c not in salida:
            salida[c] = libres.pop(0)
    return salida


def cambiar(copias, clave_de_prueba):
    """Las unidades del producto de prueba en el tramo de una tanda, en una sola fila."""
    tramo = Tramo(copias)
    modelo = producto(clave_de_prueba)
    unidad = bpy.data.objects[modelo.objeto]
    envase = acomodar.envase_de(modelo, unidad)
    salida = []
    for u in tramo.centros(envase.ancho):
        copia = unidad.copy()
        copia.parent = None
        copia.matrix_world = acomodar.matriz_de(modelo, unidad, tramo, u, envase.fondo / 2)
        copia["fila"] = "adelante"
        salida.append(copia)
    return salida


def generar():
    texto_catalogo = (RAIZ / "src/dominio/almacen/catalogo.gd").read_text(encoding="utf-8")
    declaracion = re.search(
        r"const PRODUCTOS_DE_PRUEBA.*?=\s*\[(.*?)\]", texto_catalogo, re.S
    ).group(1)
    validar_identidades_de_prueba(re.findall(r"Producto\.Id\.(\w+)", declaracion))
    completo = disponer.tandas_del_blend()
    por_cara = {}
    for clave, copias in completo.items():
        estante = clave.split("/")[0]
        letra, cara, _ = partes(estante)
        if f"{letra}.{cara}" in CARAS:
            por_cara.setdefault(f"{letra}.{cara}", {})[clave] = copias
    tandas = {}
    for cara, de_la_cara in sorted(por_cara.items()):
        columnas = columnas_de_prueba(cara, de_la_cara)
        for clave, copias in sorted(de_la_cara.items()):
            nuevo = columnas[int(clave.split("/")[1])]
            if str(copias[0]["producto"]) == nuevo:
                lugar = list(copias)
            else:
                lugar = cambiar(copias, nuevo)
            principal_antes = not bool(copias[0]["fija"])
            tandas[clave] = (nuevo, principal_antes, lugar)
    principales = {}
    for clave, (nuevo, principal_antes, _) in sorted(
        tandas.items(), key=lambda t: (partes(t[0].split("/")[0])[2], t[0])
    ):
        if principal_antes:
            principales.setdefault(nuevo, clave)
    presentes = {p for productos in CARAS.values() for p in productos}
    if set(principales) != presentes:
        raise ValueError(f"sin tanda principal: {sorted(presentes - set(principales))}")
    bases = bases_del_contenido(disponer.CONTENIDO.read_text(encoding="utf-8"))
    indices = {p.clave: i for i, p in enumerate(PRODUCTOS)}
    bloques = [[] for _ in PRODUCTOS]
    frontales = [0 for _ in PRODUCTOS]
    guias, productos_guias, frontales_guias = [], [], []
    for clave, (nuevo, _, lugar) in sorted(tandas.items()):
        orden, adelante = separar_filas([str(c["fila"]) for c in lugar])
        bloque = disponer.bloque([lugar[i] for i in orden], bases[nuevo], clave)
        if principales[nuevo] == clave:
            bloques[indices[nuevo]] = bloque
            frontales[indices[nuevo]] = adelante
        else:
            guias.append(bloque)
            productos_guias.append(indices[nuevo])
            frontales_guias.append(adelante)
    _, uid_del_script = disponer.uids(disponer.DISPOSICION.read_text(encoding="utf-8"))
    texto = escribir_disposicion(
        bloques, guias, frontales, "uid://cu2p575prueba", uid_del_script,
        productos_guias, frontales_guias,
    )
    for nuevo, clave in sorted(principales.items()):
        print(f"{nuevo}: principal en {clave}, {frontales[indices[nuevo]]} de frente")
    print(f"{len(tandas)} tandas, {len(guias)} fijas")
    return texto + "base_de_guias = 1\n"


def principal():
    configurar()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destino", type=Path, default=DESTINO)
    argumentos = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    texto = generar()
    argumentos.destino.write_text(texto, encoding="utf-8", newline="\n")
    print(f"Escrito {argumentos.destino}")


if __name__ == "__main__":
    principal()
