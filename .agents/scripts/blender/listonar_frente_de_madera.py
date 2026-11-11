"""Listonar el frente de madera: el mostrador, su compuerta y el friso de las heladeras.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/listonar_frente_de_madera.py -- [--aplicar]

Sin `--aplicar` escribe la imagen en `build/madera/` y cambia sólo la sesión de Blender. Con
`--aplicar` escribe `assets/source/textures/store/madera_lambrin.png` y guarda el `.blend`.
Antes de este script va `quitar_molduras_del_friso.py`. Después va `exportar_modelo.py`. **Reemplaza
a `texturizar_frente_de_madera.py`, que ya no se corre.**

## Por qué

El frente era una caja con una textura: paneles planos de un enchapado liso, un borde blanco que
brillaba y ningún volumen. Un mueble moderno de almacén se lee por su terminación: un zócalo
retirado que cae en sombra, listones con buñas hondas, un perfil de aluminio y un canto que cierra
la pieza. Con la luz horneada, un mapa de relieve no se ve. Lo que se ve es la geometría y el color.

## Qué cambia

- **Mostrador** (`EscritorioComputadora-col`): se rehace todo su frente. De abajo hacia arriba: un
  zócalo oscuro retirado 7,5 cm, un riel de aluminio, listones de unos 12 cm con buñas en V y una
  banda oscura de sombra bajo la losa. Los listones quedan 2,5 cm adentro del borde de la losa:
  ella vuela y da sombra. Lo mismo vale para los seis lados del mostrador en L.
- **Compuerta** (`compuerta_mostrador`): listones en las dos caras, un perfil de aluminio en el
  extremo libre y en el canto inferior, y la tapa de madera. Las bisagras y la caja no cambian.
- **Friso** (`mueble_continuo`): listones sobre las heladeras, en los dos montantes y en el pilar
  del medio. Abajo lleva un zócalo oscuro y sobre cada hueco una banda de aluminio.
- **La imagen** de 512×1024 reparte cinco columnas de enchapado de roble (Poly Haven
  `oak_veneer_01`, CC0) tomadas de lugares distintos, con otro tono cada una, una franja oscura
  para buñas y zócalo, y una franja de aluminio cepillado. Cada listón elige su columna y su
  corrimiento vertical al azar: no hay dos iguales a la vista.
- **El material** `MOSTRADOR | Frente de madera` apunta a la imagen. La malla del mostrador no
  usa más el acero: ese material sigue sólo en las bisagras.

## Lo que cuesta

Ningún material ni dibujo más (el mostrador pierde el del acero). Suma unos mil triángulos en tres
mallas fijas. El script imprime la cuenta de cada una. Es determinista e idempotente: una malla
marcada con `listones_del_frente_v1` no se toca. La imagen se reescribe igual.
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from detalle_de_madera import suave  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / "assets/source/textures/store/madera_lambrin.png"
PRUEBA = RAIZ / "build" / "madera" / DESTINO.name
CHAPA = RAIZ / "assets/source/textures/third-party/oak_veneer_01/oak_veneer_01_diff_2k.jpg"
MATERIAL = "MOSTRADOR | Frente de madera"
MARCA = "listones_del_frente_v1"
SEMILLA = 20261112

# --- La imagen -------------------------------------------------------------------------------
ANCHO_PX = 512
ALTO_PX = 1024
COLUMNAS = 5
COLUMNA_PX = 96
#: Lo que mide la imagen de alto, en metros: lo mismo que mide la chapa original de lado.
ALTO_EN_METROS = 1.83
#: Lo que mide un listón de ancho, en metros. Una columna lo cubre entera.
ANCHO_DE_COLUMNA = 0.116
OSCURO_PX = (COLUMNAS * COLUMNA_PX, COLUMNAS * COLUMNA_PX + 16)
ALUMINIO_PX = (OSCURO_PX[1], ANCHO_PX)
#: El color medio que se busca: un roble claro. La chapa original es más oscura y más naranja.
TONO = np.array([0.78, 0.64, 0.47], dtype=np.float32)
TONOS_DE_COLUMNA = (1.00, 0.94, 1.05, 0.97, 1.03)
COLOR_OSCURO = np.array([0.19, 0.145, 0.10], dtype=np.float32)
COLOR_ALUMINIO = np.array([0.66, 0.67, 0.68], dtype=np.float32)

# --- La geometría, en metros del mundo ---------------------------------------------------------
#: Lo que mide un listón con su buña, y lo que miden la buña y su fondo.
PASO = 0.13
HUECO = 0.014
HONDO = 0.012
#: Cuánto entran los listones del mostrador desde el plano viejo: la losa vuela esto sobre ellos.
ENTRADA = 0.025
ZOCALO = 0.075
RIEL = 0.032
ZOCALO_DEL_FRISO = 0.10
BANDA_DEL_FRISO = 0.03
#: Un frente más bajo que esto no lleva listones: queda una banda plana.
ALTO_MINIMO = 0.35
#: Las tiras de aluminio de la compuerta.
PERFIL = 0.015
TOLERANCIA = 1e-3


def pintar(chapa: np.ndarray) -> np.ndarray:
    """La imagen entera, (ALTO_PX, ANCHO_PX, 3) en sRGB 0..1, con la fila 0 abajo.

    `chapa` es la foto del roble, (alto, ancho, 3) en sRGB, con la veta en vertical y que se
    repite en los dos ejes.
    """
    azar = np.random.default_rng(SEMILLA)
    alto, ancho = chapa.shape[:2]
    # Verticalmente a la mitad, por promedio. Horizontalmente a la escala del mundo.
    filas = chapa.reshape(ALTO_PX, alto // ALTO_PX, ancho, 3).mean(axis=1)
    columnas_fuente = round(ALTO_EN_METROS / ANCHO_DE_COLUMNA * COLUMNA_PX)
    posicion = (np.arange(columnas_fuente) + 0.5) * ancho / columnas_fuente - 0.5
    izquierda = np.clip(np.floor(posicion).astype(int), 0, ancho - 1)
    derecha = np.clip(izquierda + 1, 0, ancho - 1)
    resto = (posicion - np.floor(posicion))[None, :, None]
    escala = filas[:, izquierda] * (1 - resto) + filas[:, derecha] * resto

    imagen = np.zeros((ALTO_PX, ANCHO_PX, 3), dtype=np.float32)
    lugares = azar.permutation(columnas_fuente // COLUMNA_PX)[:COLUMNAS]
    for k, lugar in enumerate(lugares):
        pedazo = escala[:, lugar * COLUMNA_PX:(lugar + 1) * COLUMNA_PX]
        pedazo = np.roll(pedazo, int(azar.integers(ALTO_PX)), axis=0)
        imagen[:, k * COLUMNA_PX:(k + 1) * COLUMNA_PX] = pedazo * TONOS_DE_COLUMNA[k]
    madera = imagen[:, :OSCURO_PX[0]]
    # El tono medio sale del color buscado. El contraste de la veta se conserva.
    madera *= (TONO / madera.reshape(-1, 3).mean(axis=0))[None, None, :]
    # Un canto apenas gastado: más oscuro en los bordes de cada columna.
    borde = np.minimum(np.arange(COLUMNA_PX), COLUMNA_PX - 1 - np.arange(COLUMNA_PX))
    gastado = 1.0 - 0.24 * np.exp(-borde / 1.3) - 0.07 * suave(6.0, 0.0, borde.astype(np.float32))
    madera *= np.tile(gastado, COLUMNAS)[None, :, None]

    ruido = azar.normal(0.0, 0.025, size=(ALTO_PX, 1, 1)).astype(np.float32)
    imagen[:, OSCURO_PX[0]:OSCURO_PX[1]] = COLOR_OSCURO[None, None, :] * (1.0 + ruido)
    cepillo = azar.normal(0.0, 0.03, size=(1, ALUMINIO_PX[1] - ALUMINIO_PX[0], 1))
    imagen[:, ALUMINIO_PX[0]:ALUMINIO_PX[1]] = COLOR_ALUMINIO[None, None, :] * (
        1.0 + cepillo.astype(np.float32) + ruido * 0.6
    )
    return np.clip(imagen, 0.0, 1.0)


# ---------------------------------------------------------------------------------------------
# Lo que sigue necesita Blender.
# ---------------------------------------------------------------------------------------------


def u_de_columna(k: int) -> tuple[float, float]:
    return k * COLUMNA_PX / ANCHO_PX, (k + 1) * COLUMNA_PX / ANCHO_PX


def u_del_centro(px: tuple[int, int]) -> float:
    return (px[0] + px[1]) / 2 / ANCHO_PX


U_OSCURO = u_del_centro(OSCURO_PX)
U_ALUMINIO = u_del_centro(ALUMINIO_PX)


class Obra:
    """Una malla en edición: las caras nuevas se piden en metros del mundo."""

    def __init__(self, objeto, indice_de_material: int, azar: np.random.Generator):
        import bmesh  # type: ignore[import-not-found]

        self.objeto = objeto
        self.inversa = objeto.matrix_world.inverted()
        self.bm = bmesh.new()
        self.bm.from_mesh(objeto.data)
        self.bm.normal_update()
        self.uv = self.bm.loops.layers.uv.active
        self.material = indice_de_material
        self.azar = azar
        self.anterior = -1

    def cara(self, puntos, normal, uvs) -> None:
        """Una cara de cuatro puntos. El orden se corrige para que mire hacia `normal`."""
        from mathutils import Vector  # type: ignore[import-not-found]

        hacia = Vector((0.0, 0.0, 0.0))
        for i, p in enumerate(puntos):
            q = puntos[(i + 1) % len(puntos)]
            hacia += Vector(((p.y - q.y) * (p.z + q.z), (p.z - q.z) * (p.x + q.x),
                             (p.x - q.x) * (p.y + q.y)))
        puntos, uvs = list(puntos), list(uvs)
        if hacia.dot(normal) < 0:
            puntos.reverse()
            uvs.reverse()
        cara = self.bm.faces.new([self.bm.verts.new(self.inversa @ p) for p in puntos])
        cara.material_index = self.material
        for lazo, uv in zip(cara.loops, uvs):
            lazo[self.uv].uv = uv

    def columna(self) -> int:
        """Una columna de la imagen al azar, distinta de la anterior."""
        k = int(self.azar.choice([c for c in range(COLUMNAS) if c != self.anterior]))
        self.anterior = k
        return k

    def plano(self, a, b, n, z0, z1, u, escala_v=None) -> None:
        """Una tira plana de `a` a `b`, de `z0` a `z1`, con `u` fijo y la veta en vertical."""
        from mathutils import Vector  # type: ignore[import-not-found]

        v0, v1 = z0 / ALTO_EN_METROS, z1 / ALTO_EN_METROS
        pts = [Vector((a.x, a.y, z0)), Vector((b.x, b.y, z0)),
               Vector((b.x, b.y, z1)), Vector((a.x, a.y, z1))]
        self.cara(pts, Vector((n.x, n.y, 0.0)), [(u, v0), (u, v0), (u, v1), (u, v1)])

    def horizontal(self, a, b, n, z, hondo, hacia_arriba: bool, u) -> None:
        """La tapa de una buña: un rectángulo horizontal de `a` a `b`, `hondo` hacia adentro."""
        from mathutils import Vector  # type: ignore[import-not-found]

        largo = (b - a).length
        pts = [Vector((a.x, a.y, z)), Vector((b.x, b.y, z)),
               Vector((b.x - n.x * hondo, b.y - n.y * hondo, z)),
               Vector((a.x - n.x * hondo, a.y - n.y * hondo, z))]
        v = z / ALTO_EN_METROS
        self.cara(pts, Vector((0.0, 0.0, 1.0 if hacia_arriba else -1.0)),
                  [(u, v), (u, v + largo / ALTO_EN_METROS), (u, v + largo / ALTO_EN_METROS), (u, v)])

    def listones(self, a, b, n, z0, z1) -> int:
        """Listones verticales con buñas en V de `a` a `b`. Devuelve cuántos son."""
        from mathutils import Vector  # type: ignore[import-not-found]

        largo = (b - a).length
        d = (b - a) / largo
        cuantos = max(1, round(largo / PASO))
        ancho = (largo - (cuantos - 1) * HUECO) / cuantos

        def punto(s: float, z: float, hondo: float):
            q = a + d * s - n * hondo
            return Vector((q.x, q.y, z))

        normal = Vector((n.x, n.y, 0.0))
        lado_x = Vector((d.x, d.y, 0.0))
        for i in range(cuantos):
            desde = i * (ancho + HUECO)
            hasta = desde + ancho
            u0, u1 = u_de_columna(self.columna())
            corrimiento = float(self.azar.random())
            v0, v1 = z0 / ALTO_EN_METROS + corrimiento, z1 / ALTO_EN_METROS + corrimiento
            self.cara([punto(desde, z0, 0), punto(hasta, z0, 0), punto(hasta, z1, 0),
                       punto(desde, z1, 0)], normal, [(u0, v0), (u1, v0), (u1, v1), (u0, v1)])
            if i == cuantos - 1:
                continue
            fondo = hasta + HUECO / 2
            siguiente = hasta + HUECO
            lado = [(U_OSCURO, v0), (U_OSCURO, v0), (U_OSCURO, v1), (U_OSCURO, v1)]
            self.cara([punto(hasta, z0, 0), punto(fondo, z0, HONDO), punto(fondo, z1, HONDO),
                       punto(hasta, z1, 0)], normal + lado_x, lado)
            self.cara([punto(fondo, z0, HONDO), punto(siguiente, z0, 0), punto(siguiente, z1, 0),
                       punto(fondo, z1, HONDO)], normal - lado_x, lado)
        self.horizontal(a, b, n, z0, HONDO, True, U_OSCURO)
        self.horizontal(a, b, n, z1, HONDO, False, U_OSCURO)
        return cuantos

    def cerrar(self) -> None:
        import bmesh  # type: ignore[import-not-found]

        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-6)
        malla = self.objeto.data
        self.bm.to_mesh(malla)
        self.bm.free()
        malla[MARCA] = 1
        malla.update()

    def borrar(self, caras) -> None:
        import bmesh  # type: ignore[import-not-found]

        bmesh.ops.delete(self.bm, geom=list(caras), context="FACES_ONLY")
        sueltos = [v for v in self.bm.verts if not v.link_faces]
        bmesh.ops.delete(self.bm, geom=sueltos, context="VERTS")


def triangulos(malla) -> int:
    return sum(len(p.vertices) - 2 for p in malla.polygons)


def mundo(obra: Obra, cara):
    m = obra.objeto.matrix_world
    return [m @ v.co for v in cara.verts], m.to_3x3() @ cara.normal


def v2(x: float, y: float):
    from mathutils import Vector  # type: ignore[import-not-found]

    return Vector((x, y))


def lazo_de_paredes(paredes):
    """Une las paredes de un cuerpo en un lazo cerrado de puntos, en sentido antihorario.

    `paredes` son `(normal_xy, [puntos])`. De cada una sale su arista de abajo, de izquierda a
    derecha vista desde afuera. Dos aristas seguidas en la misma recta se funden en una.
    """
    aristas = {}
    for n, pts in paredes:
        zmin = min(p.z for p in pts)
        base = [p for p in pts if p.z < zmin + TOLERANCIA]
        d = v2(-n.y, n.x)
        a, b = base[0].xy, base[1].xy
        if (b - a).dot(d) < 0:
            a, b = b, a
        aristas[(round(a.x, 3), round(a.y, 3))] = (a, b, d)
    inicio = next(iter(aristas))
    lazo, clave = [], inicio
    while True:
        a, b, d = aristas[clave]
        lazo.append((a, d))
        clave = (round(b.x, 3), round(b.y, 3))
        if clave == inicio:
            break
    puntos = []
    for i, (p, d) in enumerate(lazo):
        anterior = lazo[i - 1][1]
        if (d - anterior).length > 1e-4:
            puntos.append((p, anterior, d))
    return puntos


def entrar(esquinas, t: float):
    """Las esquinas de un lazo, corridas `t` hacia adentro. Cada una trae su normal de salida."""
    nuevas = []
    for p, anterior, siguiente in esquinas:
        na, ns = v2(anterior.y, -anterior.x), v2(siguiente.y, -siguiente.x)
        nuevas.append(p - (na + ns) * (t / (1.0 + na.dot(ns))))
    return nuevas


def lados(esquinas, t: float):
    """Los lados de un lazo corrido `t` hacia adentro: `(a, b, normal_de_salida)`."""
    puntos = entrar(esquinas, t)
    for i, p in enumerate(puntos):
        q = puntos[(i + 1) % len(puntos)]
        d = (q - p).normalized()
        yield p, q, v2(d.y, -d.x)


def rehacer_mostrador(objeto, azar) -> None:
    obra = Obra(objeto, objeto.data.materials.find("MOSTRADOR | Frente de madera"), azar)
    acero = objeto.data.materials.find("MOSTRADOR | Acero satinado")
    madera = obra.material
    reemplazar = [c for c in obra.bm.faces if c.material_index in (madera, acero)]
    paredes = []
    alturas = []
    for c in reemplazar:
        pts, n = mundo(obra, c)
        zs = [p.z for p in pts]
        if c.material_index == madera and abs(n.z) < 0.01 and max(zs) - min(zs) > 0.5:
            paredes.append((n.xy.normalized(), pts))
            alturas += zs
    z_cuerpo0, z_cuerpo1 = min(alturas), max(alturas)
    todos = [objeto.matrix_world @ v.co for v in obra.bm.verts]
    z_piso = min(p.z for p in todos)
    z_losa = min(p.z for c in obra.bm.faces if c.material_index not in (madera, acero)
                 for p in mundo(obra, c)[0])
    esquinas = lazo_de_paredes(paredes)
    obra.borrar(reemplazar)
    z_hasta = z_losa - (ENTRADA + HONDO + 0.002)
    cuenta = 0
    for a, b, n in lados(esquinas, ZOCALO):
        obra.plano(a, b, n, z_piso, z_cuerpo0, U_OSCURO)
    for a, b, n in lados(esquinas, ENTRADA):
        obra.plano(a, b, n, z_cuerpo0, z_cuerpo0 + RIEL, U_ALUMINIO)
        cuenta += obra.listones(a, b, n, z_cuerpo0 + RIEL, z_hasta)
    for a, b, n in lados(esquinas, ENTRADA + HONDO):
        obra.plano(a, b, n, z_hasta, z_losa, U_OSCURO)
    obra.cerrar()
    print(f"{objeto.name}: {cuenta} listones")


def rehacer_compuerta(objeto, azar) -> None:
    from mathutils import Vector  # type: ignore[import-not-found]

    obra = Obra(objeto, objeto.data.materials.find("MOSTRADOR | Frente de madera"), azar)
    madera = obra.material
    hoja = []
    tapa = []
    for c in obra.bm.faces:
        if c.material_index != madera:
            continue
        pts, _ = mundo(obra, c)
        (hoja if min(p.z for p in pts) < 0.5 else tapa).append(c)
    pts = [p for c in hoja for p in mundo(obra, c)[0]]
    x0, x1 = min(p.x for p in pts), max(p.x for p in pts)
    y0, y1 = min(p.y for p in pts), max(p.y for p in pts)
    z0, z1 = min(p.z for p in pts), max(p.z for p in pts)
    obra.borrar(hoja)
    perfil = PERFIL
    p = lambda x, y: Vector((x, y))  # noqa: E731
    # Las dos caras llevan listones, entre el perfil del extremo libre y la bisagra.
    cuenta = obra.listones(p(x1, y1), p(x0 + perfil, y1), p(0, 1), z0 + perfil, z1)
    cuenta += obra.listones(p(x0 + perfil, y0), p(x1, y0), p(0, -1), z0 + perfil, z1)
    for y, n in ((y1, p(0, 1)), (y0, p(0, -1))):
        a, b = (p(x0 + perfil, y), p(x0, y)) if n.y > 0 else (p(x0, y), p(x0 + perfil, y))
        obra.plano(a, b, n, z0, z1, U_ALUMINIO)
        a, b = (p(x1, y), p(x0 + perfil, y)) if n.y > 0 else (p(x0 + perfil, y), p(x1, y))
        obra.plano(a, b, n, z0, z0 + perfil, U_ALUMINIO)
    obra.plano(p(x0, y1), p(x0, y0), p(-1, 0), z0, z1, U_ALUMINIO)
    obra.plano(p(x1, y0), p(x1, y1), p(1, 0), z0, z1, U_OSCURO)
    obra.cara([Vector((x0, y0, z0)), Vector((x1, y0, z0)), Vector((x1, y1, z0)),
               Vector((x0, y1, z0))], Vector((0, 0, -1)), [(U_ALUMINIO, 0.0)] * 4)
    # La tapa conserva su forma. Sólo se le reparten las UV.
    for c in tapa:
        pts_c, n = mundo(obra, c)
        for lazo, q in zip(c.loops, pts_c):
            a_lo_largo = q.x if abs(n.z) >= 0.8 or abs(n.y) >= abs(n.x) else q.y
            lazo[obra.uv].uv = (u_del_centro((0, COLUMNA_PX)), a_lo_largo / ALTO_EN_METROS)
    obra.cerrar()
    print(f"{objeto.name}: {cuenta} listones")


def rehacer_friso(objeto, azar) -> None:
    from mathutils import Vector  # type: ignore[import-not-found]

    obra = Obra(objeto, 0, azar)
    frentes = []
    for c in obra.bm.faces:
        pts, n = mundo(obra, c)
        if n.y < -0.99:
            frentes.append((c, pts))
    plano_y = min(p.y for _, pts in frentes for p in pts)
    frentes = [(c, pts) for c, pts in frentes
               if all(abs(p.y - plano_y) < TOLERANCIA for p in pts)]
    rects = [(min(p.x for p in pts), max(p.x for p in pts),
              min(p.z for p in pts), max(p.z for p in pts)) for _, pts in frentes]
    piso, techo = min(r[2] for r in rects), max(r[3] for r in rects)
    obra.borrar([c for c, _ in frentes])
    cortes = sorted({round(r[0], 3) for r in rects} | {round(r[1], 3) for r in rects})
    n = Vector((0.0, -1.0))
    cuenta = 0
    for x0, x1 in zip(cortes, cortes[1:]):
        franjas = sorted((r[2], r[3]) for r in rects if r[0] <= x0 + 1e-6 and r[1] >= x1 - 1e-6)
        fundidas = []
        for lo, hi in franjas:
            if fundidas and lo <= fundidas[-1][1] + 1e-6:
                fundidas[-1][1] = max(hi, fundidas[-1][1])
            else:
                fundidas.append([lo, hi])
        a, b = Vector((x0, plano_y)), Vector((x1, plano_y))
        for lo, hi in fundidas:
            desde, hasta = lo, hi
            if abs(lo - piso) < TOLERANCIA:
                desde = lo + ZOCALO_DEL_FRISO
                obra.plano(a, b, n, lo, desde, U_OSCURO)
            else:
                desde = lo + BANDA_DEL_FRISO
                obra.plano(a, b, n, lo, desde, U_ALUMINIO)
            if abs(hi - techo) > TOLERANCIA:
                hasta = hi - BANDA_DEL_FRISO
                obra.plano(a, b, n, hasta, hi, U_ALUMINIO)
            if hasta - desde < ALTO_MINIMO - ZOCALO_DEL_FRISO:
                obra.plano(a, b, n, desde, hasta, U_OSCURO)
                continue
            cuenta += obra.listones(a, b, n, desde, hasta)
    obra.cerrar()
    print(f"{objeto.name}: {cuenta} listones")


REHACER = (
    ("EscritorioComputadora-col", rehacer_mostrador),
    ("compuerta_mostrador", rehacer_compuerta),
    ("mueble_continuo", rehacer_friso),
)


def leer_chapa() -> np.ndarray:
    import bpy  # type: ignore[import-not-found]

    imagen = bpy.data.images.load(str(CHAPA), check_existing=False)
    ancho, alto = imagen.size
    pixeles = np.empty(ancho * alto * 4, dtype=np.float32)
    imagen.pixels.foreach_get(pixeles)
    bpy.data.images.remove(imagen)
    return pixeles.reshape(alto, ancho, 4)[..., :3].copy()


def enlazar_imagen(ruta: Path, relativa: bool):
    import bpy  # type: ignore[import-not-found]

    material = bpy.data.materials[MATERIAL]
    nodo = next(n for n in material.node_tree.nodes if n.type == "TEX_IMAGE")
    nodo.image = None
    for imagen in list(bpy.data.images):
        if imagen.filepath and Path(bpy.path.abspath(imagen.filepath)).name == ruta.name:
            bpy.data.images.remove(imagen)
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    if relativa:
        imagen.filepath = "//../source/textures/store/" + ruta.name
    imagen.colorspace_settings.name = "sRGB"
    nodo.image = imagen
    return imagen


def main() -> None:
    import bpy  # type: ignore[import-not-found]

    from detalle_de_plastico import escribir_png
    from lib.consola import configurar

    configurar()
    aplicar = "--aplicar" in sys.argv
    destino = DESTINO if aplicar else PRUEBA
    destino.parent.mkdir(parents=True, exist_ok=True)
    escribir_png(pintar(leer_chapa()), destino)
    enlazar_imagen(destino, relativa=aplicar)
    for i, (nombre, rehacer) in enumerate(REHACER):
        objeto = bpy.data.objects[nombre]
        antes = triangulos(objeto.data)
        if MARCA in objeto.data:
            print(f"{nombre}: ya listonado, {antes} triángulos")
            continue
        rehacer(objeto, np.random.default_rng([SEMILLA, i]))
        despues = triangulos(objeto.data)
        print(f"{nombre}: {antes} -> {despues} triángulos ({despues - antes:+d})")
    print("imagen:", destino)
    if aplicar:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
