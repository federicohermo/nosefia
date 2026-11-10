"""Arma de nuevo las bolsas de papas y de chizitos: cuerpo inflado, costados curvos y aletas de costura.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/armar_bolsas.py -- [--aplicar]

Sin `--aplicar` sólo cambia la sesión de Blender. Con `--aplicar` guarda la fuente canónica.
Después van `exportar_modelo.py` y `extraer_mallas.gd`.

## Por qué

La bolsa del artista era un prisma: frente plano, fuelles en ángulo y hombros rectos. Se leía
como una caja. Su UV, además, no seguía el desplegado de la textura: el fuelle del dorso de las
papas estaba al revés y encima del dorso, y el dorso se leía espejado.

## Qué cambia

La malla se rehace entera dentro de la misma caja que ocupaba la bolsa, y entra donde entraba.

- **El cuerpo** tiene sección de superelipse: el frente casi plano y los costados redondos, que
  dan la vuelta hasta el dorso. El grosor se cierra suave hacia arriba y hacia abajo, como una
  bolsa con aire, y no pasa del grosor de la bolsa anterior.
- **Las costuras** son aletas planas arriba y abajo.
- **La UV** sale del desplegado de la textura: el frente, el dorso y los costados toman su
  recorte, y las aletas el de la tapa y el de la base. Las dos texturas comparten el desplegado.
  Los vértices se comparten entre recortes: la luz no marca la costura de la UV.

## Lo que cuesta

Unos 400 triángulos por bolsa, y ningún dibujo. La caja de la bolsa se guarda en la malla la
primera vez: correrlo de nuevo rehace la misma bolsa.
"""

import math
import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

Rect = tuple[float, float, float, float]

#: Las bolsas que se arman: una unidad de cada producto, que comparte la malla con las demás.
BOLSAS = ("chisitos2-convcol.001", "snackpapas1-convcol.002")

#: Los recortes del desplegado, como (u0, u1, v0, v1). Las dos texturas lo comparten. Medidos en
#: la imagen, con un margen de 4 milésimas para que el borde negro del desplegado no se cuele.
DESPLEGADO: dict[str, Rect] = {
    "frente": (0.1388, 0.5032, 0.1499, 0.8206),
    "dorso": (0.5423, 0.8668, 0.1499, 0.8206),
    "izquierda": (0.0199, 0.1005, 0.1499, 0.8206),
    "derecha": (0.9003, 0.9793, 0.1499, 0.8206),
    "tapa": (0.1507, 0.8485, 0.8660, 0.9657),
    "base": (0.1467, 0.8517, 0.0263, 0.1108),
}

ANILLOS = 11
GAJOS_DEL_FRENTE = 7
GAJOS_DEL_COSTADO = 3
#: Desde qué ángulo de la sección empieza el costado. El frente va de este ángulo a pi menos él.
COSTADO = 0.5
#: Qué tan plano es el frente: con 2 la sección sería una elipse.
PLANITUD = 5.0
#: El alto de cada aleta, en fracción del alto de la bolsa.
ALETA = 0.07
#: Qué parte del grosor anterior conserva el centro de la bolsa.
GROSOR = 0.85
#: Cuánto se separa cada cara de la aleta del plano medio, para que no se pisen.
SEPARACION = 0.002
MARCA = "caja_de_la_bolsa"


