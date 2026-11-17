"""Escribe el mapa de las jornadas de prueba, derivado del mapa completo. Corre adentro de
Blender y no guarda el `.blend`.

    blender <fuente>.blend --background --python .claude/scripts/blender/disponer_prueba.py

Cada producto presente conserva las tandas que tiene en el mapa completo, con su principal. La
tanda de un producto ausente la ocupa el producto que le asigna `REEMPLAZOS`, como tanda fija:
toma su frente y su piso, y copia el giro, la separación y las filas de una tanda real suya.

Un estante que queda con un solo producto se reparte de punta a punta, con una separación pareja.
Si el mueble tiene un divisor entre dos tandas, cada una se queda en su hueco: repartidas de punta
a punta, una unidad caía sobre el divisor.
Sigue siendo una tanda por columna: la principal conserva sus casilleros.
"""

import argparse
import re
import statistics
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
from mathutils import Matrix, Vector  # type: ignore[import-not-found]
from mathutils.bvhtree import BVHTree  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

import disponer  # noqa: E402
from lib.consola import configurar  # noqa: E402
from lib.gondola import AIRE, escribir_disposicion, separar_filas  # noqa: E402
from lib.reparto import MUEBLES, PRODUCTOS, partes, producto  # noqa: E402
from lib.reparto_de_prueba import (  # noqa: E402
    AIRE_MINIMO, CARAS, REEMPLAZOS, bases_del_contenido, cuantas_entran, paso_parejo, presentes,
    repartir_columnas, validar_identidades_de_prueba,
)

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / "src/escenas/puestos/disposicion_de_prueba.tres"
#: Cuánto más que su ancho puede separarse un producto al copiar la separación de su molde.
AIRE_DEL_MOLDE = AIRE + 0.03


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
        self.centro = (min(p.dot(self.u) for p in puntos) + max(p.dot(self.u) for p in puntos)) / 2
        self.origen = (self.u * min(p.dot(self.u) for p in puntos)
                       + self.v * min(p.dot(self.v) for p in puntos)
                       + self.normal * min(p.dot(self.normal) for p in puntos))

    def marco(self):
        """De los ejes del estante al mundo: u a lo largo, v hacia el fondo y la normal arriba."""
        marco = Matrix((self.u, self.v, self.normal)).transposed().to_4x4()
        marco.translation = self.origen
        return marco


def molde_de(producto, cara, columna, completo):
    """La tanda del producto que se copia: la de la misma columna, la de la cara o cualquiera."""
    def preferencia(clave):
        letra, de_la_cara, _ = partes(clave.split("/")[0])
        return (f"{letra}.{de_la_cara}" != cara, int(clave.split("/")[1]) != columna, clave)

    claves = [c for c, copias in completo.items() if str(copias[0]["producto"]) == producto]
    if not claves:
        raise ValueError(f"{producto}: no está en el mapa completo, no hay tanda que copiar")
    return completo[min(claves, key=preferencia)]


def _adelante(copias):
    return [c for c in copias if str(c["fila"]) == "adelante"]


def _extremos(copias, eje):
    valores = [(c.matrix_world @ v.co).dot(eje) for c in copias for v in c.data.vertices]
    return min(valores), max(valores)


def columnas_de(copias, molde, parejo=False, tramo=None, aire=None):
    """Dónde va el producto de `molde` en el lugar de `copias`, columna por columna: mismo frente,
    mismo piso, centrado, y tantas columnas como entran.

    `tramo` cambia el largo que ocupa, `aire` cuenta con esa separación mínima, y `parejo` reparte
    las columnas de punta a punta."""
    destino, origen = Tramo(copias), Tramo(molde)
    desde, hasta = _extremos(_adelante(copias), destino.u)
    frente = sorted(_adelante(molde), key=lambda c: c.matrix_world.translation.dot(origen.u))
    lugares = [c.matrix_world.translation.dot(origen.u) for c in frente]
    minimo, maximo = _extremos(frente[:1], origen.u)
    ancho = maximo - minimo
    paso = ancho + AIRE
    if len(lugares) > 1:
        paso = min(ancho + AIRE_DEL_MOLDE,
                   statistics.median(b - a for a, b in zip(lugares, lugares[1:])))
    columna = [c for c in molde
               if abs(c.matrix_world.translation.dot(origen.u) - lugares[0]) < paso / 2]
    corrido = 0.0
    if tramo is not None:
        corrido = tramo[0] - desde
        desde, hasta = tramo
    if aire is not None:
        paso = ancho + aire
    cuantas = cuantas_entran(hasta - desde, ancho, paso)
    if parejo:
        paso = paso_parejo(hasta - desde, ancho, cuantas, paso)
    sobra = (hasta - desde) - (ancho + paso * (cuantas - 1))
    marco_de_origen = origen.marco().inverted()
    salida = []
    for i in range(cuantas):
        corrimiento = Matrix.Translation((corrido + sobra / 2 + paso * i, 0.0, 0.0))
        salida.append([(destino.marco() @ corrimiento @ marco_de_origen @ c.matrix_world,
                        str(c["fila"])) for c in columna])
    return salida


def _copias_en(clave, columnas):
    """Copias sueltas de la unidad del producto en esos lugares. No entran a ninguna colección."""
    unidad = bpy.data.objects[producto(clave).objeto]
    salida = []
    for matriz, fila in (lugar for columna in columnas for lugar in columna):
        copia = unidad.copy()
        copia.parent = None
        copia.matrix_world = matriz
        copia["fila"] = fila
        salida.append(copia)
    return salida


def _arbol_del_mueble(letra):
    """La malla del mueble como se ve, con sus modificadores, en coordenadas del mundo."""
    objeto = bpy.data.objects[MUEBLES[letra]]
    malla = objeto.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    return BVHTree.FromPolygons(
        [objeto.matrix_world @ v.co for v in malla.vertices],
        [list(p.vertices) for p in malla.polygons],
    )


