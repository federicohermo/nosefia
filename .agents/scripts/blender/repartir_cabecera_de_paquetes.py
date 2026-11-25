"""Reparte los paquetes de la cabecera sur de la góndola B de costado a costado.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/repartir_cabecera_de_paquetes.py -- [--aplicar]

Sin `--aplicar` sólo informa. Con `--aplicar` guarda la fuente canónica.

Los paquetes de Oremos y Pepito quedaban juntos en el medio del estante, con un margen ancho a
cada lado. Acá cada estante mide lo que hay libre entre los dos costados del mueble, a la altura
de sus paquetes, y deja el mismo espacio entre un costado y un paquete que entre dos paquetes.
Sólo corre las unidades a lo largo del estante: ni las gira ni las cambia de fila. Las bandejas
de cada columna, que son piezas sueltas de la malla del frente, se corren con ella.
"""

from __future__ import annotations

import sys
from collections import defaultdict

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

CARA = "B.sur"
MUEBLES = "gondolanueva"
#: Las mallas con las bandejas de la cabecera: la del mapa completo y la de las jornadas de prueba.
BANDEJAS = ("gondolanueva2-sur-frente", "gondolanueva2-sur-frente-prueba")
#: Hasta dónde se busca el costado del mueble desde la unidad de cada punta, en metros.
ALCANCE = 1.0


def _caja(objeto) -> tuple[Vector, Vector]:
    puntos = [objeto.matrix_world @ Vector(esquina) for esquina in objeto.bound_box]
    return (
        Vector([min(p[i] for p in puntos) for i in range(3)]),
        Vector([max(p[i] for p in puntos) for i in range(3)]),
    )


def _mueble() -> BVHTree:
    grafo = bpy.context.evaluated_depsgraph_get()
    vertices, caras = [], []
    for objeto in bpy.data.objects:
        if objeto.type != "MESH" or not objeto.name.startswith(MUEBLES):
            continue
        malla = objeto.evaluated_get(grafo).to_mesh()
        base = len(vertices)
        vertices += [objeto.matrix_world @ v.co for v in malla.vertices]
        caras += [[base + i for i in p.vertices] for p in malla.polygons]
    return BVHTree.FromPolygons(vertices, caras)


def _piezas(objeto) -> list[list[int]]:
    """Los vértices de cada pieza de una malla. Sus caras no comparten vértices: dos caras son de
    la misma pieza si tienen un vértice en el mismo lugar."""
    malla = objeto.data
    lugares = [
        tuple(round(c, 4) for c in objeto.matrix_world @ v.co) for v in malla.vertices
    ]
    padre = {lugar: lugar for lugar in lugares}

    def raiz(lugar: tuple) -> tuple:
        while padre[lugar] != lugar:
            padre[lugar] = padre[padre[lugar]]
            lugar = padre[lugar]
        return lugar

    for cara in malla.polygons:
        primero = raiz(lugares[cara.vertices[0]])
        for indice in cara.vertices[1:]:
            padre[raiz(lugares[indice])] = primero
    piezas: dict[tuple, list[int]] = defaultdict(list)
    for indice, lugar in enumerate(lugares):
        piezas[raiz(lugar)].append(indice)
    return list(piezas.values())


def correr_bandejas(estantes: list[tuple[float, list[float]]], paso: float) -> None:
    """Centra cada bandeja bajo la columna más cercana del estante en que se apoya.

    `estantes` trae, por estante, la altura de la base de sus paquetes y el centro de cada columna.
    """
    for nombre in BANDEJAS:
        objeto = bpy.data.objects[nombre]
        a_la_malla = objeto.matrix_world.inverted().to_3x3()
        vertices = objeto.data.vertices
        piezas = _piezas(objeto)
        for pieza in piezas:
            puntos = [objeto.matrix_world @ vertices[i].co for i in pieza]
            base = min(p.z for p in puntos)
            centro = (min(p.x for p in puntos) + max(p.x for p in puntos)) / 2
            _, columnas = min(estantes, key=lambda e: abs(e[0] - base))
            destino = min(columnas, key=lambda x: abs(x - centro))
            if abs(destino - centro) > paso / 2:
                raise SystemExit(f"{nombre}: una bandeja no queda bajo ninguna columna")
            corrimiento = a_la_malla @ Vector((destino - centro, 0.0, 0.0))
            for i in pieza:
                vertices[i].co += corrimiento
        objeto.data.update()
        print(f"{nombre}: {len(piezas)} piezas de bandeja centradas")


def repartir() -> None:
    arbol = _mueble()
    estantes = []
    paso = 0.0
    tandas = defaultdict(list)
    for objeto in bpy.data.objects:
        tanda = objeto.get("tanda", "")
        if tanda.startswith(CARA + "."):
            tandas[tanda].append(objeto)
    if not tandas:
        raise SystemExit(f"ninguna unidad lleva una tanda de {CARA}")
    for clave in sorted(tandas):
        cajas = {objeto: _caja(objeto) for objeto in tandas[clave]}
        desde = Vector([min(c[0][i] for c in cajas.values()) for i in range(3)])
        hasta = Vector([max(c[1][i] for c in cajas.values()) for i in range(3)])
        # Lo libre a cada lado, donde menos hay: adelante y atrás, abajo, al medio y arriba.
        libres = {-1: ALCANCE, 1: ALCANCE}
        for y in (desde.y, hasta.y):
            for parte in (0.05, 0.5, 0.95):
                z = desde.z + (hasta.z - desde.z) * parte
                for sentido, x in ((-1, desde.x), (1, hasta.x)):
                    golpe = arbol.ray_cast(Vector((x, y, z)), Vector((sentido, 0, 0)), ALCANCE)
                    if golpe[0] is not None:
                        libres[sentido] = min(libres[sentido], golpe[3])
        if ALCANCE in libres.values():
            raise SystemExit(f"{clave}: no se encontró el costado del mueble")
        izquierda, derecha = desde.x - libres[-1], hasta.x + libres[1]
        # Las columnas, de izquierda a derecha: las dos filas comparten el centro.
        columnas: list[list] = []
        for objeto in sorted(cajas, key=lambda o: cajas[o][0].x + cajas[o][1].x):
            centro = (cajas[objeto][0].x + cajas[objeto][1].x) / 2
            if columnas and abs(centro - columnas[-1][0]) < 0.01:
                columnas[-1][1].append(objeto)
            else:
                columnas.append([centro, [objeto]])
        ancho = max(c[1].x - c[0].x for c in cajas.values())
        espacio = (derecha - izquierda - len(columnas) * ancho) / (len(columnas) + 1)
        if espacio < 0:
            raise SystemExit(f"{clave}: las columnas no entran entre los costados")
        paso = ancho + espacio
        estantes.append(
            (desde.z, [izquierda + espacio + ancho / 2 + i * paso for i in range(len(columnas))])
        )
        for indice, (centro, objetos) in enumerate(columnas):
            nuevo = izquierda + espacio + ancho / 2 + indice * paso
            for objeto in objetos:
                matriz = objeto.matrix_world.copy()
                matriz.translation.x += nuevo - centro
                escala = objeto.scale.copy()
                objeto.matrix_world = matriz
                objeto.scale = escala
        print(
            f"{clave}: {len(columnas)} columnas entre {izquierda:.3f} y {derecha:.3f}, "
            f"espacio {espacio * 100:.1f} cm"
        )
    correr_bandejas(estantes, paso)


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    repartir()
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
