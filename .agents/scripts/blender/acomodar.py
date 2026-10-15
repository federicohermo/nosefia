"""El acomodador: lleva el reparto de `lib/reparto.py` al `.blend`. Corre adentro de Blender.

    blender <fuente>.blend --background --python .claude/scripts/blender/acomodar.py

**Cambia el `.blend` y lo guarda en su lugar**: sus texturas van por rutas relativas al archivo,
y guardarlo en otro lado las correría. Después van `exportar_modelo.py` y `blender/disponer.py`,
en ese orden.

## Qué hace, en orden

1. **Saca lo que arma él.** Las copias de la colección `guia` son suyas y se rehacen enteras, y
   a la unidad de cada producto se le sacan los `Array`: la tanda la dibujan las copias, y un
   `Array` prendido la dibujaría dos veces en el viewport.
2. **Palpa cada estante del reparto.** La chapa es la cara de arriba de una isla de la malla del
   mueble. El tramo útil se recorta contra lo que haya a los costados —**adentro de una pared la
   chapa sigue**, y medida sola da un tramo que no se puede llenar—, contra lo que haya detrás
   —**la chapa también sigue detrás del panel perforado**, hasta el centro de la góndola— y
   contra lo que haya encima: el labio de una cabecera, la tapa del panel sobre el estante de
   arriba, el dintel de la heladera.
3. **Pone cada tanda**: la unidad del producto en el primer lugar de su tanda, y una copia
   enlazada de ella en cada uno de los demás, en `guia`. Cada unidad y cada copia llevan escrito
   de qué tanda son, en qué fila y en qué orden: es lo que lee `disponer.py`. En la rampa de una
   cabecera, la unidad va echada hacia atrás, como la ponía el artista (`lib/gondola.py`).

Al final imprime un resumen —estantes, tandas, unidades, choques y filas cortas— y, si hay
choques, sale con error y no guarda.
"""

import math
import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import bpy  # type: ignore[import-not-found]
from mathutils import Matrix, Vector  # type: ignore[import-not-found]
from mathutils.bvhtree import BVHTree  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib.blender import COLECCION_DE_GUIA, es_un_array  # noqa: E402
from lib.gondola import (  # noqa: E402
    Envase,
    alto_en_la_rampa,
    centros,
    desplazamiento_que_entra,
    franja_libre,
    repartir,
    tanda,
)
from lib.reparto import (  # noqa: E402
    ESTANTES,
    HELADERAS,
    MUEBLES,
    PRODUCTOS,
    cara_de_isla,
    partes,
    producto,
    validar_reparto,
)

#: Lo que se le pide como mínimo a la fila de adelante de un producto: una caja entera, que es lo
#: más que una jornada le puede hacer faltar. La fila que sale es su cupo en el juego —cada lugar
#: es un casillero—. Si el estante no da para tanto, la fila lleva lo que entra y el resumen lo
#: dice.
FILA_DE_ADELANTE_PEDIDA = 8

#: Hacia dónde mira cada cara, en el mundo de Blender.
MIRA = {
    "oeste": Vector((-1.0, 0.0, 0.0)),
    "este": Vector((1.0, 0.0, 0.0)),
    "sur": Vector((0.0, -1.0, 0.0)),
    "norte": Vector((0.0, 1.0, 0.0)),
}

#: A qué altura sobre la chapa se tantean los costados del estante, en metros.
ALTURAS_DEL_TANTEO = (0.03, 0.12)

#: Cada cuánto se tantea lo que hay encima de la chapa, de adelante hacia atrás, en metros. El
#: borde de lo libre cae entre dos muestras: achicar deja un paso de más para no perderlo.
PASO_DEL_TANTEO = 0.001

#: Cuánto puede rozar la unidad más alta lo que tiene encima, en metros. Medido el 2026-09-29:
#: el Fernet God mide 0,4324 y la bandeja de arriba de la heladera deja 0,432; un roce de medio
#: milímetro contra el techo del mueble no se ve desde ningún lado.
ROCE_DE_ARRIBA = 0.001

