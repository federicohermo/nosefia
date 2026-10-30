"""Escribe el mapa de las jornadas de prueba sobre los estantes del mapa completo. Corre adentro
de Blender y no guarda el `.blend`.

    blender <fuente>.blend --background --python .claude/scripts/blender/disponer_prueba.py

Cada cara del mapa de prueba se llena de nuevo sobre los estantes del mapa completo, con el
mismo frente y a la misma altura. Cuántas unidades lleva cada producto, cada cuánto y en qué punto
del estante lo declara `FRENTES`, igual en todos los estantes de la cara.

Cada producto copia el giro de una tanda real suya: la de la misma columna de la cara, y si la cara
no tiene ninguna, la de cualquier otro mueble. Su tanda principal es la más baja de las que eran
principales en el mapa completo: queda a la altura de la mano.
"""

import argparse
import re
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
from mathutils import Matrix, Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import disponer  # noqa: E402
from lib.consola import configurar  # noqa: E402
from lib.gondola import escribir_disposicion, separar_filas  # noqa: E402
from lib.reparto import PRODUCTOS, partes, producto  # noqa: E402
from lib.reparto_de_prueba import (  # noqa: E402
    CARAS, FRENTES, bases_del_contenido, validar_identidades_de_prueba,
)

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / "src/escenas/puestos/disposicion_de_prueba.tres"


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
        self.origen = (self.u * min(p.dot(self.u) for p in puntos)
                       + self.v * min(p.dot(self.v) for p in puntos)
                       + self.normal * min(p.dot(self.normal) for p in puntos))

    def marco(self):
        """De los ejes del estante al mundo: u a lo largo, v hacia el fondo y la normal arriba."""
        marco = Matrix((self.u, self.v, self.normal)).transposed().to_4x4()
        marco.translation = self.origen
        return marco


def columnas_de_prueba(cara, tandas):
    """Qué producto va en cada columna de la cara: el primero del estante, en la primera."""
    tramos = {int(clave.split("/")[1]): Tramo(copias) for clave, copias in tandas.items()}
    columnas = sorted(tramos, key=lambda c: tramos[c].origen.dot(tramos[c].u))
    productos = sorted(FRENTES[cara], key=lambda p: FRENTES[cara][p].medio)
    return dict(zip(columnas, productos))


def molde_de(producto, cara, columna, completo):
    """La tanda del producto que se copia: la de la misma columna, la de la cara o cualquiera."""
    def preferencia(clave):
        letra, de_la_cara, _ = partes(clave.split("/")[0])
        return (f"{letra}.{de_la_cara}" != cara, int(clave.split("/")[1]) != columna, clave)

    claves = [c for c, copias in completo.items() if str(copias[0]["producto"]) == producto]
    if not claves:
        raise ValueError(f"{producto}: no está en el mapa completo, no hay tanda que copiar")
    return completo[min(claves, key=preferencia)]


def llenar(copias, molde, frente):
    """Las unidades del producto en el estante de una tanda, con el giro de `molde`."""
    destino, origen = Tramo(copias), Tramo(molde)
    primera = next(c for c in molde if c["fila"] == "adelante")
    relativa = origen.marco().inverted() @ primera.matrix_world
    estante = destino.marco()
    estante.translation -= destino.u * destino.origen.dot(destino.u)
    unidad = bpy.data.objects[producto(str(molde[0]["producto"])).objeto]
    salida = []
    for i in range(frente.cuantas):
        lugar = frente.medio + frente.paso * (i - (frente.cuantas - 1) / 2)
        corrimiento = Matrix.Translation((lugar - relativa.translation.x, 0.0, 0.0))
        copia = unidad.copy()
        copia.parent = None
        copia.matrix_world = estante @ corrimiento @ relativa
        copia["fila"] = "adelante"
        salida.append(copia)
    return salida


def disponer_cara(cara, de_la_cara, completo):
    """El producto y las unidades de cada tanda de una cara del mapa de prueba."""
    productos = columnas_de_prueba(cara, de_la_cara)
    salida = {}
    for clave, copias in de_la_cara.items():
        columna = int(clave.split("/")[1])
        nuevo = productos[columna]
        molde = molde_de(nuevo, cara, columna, completo)
        salida[clave] = (nuevo, llenar(copias, molde, FRENTES[cara][nuevo]))
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
        for clave, (nuevo, lugar) in disponer_cara(cara, de_la_cara, completo).items():
            tandas[clave] = (nuevo, not bool(de_la_cara[clave][0]["fija"]), lugar)
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
