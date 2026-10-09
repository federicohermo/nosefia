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
3. **Achica cada estante de góndola** a la profundidad de dos unidades de su producto más
   profundo, más lo que el mueble le tapa. El mueble se achica por su malla y no por su objeto:
   lo que cuelga del objeto se escalaría con él. Se corren hacia el fondo los vértices del frente
   de la chapa, con su labio y su portaprecio; en las cabeceras, además, el frente de los
   laterales y el de las ménsulas. Las bandejas de la heladera no se achican.
4. **Angosta cada cara de lado hasta sus estantes**: el lateral, la cabecera y lo demás que asome
   del panel perforado hacia el pasillo de esa cara entran hasta el frente del estante más hondo
   de arriba del zócalo. Con sólo los estantes achicados, el mueble conservaba su ancho y los
   estantes quedaban hundidos entre los laterales. El zócalo puede seguir asomando.
5. **Pone cada tanda**: la unidad del producto en el primer lugar de su tanda, y una copia
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
    alinear_frentes,
    centros,
    fondo_del_estante,
    fondo_nuevo,
    franja_libre,
    repartir,
    tanda,
)
from lib.reparto import (  # noqa: E402
    CABECERAS,
    DE_UNA_FILA,
    ESTANTES,
    HELADERAS,
    MUEBLES,
    PRODUCTOS,
    partes,
    producto,
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

#: Las caras de cada mueble que se angostan hasta sus estantes: las de lado de las góndolas del
#: medio y la única de las de pared, cuyo fondo contra la pared no se mueve. La heladera no.
CARAS_QUE_SE_ANGOSTAN = {
    "A": ("oeste", "este"),
    "B": ("oeste", "este"),
    "N": ("sur",),
    "S": ("sur",),
}

#: Lo que tiene que asomar un vértice del panel perforado hacia el pasillo para correrse con el
#: lateral, en metros: lo que está sobre el panel es el cuerpo del mueble, y no se mueve.
ASOMA_DEL_PANEL = 0.01


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

    Devuelve también el `bmesh`: achicar mueve vértices de estas mismas islas.
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
            if abs(medio.y - centro.y) < 1.9:
                nombre = "oeste" if medio.x < centro.x else "este"
            else:
                nombre = "norte" if medio.y > centro.y else "sur"
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


def achicar(estante, nuevo):
    """Corre el frente de la chapa hacia el fondo hasta que quede `nuevo` de hondo.

    Se mueven los vértices de la mitad de adelante de la isla, en el plano de la chapa: el labio
    y el portaprecio se van con ella. Lo que queda por debajo de la chapa —el frente del zócalo—
    se corre sólo en horizontal, o se despegaría del piso.
    """
    delta = estante.fondo - nuevo
    if abs(delta) <= 2 * PASO_DEL_TANTEO:
        # Ya está a su medida: lo que falta es el error del tanteo, y correrlo cada vez haría
        # que acomodar dos veces no diera lo mismo.
        return 0.0
    horizontal = Vector((estante.v.x, estante.v.y, 0.0))
    alto_de_la_chapa = min(estante.punto(0, 0).z, estante.punto(0, estante.fondo).z)
    for vert in {v for cara in estante.isla for v in cara.verts}:
        mundo = vert.co.copy()
        if (mundo - estante.origen).dot(estante.v) > estante.fondo / 2:
            continue
        if mundo.z < alto_de_la_chapa - 0.05:
            vert.co = mundo + horizontal * delta
        else:
            vert.co = mundo + estante.v * delta
    return delta


def achicar_cabecera(estantes, deltas, islas):
    """Los laterales y las ménsulas de una cabecera siguen a sus chapas.

    El frente de los laterales baja hasta el zócalo: se corre lo mismo que el frente del zócalo.
    Una ménsula más larga que su chapa asomaría por delante: se recorta al frente nuevo.
    """
    zocalo = min(estantes, key=lambda e: e.origen.z)
    plano = Vector((zocalo.v.x, zocalo.v.y, 0.0))
    horizontal = plano.normalized()
    fondo_del_mueble = zocalo.punto(0, zocalo.fondo)
    corrimiento = deltas.get(zocalo.clave, 0.0) * plano.length
    chapas = set().union(*(e.caras for e in estantes))
    for isla in islas:
        if isla[0].index in chapas:
            continue
        verts = list({v for cara in isla for v in cara.verts})
        profundidades = [(fondo_del_mueble - v.co).dot(horizontal) for v in verts]
        if max(profundidades) < 0.05 or min(profundidades) > zocalo.fondo + 0.1:
            continue
        a_lo_largo = [(v.co - zocalo.origen).dot(zocalo.u) for v in verts]
        if min(a_lo_largo) < -0.2 or max(a_lo_largo) > zocalo.largo + 0.2:
            continue
        alto = max(v.co.z for v in verts) - min(v.co.z for v in verts)
        if alto > 1.5:
            # Un lateral: su frente de abajo sigue al zócalo.
            for vert, profundidad in zip(verts, profundidades):
                if profundidad > zocalo.fondo / 2 + 0.05:
                    vert.co = vert.co + horizontal * corrimiento
            continue
        # Una ménsula: no puede asomar por delante de la chapa que sostiene.
        techo = max(v.co.z for v in verts)
        dueno = min(
            (e for e in estantes if e is not zocalo), key=lambda e: abs(e.origen.z - techo)
        )
        nuevo = dueno.fondo - deltas.get(dueno.clave, 0.0)
        tope = nuevo * Vector((dueno.v.x, dueno.v.y, 0.0)).length - 0.02
        for vert, profundidad in zip(verts, profundidades):
            if profundidad > tope:
                vert.co = vert.co + horizontal * (profundidad - tope)


def parejos(letra, estantes, nuevos):
    """Los estantes de una cara de lado llegan todos al frente del más hondo de arriba del zócalo.

    Las filas de cada producto siguen yendo al frente, y lo que sobra queda detrás del producto.
    El zócalo llega al mismo plano, tanto si estaba hundido como si sobresalía.
    """
    for cara in CARAS_QUE_SE_ANGOSTAN.get(letra, ()):
        de_la_cara = {c: e for c, e in estantes.items() if partes(c)[1] == cara}
        if not any(partes(c)[2] > 0 for c in de_la_cara):
            continue
        # El fondo de cada chapa, medido hacia el pasillo: achicada a `nuevo`, su frente queda ahí
        # más lo nuevo, porque en un estante plano `v` es lo contrario de hacia dónde mira.
        fondo = {c: e.punto(0, e.fondo).dot(e.mira) for c, e in de_la_cara.items()}
        claves = list(de_la_cara)
        alineados = alinear_frentes(
            [fondo[c] for c in claves], [nuevos[c] for c in claves],
        )
        nuevos.update(zip(claves, alineados))


def angostar(letra, estantes, islas, objeto):
    """Cada cara de lado se angosta hasta el frente de sus estantes; devuelve cuánto entró cada una.

    Lo que asoma del panel perforado hacia el pasillo de la cara —el lateral, las puntas de la
    cabecera, sus ménsulas y sus laterales— se traslada hacia adentro hasta el frente del estante
    más hondo de arriba del zócalo. Se traslada entero, sin deformarlo: la cabecera, que va de
    punta a punta del mueble, se angosta lo que entran las dos caras. Los estantes de la cara ya
    tienen su medida y no se tocan, y el zócalo puede seguir asomando.
    """
    entradas = {}
    for cara in CARAS_QUE_SE_ANGOSTAN.get(letra, ()):
        mira = MIRA[cara]
        de_la_cara = [e for c, e in estantes.items() if partes(c)[1] == cara]
        de_arriba = [e for e in de_la_cara if partes(e.clave)[2] > 0]
        if not de_arriba:
            continue
        propias = set().union(*(e.caras for e in de_la_cara))
        frentes = {
            e.clave: max(v.co.dot(mira) for c in e.isla for v in c.verts) for e in de_arriba
        }
        frente = max(frentes.values())
        panel = _panel_hacia(islas, objeto, mira)
        asoman = {
            v
            for isla in islas
            if isla[0].index not in propias
            for c in isla
            for v in c.verts
            if v.co.dot(mira) > panel + ASOMA_DEL_PANEL
        }
        entra = max(v.co.dot(mira) for v in asoman) - frente
        if entra > 2 * PASO_DEL_TANTEO:
            for v in asoman:
                v.co = v.co - mira * entra
        else:
            entra = 0.0
        entradas[f"{letra}.{cara}"] = entra
        hundidos = ", ".join(
            f"{clave} {frente - f:.3f}" for clave, f in sorted(frentes.items()) if frente - f > 0.01
        )
        print(
            f"{letra}.{cara}: el lateral entra {entra:.3f}"
            + (f"; quedan detrás del lateral: {hundidos}" if hundidos else "")
        )
    return entradas


def _panel_hacia(islas, objeto, mira):
    """Dónde está el panel perforado que da a una cara, medido hacia su pasillo.

    **Es la cara de panel más grande que mira hacia ahí**: los laterales de la cabecera también
    llevan panel, y el de la punta de enfrente mira hacia adentro. Tomarlo a él correría la
    góndola entera.
    """
    mejor = None
    for isla in islas:
        for cara in isla:
            material = objeto.material_slots[cara.material_index].material
            if material is None or "Panel" not in material.name or cara.normal.dot(mira) < 0.99:
                continue
            if mejor is None or cara.calc_area() > mejor.calc_area():
                mejor = cara
    if mejor is None:
        raise SystemExit(f"{objeto.name}: no hay panel perforado que mire hacia {tuple(mira)}")
    return mejor.calc_center_median().dot(mira)


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
    objeto.parent = mueble
    objeto.matrix_world = matriz
    for clave, valor in datos.items():
        objeto[clave] = valor


def acomodar_mueble(letra, envases, resumen):
    objeto, bm, estantes = medir(letra)
    propios = {c: e for c, e in estantes.items() if c in ESTANTES}
    faltan = sorted(c for c in ESTANTES if partes(c)[0] == letra and c not in estantes)
    if faltan:
        raise SystemExit(f"el reparto nombra estantes que el mueble no tiene: {faltan}")
    if letra not in HELADERAS:
        arbol = BVHTree.FromBMesh(bm)
        deltas = {}
        nuevos = {}
        for clave, estante in propios.items():
            de_estas = [envases[t.producto] for t in ESTANTES[clave]]
            inclinacion = inclinacion_de(estante)
            alto = max(alto_en_la_rampa(e, inclinacion) for e in de_estas) - ROCE_DE_ARRIBA
            desde, hasta = franja_del_estante(estante, arbol, alto)
            atras = estante.fondo - hasta
            filas = [1 if t.producto in DE_UNA_FILA else 2 for t in ESTANTES[clave]]
            nuevos[clave] = (
                fondo_nuevo(desde, de_estas, atras, inclinacion, filas) + PASO_DEL_TANTEO
            )
        if letra in ("A", "B"):
            for clave, estante in propios.items():
                if partes(clave)[1] not in CABECERAS and partes(clave)[2] > 0:
                    nuevos[clave] = max(nuevos[clave], estante.fondo)
        parejos(letra, propios, nuevos)
        for clave, estante in propios.items():
            deltas[clave] = achicar(estante, nuevos[clave])
        islas = _islas(bm)
        for cara in CABECERAS if letra in ("A", "B") else ():
            de_la_cara = [e for c, e in propios.items() if partes(c)[1] == cara]
            if de_la_cara:
                achicar_cabecera(de_la_cara, deltas, islas)
        if letra not in ("A", "B"):
            resumen["entradas"].update(angostar(letra, estantes, islas, objeto))
        bm.transform(objeto.matrix_world.inverted())
        bm.to_mesh(objeto.data)
        objeto.data.update()
        bm.free()
        objeto, bm, estantes = medir(letra)
        propios = {c: e for c, e in estantes.items() if c in ESTANTES}
    arbol = BVHTree.FromBMesh(bm)
    for clave, estante in sorted(propios.items()):
        reparto = ESTANTES[clave]
        de_estas = [envases[t.producto] for t in reparto]
        inclinacion = inclinacion_de(estante)
        alto = max(alto_en_la_rampa(e, inclinacion) for e in de_estas) - ROCE_DE_ARRIBA
        desde_v, hasta_v = franja_del_estante(estante, arbol, alto)
        filas = [1 if t.producto in DE_UNA_FILA else 2 for t in reparto]
        hace_falta = fondo_del_estante(de_estas, inclinacion, filas)
        if hasta_v - desde_v < hace_falta - PASO_DEL_TANTEO:
            resumen["choques"].append(
                f"{clave}: hay {hasta_v - desde_v:.3f} m de fondo libre para "
                f"{alto:.3f} m de alto, y hacen falta {hace_falta:.3f}"
            )
            continue
        izquierda, derecha = tramo_util(estante, arbol, desde_v, hasta_v)
        largo = derecha - izquierda
        pedidos = [1 if t.fija else FILA_DE_ADELANTE_PEDIDA for t in reparto]
        cuentas = repartir(largo, de_estas)
        for t, pedido, cuenta in zip(reparto, pedidos, cuentas):
            if cuenta < pedido:
                resumen["cortas"].append(f"{producto(t.producto).nombre} en {clave}: {cuenta}")
        for indice, (t, envase, us) in enumerate(
            zip(reparto, de_estas, centros(largo, de_estas, cuentas))
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


def igualar_muebles_del_medio():
    """Conserva el contorno mayor para que cuatro bolsas entren también en la cabecera de A.

    Cambia sólo la malla del mueble: escalar el objeto deformaría las unidades hijas.
    """
    objetos = [bpy.data.objects[MUEBLES[letra]] for letra in ("A", "B")]
    medidas = []
    for objeto in objetos:
        xs = [(objeto.matrix_world @ vert.co).x for vert in objeto.data.vertices]
        medidas.append((min(xs), max(xs)))
    ancho = max(hasta - desde for desde, hasta in medidas)
    for objeto, (desde, hasta) in zip(objetos, medidas):
        centro = (desde + hasta) / 2
        factor = ancho / (hasta - desde)
        inversa = objeto.matrix_world.inverted()
        for vert in objeto.data.vertices:
            mundo = objeto.matrix_world @ vert.co
            mundo.x = centro + (mundo.x - centro) * factor
            vert.co = inversa @ mundo
        objeto.data.update()
    bpy.context.view_layer.update()


def principal():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    limpiar_guia()
    preparar_unidades()
    igualar_muebles_del_medio()
    envases = {p.clave: envase_de(p, bpy.data.objects[p.objeto]) for p in PRODUCTOS}
    resumen = {"tandas": 0, "unidades": 0, "choques": [], "cortas": [], "entradas": {}}
    for letra in sorted({partes(clave)[0] for clave in ESTANTES}):
        acomodar_mueble(letra, envases, resumen)
    # Sacar el saliente del zócalo cambia el contorno medido de B. Se iguala después de esa
    # corrección y se vuelven a ubicar las unidades, manteniendo el tamaño de cada envase.
    igualar_muebles_del_medio()
    limpiar_guia()
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