#: Lo más arriba que puede estar una chapa de heladera: más arriba está el techo del mueble.
TECHO_DE_LA_HELADERA = 2.3

#: Cuánto puede separarse un vértice del plano de la chapa y seguir siendo de su cara de arriba.
TOLERANCIA_DEL_PLANO = 0.002

class Estante:
    """La chapa de un estante, medida: su marco y su tamaño."""

    def __init__(self, clave, isla, cara_de_arriba):
        self.clave = clave
        self.isla = isla
        self.caras = {c.index for c in isla}
        self.normal = cara_de_arriba.normal.copy()
        _, cara, _ = partes(clave)
        self.mira = MIRA[cara]
        adentro = -self.mira
        self.v = (adentro - self.normal * adentro.dot(self.normal)).normalized()
        self.u = (-self.mira).cross(Vector((0.0, 0.0, 1.0))).normalized()
        vertices = _vertices_del_plano(isla, cara_de_arriba)
        base = vertices[0]
        us = [(p - base).dot(self.u) for p in vertices]
        vs = [(p - base).dot(self.v) for p in vertices]
        self.origen = base + self.u * min(us) + self.v * min(vs)
        self.largo = max(us) - min(us)
        self.fondo = max(vs) - min(vs)

    def punto(self, u, v):
        return self.origen + self.u * u + self.v * v


def _islas(bm):
    bm.faces.ensure_lookup_table()
    visto = set()
    salida = []
    for cara in bm.faces:
        if cara.index in visto:
            continue
        pila = [cara]
        isla = []
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


def _cara_de_arriba(isla):
    """La cara más grande que mira hacia arriba, o `None` si la isla no es una chapa."""
    arriba = [c for c in isla if c.normal.z > 0.9 and c.calc_area() > 0.1]
    return max(arriba, key=lambda c: c.calc_area()) if arriba else None


def _vertices_del_plano(isla, cara):
    """Los vértices de la isla que están en el plano de su cara de arriba.

    **La chapa puede venir partida en varias caras**: la bandeja de abajo de la heladera son dos.
    Medir sólo la más grande da medio tramo.
    """
    punto = cara.verts[0].co
    salida = []
    for c in isla:
        if c.normal.dot(cara.normal) < 0.999:
            continue
        for vert in c.verts:
            if abs((vert.co - punto).dot(cara.normal)) < TOLERANCIA_DEL_PLANO:
                salida.append(vert.co.copy())
    return salida


def _es_panel(isla, objeto):
    """Si la isla lleva el panel perforado: es el cuerpo del mueble, y su tapa no es un estante."""
    for cara in isla:
        material = objeto.material_slots[cara.material_index].material
        if material is not None and "Panel" in material.name:
            return True
    return False


def medir(letra):
    """Los estantes de un mueble, por clave del reparto, con la malla en coordenadas del mundo.

    Devuelve también el `bmesh` para consultar los obstáculos sin modificar la malla.
    """
    objeto = bpy.data.objects[MUEBLES[letra]]
    bm = bmesh.new()
    bm.from_mesh(objeto.data)
    bm.transform(objeto.matrix_world)
    centro = objeto.matrix_world.translation
    por_cara = {}
    for isla in _islas(bm):
        cara = _cara_de_arriba(isla)
        if cara is None or _es_panel(isla, objeto):
            continue
        medio = cara.calc_center_median()
        if letra in HELADERAS and medio.z > TECHO_DE_LA_HELADERA:
            continue
        if letra in ("A", "B"):
            nombre = cara_de_isla(tuple(cara.normal), tuple(medio - centro))
        else:
            nombre = next(partes(c)[1] for c in ESTANTES if partes(c)[0] == letra)
        por_cara.setdefault(nombre, []).append((medio.z, isla, cara))
    estantes = {}
    for nombre, chapas in por_cara.items():
        chapas.sort(key=lambda t: t[0])
        for nivel, (_, isla, cara) in enumerate(chapas):
            clave = f"{letra}.{nombre}.{nivel}"
            estantes[clave] = Estante(clave, isla, cara)
    return objeto, bm, estantes


