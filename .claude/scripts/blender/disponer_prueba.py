"""Escribe el mapa de las jornadas de prueba sobre los estantes del mapa completo. Corre adentro
de Blender y no guarda el `.blend`.

    blender <fuente>.blend --background --python .claude/scripts/blender/disponer_prueba.py

Cada cara del mapa de prueba se llena de nuevo sobre los estantes del mapa completo, con el
mismo frente y a la misma altura. Así el mapa de prueba sigue a la góndola sin medirla de nuevo:
lo que mide el mapa completo vale para los dos.

En cada cara, el producto de prueba toma la columna donde ya está en el mapa completo. Su tanda
principal es la más baja de las que eran principales en el mapa completo: queda a la altura de la
mano.

**Todos los estantes de una cara se ven iguales.** Cada columna se llena con una tanda real de su
producto, con su giro y su paso: la de la misma columna de la cara, y si la cara no tiene
ninguna, la de cualquier otro mueble. El tramo es el más ancho que ocupan las tandas de la cara
en cualquier estante. Con dos productos, entre ellos queda el aire más justo que dejaba el mapa
completo, y el reparto busca a la vez la junta más cerca de donde estaba y el menor hueco sin
llenar.
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
from lib.reparto_de_prueba import CARAS, bases_del_contenido, validar_identidades_de_prueba  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / "src/escenas/puestos/disposicion_de_prueba.tres"

#: Lo menos que se separan dos unidades vecinas de un producto cambiado, en metros.
SEPARACION_MINIMA = 0.008

#: Lo que puede pasarse un bloque de su tramo y seguir entrando, en metros.
TOLERANCIA = 0.002


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

    def marco(self):
        """De los ejes del estante al mundo: u a lo largo, v hacia el fondo y la normal arriba."""
        marco = Matrix((self.u, self.v, self.normal)).transposed().to_4x4()
        marco.translation = self.origen
        return marco


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


def molde_de(producto, cara, columna, completo):
    """La tanda del producto que se copia: la de la misma columna, la de la cara o cualquiera."""
    def preferencia(clave):
        letra, de_la_cara, _ = partes(clave.split("/")[0])
        return (f"{letra}.{de_la_cara}" != cara, int(clave.split("/")[1]) != columna, clave)

    claves = [c for c, copias in completo.items() if str(copias[0]["producto"]) == producto]
    if not claves:
        raise ValueError(f"{producto}: no está en el mapa completo, no hay tanda que copiar")
    return completo[min(claves, key=preferencia)]


class Molde:
    """Una tanda real de un producto: el giro de sus unidades, su ancho y el paso entre ellas."""

    def __init__(self, copias):
        self.tramo = Tramo(copias)
        adelante = sorted(
            (c for c in copias if c["fila"] == "adelante"),
            key=lambda c: (c.matrix_world.translation - self.tramo.origen).dot(self.tramo.u),
        )
        self.relativa = self.tramo.marco().inverted() @ adelante[0].matrix_world
        lugares = self.tramo.lugares
        self.ancho = self.tramo.largo - (lugares[-1] - lugares[0])
        if len(lugares) > 1:
            self.paso = (lugares[-1] - lugares[0]) / (len(lugares) - 1)
        else:
            self.paso = self.ancho + SEPARACION_MINIMA
        self.unidad = bpy.data.objects[producto(str(copias[0]["producto"])).objeto]

    def largo(self, cuantas):
        return self.ancho + self.paso * (cuantas - 1)

    def cuantas(self, largo):
        return max(1, int((largo - self.ancho + TOLERANCIA) / self.paso) + 1)


def bloques(tramos, columnas, moldes):
    """Dónde empieza cada columna a lo largo del estante y cuántas unidades lleva."""
    lados = {}
    for clave, tramo in tramos.items():
        desde = tramo.origen.dot(tramo.u)
        lados.setdefault(columnas[clave], {})[clave.split("/")[0]] = (desde, desde + tramo.largo)
    desde = min(d for l in lados.values() for d, _ in l.values())
    hasta = max(h for l in lados.values() for _, h in l.values())
    if len(lados) == 1:
        (c,) = lados
        n = moldes[c].cuantas(hasta - desde)
        return {c: (desde + (hasta - desde - moldes[c].largo(n)) / 2, n)}
    baja, alta = sorted(lados, key=lambda c: min(d for d, _ in lados[c].values()))
    juntas = [(lados[baja][e][1], lados[alta][e][0]) for e in lados[baja].keys() & lados[alta].keys()]
    corte = sum(h + d for h, d in juntas) / (2 * len(juntas))
    aire = max(SEPARACION_MINIMA, min(d - h for h, d in juntas))
    candidatas = []
    for n in range(1, moldes[baja].cuantas(hasta - desde) + 1):
        resto = hasta - desde - aire - moldes[baja].largo(n)
        if resto < moldes[alta].ancho - TOLERANCIA:
            continue
        m = moldes[alta].cuantas(resto)
        sobra = resto - moldes[alta].largo(m)
        junta = desde + sobra / 3 + moldes[baja].largo(n) + aire / 2 + sobra / 6
        candidatas.append((abs(junta - corte) + sobra, n, m, sobra))
    _, n, m, sobra = min(candidatas)
    inicio = desde + sobra / 3
    return {baja: (inicio, n),
            alta: (inicio + moldes[baja].largo(n) + aire + sobra / 3, m)}


def llenar(copias, molde, inicio, cuantas):
    """Las unidades del molde sobre el estante de una tanda, desde `inicio` a lo largo."""
    destino = Tramo(copias)
    estante = destino.marco()
    estante.translation -= destino.u * destino.origen.dot(destino.u)
    salida = []
    for i in range(cuantas):
        corrimiento = Matrix.Translation(
            (inicio + molde.ancho / 2 + molde.paso * i - molde.tramo.lugares[0], 0.0, 0.0))
        copia = molde.unidad.copy()
        copia.parent = None
        copia.matrix_world = estante @ corrimiento @ molde.relativa
        copia["fila"] = "adelante"
        salida.append(copia)
    return salida


def disponer_cara(cara, de_la_cara, completo):
    """El producto y las unidades de cada tanda de una cara del mapa de prueba."""
    productos = columnas_de_prueba(cara, de_la_cara)
    columnas = {clave: int(clave.split("/")[1]) for clave in de_la_cara}
    moldes = {c: Molde(molde_de(productos[c], cara, c, completo)) for c in set(columnas.values())}
    tramos = {clave: Tramo(copias) for clave, copias in de_la_cara.items()}
    lugares = bloques(tramos, columnas, moldes)
    return {
        clave: (productos[columnas[clave]],
                llenar(copias, moldes[columnas[clave]], *lugares[columnas[clave]]))
        for clave, copias in de_la_cara.items()
    }


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