def potencia(valor: float, exponente: float) -> float:
    return math.copysign(abs(valor) ** exponente, valor)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def armar(objeto, desplegado: dict[str, Rect]) -> tuple[int, int]:
    malla = objeto.data
    antes = sum(len(p.vertices) - 2 for p in malla.polygons)
    if MARCA not in malla:
        xs = [v.co.x for v in malla.vertices]
        ys = [v.co.y for v in malla.vertices]
        zs = [v.co.z for v in malla.vertices]
        malla[MARCA] = [min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)]
    x0, x1, y0, y1, z0, z1 = malla[MARCA]
    xc, grosor = (x0 + x1) / 2, (x1 - x0) / 2 * GROSOR
    yc, ancho = (y0 + y1) / 2, (y1 - y0) / 2
    aleta = (z1 - z0) * ALETA
    abajo, arriba = z0 + aleta, z1 - aleta

    # Los ángulos de la sección y la cara a la que pertenece cada tramo. El frente mira a +x.
    tramos = [
        ("derecha", -COSTADO, COSTADO, GAJOS_DEL_COSTADO),
        ("frente", COSTADO, math.pi - COSTADO, GAJOS_DEL_FRENTE),
        ("izquierda", math.pi - COSTADO, math.pi + COSTADO, GAJOS_DEL_COSTADO),
        ("dorso", math.pi + COSTADO, 2 * math.pi - COSTADO, GAJOS_DEL_FRENTE),
    ]
    angulos: list[float] = []
    caras_de_tramo: list[str] = []
    for nombre, desde, hasta, gajos in tramos:
        for k in range(gajos):
            angulos.append(lerp(desde, hasta, k / gajos))
            caras_de_tramo.append(nombre)
    vueltas = len(angulos)
    borde_del_frente = potencia(math.cos(COSTADO), 2 / PLANITUD)

    def seccion(angulo: float) -> tuple[float, float]:
        return potencia(math.cos(angulo), 2 / PLANITUD), math.sin(angulo)

    vertices: list[tuple[float, float, float]] = []
    caras: list[tuple[list[int], list[tuple[float, float]]]] = []
    anillos: list[list[int]] = []
    for i in range(ANILLOS + 1):
        t = i / ANILLOS
        espesor = grosor * max(0.0, 1 - abs(2 * t - 1) ** 3) ** 0.5
        z = lerp(abajo, arriba, t)
        anillo = []
        for angulo in angulos:
            c, s = seccion(angulo)
            anillo.append(len(vertices))
            vertices.append((xc + espesor * s, yc + ancho * c, z))
        anillos.append(anillo)

    def uv(cara: str, angulo: float, t: float) -> tuple[float, float]:
        u0, u1, v0, v1 = desplegado[cara]
        c, _ = seccion(angulo)
        if cara == "frente":
            a = (c + borde_del_frente) / (2 * borde_del_frente)
        elif cara == "dorso":
            a = (borde_del_frente - c) / (2 * borde_del_frente)
        elif cara == "derecha":
            # Mirado desde afuera, el costado derecho va del frente al dorso.
            a = (COSTADO - angulo) / (2 * COSTADO)
        else:
            a = (math.pi + COSTADO - angulo) / (2 * COSTADO)
        return lerp(u0, u1, min(max(a, 0.0), 1.0)), lerp(v0, v1, t)

    for i in range(ANILLOS):
        for k in range(vueltas):
            m = (k + 1) % vueltas
            cara = caras_de_tramo[k]
            # El último gajo de un tramo cierra en el primer ángulo del siguiente.
            fin = angulos[m] if m else 2 * math.pi - COSTADO
            ids = [anillos[i][k], anillos[i][m], anillos[i + 1][m], anillos[i + 1][k]]
            t0, t1 = i / ANILLOS, (i + 1) / ANILLOS
            uvs = [uv(cara, angulos[k], t0), uv(cara, fin, t0), uv(cara, fin, t1), uv(cara, angulos[k], t1)]
            caras.append((ids, uvs))

    # Las aletas: una cara por lado, con la tapa o la base del desplegado partida al medio.
    for nombre, borde, punta in (("base", abajo, z0), ("tapa", arriba, z1)):
        u0, u1, v0, v1 = desplegado[nombre]
        medio = (u0 + u1) / 2
        for lado in (1, -1):
            x = xc + lado * SEPARACION
            ids = []
            for y, z in ((y0, borde), (y1, borde), (y1, punta), (y0, punta)):
                ids.append(len(vertices))
                vertices.append((x, y, z))
            if nombre == "tapa":
                va, vb = v0, v1
            else:
                va, vb = v1, v0
            if lado == 1:
                uvs = [(u0, va), (medio, va), (medio, vb), (u0, vb)]
            else:
                uvs = [(u1, va), (medio, va), (medio, vb), (u1, vb)]
            caras.append((ids, uvs))

    # Toda cara mira hacia afuera del centro de la bolsa.
    centro = (xc, yc, (z0 + z1) / 2)
    ordenadas = []
    for ids, uvs in caras:
        p = [vertices[i] for i in ids]
        normal = [0.0, 0.0, 0.0]
        for a, b in zip(p, p[1:] + p[:1]):
            normal[0] += (a[1] - b[1]) * (a[2] + b[2])
            normal[1] += (a[2] - b[2]) * (a[0] + b[0])
            normal[2] += (a[0] - b[0]) * (a[1] + b[1])
        medio = [sum(q[j] for q in p) / len(p) for j in range(3)]
        afuera = [medio[j] - centro[j] for j in range(3)]
        if len(p) == 4 and abs(p[0][0] - p[1][0]) < 1e-9 and abs(p[0][0] - p[2][0]) < 1e-9:
            # Una aleta es plana: mira hacia su lado.
            afuera = [p[0][0] - xc, 0.0, 0.0]
        if sum(normal[j] * afuera[j] for j in range(3)) < 0:
            ids, uvs = ids[::-1], uvs[::-1]
        ordenadas.append((ids, uvs))

    malla.clear_geometry()
    malla.from_pydata(vertices, [], [ids for ids, _ in ordenadas])
    malla.update()
    capa = malla.uv_layers.new(name="UVMap")
    cuerpo = len(ordenadas) - 4
    for indice, (poligono, (_, uvs)) in enumerate(zip(malla.polygons, ordenadas)):
        poligono.use_smooth = indice < cuerpo
        for lazo, valor in zip(poligono.loop_indices, uvs):
            capa.data[lazo].uv = valor
    despues = sum(len(p.vertices) - 2 for p in malla.polygons)
    return antes, despues


def main() -> None:
    configurar()
    for nombre in BOLSAS:
        objeto = bpy.data.objects[nombre]
        antes, despues = armar(objeto, DESPLEGADO)
        print(f"{nombre}: {antes} -> {despues} triángulos, en {objeto.data.users} unidades")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