def hay_un_divisor(arbol, tramo, de_un_lado, del_otro):
    """Si el mueble pasa entre dos tandas vecinas, a media altura y a medio fondo de sus unidades."""
    def caja(copias):
        puntos = [c.matrix_world @ v.co for c in copias for v in c.data.vertices]
        return [(min(p.dot(e) for p in puntos), max(p.dot(e) for p in puntos))
                for e in (tramo.u, tramo.v, tramo.normal)]

    (_, fin), fondo, alto = caja(de_un_lado)
    (inicio, _), _, _ = caja(del_otro)
    if inicio <= fin:
        return False
    desde = (tramo.u * fin + tramo.v * (fondo[0] + fondo[1]) / 2
             + tramo.normal * (alto[0] + alto[1]) / 2)
    return arbol.ray_cast(desde, tramo.u, inicio - fin)[0] is not None


def emparejar(tandas, temporales):
    """Un estante con el mismo producto en todas sus columnas se reparte de punta a punta, salvo
    que un divisor del mueble separe sus tandas."""
    arboles = {}
    por_estante = {}
    for clave in tandas:
        por_estante.setdefault(clave.split("/")[0], []).append(clave)
    for estante, claves in sorted(por_estante.items()):
        if len(claves) < 2 or len({tandas[c][0] for c in claves}) != 1:
            continue
        nuevo = tandas[claves[0]][0]
        todas = [o for c in claves for o in tandas[c][2]]
        tramo = Tramo(todas)
        claves.sort(key=lambda c: min(
            o.matrix_world.translation.dot(tramo.u) for o in tandas[c][2]))
        letra = partes(estante)[0]
        if letra not in arboles:
            arboles[letra] = _arbol_del_mueble(letra)
        if any(hay_un_divisor(arboles[letra], tramo, tandas[a][2], tandas[b][2])
               for a, b in zip(claves, claves[1:])):
            print(f"{estante}: {nuevo} queda en sus huecos, hay un divisor entre las tandas")
            continue
        columnas = columnas_de(todas, tandas[claves[0]][2], parejo=True, aire=AIRE_MINIMO)
        frentes = [len(_adelante(tandas[c][2])) for c in claves]
        desde = 0
        for clave, cuantas in zip(claves, repartir_columnas(len(columnas), frentes)):
            copias = _copias_en(nuevo, columnas[desde:desde + cuantas])
            temporales.extend(copias)
            tandas[clave] = (nuevo, tandas[clave][1], copias)
            desde += cuantas
        print(f"{estante}: {nuevo} de punta a punta, {len(columnas)} de frente")


def tandas_de_prueba(completo):
    """El producto, si es la principal, y las unidades de cada tanda del mapa de prueba.

    Devuelve también las copias sueltas que creó: quien llama las borra al terminar."""
    tandas = {}
    temporales = []
    for clave, copias in sorted(completo.items()):
        letra, cara, _ = partes(clave.split("/")[0])
        if f"{letra}.{cara}" not in CARAS:
            continue
        propio = str(copias[0]["producto"])
        if propio not in REEMPLAZOS:
            tandas[clave] = (propio, not bool(copias[0]["fija"]), list(copias))
            continue
        nuevo = REEMPLAZOS[propio]
        molde = molde_de(nuevo, f"{letra}.{cara}", int(clave.split("/")[1]), completo)
        tandas[clave] = (nuevo, False, _copias_en(nuevo, columnas_de(copias, molde)))
        temporales.extend(tandas[clave][2])
    emparejar(tandas, temporales)
    return tandas, temporales


def generar():
    texto_catalogo = (RAIZ / "src/dominio/almacen/catalogo.gd").read_text(encoding="utf-8")
    declaracion = re.search(
        r"const PRODUCTOS_DE_PRUEBA.*?=\s*\[(.*?)\]", texto_catalogo, re.S
    ).group(1)
    validar_identidades_de_prueba(re.findall(r"Producto\.Id\.(\w+)", declaracion))
    tandas, temporales = tandas_de_prueba(disponer.tandas_del_blend())
    bases = bases_del_contenido(disponer.CONTENIDO.read_text(encoding="utf-8"))
    indices = {p.clave: i for i, p in enumerate(PRODUCTOS)}
    bloques = [[] for _ in PRODUCTOS]
    frontales = [0 for _ in PRODUCTOS]
    guias, productos_guias, frontales_guias = [], [], []
    for clave, (nuevo, principal, lugar) in sorted(tandas.items()):
        orden, adelante = separar_filas([str(c["fila"]) for c in lugar])
        bloque = disponer.bloque([lugar[i] for i in orden], bases[nuevo], clave)
        if principal:
            if bloques[indices[nuevo]]:
                raise ValueError(f"{nuevo}: dos tandas principales")
            bloques[indices[nuevo]] = bloque
            frontales[indices[nuevo]] = adelante
            print(f"{nuevo}: principal en {clave}, {adelante} de frente")
        else:
            guias.append(bloque)
            productos_guias.append(indices[nuevo])
            frontales_guias.append(adelante)
    sin_principal = [p for p in presentes() if not bloques[indices[p]]]
    if sin_principal:
        raise ValueError(f"sin tanda principal: {sin_principal}")
    for temporal in temporales:
        bpy.data.objects.remove(temporal, do_unlink=True)
    _, uid_del_script = disponer.uids(disponer.DISPOSICION.read_text(encoding="utf-8"))
    texto = escribir_disposicion(
        bloques, guias, frontales, "uid://cu2p575prueba", uid_del_script,
        productos_guias, frontales_guias,
    )
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
