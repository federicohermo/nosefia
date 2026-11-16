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
- **Las costuras** son aletas planas arriba y abajo. Cada una sigue el borde del frente o del
  dorso: el cierre no lleva letras.
- **La UV** sale del desplegado de la textura: el frente, el dorso y los costados toman su
  recorte. Las dos texturas comparten el desplegado.
  Los vértices se comparten entre recortes: la luz no marca la costura de la UV.

## Las galletitas

Petisas, Macumbas y Don Saturados eran un prisma de seis caras con una mitad de textura en cada
cara. Pasan por la misma construcción, con tres diferencias:

- **El cierre** es el de `lib/cierre_de_envases.py`, el mismo de los paquetes de Oremos y Pepito:
  una aleta plana de borde recto, como la de Chisitos y Lay'snt't. Las papas usan esa misma
  construcción y salen igual que siempre, vértice por vértice.
- **El desplegado** es el de `lib/desplegado_de_bolsas.py`: una sola textura de 512 x 352 con
  frente, dorso y los dos costados acostados, en lugar del par `completo` y `costado`.
- **El frente** mira a `-x`, como mira hoy cada una de las tres. El ancho y el alto de la caja que
  ocupaba no cambian. El fondo sí: la bolsa es más flaca que el prisma (dos tercios de su grosor),
  y el estante la mide más angosta, con las mismas filas y la misma cantidad por fila.
- **La forma** sigue la de Chisitos con otras proporciones. El espesor sube desde cada costura
  con un seno y llega a su máximo en el centro. El frente es más redondo (`planitud` 3,5) y el
  ancho se recoge un 4 % donde la bolsa más se infla: los costados quedan apenas cóncavos entre
  las dos aletas, que miden todo el ancho.

## Lo que cuesta

