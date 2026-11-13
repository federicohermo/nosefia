"""Pone la góndola alta en cuatro piezas contra las paredes este y norte, y corre la baja.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/gondola_a_la_pared.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/gondola-a-la-pared.blend` y no modifica el `.blend` del repo.
Con `--aplicar`, guarda la fuente canónica en su lugar. Después corren
`separadores_de_prueba.py --aplicar`, `armar_atlas.py`, `exportar_modelo.py`, `disponer.py`,
`disponer_prueba.py`, `integrar_modelo.py`, `actualizar_apoyos.py`, `extraer_mallas.gd`, y
`hornear.py` con y sin `--sin-luz`.

## Qué cambia

- **`A` pasa de una góndola de dos caras largas y dos cabeceras a cuatro estanterías de un solo
  frente**, de espaldas a una pared. Cada una conserva su nombre —`este`, `oeste`, `sur`,
  `norte`—, que ya no dice hacia dónde mira. Primero las cuatro van contra la pared este, de sur
  a norte: cabecera sur, las dos caras largas y cabecera norte, con el mismo hueco entre piezas.
- **La cabecera norte (la de grilla) se muda a la pared norte**, mirando al sur, a
  `SEPARACION_DE_LA_PUERTA` del marco de la puerta del depósito. Las otras tres —las dos caras
  largas y la cabecera sur (la de panel perforado)— quedan una junto a la otra, con `ENTRE_PIEZAS`
  entre ellas, y su extremo sur alineado con el de `B`: se leen los dos extremos del `.blend`.
- **Cada cara larga pasa a medir `LARGO_DE_LA_CARA`.** Cada grupo de vértices viaja entero hacia
  el medio de la pieza y lo que hay entre dos grupos se encoge. En una cara encogida las UV de
  las dos capas conservan la escala de la textura. La baranda de alambre se escala a lo largo.
- **`B` queda entera y se corre** hasta que su pasillo con el frente de las caras largas mida
  `PASILLO_CON_B`. Las mesas y las sillas no se mueven.
- **Las cabeceras y todo `B` llevan sus unidades rígidas** con su pieza.
- **Las caras largas vuelven a repartirse** con el acomodador, sólo en sus ocho estantes: el
  estante mide menos y entran menos unidades.

## Por qué se mueven dos mallas

El modificador `Muebles` de `A` arma su geometría uniendo los cuatro `-noimp`: la malla que ve
Godot sale de ellos, y la de `A` en sí la lee el acomodador. Las dos se mueven con la misma
cuenta, y al final el script comprueba que sigan siendo la misma geometría.

**El origen de `A` no se mueve**: en Godot `gondolanueva/StaticBody3D` es el estante de todo el
local y `Contenido` cuelga de ahí.

## Lo que cuesta

0 triángulos, 0 materiales y 0 texturas adicionales. Es idempotente: cada paso sale de la
posición de ahora y no mueve nada si ya está donde va.
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
sys.path.insert(0, str(RAIZ / ".claude/scripts/blender"))
import acomodar  # noqa: E402
from achicar_gondola_b import _uv_conservada  # noqa: E402
from espejar_salon import PARED_ESTE_X  # noqa: E402
from lib.consola import configurar  # noqa: E402
from lib.gondola_a_la_pared import Recorrido, agrupar, repartir_en_la_pared  # noqa: E402
from lib.reparto import ESTANTES, PRODUCTOS, partes  # noqa: E402

#: Lo que mide cada cara larga de `A`, de punta a punta de su malla.
LARGO_DE_LA_CARA = 2.28
#: El pasillo entre el borde este de `B` y el frente de las caras largas de `A`.
PASILLO_CON_B = 2.30
#: Lo libre de la pared este, de sur a norte: desde el marco de la puerta del baño hasta la puerta
#: del depósito, sin contar lo que ocupan sus jambas.
PARED_DESDE_Y = -0.6
PARED_HASTA_Y = 6.9
#: De sur a norte, contra la pared este, antes de mudar la cabecera norte.
ORDEN = ("este", "oeste", "sur", "norte")
LATERALES = ("este", "oeste")
#: Cómo gira cada pieza sobre su centro para quedar mirando al oeste, como una matriz de 2x2 sobre
#: `(x, y)`. Exactas, porque un giro calculado con senos deja ruido en cada vértice.
GIROS = {
    "sur": ((0.0, 1.0), (-1.0, 0.0)),
    "este": ((-1.0, 0.0), (0.0, -1.0)),
    "oeste": ((1.0, 0.0), (0.0, 1.0)),
    "norte": ((0.0, -1.0), (1.0, 0.0)),
}
#: Cómo gira la cabecera sur para pasar de mirar al oeste a mirar al sur (+90 grados).
GIRO_A_SUR = ((0.0, -1.0), (1.0, 0.0))
#: La cara interior del zócalo de la pared norte, medida con un rayo como la de la pared este.
PARED_NORTE_Y = 7.854
#: Lo que queda libre entre la pieza de la pared norte y el marco de la puerta del depósito.
SEPARACION_DE_LA_PUERTA = 0.45
#: Lo menos que le queda a esa pieza hasta la madera que cubre la pared norte, al oeste.
LIBRE_JUNTO_A_LA_MADERA = 0.2
MADERA = "mueble_continuo"
#: La pieza que va contra la pared norte.
PIEZA_DE_LA_PARED_NORTE = "norte"
#: Lo menos que puede quedar entre las tres piezas de la pared este y la puerta del baño.
LIBRE_JUNTO_A_LA_PUERTA_DEL_BANO = 0.3
#: Lo que queda entre dos piezas vecinas de la pared este.
ENTRE_PIEZAS = 0.02
#: De sur a norte, las piezas que quedan contra la pared este.
GRUPO_DE_LA_PARED_ESTE = ("este", "oeste", "sur")
MARCO_DE_LA_PUERTA = "marco_puerta_deposito-col"
MARCO_DEL_BANO = "bano_marco_entrada"
A = "gondolanueva-col"
B = "gondolanueva2-col"
#: Un vértice a menos de esto de otro es el mismo punto.
DECIMALES = 4


def _objeto(nombre: str):
    objeto = bpy.data.objects.get(nombre)
    if objeto is None:
        raise SystemExit(f"falta el objeto {nombre}; no se guardó nada")
    return objeto


def _puntos(objeto) -> list[Vector]:
    return [objeto.matrix_world @ v.co for v in objeto.data.vertices]


def _caja(puntos: list[Vector]) -> tuple[Vector, Vector]:
    return (
        Vector([min(p[i] for p in puntos) for i in range(3)]),
        Vector([max(p[i] for p in puntos) for i in range(3)]),
    )


def _medio_en_y(puntos: list[Vector]) -> float:
    minimo, maximo = _caja(puntos)
    return (minimo.y + maximo.y) / 2


def _clave(puntos: list[Vector]) -> tuple:
    return tuple(sorted(tuple(round(c, DECIMALES) for c in p) for p in puntos))


class Pieza:
    """Una de las cuatro partes de `A`: su malla suelta, su baranda y sus vértices en la malla de A."""

    def __init__(self, nombre: str) -> None:
        self.nombre = nombre
        self.cuerpo = _objeto(f"gondolanueva-{nombre}-noimp")
        self.baranda = bpy.data.objects.get(f"gondolanueva-{nombre}-frente")
        self.vertices: set[int] = set()
        self.matriz = Matrix.Identity(4)


def _piezas() -> dict[str, Pieza]:
    """Las piezas de `A`, con las caras de su malla repartidas por coincidencia exacta.

    La malla de `A` y los `-noimp` son la misma geometría, y cada cara es una isla: la cara de una
    cae en la otra con los mismos cuatro puntos. Un corte por posición mezcla las caras de las
    puntas de una cara larga con las de una cabecera.
    """
    gondola = _objeto(A)
    piezas = {nombre: Pieza(nombre) for nombre in ORDEN}
    dueña: dict[tuple, str] = {}
    for nombre, pieza in piezas.items():
        malla, mundo = pieza.cuerpo.data, pieza.cuerpo.matrix_world
        for cara in malla.polygons:
            dueña[_clave([mundo @ malla.vertices[i].co for i in cara.vertices])] = nombre
    malla, mundo = gondola.data, gondola.matrix_world
    usos: dict[int, set[str]] = {}
    for cara in malla.polygons:
        clave = _clave([mundo @ malla.vertices[i].co for i in cara.vertices])
        if clave not in dueña:
            raise SystemExit("una cara de A no está en ninguno de sus -noimp; no se guardó nada")
        for i in cara.vertices:
            usos.setdefault(i, set()).add(dueña[clave])
    if any(len(piezas_del_vertice) != 1 for piezas_del_vertice in usos.values()):
        raise SystemExit("un vértice de A es de dos piezas; no se guardó nada")
    for indice, (nombre,) in ((i, tuple(s)) for i, s in usos.items()):
        piezas[nombre].vertices.add(indice)
    if sum(len(p.vertices) for p in piezas.values()) != len(malla.vertices):
        raise SystemExit("A tiene vértices sueltos; no se guardó nada")
    return piezas


def _mover_vertices(objeto, indices, funcion, uv_conservadas: bool) -> None:
    """Lleva cada vértice de `indices` a `funcion(punto del mundo)`. Si `uv_conservadas`, las
    caras que se estiran recalculan sus UV con la misma escala de textura, en todas las capas."""
    bm = bmesh.new()
    bm.from_mesh(objeto.data)
    mundo, inversa = objeto.matrix_world, objeto.matrix_world.inverted()
    viejas = {v.index: tuple(v.co) for v in bm.verts}
    corrimiento: dict[int, Vector] = {}
    for v in bm.verts:
        if indices is None or v.index in indices:
            nuevo = funcion(mundo @ v.co)
            corrimiento[v.index] = nuevo - mundo @ v.co
            v.co = inversa @ nuevo
    if uv_conservadas:
        capas = list(bm.loops.layers.uv.values())
        for cara in bm.faces:
            valores = [corrimiento.get(v.index, Vector()) for v in cara.verts]
            estirada = any((a - b).length > 1e-5 for a in valores for b in valores)
            if estirada:
                for capa in capas:
                    _uv_conservada(bm, cara, capa, viejas)
    bm.to_mesh(objeto.data)
    bm.free()
    objeto.data.update()


def _acortar(pieza: Pieza, gondola) -> None:
    """Acorta una cara larga y su baranda a `LARGO_DE_LA_CARA`."""
    ys = [p.y for p in _puntos(pieza.cuerpo)]
    recorrido = Recorrido(agrupar(ys), (max(ys) - min(ys)) - LARGO_DE_LA_CARA)

    def acortada(punto: Vector) -> Vector:
        return Vector((punto.x, recorrido(punto.y), punto.z))

    _mover_vertices(pieza.cuerpo, None, acortada, True)
    _mover_vertices(gondola, pieza.vertices, acortada, True)
    if pieza.baranda is not None:
        desde, hasta = (f(p.y for p in _puntos(pieza.baranda)) for f in (min, max))
        escala = (recorrido(hasta) - recorrido(desde)) / (hasta - desde)

        def escalada(punto: Vector) -> Vector:
            return Vector((punto.x, recorrido(desde) + (punto.y - desde) * escala, punto.z))

        _mover_vertices(pieza.baranda, None, escalada, True)


def _rotar(giro_2x2: tuple, centro: Vector) -> Matrix:
    (a, b), (c, d) = giro_2x2
    giro = Matrix(((a, b, 0.0), (c, d, 0.0), (0.0, 0.0, 1.0))).to_4x4()
    return Matrix.Translation(centro) @ giro @ Matrix.Translation(-centro)


def _giro(nombre: str, centro: Vector) -> Matrix:
    return _rotar(GIROS[nombre], centro)


def _plan(piezas: dict[str, Pieza]) -> None:
    """La matriz de cada pieza: su giro y su traslado hasta la pared, con el mismo hueco entre
    una y la siguiente."""
    giradas = {}
    for nombre, pieza in piezas.items():
        puntos = _puntos(pieza.cuerpo)
        minimo, maximo = _caja(puntos)
        giro = _giro(nombre, (minimo + maximo) / 2)
        giradas[nombre] = (giro, _caja([giro @ p for p in puntos]))
    largos = [giradas[n][1][1].y - giradas[n][1][0].y for n in ORDEN]
    desde = repartir_en_la_pared(largos, PARED_DESDE_Y, PARED_HASTA_Y)
    for nombre, y in zip(ORDEN, desde):
        giro, (minimo, maximo) = giradas[nombre]
        traslado = Vector((PARED_ESTE_X - maximo.x, y - minimo.y, 0.0))
        piezas[nombre].matriz = Matrix.Translation(traslado) @ giro


def _mover_pieza(pieza: Pieza, matriz: Matrix, gondola) -> None:
    """Lleva una pieza entera —su malla suelta, sus vértices en la malla de `A` y su baranda—."""

    def movida(punto: Vector) -> Vector:
        return matriz @ punto

    _mover_vertices(pieza.cuerpo, None, movida, False)
    _mover_vertices(gondola, pieza.vertices, movida, False)
    if pieza.baranda is not None:
        _mover_vertices(pieza.baranda, None, movida, False)


def _unidades_de(prefijos: tuple[str, ...]) -> list:
    return [
        o for o in bpy.data.objects
        if str(o.get("tanda", "")).startswith(prefijos)
    ]


def _mover_unidades(prefijos: tuple[str, ...], matriz: Matrix) -> int:
    """Las unidades de unos estantes viajan rígidas. Se leen las matrices de antes de mover."""
    plan = [(o, matriz @ o.matrix_world) for o in _unidades_de(prefijos)]
    for objeto, nueva in plan:
        escala = objeto.scale.copy()
        objeto.matrix_world = nueva
        objeto.scale = escala
    return len(plan)


def _nivel_de(tanda: str) -> int:
    return partes(tanda.split("/")[0])[2]


def _coleccion_del_nivel(letra: str, nivel: int):
    """La subcolección de `guia` donde el artista guarda las copias de ese nivel del mueble."""
    prefijo = f"{letra} - Estante {nivel + 1}"
    for coleccion in bpy.data.collections:
        if coleccion.name.startswith(prefijo):
            return coleccion
    raise SystemExit(f"falta la colección «{prefijo}»")


def _repartir_las_caras_largas(piezas: dict[str, Pieza]) -> int:
    """Pone las unidades de las caras largas sobre su chapa nueva, con menos columnas.

    El acomodador sólo dice cuántas columnas entran y dónde. Cada unidad conserva su profundidad,
    su altura y su giro de antes, llevados a la pieza nueva: el acomodador entero las pondría
    pegadas al labio y cambiaría cantidades de tandas que otros scripts ajustaron después.
    """
    estantes = {c: t for c, t in ESTANTES.items() if c.startswith(("A.este.", "A.oeste."))}
    fuentes = {p.objeto for p in PRODUCTOS}
    antes = {(str(o["tanda"]), str(o["fila"])): o.matrix_world.copy()
             for o in _unidades_de(("A.este.", "A.oeste."))}
    for objeto in _unidades_de(("A.este.", "A.oeste.")):
        if objeto.name in fuentes:
            for clave in ("tanda", "fila", "orden", "producto", "fija"):
                if clave in objeto:
                    del objeto[clave]
        else:
            bpy.data.objects.remove(objeto, do_unlink=True)
    envases = {p.clave: acomodar.envase_de(p, bpy.data.objects[p.objeto]) for p in PRODUCTOS}
    resumen = {"tandas": 0, "unidades": 0, "choques": [], "cortas": [], "entradas": {}}
    acomodar.acomodar_mueble("A", envases, resumen, estantes_declarados=estantes)
    if resumen["choques"]:
        raise SystemExit("choques en las caras largas: " + "; ".join(resumen["choques"]))
    for objeto in _unidades_de(("A.este.", "A.oeste.")):
        tanda = str(objeto["tanda"])
        vieja = antes[(tanda, str(objeto["fila"]))]
        destino = piezas[partes(tanda.split("/")[0])[1]].matriz @ vieja
        corrimiento = _medio_en_y(_puntos(objeto)) - _medio_en_y(
            [destino @ v.co for v in objeto.data.vertices]
        )
        escala = objeto.scale.copy()
        objeto.matrix_world = Matrix.Translation((0.0, corrimiento, 0.0)) @ destino
        objeto.scale = escala
        if objeto.name not in fuentes:
            for coleccion in list(objeto.users_collection):
                coleccion.objects.unlink(objeto)
            _coleccion_del_nivel("A", _nivel_de(tanda)).objects.link(objeto)
    bpy.context.view_layer.update()
    _verificar_apoyos(estantes)
    return resumen["unidades"]


def _verificar_apoyos(estantes: dict) -> None:
    """Cada estante tiene que aceptar sus unidades donde están: apoyadas y sin tocar el mueble."""
    objeto, bm, medidos = acomodar.medir("A")
    arbol = BVHTree.FromBMesh(bm)
    por_estante: dict[str, list] = {}
    for unidad in _unidades_de(("A.este.", "A.oeste.")):
        por_estante.setdefault(str(unidad["tanda"]).split("/")[0], []).append(unidad)
    for clave, unidades in sorted(por_estante.items()):
        posiciones = [(u, u.matrix_world.copy()) for u in unidades]
        desplazamiento = acomodar.medir_encaje(medidos[clave], bm, arbol, [], posiciones)
        if desplazamiento is None or abs(desplazamiento) > 1e-6:
            raise SystemExit(f"{clave}: las unidades no apoyan donde quedaron ({desplazamiento})")
    bm.free()


def _a_la_pared() -> bool:
    """Si las caras largas ya están contra la pared este: no cambia aunque la cabecera sur se mude."""
    minimo, _ = _caja(_puntos(_objeto("gondolanueva-este-noimp")))
    return minimo.x > PARED_ESTE_X - 1.0


def poner_a() -> bool:
    gondola = _objeto(A)
    if _a_la_pared():
        print("A ya está contra la pared; no cambia nada")
        return False
    piezas = _piezas()
    for nombre in LATERALES:
        _acortar(piezas[nombre], gondola)
    _plan(piezas)
    rigidas = sum(_mover_unidades((f"A.{n}.",), piezas[n].matriz) for n in ("sur", "norte"))
    for pieza in piezas.values():
        _mover_pieza(pieza, pieza.matriz, gondola)
    bpy.context.view_layer.update()
    repartidas = _repartir_las_caras_largas(piezas)
    for nombre in ORDEN:
        minimo, maximo = _caja(_puntos(piezas[nombre].cuerpo))
        print(
            f"{nombre}: x[{minimo.x:.3f}, {maximo.x:.3f}] y[{minimo.y:.3f}, {maximo.y:.3f}]"
        )
    print(f"{rigidas} unidades de cabecera movidas; {repartidas} unidades en las caras largas")
    return True


def _en_la_pared_este(pieza: Pieza) -> bool:
    return _caja(_puntos(pieza.cuerpo))[1].x > PARED_ESTE_X - 0.5


def devolver_a_la_pared_este() -> bool:
    """Lleva a la pared este, mirando al oeste, las piezas del grupo que están en otra pared.

    Quedan al final del grupo: `compactar_las_piezas_de_la_pared_este` las acomoda después."""
    gondola = _objeto(A)
    piezas = _piezas()
    movido = False
    for nombre in GRUPO_DE_LA_PARED_ESTE:
        pieza = piezas[nombre]
        if _en_la_pared_este(pieza):
            continue
        puntos = _puntos(pieza.cuerpo)
        minimo, maximo = _caja(puntos)
        giro = _rotar(GIROS["sur"], (minimo + maximo) / 2)
        _, girada = _caja([giro @ p for p in puntos])
        final = max(
            _caja(_puntos(piezas[n].cuerpo))[1].y
            for n in GRUPO_DE_LA_PARED_ESTE
            if _en_la_pared_este(piezas[n])
        )
        girado_min, _ = _caja([giro @ p for p in puntos])
        matriz = Matrix.Translation(
            Vector((PARED_ESTE_X - girada.x, final + ENTRE_PIEZAS - girado_min.y, 0.0))
        ) @ giro
        _mover_pieza(pieza, matriz, gondola)
        _mover_unidades((f"A.{nombre}.",), matriz)
        print(f"{nombre} vuelve a la pared este")
        movido = True
    return movido


def mudar_a_la_pared_norte() -> bool:
    """Pone la pieza de la pared norte de espaldas a ella, mirando al sur, a
    `SEPARACION_DE_LA_PUERTA` del marco de la puerta del depósito."""
    gondola = _objeto(A)
    pieza = _piezas()[PIEZA_DE_LA_PARED_NORTE]
    puntos = _puntos(pieza.cuerpo)
    minimo, maximo = _caja(puntos)
    marco, _ = _caja(_puntos(_objeto(MARCO_DE_LA_PUERTA)))
    madera = _caja(_puntos(_objeto(MADERA)))[1].x
    giro = Matrix.Identity(4)
    if _en_la_pared_este(pieza):
        giro = _rotar(GIRO_A_SUR, (minimo + maximo) / 2)
    _, girada = _caja([giro @ p for p in puntos])
    traslado = Vector((marco.x - SEPARACION_DE_LA_PUERTA - girada.x, PARED_NORTE_Y - girada.y, 0.0))
    if giro == Matrix.Identity(4) and traslado.length < 1e-4:
        print("la cabecera de la pared norte ya está donde va; no cambia nada")
        return False
    matriz = Matrix.Translation(traslado) @ giro
    _mover_pieza(pieza, matriz, gondola)
    unidades = _mover_unidades((f"A.{PIEZA_DE_LA_PARED_NORTE}.",), matriz)
    minimo, maximo = _caja(_puntos(pieza.cuerpo))
    if minimo.x - madera < LIBRE_JUNTO_A_LA_MADERA:
        raise SystemExit(f"la pieza de la pared norte queda a {minimo.x - madera:.3f} de la madera")
    print(
        f"{PIEZA_DE_LA_PARED_NORTE}: x[{minimo.x:.3f}, {maximo.x:.3f}] y[{minimo.y:.3f}, "
        f"{maximo.y:.3f}], {marco.x - maximo.x:.3f} del marco y {minimo.x - madera:.3f} de la "
        f"madera; {unidades} unidades"
    )
    return True


def compactar_las_piezas_de_la_pared_este() -> bool:
    """Pone la cara este, la cara oeste y la cabecera sur una junto a la otra, con
    `ENTRE_PIEZAS` entre ellas, y el extremo sur del grupo alineado con el de `B`."""
    gondola = _objeto(A)
    piezas = _piezas()
    borde = _caja(_puntos(_objeto(B)))[0].y
    movido = False
    for nombre in GRUPO_DE_LA_PARED_ESTE:
        minimo, maximo = _caja(_puntos(piezas[nombre].cuerpo))
        corrimiento = borde - minimo.y
        if abs(corrimiento) > 1e-4:
            matriz = Matrix.Translation((0.0, corrimiento, 0.0))
            _mover_pieza(piezas[nombre], matriz, gondola)
            _mover_unidades((f"A.{nombre}.",), matriz)
            movido = True
        borde = maximo.y + (corrimiento if abs(corrimiento) > 1e-4 else 0.0) + ENTRE_PIEZAS
    if movido:
        print("las piezas de la pared este quedaron juntas y alineadas con B")
    else:
        print("las piezas de la pared este ya están juntas y alineadas con B; no cambia nada")
    return movido


def _verificar_la_pared_este() -> None:
    """Las piezas vecinas no se pisan, sus unidades quedan adentro de su pieza y el grupo no queda
    pegado a la puerta del baño."""
    piezas = _piezas()
    rangos = {}
    for nombre in GRUPO_DE_LA_PARED_ESTE:
        minimo, maximo = _caja(_puntos(piezas[nombre].cuerpo))
        rangos[nombre] = (minimo.y, maximo.y)
        for unidad in _unidades_de((f"A.{nombre}.",)):
            desde, hasta = (f(p.y for p in _puntos(unidad)) for f in (min, max))
            if desde < minimo.y - 1e-3 or hasta > maximo.y + 1e-3:
                raise SystemExit(f"una unidad de {nombre} se sale de su pieza: {unidad.name}")
    for a, b in zip(GRUPO_DE_LA_PARED_ESTE, GRUPO_DE_LA_PARED_ESTE[1:]):
        hueco = rangos[b][0] - rangos[a][1]
        if abs(hueco - ENTRE_PIEZAS) > 1e-3:
            raise SystemExit(f"entre {a} y {b} hay {hueco:.4f} y no {ENTRE_PIEZAS}")
    marco = _caja(_puntos(_objeto(MARCO_DEL_BANO)))[1].y
    libre = rangos[GRUPO_DE_LA_PARED_ESTE[0]][0] - marco
    if libre < LIBRE_JUNTO_A_LA_PUERTA_DEL_BANO:
        raise SystemExit(f"el grupo queda a {libre:.3f} de la puerta del baño")
    print(f"grupo de la pared este: {libre:.3f} de la puerta del baño")


def _verificar_mallas() -> None:
    """La malla de `A` y la que arman sus `-noimp` tienen que seguir siendo la misma."""
    gondola = _objeto(A)
    evaluada = gondola.evaluated_get(bpy.context.evaluated_depsgraph_get())
    malla = evaluada.to_mesh()
    try:
        de_la_union = sorted(
            _clave([evaluada.matrix_world @ malla.vertices[i].co for i in c.vertices])
            for c in malla.polygons
        )
    finally:
        evaluada.to_mesh_clear()
    propia = sorted(
        _clave([gondola.matrix_world @ gondola.data.vertices[i].co for i in c.vertices])
        for c in gondola.data.polygons
    )
    if de_la_union != propia:
        raise SystemExit("la malla de A y la unión de sus -noimp ya no coinciden")


def correr_b() -> bool:
    """Corre `B` hasta que su pasillo con las caras largas de `A` mida `PASILLO_CON_B`.

    Se calcula desde la posición de ahora, y las unidades se llevan a su matriz de destino: unas
    cuelgan de `B` y se mueven solas, y otras conservan un padre histórico y no.
    """
    bpy.context.view_layer.update()
    piezas = _piezas()
    frente, _ = _caja([p for n in LATERALES for p in _puntos(piezas[n].cuerpo)])
    _, borde = _caja(_puntos(_objeto(B)))
    corrimiento = frente.x - PASILLO_CON_B - borde.x
    if abs(corrimiento) < 1e-4:
        print("B ya está a su distancia de A; no cambia nada")
        return False
    unidades = _unidades_de(("B.",))
    destino = [(o, Matrix.Translation((corrimiento, 0.0, 0.0)) @ o.matrix_world) for o in unidades]
    gondola = _objeto(B)
    gondola.location.x += corrimiento
    bpy.context.view_layer.update()
    for objeto, matriz in destino:
        escala = objeto.scale.copy()
        objeto.matrix_world = matriz
        objeto.scale = escala
    print(f"B corrida {corrimiento:+.4f} con {len(unidades)} unidades")
    return True


def main() -> None:
    configurar()
    poner_a()
    devolver_a_la_pared_este()
    mudar_a_la_pared_norte()
    compactar_las_piezas_de_la_pared_este()
    correr_b()
    bpy.context.view_layer.update()
    _verificar_la_pared_este()
    _verificar_mallas()
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        destino = RAIZ / "reports/gondola-a-la-pared.blend"
        destino.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
        print(f"prueba guardada en {destino}")


if __name__ == "__main__":
    main()