def tramo_util(estante, arbol, desde_v, hasta_v):
    """El tramo a lo largo que se puede llenar: la chapa recortada contra lo que tenga al costado.

    Se tantea desde el medio de la chapa hacia los dos lados, a dos alturas y a dos
    profundidades del tramo libre, y gana lo más cerca que se encuentre.
    """
    medio = estante.largo / 2
    izquierda = 0.0
    derecha = estante.largo
    for alto in ALTURAS_DEL_TANTEO:
        for fraccion in (0.25, 0.75):
            v = desde_v + (hasta_v - desde_v) * fraccion
            desde = estante.punto(medio, v) + estante.normal * alto
            for sentido in (-1.0, 1.0):
                golpe = arbol.ray_cast(desde, estante.u * sentido, estante.largo)
                if golpe[0] is None:
                    continue
                if sentido < 0:
                    izquierda = max(izquierda, medio - golpe[3])
                else:
                    derecha = min(derecha, medio + golpe[3])
    return izquierda, derecha


def fondo_util(estante, arbol, desde_v):
    """Hasta dónde se puede llenar la chapa hacia atrás: lo primero que corta un rayo que entra
    desde el frente del tramo libre, a dos alturas y en tres puntos a lo largo.

    **Detrás del panel perforado la chapa sigue**: en las góndolas del medio llega hasta el centro
    del mueble, y los rayos que miden lo libre encima no ven el panel, que es vertical. Medido el
    2026-09-29: sin este corte, la fila de atrás de cada estante de lado quedaba adentro de la
    góndola, detrás del panel, y desde el pasillo se veía un estante vacío.
    """
    hasta = estante.fondo
    v = desde_v + PASO_DEL_TANTEO / 2
    for alto in ALTURAS_DEL_TANTEO:
        for fraccion in (0.3, 0.5, 0.7):
            desde = estante.punto(estante.largo * fraccion, v) + estante.normal * alto
            golpe = arbol.ray_cast(desde, estante.v, estante.fondo)
            if golpe[0] is not None:
                hasta = min(hasta, v + golpe[3])
    return hasta


def franja_del_estante(estante, arbol, alto):
    """El tramo de fondo donde van las filas: libre encima para el alto, y delante del panel."""
    desde, hasta = franja_libre(muestras_de_arriba(estante, arbol), alto)
    return desde, min(hasta, fondo_util(estante, arbol, desde) - PASO_DEL_TANTEO)


def muestras_de_arriba(estante, arbol):
    """Lo que hay libre encima de la chapa, cada `PASO_DEL_TANTEO` de adelante hacia atrás.

    Se mide en tres puntos a lo largo y gana el más bajo: la tapa del panel es pareja, pero una
    ménsula o un parante no lo son.

    **Se mide en el medio de cada paso y no en su borde.** La cara de adentro del labio cae justo
    en el frente de la chapa, y un rayo que arranca sobre ella pega o no según el último decimal:
    dos corridas seguidas movían la tanda un milímetro.
    """
    muestras = []
    pasos = int(estante.fondo / PASO_DEL_TANTEO)
    for i in range(pasos):
        v = (i + 0.5) * PASO_DEL_TANTEO
        libre = float("inf")
        for fraccion in (0.1, 0.5, 0.9):
            desde = estante.punto(estante.largo * fraccion, v) + estante.normal * 0.002
            golpe = arbol.ray_cast(desde, estante.normal, 5.0)
            if golpe[0] is not None:
                libre = min(libre, golpe[3])
        muestras.append((v, libre))
    return muestras


