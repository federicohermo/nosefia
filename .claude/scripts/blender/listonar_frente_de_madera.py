"""Listonar el frente de madera: el mostrador, su compuerta y el friso de las heladeras.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/listonar_frente_de_madera.py -- [--aplicar]

Sin `--aplicar` escribe la imagen en `build/madera/` y cambia sólo la sesión de Blender. Con
`--aplicar` escribe `assets/source/textures/store/madera_lambrin.png` y guarda el `.blend`.
Antes de este script va `quitar_molduras_del_friso.py`. Después va `exportar_modelo.py`.

## Por qué

El frente era una caja con una textura de tablas. La referencia del usuario es el mostrador de
una tienda de estación de servicio: un frente de listones verticales muy angostos y juntos, con
una ranura fina y oscura entre cada uno, de una madera media y cálida, entre nogal claro y roble
ahumado. Arriba una banda lisa de la misma madera, abajo un zócalo claro y retirado, y los
cantos lisos. Con la luz horneada, un mapa de relieve no se ve. Lo que se ve es la geometría
(la ranura es una sombra, y de costado el frente se lee como un peine) y el color.

## Qué cambia

- **Mostrador** (`EscritorioComputadora-col`): se rehace todo su frente. De abajo hacia arriba:
  un zócalo claro y liso, retirado 6 cm; listones de 3,5 cm con una ranura de 1 cm y 1,5 cm de
  hondo; y una banda lisa de enchapado bajo la losa. Los listones quedan 2,5 cm adentro del borde
  de la losa: ella vuela y da sombra. En cada esquina el listonado termina contra un canto liso.
- **Compuerta** (`compuerta_mostrador`): el mismo listonado en las dos caras, un canto liso en
  el extremo libre y abajo, y el enchapado liso en la tapa. Las bisagras y la caja no cambian.
- **Friso** (`mueble_continuo`): no lleva listones. Es enchapado liso: cada cara toma la veta de
  la chapa, horizontal en las anchas y vertical en las altas y angostas. La malla no cambia.
- **La imagen** de 1024×1024 lleva la chapa CC0 de Poly Haven `european_walnut_veneer_04`
  (veta fina y pareja), rotada para que la veta corra en vertical y reentonada al color de la
  referencia, una franja casi negra para las ranuras y una franja clara para el zócalo. Cada
  listón toma un tramo distinto de la chapa: el tono varía muy poco entre uno y otro.
- **El material** `MOSTRADOR | Frente de madera` apunta a la imagen. La malla del mostrador no
  usa más el acero: ese material sigue sólo en las bisagras.

## Lo que cuesta

Ningún material ni dibujo más (el mostrador pierde el del acero). Suma triángulos en dos mallas
fijas: el script imprime la cuenta de cada una. La textura pasa de 512×1024 a 1024×1024 en el
grupo de edificio (tope de 1024). Es determinista e idempotente: una malla marcada con
`listones_del_frente_v2` no se toca. La imagen se reescribe igual.
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / "assets/source/textures/store/madera_lambrin.png"
PRUEBA = RAIZ / "build" / "madera" / DESTINO.name
CHAPA = (
    RAIZ
    / "assets/source/textures/third-party/european_walnut_veneer_04"
    / "european_walnut_veneer_04_diff_1k.jpg"
)
MATERIAL = "MOSTRADOR | Frente de madera"
MARCA = "listones_del_frente_v2"
SEMILLA = 20261113

# --- La imagen -------------------------------------------------------------------------------
#: La imagen mide 1 m por 1 m: una unidad de UV es un metro, igual que la chapa original.
LADO_PX = 1024
MADERA_PX = 928
RANURA_PX = (928, 960)
ZOCALO_PX = (960, 1024)
#: La madera de la referencia: media y cálida, entre nogal claro y roble ahumado.
TONO = np.array([0.62, 0.41, 0.27], dtype=np.float32)
COLOR_RANURA = np.array([0.075, 0.048, 0.032], dtype=np.float32)
COLOR_ZOCALO = np.array([0.80, 0.76, 0.69], dtype=np.float32)
#: Hasta dónde llega la madera en `u`, en metros. Una cara no pasa de acá.
U_MADERA = MADERA_PX / LADO_PX

# --- La geometría, en metros del mundo ---------------------------------------------------------
ANCHO_LISTON = 0.035
RANURA = 0.010
HONDO = 0.015
#: Cuánto entran los listones del mostrador desde el plano viejo: la losa vuela esto sobre ellos.
ENTRADA = 0.025
#: Cuánto más atrás que los listones queda el zócalo.
ZOCALO_RETIRADO = 0.035
BANDA = 0.07
#: El canto liso donde el listonado termina: en cada esquina del mostrador y en la compuerta.
CANTO = 0.03
TOLERANCIA = 1e-3


def pintar(chapa: np.ndarray) -> np.ndarray:
    """La imagen entera, (LADO_PX, LADO_PX, 3) en sRGB 0..1, con la fila 0 abajo.

    `chapa` es la foto del enchapado, (alto, ancho, 3) en sRGB, con la veta en horizontal y que
    se repite en los dos ejes.
    """
    azar = np.random.default_rng(SEMILLA)
    imagen = np.zeros((LADO_PX, LADO_PX, 3), dtype=np.float32)
    # La veta pasa a vertical: la chapa gira un cuarto de vuelta.
    madera = np.rot90(chapa)[:LADO_PX, :MADERA_PX].astype(np.float32).copy()
    # El tono medio sale del color buscado. El contraste de la veta se conserva.
    madera *= TONO / madera.reshape(-1, 3).mean(axis=0)
    imagen[:, :MADERA_PX] = madera
    ruido = azar.normal(0.0, 0.02, size=(LADO_PX, 1, 1)).astype(np.float32)
    imagen[:, RANURA_PX[0]:RANURA_PX[1]] = COLOR_RANURA * (1.0 + ruido)
    imagen[:, ZOCALO_PX[0]:ZOCALO_PX[1]] = COLOR_ZOCALO * (1.0 + ruido * 0.5)
    return np.clip(imagen, 0.0, 1.0)


# ---------------------------------------------------------------------------------------------
# Lo que sigue necesita Blender.
# ---------------------------------------------------------------------------------------------

U_RANURA = (RANURA_PX[0] + RANURA_PX[1]) / 2 / LADO_PX
U_ZOCALO = (ZOCALO_PX[0] + ZOCALO_PX[1]) / 2 / LADO_PX


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

    def u_al_azar(self, ancho: float) -> float:
        """Dónde empieza en `u` un tramo de madera de `ancho` metros."""
        return float(self.azar.random()) * max(U_MADERA - ancho - 1e-3, 0.0)

    def liso(self, a, b, n, z0, z1, vertical: bool) -> None:
        """Una tira plana de `a` a `b`, de `z0` a `z1`, de enchapado liso.

        Con `vertical` la veta corre de `z0` a `z1`. Si no, de `a` a `b`.
        """
        from mathutils import Vector  # type: ignore[import-not-found]

        largo = (b - a).length
        pts = [Vector((a.x, a.y, z0)), Vector((b.x, b.y, z0)),
               Vector((b.x, b.y, z1)), Vector((a.x, a.y, z1))]
        v0 = float(self.azar.random())
        if vertical:
            u0 = self.u_al_azar(largo)
            uvs = [(u0, v0 + z0), (u0 + largo, v0 + z0), (u0 + largo, v0 + z1), (u0, v0 + z1)]
        else:
            u0 = self.u_al_azar(z1 - z0)
            uvs = [(u0, v0), (u0, v0 + largo), (u0 + z1 - z0, v0 + largo), (u0 + z1 - z0, v0)]
        self.cara(pts, Vector((n.x, n.y, 0.0)), uvs)

    def zocalo(self, a, b, n, z0, z1) -> None:
        """Una tira plana del color del zócalo."""
        from mathutils import Vector  # type: ignore[import-not-found]

        pts = [Vector((a.x, a.y, z0)), Vector((b.x, b.y, z0)),
               Vector((b.x, b.y, z1)), Vector((a.x, a.y, z1))]
        self.cara(pts, Vector((n.x, n.y, 0.0)), [(U_ZOCALO, 0.5)] * 4)

    def horizontal(self, a, b, n, z, hondo: float, hacia_arriba: bool, color=None) -> None:
        """Una tapa horizontal de `a` a `b`, `hondo` hacia adentro. Sin `color`, de madera."""
        from mathutils import Vector  # type: ignore[import-not-found]

        pts = [Vector((a.x, a.y, z)), Vector((b.x, b.y, z)),
               Vector((b.x - n.x * hondo, b.y - n.y * hondo, z)),
               Vector((a.x - n.x * hondo, a.y - n.y * hondo, z))]
        if color is None:
            largo = (b - a).length
            u0, v0 = self.u_al_azar(hondo), float(self.azar.random())
            uvs = [(u0, v0), (u0, v0 + largo), (u0 + hondo, v0 + largo), (u0 + hondo, v0)]
        else:
            uvs = [(color, 0.5)] * 4
        self.cara(pts, Vector((0.0, 0.0, 1.0 if hacia_arriba else -1.0)), uvs)

    def listones(self, a, b, n, z0, z1) -> int:
        """Listones verticales con ranuras de `a` a `b`. Devuelve cuántos son."""
        from mathutils import Vector  # type: ignore[import-not-found]

        largo = (b - a).length
        d = (b - a) / largo
        cuantos = max(1, round((largo + RANURA) / (ANCHO_LISTON + RANURA)))
        ancho = (largo - (cuantos - 1) * RANURA) / cuantos

        def punto(s: float, z: float, hondo: float):
            q = a + d * s - n * hondo
            return Vector((q.x, q.y, z))

        normal = Vector((n.x, n.y, 0.0))
        lado_x = Vector((d.x, d.y, 0.0))
        for i in range(cuantos):
            desde = i * (ancho + RANURA)
            hasta = desde + ancho
            u0 = self.u_al_azar(ancho)
            v0 = float(self.azar.random())
            self.cara([punto(desde, z0, 0), punto(hasta, z0, 0), punto(hasta, z1, 0),
                       punto(desde, z1, 0)], normal,
                      [(u0, v0 + z0), (u0 + ancho, v0 + z0), (u0 + ancho, v0 + z1),
                       (u0, v0 + z1)])
            if i == cuantos - 1:
                continue
            siguiente = hasta + RANURA
            oscuro = [(U_RANURA, 0.5)] * 4
            self.cara([punto(hasta, z0, 0), punto(hasta, z0, HONDO), punto(hasta, z1, HONDO),
                       punto(hasta, z1, 0)], lado_x, oscuro)
            self.cara([punto(hasta, z0, HONDO), punto(siguiente, z0, HONDO),
                       punto(siguiente, z1, HONDO), punto(hasta, z1, HONDO)], normal, oscuro)
            self.cara([punto(siguiente, z0, HONDO), punto(siguiente, z0, 0),
                       punto(siguiente, z1, 0), punto(siguiente, z1, HONDO)], -lado_x, oscuro)
        self.horizontal(a, b, n, z0, HONDO, True, U_RANURA)
        self.horizontal(a, b, n, z1, HONDO, False, U_RANURA)
        return cuantos

    def enchapar(self, caras) -> None:
        """Reparte la veta sobre caras que ya existen, desde las coordenadas del mundo.

        La veta corre a lo largo de la dimensión mayor de la cara. Dos caras vecinas del mismo
        alto comparten el tramo de `u`, y la `v` sale del mundo: la veta sigue de una a otra.
        """
        from mathutils import Vector  # type: ignore[import-not-found]

        for c in caras:
            pts, n = mundo(self, c)
            if abs(n.z) > 0.9:
                tangente = Vector((1.0, 0.0, 0.0))
            else:
                tangente = Vector((-n.y, n.x, 0.0)).normalized()
            h = [p.dot(tangente) for p in pts]
            z = [p.z for p in pts]
            ancho_h, alto_z = max(h) - min(h), max(z) - min(z)
            for lazo, p in zip(c.loops, pts):
                if abs(n.z) > 0.9:
                    lazo[self.uv].uv = (0.02 + (p.y - min(q.y for q in pts)) % 0.85, p.x)
                elif alto_z > 1.5 * ancho_h:
                    lazo[self.uv].uv = (0.02 + (p.dot(tangente) - min(h)), p.z)
                else:
                    lazo[self.uv].uv = (0.02 + (p.z - min(z)), p.dot(tangente))

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


def frente_listonado(obra: Obra, a, b, n, z0, z1, banda: bool) -> int:
    """Un paño del frente: cantos lisos en las puntas, listones en medio y, con `banda`, una
    banda lisa arriba. Devuelve cuántos listones."""
    d = (b - a).normalized()
    ca, cb = a + d * CANTO, b - d * CANTO
    obra.liso(a, ca, n, z0, z1, vertical=True)
    obra.liso(cb, b, n, z0, z1, vertical=True)
    z_listones = z1 - BANDA if banda else z1
    if banda:
        obra.liso(ca, cb, n, z_listones, z1, vertical=False)
    return obra.listones(ca, cb, n, z0, z_listones)


def rehacer_mostrador(objeto, azar) -> None:
    obra = Obra(objeto, objeto.data.materials.find(MATERIAL), azar)
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
    z_cuerpo0 = min(alturas)
    todos = [objeto.matrix_world @ v.co for v in obra.bm.verts]
    z_piso = min(p.z for p in todos)
    z_losa = min(p.z for c in obra.bm.faces if c.material_index not in (madera, acero)
                 for p in mundo(obra, c)[0])
    esquinas = lazo_de_paredes(paredes)
    obra.borrar(reemplazar)
    cuenta = 0
    retiro = ENTRADA + ZOCALO_RETIRADO
    for a, b, n in lados(esquinas, retiro):
        obra.zocalo(a, b, n, z_piso, z_cuerpo0)
    for a, b, n in lados(esquinas, ENTRADA):
        cuenta += frente_listonado(obra, a, b, n, z_cuerpo0, z_losa, banda=True)
        # El suelo de los listones, que une el plano del zócalo con el de ellos.
        obra.horizontal(a, b, n, z_cuerpo0, ZOCALO_RETIRADO, False)
    obra.cerrar()
    print(f"{objeto.name}: {cuenta} listones")


def rehacer_compuerta(objeto, azar) -> None:
    from mathutils import Vector  # type: ignore[import-not-found]

    obra = Obra(objeto, objeto.data.materials.find(MATERIAL), azar)
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
    p = lambda x, y: Vector((x, y))  # noqa: E731
    # Las dos caras: canto liso en el extremo libre (`x0`) y abajo, listones en el resto.
    cuenta = 0
    for y, n in ((y1, p(0, 1)), (y0, p(0, -1))):
        a, b = p(x0, y), p(x1, y)
        obra.liso(a, a + p(CANTO, 0), n, z0, z1, vertical=True)
        obra.liso(a + p(CANTO, 0), b, n, z0, z0 + CANTO, vertical=False)
        cuenta += obra.listones(a + p(CANTO, 0), b, n, z0 + CANTO, z1)
    # Los cantos: el extremo libre y el de abajo, lisos. Arriba y la bisagra quedan cerrados.
    obra.liso(p(x0, y1), p(x0, y0), p(-1, 0), z0, z1, vertical=True)
    obra.liso(p(x1, y0), p(x1, y1), p(1, 0), z0, z1, vertical=True)
    obra.horizontal(p(x0, y0), p(x1, y0), p(0, -1), z0, y1 - y0, False)
    obra.horizontal(p(x0, y1), p(x1, y1), p(0, 1), z1, y1 - y0, True)
    obra.enchapar([c for c in tapa])
    obra.cerrar()
    print(f"{objeto.name}: {cuenta} listones")


def rehacer_friso(objeto, azar) -> None:
    obra = Obra(objeto, 0, azar)
    obra.enchapar(list(obra.bm.faces))
    obra.cerrar()
    print(f"{objeto.name}: {len(objeto.data.polygons)} caras enchapadas")


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