608 triángulos por bolsa de papas, 448 por bolsa de galletitas (468 la de Macumbas, con su
agujero), y ningún dibujo. La caja de la bolsa se guarda en la malla la
primera vez: correrlo de nuevo rehace la misma bolsa.
"""

import math
import sys
from dataclasses import dataclass, field
from pathlib import Path

import bpy  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib import cierre_de_envases, desplegado_de_bolsas  # noqa: E402
from lib.consola import configurar  # noqa: E402

Rect = tuple[float, float, float, float]

#: Los recortes del desplegado, como (u0, u1, v0, v1). Las dos texturas lo comparten. Medidos en
#: la imagen, con un margen de 4 milésimas para que el borde negro del desplegado no se cuele.
DESPLEGADO: dict[str, Rect] = {
    "frente": (0.1388, 0.5032, 0.1499, 0.8206),
    "dorso": (0.5423, 0.8668, 0.1499, 0.8206),
    "izquierda": (0.0199, 0.1005, 0.1499, 0.8206),
    "derecha": (0.9003, 0.9793, 0.1499, 0.8206),
}

#: El desplegado de las galletitas: una sola textura, sin el negro entre paneles. Los costados van
#: acostados: su largo corre a lo ancho de la imagen. Lo declara `lib/desplegado_de_bolsas.py`.
DESPLEGADO_DE_GALLETITAS: dict[str, Rect] = {
    nombre: desplegado_de_bolsas.recorte(nombre) for nombre in desplegado_de_bolsas.REGIONES
}
ACOSTADAS = desplegado_de_bolsas.ACOSTADAS

ANILLOS = 15
#: Qué parte del alto, en cada punta, ocupa el afinado del cuerpo hasta la costura.
TRANSICION = 0.2
GAJOS_DEL_FRENTE = 7
GAJOS_DEL_COSTADO = 3
#: Desde qué ángulo de la sección empieza el costado. El frente va de este ángulo a pi menos él.
COSTADO = 0.5
#: Qué tan plano es el frente: con 2 la sección sería una elipse.
PLANITUD = 5.0
#: El alto de cada aleta, en fracción del alto de la bolsa.
ALETA = 0.05
#: Qué franja del borde del frente o del dorso pinta la aleta, en fracción de la textura.
#: Es angosta: los sellos de advertencia arrancan a 24 píxeles de 1254 del borde del frente.
BANDA_DE_LA_ALETA = 0.014
#: Qué parte del grosor anterior conserva el centro de la bolsa.
GROSOR = 0.85
MARCA = "caja_de_la_bolsa"

ANILLOS_DE_LAS_GALLETITAS = 11
#: Qué parte del grosor de la caja que ocupaba la bolsa conserva el centro de las galletitas.
#: Es una bolsa más flaca que el prisma: el estante la mide más angosta, sin cambiar su ancho ni
#: su alto.
GROSOR_DE_LAS_GALLETITAS = 0.66
#: Qué parte del alto, en cada punta, ocupa el afinado de las galletitas. Con 0,5 el espesor sería
#: un seno de punta a punta, y con 0,2 el de las papas: 6 cm de un alto de 31. Acá son 8 cm de 24,
#: sin llegar a un tramo parejo.
TRANSICION_DE_LAS_GALLETITAS = 0.35
#: Qué tan plano es el frente de las galletitas. Más bajo que el de las papas: más redondo.
PLANITUD_DE_LAS_GALLETITAS = 3.5
#: Cuánto ancho recoge el film donde la bolsa más se infla, en fracción del ancho de la aleta.
RECOGIDA_DE_LAS_GALLETITAS = 0.04
#: El alto de la aleta de las galletitas, en fracción del alto de la bolsa: 1,56 cm, el mismo
#: que el de las papas.
ALETA_DE_LAS_GALLETITAS = 0.065
#: La franja del borde que pinta la aleta de las galletitas, en fracción de la textura.
BANDA_DE_LAS_GALLETITAS = desplegado_de_bolsas.banda_del_cierre()

#: Cuánto se aparta del plano de la costura cada hoja del cierre de las galletitas, en metros del
#: mundo. Las papas llevan `cierre_de_envases.SEPARACION` en su malla, que con su escala son
#: 0,4 mm. Las galletitas tienen otra escala: con esa misma cifra cada hoja quedaba a 1,3 mm, y
#: el cierre se veía doble y despegado de la costura, donde el cuerpo cierra en cero.
SEPARACION_DE_LAS_GALLETITAS = 0.0002

TEXTURAS = RAIZ / "assets" / "source" / "products-textured" / "bolsas"


@dataclass(frozen=True)
class Bolsa:
    """Una bolsa a armar: su unidad, que comparte la malla con las demás, y lo que la distingue.

    Las aletas las arma `lib/cierre_de_envases.py` para todas: `banda` es qué franja del borde del
    frente y del dorso pinta. `mira_a_menos_x` gira la bolsa 180
    grados sobre su eje vertical: el frente de las papas mira a `+x` y el de las galletitas a
    `-x`, que es hacia donde las acomoda `lib/reparto.py`. `textura` es la imagen que pasa a
    llevar el material, y reemplaza a la de la malla anterior. `grosor` es la fracción del
    grosor de la caja que conserva el centro; `transicion`, qué parte del alto ocupa el afinado en
    cada punta; `planitud`, qué tan plano es el frente; `recogida`, cuánto ancho se recoge donde
    la bolsa es más gruesa.
    `acostadas` son los costados cuyo
    recorte va acostado en la textura: las papas llevan los suyos de pie, y mezclarlos rompe su UV.
    """

    objeto: str
    desplegado: dict[str, Rect] = field(default_factory=lambda: DESPLEGADO)
    mira_a_menos_x: bool = False
    anillos: int = ANILLOS
    grosor: float = GROSOR
    transicion: float = TRANSICION
    planitud: float = PLANITUD
    recogida: float = 0.0
    aleta: float = ALETA
    textura: Path | None = None
    acostadas: tuple[str, ...] = ()
    banda: float = BANDA_DE_LA_ALETA
    separacion_en_metros: float | None = None


#: Las bolsas que se arman. Las papas llevan la aleta plana de siempre y las galletitas, con la
#: misma forma: una aleta plana de borde recto en las cinco, como la de los paquetes.
BOLSAS = (
    Bolsa("chisitos2-convcol.001"),
    Bolsa("snackpapas1-convcol.002"),
    *(
        Bolsa(
            objeto,
            desplegado=DESPLEGADO_DE_GALLETITAS,
            mira_a_menos_x=True,
            anillos=ANILLOS_DE_LAS_GALLETITAS,
            grosor=GROSOR_DE_LAS_GALLETITAS,
            transicion=TRANSICION_DE_LAS_GALLETITAS,
            planitud=PLANITUD_DE_LAS_GALLETITAS,
            recogida=RECOGIDA_DE_LAS_GALLETITAS,
            aleta=ALETA_DE_LAS_GALLETITAS,
            textura=TEXTURAS / f"{producto}.png",
            acostadas=ACOSTADAS,
            banda=BANDA_DE_LAS_GALLETITAS,
            separacion_en_metros=SEPARACION_DE_LAS_GALLETITAS,
        )
        for objeto, producto in (
            ("petisas-convcol", "petisas"),
            ("macumbas-convcol", "macumbas"),
            ("donsaturados-convcol.001", "donsaturados"),
        )
    ),
)


def potencia(valor: float, exponente: float) -> float:
    return math.copysign(abs(valor) ** exponente, valor)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def armar(objeto, bolsa: Bolsa) -> tuple[int, int]:
    malla = objeto.data
    desplegado, anillos_totales = bolsa.desplegado, bolsa.anillos
    antes = sum(len(p.vertices) - 2 for p in malla.polygons)
    if MARCA not in malla:
        xs = [v.co.x for v in malla.vertices]
        ys = [v.co.y for v in malla.vertices]
        zs = [v.co.z for v in malla.vertices]
        malla[MARCA] = [min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)]
    x0, x1, y0, y1, z0, z1 = malla[MARCA]
    xc, grosor = (x0 + x1) / 2, (x1 - x0) / 2 * bolsa.grosor
    yc, ancho = (y0 + y1) / 2, (y1 - y0) / 2
    aleta = (z1 - z0) * bolsa.aleta
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
    borde_del_frente = potencia(math.cos(COSTADO), 2 / bolsa.planitud)

    def seccion(angulo: float) -> tuple[float, float]:
        return potencia(math.cos(angulo), 2 / bolsa.planitud), math.sin(angulo)

    vertices: list[tuple[float, float, float]] = []
    # Cada cara lleva sus vértices, su UV y si ya mira hacia afuera: las del cierre lo traen de
    # `cierre_de_envases`, y las del cuerpo y las aletas lisas se ordenan más abajo.
    caras: list[tuple[list[int], list[tuple[float, float]], bool]] = []
    anillos: list[list[int]] = []
    # Los anillos se juntan cerca de las costuras, donde la bolsa se cierra.
    alturas = [
        0.5 - 0.5 * math.cos(math.pi * i / anillos_totales) for i in range(anillos_totales + 1)
    ]

    def espesor_en(t: float) -> float:
        # El cuerpo se afina de a poco hacia cada costura: sin quiebre donde empieza la curva, y en
        # cero en la costura, donde sigue la aleta.
        return grosor * math.sin(math.pi / 2 * min(1.0, min(t, 1 - t) / bolsa.transicion))

    # La v de cada anillo sigue el largo de la superficie del frente, no la altura: el arte se
    # reparte parejo sobre la curva y no se aplasta cerca de la costura.
    largos = [0.0]
    for t0, t1 in zip(alturas, alturas[1:]):
        dz = (t1 - t0) * (arriba - abajo)
        largos.append(largos[-1] + math.hypot(dz, espesor_en(t1) - espesor_en(t0)))
    recorridos = [largo / largos[-1] for largo in largos]

    for i, t in enumerate(alturas):
        espesor = espesor_en(t)
        z = lerp(abajo, arriba, t)
        anillo = []
        # Donde la bolsa se infla, el film se recoge: el ancho baja con el espesor y vuelve a ser el
        # de la aleta en cada costura.
        ancho_aca = ancho * (1.0 - bolsa.recogida * espesor / grosor)
        for angulo in angulos:
            c, s = seccion(angulo)
            anillo.append(len(vertices))
            vertices.append((xc + espesor * s, yc + ancho_aca * c, z))
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
        a = min(max(a, 0.0), 1.0)
        if cara in bolsa.acostadas:
            # El costado va acostado: su alto corre a lo ancho de la imagen, y del frente al dorso
            # baja por ella. A la izquierda `a` crece del dorso al frente.
            del_frente = a if cara == "derecha" else 1.0 - a
            return lerp(u0, u1, t), lerp(v1, v0, del_frente)
        return lerp(u0, u1, a), lerp(v0, v1, t)

    for i in range(anillos_totales):
        for k in range(vueltas):
            m = (k + 1) % vueltas
            cara = caras_de_tramo[k]
            # El último gajo de un tramo cierra en el primer ángulo del siguiente.
            fin = angulos[m] if m else 2 * math.pi - COSTADO
            ids = [anillos[i][k], anillos[i][m], anillos[i + 1][m], anillos[i + 1][k]]
            t0, t1 = recorridos[i], recorridos[i + 1]
            uvs = [uv(cara, angulos[k], t0), uv(cara, fin, t0), uv(cara, fin, t1), uv(cara, angulos[k], t1)]
            caras.append((ids, uvs, False))
    cuerpo = len(caras)

    _cierres(
        vertices, caras, desplegado, (xc, y0, y1), (abajo, arriba, aleta), objeto.matrix_world.to_scale().x, bolsa
    )

    # Toda cara mira hacia afuera del centro de la bolsa.
    centro = (xc, yc, (z0 + z1) / 2)
    ordenadas = []
    for ids, uvs, orientada in caras:
        if not orientada:
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

    if bolsa.mira_a_menos_x:
        # Un giro de 180 grados sobre el eje vertical: conserva el orden de las caras.
        vertices = [(2 * xc - x, 2 * yc - y, z) for x, y, z in vertices]

    malla.clear_geometry()
    malla.from_pydata(vertices, [], [ids for ids, _ in ordenadas])
    malla.update()
    capa = malla.uv_layers.new(name="UVMap")
    for indice, (poligono, (_, uvs)) in enumerate(zip(malla.polygons, ordenadas)):
        poligono.use_smooth = indice < cuerpo
        for lazo, valor in zip(poligono.loop_indices, uvs):
            capa.data[lazo].uv = valor
    despues = sum(len(p.vertices) - 2 for p in malla.polygons)
    return antes, despues


def _entre(a: float, b: float, t: float) -> float:
    """Como `lerp`, pero los extremos salen exactos: la UV de una punta es la del recorte."""
    return a if t == 0.0 else b if t == 1.0 else lerp(a, b, t)


def _cierres(
    vertices: list[tuple[float, float, float]],
    caras: list[tuple[list[int], list[tuple[float, float]], bool]],
    desplegado: dict[str, Rect],
    ancho_y: tuple[float, float, float],
    alturas_z: tuple[float, float, float],
    escala_x: float,
    bolsa: Bolsa,
) -> None:
    """Agrega el cierre de arriba y el de abajo, armados por `lib/cierre_de_envases.py`.

    La costura de cada uno es horizontal, en el plano medio de la bolsa, y la aleta sale hacia
    arriba o hacia abajo. Cada vértice trae su `(s, t)`: `s` va a lo largo de la costura y `t`
    hacia afuera. La textura repite, en espejo, la franja de prensado del borde del frente o del
    dorso que toca la aleta.
    """
    xc, y0, y1 = ancho_y
    abajo, arriba, aleta = alturas_z
    separacion = cierre_de_envases.SEPARACION
    if bolsa.separacion_en_metros is not None:
        separacion = bolsa.separacion_en_metros / escala_x
    for arriba_de_todo, borde in ((False, abajo), (True, arriba)):
        c = cierre_de_envases.cierre(
            origen=(xc, y0, borde),
            eje=(0.0, 1.0, 0.0),
            largo=y1 - y0,
            afuera=(0.0, 0.0, 1.0 if arriba_de_todo else -1.0),
            salida=aleta,
            normal=(1.0, 0.0, 0.0),
            separacion=separacion,
        )
        base = len(vertices)
        vertices.extend(c.vertices)
        for cara in c.caras:
            panel = "frente" if cara.lado == 1 else "dorso"
            franja = desplegado.get(f"aleta_{panel}_{'arriba' if arriba_de_todo else 'abajo'}")
            u0, u1, v0, v1 = franja or desplegado[panel]
            # Con franja propia la aleta la recorre entera; sin ella repite el borde del panel.
            banda = (v1 - v0) if franja else bolsa.banda
            uvs = []
            for s, t in cara.st:
                u = _entre(u0, u1, s) if cara.lado == 1 else _entre(u1, u0, s)
                v = v1 - banda * t if arriba_de_todo else v0 + banda * t
                uvs.append((u, v))
            caras.append(([base + i for i in cara.vertices], uvs, True))


def usar_textura(malla, textura: Path) -> None:
    """Hace que el material de la bolsa lleve `textura`, y deja un solo material: el desplegado
    nuevo trae el costado adentro, y el `costado` aparte ya no se usa."""
    imagen = bpy.data.images.load(str(textura), check_existing=True)
    imagen.filepath = bpy.path.relpath(str(textura))
    imagen.reload()
    material = malla.materials[0]
    nodo = next(n for n in material.node_tree.nodes if n.type == "TEX_IMAGE")
    nodo.image = imagen
    while len(malla.materials) > 1:
        malla.materials.pop(index=len(malla.materials) - 1)


def sin_modificadores(malla) -> int:
    """Quita los modificadores de cada unidad que comparte la malla: ninguno hace falta sobre una
    bolsa con el sombreado puesto cara por cara. Devuelve cuántos quitó."""
    quitados = 0
    for objeto in bpy.data.objects:
        if objeto.data is malla and objeto.modifiers:
            quitados += len(objeto.modifiers)
            objeto.modifiers.clear()
    return quitados


def medir(objeto) -> str:
    """Lo que mide la malla de una unidad, con la escala del objeto: fondo, ancho y alto, en m."""
    medidas = []
    for eje in range(3):
        valores = [v.co[eje] * objeto.scale[eje] for v in objeto.data.vertices]
        medidas.append(f"{max(valores) - min(valores):.4f}")
    return " x ".join(medidas)


REPORTE = RAIZ / "reports" / "armar-bolsas.blend"


def main() -> None:
    configurar()
    for bolsa in BOLSAS:
        objeto = bpy.data.objects[bolsa.objeto]
        antes_de_medir = medir(objeto)
        antes, despues = armar(objeto, bolsa)
        if bolsa.textura is not None:
            usar_textura(objeto.data, bolsa.textura)
            sin_modificadores(objeto.data)
        print(
            f"{bolsa.objeto}: {antes} -> {despues} triángulos, en {objeto.data.users} unidades; "
            f"mide {antes_de_medir} -> {medir(objeto)} m"
        )
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        REPORTE.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(REPORTE), copy=True)
        print(f"guardado en {REPORTE}")


if __name__ == "__main__":
    main()