def inclinacion_de(estante):
    """Lo que se echa hacia atrás una unidad contra la chapa, en radianes: el doble de lo que la
    chapa baja hacia el pasillo, porque la unidad sube otro tanto. Cero en un estante plano."""
    if estante.normal.z > 0.9999:
        return 0.0
    return 2 * math.asin(max(-1.0, min(1.0, estante.normal.dot(estante.mira))))


def _marco(estante):
    """Hacia dónde miran el frente y lo de arriba de una unidad sobre este estante.

    En un estante plano, el frente al pasillo y lo de arriba por la normal de la chapa. En la
    rampa de una cabecera, echada hacia atrás lo que baja la chapa: el frente mira hacia arriba y
    hacia el pasillo. Medido el 2026-09-30 sobre el `.blend` del artista: Malbardo, Durextra,
    Duronga, Chisitos y Laysntt iban echados entre 9 y 15 grados; la chapa baja 11. Apoyada de
    plano, la unidad caía hacia adelante, con el frente mirando al piso.
    """
    if inclinacion_de(estante) == 0.0:
        return -estante.v, estante.normal
    seno = estante.normal.dot(estante.mira)
    coseno = math.sqrt(1.0 - seno * seno)
    vertical = Vector((0.0, 0.0, 1.0))
    return estante.mira * coseno + vertical * seno, vertical * coseno - estante.mira * seno


def envase_de(p, unidad):
    """Lo que ocupa una unidad parada de frente, medido sobre su malla."""
    frente, arriba, derecha = _ejes(p)
    puntos = _puntos(unidad)
    return Envase(
        ancho=_extension(puntos, derecha),
        fondo=_extension(puntos, frente),
        alto=_extension(puntos, arriba),
    )


def _puntos(unidad):
    """Los vértices de la malla con la escala del objeto: el espacio en el que gira."""
    escala = unidad.matrix_world.to_scale()
    return [
        Vector((c.co.x * escala.x, c.co.y * escala.y, c.co.z * escala.z))
        for c in unidad.data.vertices
    ]


def _extension(puntos, eje):
    valores = [p.dot(eje) for p in puntos]
    return max(valores) - min(valores)


def _medio(puntos, eje):
    valores = [p.dot(eje) for p in puntos]
    return (max(valores) + min(valores)) / 2


def _ejes(p):
    frente = Vector(p.frente).normalized()
    arriba = Vector(p.arriba).normalized()
    derecha = (-frente).cross(arriba).normalized()
    return frente, arriba, derecha


def matriz_de(p, unidad, estante, u, v):
    """Dónde va la unidad para que su base quede sobre la chapa en `(u, v)`, mirando al pasillo.

    Echada en una rampa, su base ya no está en el plano de la chapa: se la levanta hasta que lo
    más bajo de la unidad la toque.
    """
    frente, arriba, derecha = _ejes(p)
    local = Matrix((derecha, frente, arriba)).transposed()
    adelante, hacia_arriba = _marco(estante)
    mundo = Matrix((estante.u, adelante, hacia_arriba)).transposed()
    giro = mundo @ local.inverted()
    puntos = _puntos(unidad)
    referencia = (
        derecha * _medio(puntos, derecha)
        + frente * _medio(puntos, frente)
        + arriba * min(pt.dot(arriba) for pt in puntos)
    )
    ubicacion = estante.punto(u, v) - giro @ referencia
    if inclinacion_de(estante) != 0.0:
        bajo = min((ubicacion + giro @ pt - estante.origen).dot(estante.normal) for pt in puntos)
        ubicacion = ubicacion - estante.normal * bajo
    escala = unidad.matrix_world.to_scale()
    return Matrix.Translation(ubicacion) @ giro.to_4x4() @ Matrix.Diagonal(escala.to_4d())


def limpiar_guia():
    coleccion = bpy.data.collections[COLECCION_DE_GUIA]
    for objeto in list(coleccion.objects):
        bpy.data.objects.remove(objeto, do_unlink=True)


