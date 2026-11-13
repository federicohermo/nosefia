"""Deja la estantería empotrada de no comestibles con cinco huecos iguales en cada columna.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1         --python .claude/scripts/blender/parejar_estanteria_n.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/parejar-estanteria-n.blend` y no modifica el `.blend` del
repo. Con `--aplicar`, guarda la fuente canónica en su lugar. Después va la cadena: `disponer.py`
y `disponer_prueba.py`, `exportar_modelo.py`, `integrar_modelo.py`, `actualizar_apoyos.py` y
`hornear.py`.

## Por qué

Las dos columnas de `gondolanueva-col.001` no coincidían: la izquierda tenía cinco estantes a
alturas desparejas y la derecha seis. Y con los estantes parejos entre sí, los huecos no se veían
iguales: el de arriba tenía aire de más contra el techo del mueble.

## Qué cambia

- **Las dos columnas quedan con `NIVELES` estantes cada una y `NIVELES` huecos iguales.** El de
  abajo es el piso del nicho y no se mueve; el alto interior, del piso a la cara de abajo de la
  tapa, se reparte en cinco huecos del mismo alto descontando el grosor de las cuatro chapas.
  Los estantes que sobran se borran.
- **Cada estante lleva su portaprecios** (`estanteria_precios`), y los de los estantes que se
  borran se borran.
- **Cada producto conserva su columna.** El de abajo de cada columna (Poético, Actroncito)
  ocupa los tres estantes de abajo: dos referencias fijas y, arriba de ellas, su principal. El de
  arriba (Duronga, Durextra) ocupa los dos de arriba: su principal y una referencia fija. Las
  unidades viajan rígidas con su estante, se renombran `N.sur.<nivel>/<columna>` y las
  referencias que faltan se copian de otra del mismo producto.
- El marco, el hueco en la madera, el panel y las tapas no cambian.

## Lo que cuesta

0 triángulos nuevos, 0 materiales y 0 texturas. Es idempotente: si los estantes y las tandas ya
están donde van, no cambia nada.
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
from lib.estanteria_pareja import alturas_con_huecos_iguales  # noqa: E402
from lib.reparto import PRODUCTOS  # noqa: E402

ESTANTERIA = "gondolanueva-col.001"
PRECIOS = "estanteria_precios"
#: Cuántos estantes lleva cada columna, con el piso del nicho.
NIVELES = 5
#: Qué lleva cada nivel, como `(nivel, es fija)`: el producto de abajo ocupa los tres primeros, con
#: su principal en el de arriba de los tres, y el de arriba los dos últimos, con su principal en el
#: de abajo de los dos.
NIVELES_DE_ABAJO = ((0, True), (1, True), (2, False))
NIVELES_DE_ARRIBA = ((3, False), (4, True))
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


def _techo(bm, mundo: Matrix) -> float:
    """La cara de abajo de la tapa: la chapa fina y ancha que cierra el nicho por arriba."""
    bajos = []
    for isla in _islas(bm):
        minimo, maximo = _caja(isla, mundo)
        if maximo.z - minimo.z < GROSOR_MAXIMO and maximo.x - minimo.x > ANCHO_DE_UNA_COLUMNA[1]:
            bajos.append(minimo.z)
    if not bajos:
        raise SystemExit("la estantería no tiene tapa")
    return max(bajos)


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


def _plan_de_las_unidades(
    columna: int, tandas: dict[int, list]
) -> tuple[dict[int, int], list[tuple[int, int]], list[int]]:
    """Qué nivel viejo pasa a qué nivel nuevo en una columna, qué referencias se copian y qué
    niveles se borran.

    El producto de abajo conserva su principal y llena los otros dos niveles de abajo con
    referencias fijas; el de arriba conserva su principal y una fija. Una fija que falta se copia
    de la primera que se conserva, y las que sobran se borran.
    """
    por_producto: dict[str, list[int]] = {}
    for nivel in sorted(tandas):
        por_producto.setdefault(str(tandas[nivel][0]["producto"]), []).append(nivel)
    if len(por_producto) != 2:
        raise SystemExit(f"la columna {columna} no lleva dos productos: {sorted(por_producto)}")
    de_abajo, de_arriba = sorted(por_producto.values(), key=lambda niveles: niveles[0])
    mover: dict[int, int] = {}
    copiar: list[tuple[int, int]] = []
    borrar: list[int] = []
    for niveles, destinos in ((de_abajo, NIVELES_DE_ABAJO), (de_arriba, NIVELES_DE_ARRIBA)):
        principales = [n for n in niveles if not bool(tandas[n][0]["fija"])]
        fijas = [n for n in niveles if bool(tandas[n][0]["fija"])]
        if len(principales) != 1 or not fijas:
            raise SystemExit(f"la columna {columna} no tiene una principal y una fija por producto")
        mover[principales[0]] = next(nivel for nivel, fija in destinos if not fija)
        molde = fijas[0]
        for destino in (nivel for nivel, fija in destinos if fija):
            if fijas:
                mover[fijas.pop(0)] = destino
            else:
                copiar.append((molde, destino))
        borrar += fijas
    return mover, copiar, borrar


def _copiar(unidad, nuevo: int, columna: int, corrimiento: float):
    copia = unidad.copy()
    for coleccion in unidad.users_collection:
        coleccion.objects.link(copia)
    escala = unidad.scale.copy()
    copia.matrix_world = Matrix.Translation((0.0, 0.0, corrimiento)) @ unidad.matrix_world
    copia.scale = escala
    copia["tanda"] = f"N.sur.{nuevo}/{columna}"
    return copia


def _tandas_por_columna() -> dict[int, dict[int, list]]:
    por_columna: dict[int, dict[int, list]] = {0: {}, 1: {}}
    for unidad in _unidades_de_la_estanteria():
        nivel, columna = str(unidad["tanda"]).removeprefix("N.sur.").split("/")
        por_columna[int(columna)].setdefault(int(nivel), []).append(unidad)
    return por_columna


def _ya_estan_las_tandas(por_columna: dict[int, dict[int, list]]) -> bool:
    for columna in (0, 1):
        tandas = por_columna[columna]
        if sorted(tandas) != list(range(NIVELES)):
            return False
        for destinos in (NIVELES_DE_ABAJO, NIVELES_DE_ARRIBA):
            productos = {str(tandas[nivel][0]["producto"]) for nivel, _ in destinos}
            if len(productos) != 1:
                return False
            if any(bool(tandas[nivel][0]["fija"]) != fija for nivel, fija in destinos):
                return False
    return True


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
    techo = _techo(bm, mundo)
    minimo, maximo = _caja(estantes[0][1][1], mundo)
    grosor = maximo.z - minimo.z
    nuevas = alturas_con_huecos_iguales(piso, techo, grosor, NIVELES)
    por_columna = _tandas_por_columna()
    ya = _ya_estan_las_tandas(por_columna) and all(
        len(estantes[c]) == NIVELES
        and all(abs(e[0] - z) < IGUAL for e, z in zip(estantes[c], nuevas))
        for c in (0, 1)
    )
    if ya:
        print("la estantería ya tiene sus cinco huecos iguales y sus tandas; no cambia nada")
        bm.free()
        return False
    viejas = {c: [e[0] for e in estantes[c]] for c in (0, 1)}
    print(
        f"piso {piso:.3f}, tapa {techo:.3f}, chapa {grosor:.3f}; estantes nuevos: "
        + ", ".join(f"{z:.3f}" for z in nuevas)
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
    borrar_precios = []
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
            borrar_precios.append(isla)
        else:
            _mover_z(bp, isla, nuevas[nivel] - viejas[c][nivel])
    _borrar(bp, borrar_precios)
    bp.to_mesh(precios.data)
    bp.free()
    precios.data.update()

    # Las unidades.
    fuentes = {p.objeto for p in PRODUCTOS}
    movidas = borradas = copiadas = 0
    for c in (0, 1):
        mover, copiar, borrar = _plan_de_las_unidades(c, por_columna[c])
        for viejo, unidades in sorted(por_columna[c].items()):
            if viejo in borrar:
                for unidad in unidades:
                    if unidad.name in fuentes:
                        raise SystemExit(f"se iba a borrar la unidad fuente {unidad.name}")
                    bpy.data.objects.remove(unidad, do_unlink=True)
                    borradas += 1
                continue
            nuevo = mover[viejo]
            for unidad in unidades:
                escala = unidad.scale.copy()
                unidad.matrix_world = (
                    Matrix.Translation((0.0, 0.0, nuevas[nuevo] - viejas[c][viejo]))
                    @ unidad.matrix_world
                )
                unidad.scale = escala
                unidad["tanda"] = f"N.sur.{nuevo}/{c}"
                movidas += 1
        for molde, nuevo in copiar:
            for unidad in por_columna[c][molde]:
                _copiar(unidad, nuevo, c, nuevas[nuevo] - viejas[c][molde])
                copiadas += 1
    print(f"{movidas} unidades movidas, {copiadas} copiadas y {borradas} borradas")
    bpy.context.view_layer.update()
    return True


def verificar() -> None:
    """Cada columna tiene cinco huecos iguales, las tandas están donde van, cada unidad apoya en su
    estante y entra en alto, y no queda ningún portaprecios sin estante."""
    estanteria = _objeto(ESTANTERIA)
    precios = _objeto(PRECIOS)
    mundo = estanteria.matrix_world
    bm = bmesh.new()
    bm.from_mesh(estanteria.data)
    estantes = _estantes(bm, mundo, mundo.translation.x)
    techo = _techo(bm, mundo)
    por_debajo = [[_caja(e[1], mundo)[0].z for e in estantes[c][1:]] for c in (0, 1)]
    bm.free()
    huecos_de_las_columnas = []
    for c in (0, 1):
        alturas = [e[0] for e in estantes[c]]
        if len(alturas) != NIVELES:
            raise SystemExit(f"la columna {c} tiene {len(alturas)} estantes")
        debajo_de_cada_chapa = por_debajo[c] + [techo]
        huecos = [b - a for a, b in zip(alturas, debajo_de_cada_chapa)]
        if max(huecos) - min(huecos) > IGUAL:
            raise SystemExit(f"la columna {c} no tiene huecos iguales: {huecos}")
        huecos_de_las_columnas.append(huecos)
    if any(abs(a - b) > IGUAL for a, b in zip(*huecos_de_las_columnas)):
        raise SystemExit("las dos columnas no tienen los mismos huecos")
    if any(abs(a[0] - b[0]) > IGUAL for a, b in zip(estantes[0], estantes[1])):
        raise SystemExit("las dos columnas no están a las mismas alturas")
    alturas = [e[0] for e in estantes[0]]
    huecos = huecos_de_las_columnas[0]
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
    if not _ya_estan_las_tandas(_tandas_por_columna()):
        raise SystemExit("las tandas no están en los niveles que van")
    caras = [(mundo @ v.co) for v in estanteria.data.vertices]
    arbol = BVHTree.FromPolygons(caras, [list(p.vertices) for p in estanteria.data.polygons])
    for unidad in _unidades_de_la_estanteria():
        puntos = [unidad.matrix_world @ v.co for v in unidad.data.vertices]
        base = min(p.z for p in puntos)
        nivel = int(str(unidad["tanda"]).removeprefix("N.sur.").split("/")[0])
        if max(p.z for p in puntos) > base + huecos[nivel] - 0.005:
            raise SystemExit(f"{unidad.name} no entra en el alto de su hueco")
        propio = BVHTree.FromPolygons(puntos, [list(p.vertices) for p in unidad.data.polygons])
        for cara, _ in arbol.overlap(propio):
            techo_de_la_cara = max(caras[i].z for i in estanteria.data.polygons[cara].vertices)
            if techo_de_la_cara > base + 0.002:
                raise SystemExit(f"{unidad.name} toca el mueble por encima de su estante")
        if abs(base - alturas[nivel]) > 0.002:
            raise SystemExit(f"{unidad.name} no apoya en su estante: z={base:.4f}")
    print(f"la estantería queda con cinco huecos de {huecos[0]:.3f} m y sus unidades apoyadas")


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
