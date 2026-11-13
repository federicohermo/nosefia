"""Deja la estantería empotrada de no comestibles con cinco estantes parejos en cada columna.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/parejar_estanteria_n.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/parejar-estanteria-n.blend` y no modifica el `.blend` del
repo. Con `--aplicar`, guarda la fuente canónica en su lugar. Después va la cadena: `disponer.py`
y `disponer_prueba.py`, `exportar_modelo.py`, `integrar_modelo.py`, `actualizar_apoyos.py` y
`hornear.py`.

## Por qué

Las dos columnas de `gondolanueva-col.001` no coincidían: la izquierda tenía cinco estantes a
alturas desparejas y la derecha seis, y las líneas no seguían las de las heladeras vecinas.

## Qué cambia

- **Las dos columnas quedan con `NIVELES` estantes cada una, a las mismas alturas y con la
  misma separación.** El de abajo es el piso del nicho, a la altura de la rejilla de las
  heladeras, y no se mueve. El de arriba queda a la altura de la bandeja más alta de las
  heladeras que funcionan, que se mide en `heladeranueva-col`; los otros tres se reparten parejo
  entre los dos. Los demás estantes se borran.
- **Cada estante lleva su portaprecios** (`estanteria_precios`), y los de los estantes que se
  borran se borran.
- **Cada producto conserva su columna.** El de abajo de cada columna (Poético, Actroncito) queda
  con dos estantes: el piso, con su referencia fija, y el siguiente, con su principal. El de arriba
  (Duronga, Durextra) queda con los tres de arriba: su principal en el de en medio y dos
  referencias fijas. Las unidades viajan rígidas con su estante y se renombran `N.sur.<nivel>/<columna>`.
- El marco, el hueco en la madera, el panel y las tapas no cambian.

## Lo que cuesta

0 triángulos nuevos, 0 materiales y 0 texturas. Es idempotente: si los estantes ya están a las
alturas pedidas, no cambia nada.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]
from mathutils import Matrix, Vector  # type: ignore[import-not-found]
from mathutils.bvhtree import BVHTree  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402
from lib.estanteria_pareja import alturas_parejas  # noqa: E402
from lib.reparto import PRODUCTOS  # noqa: E402

ESTANTERIA = "gondolanueva-col.001"
PRECIOS = "estanteria_precios"
HELADERA = "heladeranueva-col"
#: Cuántos estantes lleva cada columna, con el piso del nicho.
NIVELES = 5
#: Cuántos de ellos son del producto de arriba de cada columna, que lleva su principal en el
#: primero. El de abajo lleva los dos primeros: el piso con su fija y el siguiente con su principal.
DE_ARRIBA = 3
#: Un estante es una caja de este grosor, y su ancho es el de una columna.
GROSOR_MAXIMO = 0.05
ANCHO_DE_UNA_COLUMNA = (0.9, 1.2)
#: Cuánto sube el portaprecios sobre el estante en que está.
SOBRE_EL_ESTANTE = 0.004
#: Dos alturas a menos de esto son la misma.
IGUAL = 1e-3


def _objeto(nombre: str):
    objeto = bpy.data.objects.get(nombre)
    if objeto is None:
        raise SystemExit(f"falta el objeto {nombre}; no se guardó nada")
    return objeto


def _islas(bm) -> list[list]:
    bm.faces.ensure_lookup_table()
    visto: set[int] = set()
    salida = []
    for cara in bm.faces:
        if cara.index in visto:
            continue
        pila, isla = [cara], []
        visto.add(cara.index)
        while pila:
            actual = pila.pop()
            isla.append(actual)
            for arista in actual.edges:
                for vecina in arista.link_faces:
                    if vecina.index not in visto:
                        visto.add(vecina.index)
                        pila.append(vecina)
        salida.append(isla)
    return salida


def _caja(isla, mundo: Matrix) -> tuple[Vector, Vector]:
    puntos = [mundo @ v.co for cara in isla for v in cara.verts]
    return (
        Vector([min(p[i] for p in puntos) for i in range(3)]),
        Vector([max(p[i] for p in puntos) for i in range(3)]),
    )


def _columna(minimo: Vector, maximo: Vector, medio_x: float) -> int:
    return 0 if (minimo.x + maximo.x) / 2 < medio_x else 1


def _bandejas_de_las_heladeras() -> list[float]:
    """La cara de arriba de cada bandeja de la heladera 1, de abajo hacia arriba."""
    heladera = _objeto(HELADERA)
    bm = bmesh.new()
    bm.from_mesh(heladera.data)
    alturas: list[float] = []
    for cara in bm.faces:
        normal = heladera.matrix_world.to_3x3() @ cara.normal
        if normal.z < 0.99 or cara.calc_area() < 0.2:
            continue
        z = (heladera.matrix_world @ cara.calc_center_median()).z
        if 0.4 < z < 2.3 and not any(abs(z - a) < IGUAL for a in alturas):
            alturas.append(z)
    bm.free()
    return sorted(alturas)


def _estantes(bm, mundo: Matrix, medio_x: float) -> dict[int, list[tuple[float, list]]]:
    """Los estantes de cada columna, de abajo hacia arriba, como `(cara de arriba, isla)`. El
    primero es el piso del nicho."""
    por_columna: dict[int, list[tuple[float, list]]] = {0: [], 1: []}
    for isla in _islas(bm):
        minimo, maximo = _caja(isla, mundo)
        ancho = maximo.x - minimo.x
        if maximo.z - minimo.z < GROSOR_MAXIMO and ANCHO_DE_UNA_COLUMNA[0] < ancho < ANCHO_DE_UNA_COLUMNA[1]:
            por_columna[_columna(minimo, maximo, medio_x)].append((maximo.z, isla))
    return {c: sorted(estantes, key=lambda e: e[0]) for c, estantes in por_columna.items()}


def _mover_z(bm, isla, corrimiento: float) -> None:
    for vertice in {v for cara in isla for v in cara.verts}:
        vertice.co.z += corrimiento


def _borrar(bm, islas: list[list]) -> None:
    bmesh.ops.delete(bm, geom=[cara for isla in islas for cara in isla], context="FACES")


def _unidades_de_la_estanteria() -> list:
    return [o for o in bpy.data.objects if str(o.get("tanda", "")).startswith("N.sur.")]


def _plan_de_las_unidades(columna: int, tandas: dict[int, list]) -> dict[int, int]:
    """Qué nivel viejo pasa a qué nivel nuevo, en una columna. Lo que no aparece se borra.

    El producto de abajo conserva su piso y su principal; el de arriba, sus tres primeros niveles.
    """
    por_producto: dict[str, list[int]] = {}
    for nivel in sorted(tandas):
        producto = str(tandas[nivel][0]["producto"])
        por_producto.setdefault(producto, []).append(nivel)
    if len(por_producto) != 2:
        raise SystemExit(f"la columna {columna} no lleva dos productos: {sorted(por_producto)}")
    de_abajo, de_arriba = sorted(por_producto.values(), key=lambda niveles: niveles[0])
    principal = next(n for n in de_abajo if not bool(tandas[n][0]["fija"]))
    plan = {de_abajo[0]: 0, principal: 1}
    for nuevo, viejo in enumerate(de_arriba[:DE_ARRIBA], start=NIVELES - DE_ARRIBA):
        plan[viejo] = nuevo
    if bool(tandas[de_arriba[0]][0]["fija"]):
        raise SystemExit(f"la columna {columna} no tiene su principal en el primer nivel de arriba")
    return plan


def parejar() -> bool:
    estanteria = _objeto(ESTANTERIA)
    precios = _objeto(PRECIOS)
    mundo = estanteria.matrix_world
    bm = bmesh.new()
    bm.from_mesh(estanteria.data)
    medio_x = mundo.translation.x
    estantes = _estantes(bm, mundo, medio_x)
    piso = estantes[0][0][0]
    if abs(estantes[1][0][0] - piso) > IGUAL:
        raise SystemExit("las dos columnas no tienen el piso a la misma altura")
    bandejas = _bandejas_de_las_heladeras()
    if len(bandejas) != 4:
        raise SystemExit(f"{HELADERA} no tiene cuatro bandejas: {bandejas}")
    nuevas = alturas_parejas(piso, bandejas[-1], NIVELES)
    ya = all(
        len(estantes[c]) == NIVELES
        and all(abs(e[0] - z) < IGUAL for e, z in zip(estantes[c], nuevas))
        for c in (0, 1)
    )
    if ya:
        print("la estantería ya tiene sus cinco estantes parejos; no cambia nada")
        bm.free()
        return False
    viejas = {c: [e[0] for e in estantes[c]] for c in (0, 1)}
    print(
        "bandejas de la heladera: "
        + ", ".join(f"{z:.3f}" for z in bandejas)
        + f"; estantes nuevos: {', '.join(f'{z:.3f}' for z in nuevas)}"
    )

    # Los estantes: los de arriba del piso suben o bajan a su altura y los que sobran se borran.
    sobran = []
    for c in (0, 1):
        for nivel, (arriba, isla) in enumerate(estantes[c]):
            if nivel >= NIVELES:
                sobran.append(isla)
            elif nivel > 0:
                _mover_z(bm, isla, nuevas[nivel] - arriba)
    _borrar(bm, sobran)
    bm.to_mesh(estanteria.data)
    bm.free()
    estanteria.data.update()

    # Los portaprecios van con su estante.
    bp = bmesh.new()
    bp.from_mesh(precios.data)
    mundo_p = precios.matrix_world
    borrar = []
    for isla in _islas(bp):
        minimo, maximo = _caja(isla, mundo_p)
        c = _columna(minimo, maximo, medio_x)
        nivel = min(
            range(len(viejas[c])),
            key=lambda k: abs(minimo.z - (viejas[c][k] + SOBRE_EL_ESTANTE)),
        )
        if abs(minimo.z - (viejas[c][nivel] + SOBRE_EL_ESTANTE)) > 0.01:
            raise SystemExit(f"un portaprecios no está sobre ningún estante: z={minimo.z:.3f}")
        if nivel >= NIVELES:
            borrar.append(isla)
        else:
            _mover_z(bp, isla, nuevas[nivel] - viejas[c][nivel])
    _borrar(bp, borrar)
    bp.to_mesh(precios.data)
    bp.free()
    precios.data.update()

    # Las unidades.
    fuentes = {p.objeto for p in PRODUCTOS}
    todas = _unidades_de_la_estanteria()
    por_columna: dict[int, dict[int, list]] = {0: {}, 1: {}}
    for unidad in todas:
        nivel, columna = str(unidad["tanda"]).removeprefix("N.sur.").split("/")
        por_columna[int(columna)].setdefault(int(nivel), []).append(unidad)
    movidas = borradas = 0
    for c in (0, 1):
        plan = _plan_de_las_unidades(c, por_columna[c])
        for viejo, unidades in sorted(por_columna[c].items()):
            nuevo = plan.get(viejo)
            for unidad in unidades:
                if nuevo is None:
                    if unidad.name in fuentes:
                        raise SystemExit(f"se iba a borrar la unidad fuente {unidad.name}")
                    bpy.data.objects.remove(unidad, do_unlink=True)
                    borradas += 1
                    continue
                escala = unidad.scale.copy()
                unidad.matrix_world = (
                    Matrix.Translation((0.0, 0.0, nuevas[nuevo] - viejas[c][viejo]))
                    @ unidad.matrix_world
                )
                unidad.scale = escala
                unidad["tanda"] = f"N.sur.{nuevo}/{c}"
                movidas += 1
    print(f"{movidas} unidades movidas y {borradas} borradas")
    bpy.context.view_layer.update()
    return True


def verificar() -> None:
    """Cada columna tiene cinco estantes parejos, cada unidad apoya en su estante sin tocar el
    mueble, y no queda ningún portaprecios sin estante."""
    estanteria = _objeto(ESTANTERIA)
    precios = _objeto(PRECIOS)
    mundo = estanteria.matrix_world
    bm = bmesh.new()
    bm.from_mesh(estanteria.data)
    estantes = _estantes(bm, mundo, mundo.translation.x)
    bm.free()
    for c in (0, 1):
        alturas = [e[0] for e in estantes[c]]
        if len(alturas) != NIVELES:
            raise SystemExit(f"la columna {c} tiene {len(alturas)} estantes")
        separaciones = [b - a for a, b in zip(alturas, alturas[1:])]
        if max(separaciones) - min(separaciones) > IGUAL:
            raise SystemExit(f"la columna {c} no tiene la misma separación: {separaciones}")
    if any(abs(a[0] - b[0]) > IGUAL for a, b in zip(estantes[0], estantes[1])):
        raise SystemExit("las dos columnas no están a las mismas alturas")
    alturas = [e[0] for e in estantes[0]]
    bp = bmesh.new()
    bp.from_mesh(precios.data)
    cuentas = {0: 0, 1: 0}
    for isla in _islas(bp):
        minimo, maximo = _caja(isla, precios.matrix_world)
        c = _columna(minimo, maximo, mundo.translation.x)
        if not any(abs(minimo.z - (z + SOBRE_EL_ESTANTE)) < IGUAL for z in alturas):
            raise SystemExit(f"un portaprecios quedó fuera de su estante: z={minimo.z:.3f}")
        cuentas[c] += 1
    bp.free()
    if cuentas != {0: NIVELES, 1: NIVELES}:
        raise SystemExit(f"los portaprecios no son uno por estante: {cuentas}")
    caras = [(mundo @ v.co) for v in estanteria.data.vertices]
    arbol = BVHTree.FromPolygons(
        caras, [list(p.vertices) for p in estanteria.data.polygons]
    )
    for unidad in _unidades_de_la_estanteria():
        puntos = [unidad.matrix_world @ v.co for v in unidad.data.vertices]
        base = min(p.z for p in puntos)
        propio = BVHTree.FromPolygons(puntos, [list(p.vertices) for p in unidad.data.polygons])
        for cara, _ in arbol.overlap(propio):
            techo = max(caras[i].z for i in estanteria.data.polygons[cara].vertices)
            if techo > base + 0.002:
                raise SystemExit(f"{unidad.name} toca el mueble por encima de su estante")
        if not any(abs(base - z) < 0.002 for z in alturas):
            raise SystemExit(f"{unidad.name} no apoya en ningún estante: z={base:.4f}")
    print("la estantería queda con cinco estantes parejos y sus unidades apoyadas")


def main() -> None:
    configurar()
    parejar()
    verificar()
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        destino = RAIZ / "reports/parejar-estanteria-n.blend"
        destino.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
        print(f"prueba guardada en {destino}")


if __name__ == "__main__":
    main()