def preparar_unidades():
    for p in PRODUCTOS:
        unidad = bpy.data.objects[p.objeto]
        for modificador in list(unidad.modifiers):
            if es_un_array(modificador.name):
                unidad.modifiers.remove(modificador)
        for clave in ("tanda", "fila", "orden", "producto", "fija"):
            if clave in unidad:
                del unidad[clave]


def poner(unidad, mueble, matriz, datos, copia):
    """La unidad misma, o una copia enlazada de ella en `guia`, en su lugar y con su rótulo."""
    if copia:
        objeto = unidad.copy()
        for coleccion in list(objeto.users_collection):
            coleccion.objects.unlink(objeto)
        bpy.data.collections[COLECCION_DE_GUIA].objects.link(objeto)
    else:
        objeto = unidad
    # La fuente conserva su NodePath importado: estructura_del_almacen la oculta allí.
    # Su matriz global determina el sector nuevo, independientemente de ese padre histórico.
    if copia:
        objeto.parent = mueble
    objeto.matrix_world = matriz
    for clave, valor in datos.items():
        objeto[clave] = valor


def obstaculos_del_mueble(objeto):
    """Las hojas cerradas también cuentan al medir el interior de una heladera."""
    salida = []
    for hijo in objeto.children_recursive:
        if hijo.type != "MESH" or not hijo.name.startswith("puerta_heladera"):
            continue
        salida.append(BVHTree.FromPolygons(
            [hijo.matrix_world @ v.co for v in hijo.data.vertices],
            [list(p.vertices) for p in hijo.data.polygons],
        ))
    return salida


def medir_encaje(estante, bm, arbol, hojas, posiciones):
    """Contrasta los apoyos y las mallas, sin sustituirlas por su envolvente rectangular.

    `posiciones` conserva columnas, filas, inclinación y escala. Sólo se desplaza la tanda
    hacia dentro o fuera sobre la chapa existente; el tramo común conserva todos sus contactos.
    """
    desde, hasta = -math.inf, math.inf
    for unidad, matriz in posiciones:
        contactos = [matriz @ v.co - estante.origen for v in unidad.data.vertices
                     if abs((matriz @ v.co - estante.origen).dot(estante.normal))
                     <= TOLERANCIA_DEL_PLANO]
        if not contactos or any(not 0 <= v.dot(estante.u) <= estante.largo for v in contactos):
            return None
        desde = max(desde, -min(v.dot(estante.v) for v in contactos))
        hasta = min(hasta, estante.fondo - max(v.dot(estante.v) for v in contactos))
    bm.faces.ensure_lookup_table()
    apoyo = {i for i in estante.caras if all(
        abs((v.co - estante.origen).dot(estante.normal)) <= TOLERANCIA_DEL_PLANO
        for v in bm.faces[i].verts
    )}

    def entra(delta):
        for unidad, matriz in posiciones:
            puntos = [matriz @ v.co + estante.v * delta for v in unidad.data.vertices]
            if min((v - estante.origen).dot(estante.normal) for v in puntos) < -TOLERANCIA_DEL_PLANO:
                return False
            propio = BVHTree.FromPolygons(puntos, [list(p.vertices) for p in unidad.data.polygons])
            if any(i not in apoyo for i, _ in arbol.overlap(propio)):
                return False
            if any(hoja.overlap(propio) for hoja in hojas):
                return False
        return True

    return desplazamiento_que_entra(desde, hasta, PASO_DEL_TANTEO, entra)


def acomodar_mueble(letra, envases, resumen):
    objeto, bm, estantes = medir(letra)
    propios = {c: e for c, e in estantes.items() if c in ESTANTES}
    faltan = sorted(c for c in ESTANTES if partes(c)[0] == letra and c not in estantes)
    if faltan:
        raise SystemExit(f"el reparto nombra estantes que el mueble no tiene: {faltan}")
    # El mapa cambia productos, no muebles: se reparte sobre la chapa existente.
    arbol = BVHTree.FromBMesh(bm)
    hojas = obstaculos_del_mueble(objeto)
    for clave, estante in sorted(propios.items()):
        reparto = ESTANTES[clave]
        de_estas = [envases[t.producto] for t in reparto]
        inclinacion = inclinacion_de(estante)
        alto = max(alto_en_la_rampa(e, inclinacion) for e in de_estas) - ROCE_DE_ARRIBA
        desde_v, hasta_v = franja_del_estante(estante, arbol, alto)
        filas = [t.cantidad_de_filas for t in reparto]
        izquierda, derecha = tramo_util(estante, arbol, desde_v, hasta_v)
        largo = derecha - izquierda
        pedidos = [1 if t.fija else FILA_DE_ADELANTE_PEDIDA for t in reparto]
        cuentas = repartir(largo, de_estas)
        for t, pedido, cuenta in zip(reparto, pedidos, cuentas):
            if cuenta < pedido:
                resumen["cortas"].append(f"{producto(t.producto).nombre} en {clave}: {cuenta}")
        centros_por_tanda = centros(largo, de_estas, cuentas)
        posiciones = []
        for indice, (t, envase, us) in enumerate(zip(reparto, de_estas, centros_por_tanda)):
            p = producto(t.producto)
            unidad = bpy.data.objects[p.objeto]
            for lugar in tanda(envase, [izquierda + u for u in us], inclinacion, filas[indice]):
                posiciones.append((unidad, matriz_de(p, unidad, estante, lugar.u, desde_v + lugar.v)))
        desplazamiento = medir_encaje(estante, bm, arbol, hojas, posiciones)
        if desplazamiento is None:
            resumen["choques"].append(
                f"{clave}: ninguna traslación conserva todos los apoyos sin intersecciones "
                f"con {filas} filas"
            )
            continue
        desde_v += desplazamiento
        for indice, (t, envase, us) in enumerate(
            zip(reparto, de_estas, centros_por_tanda)
        ):
            p = producto(t.producto)
            unidad = bpy.data.objects[p.objeto]
            lugares = tanda(envase, [izquierda + u for u in us], inclinacion, filas[indice])
            resumen["tandas"] += 1
            for orden, lugar in enumerate(lugares):
                matriz = matriz_de(p, unidad, estante, lugar.u, desde_v + lugar.v)
                datos = {
                    "tanda": f"{clave}/{indice}",
                    "producto": p.clave,
                    "fila": lugar.fila,
                    "orden": orden,
                    "fija": t.fija,
                }
                poner(unidad, objeto, matriz, datos, copia=t.fija or orden > 0)
                resumen["unidades"] += 1
        print(
            f"{clave}: largo {largo:.3f}, fondo {estante.fondo:.3f}, libre desde {desde_v:.3f}: "
            + ", ".join(
                f"{producto(t.producto).nombre}{' (fija)' if t.fija else ''} x{c}"
                for t, c in zip(reparto, cuentas)
            )
        )
    bm.free()


def principal():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    validar_reparto(ESTANTES)
    limpiar_guia()
    preparar_unidades()
    envases = {p.clave: envase_de(p, bpy.data.objects[p.objeto]) for p in PRODUCTOS}
    resumen = {"tandas": 0, "unidades": 0, "choques": [], "cortas": [], "entradas": {}}
    for letra in sorted({partes(clave)[0] for clave in ESTANTES}):
        acomodar_mueble(letra, envases, resumen)
    for corta in resumen["cortas"]:
        print(f"fila de adelante corta: {corta}")
    for choque in resumen["choques"]:
        print(f"choque: {choque}")
    print(
        f"estantes: {len(ESTANTES)}, tandas: {resumen['tandas']}, "
        f"unidades: {resumen['unidades']}, choques: {len(resumen['choques'])}, "
        f"filas cortas: {len(resumen['cortas'])}"
    )
    if resumen["choques"]:
        raise SystemExit("hay choques: no se guarda")
    bpy.ops.wm.save_mainfile()
    print(f"guardado: {bpy.data.filepath}")


if __name__ == "__main__":
    principal()
