"""Arma la ventanilla de atención: paño de vidrio arriba, tabla de madera y escuadras.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/ventanilla_de_madera.py -- [--aplicar]

Sin `--aplicar` guarda `reports/ventanilla-de-madera.blend` y no toca la fuente. Con `--aplicar`
guarda la fuente y reescribe `aluminio_del_local_{color,orm}.png`. Después van `armar_atlas.py`,
`exportar_modelo.py`, `integrar_modelo.py`, `assets/models/extraer_mallas.gd` y los dos horneados.

## Qué cambia

- **El hueco de la pared sube** de `2,44` a `2,74`. Abajo sigue siendo la abertura por la que se
  atiende; los 30 cm de arriba son un paño fijo.
- **El marco** (`local_marco_ventanilla`) se rehace con sus mismos perfiles: las dos jambas suben
  hasta el dintel nuevo, y un travesaño separa la abertura del paño.
- **El paño** (`local_vidrio_sobre_ventanilla`) es un vidrio fijo entre el travesaño y el dintel.
  `local_vidrio_ventanilla` no se toca: el juego lo esconde, y los mapas de luz lo nombran.
- **La tabla** (`local_tabla_ventanilla`) lleva la madera de las sillas. Es una sola pieza que
  pasa entre las dos jambas y se apoya sobre el perfil de abajo: no tapa ninguna cara del marco.
  Para eso el perfil de abajo baja 4 cm, y la tabla ocupa su lugar en la abertura.
- **Las escuadras** (`local_escuadra_ventanilla`) sostienen la tabla del lado de adentro, con el
  aluminio del marco.
- **La manija** (`local_manija_ventanilla`) va en el travesaño, del lado de adentro: es de donde
  se baja el vidrio.

Es idempotente: todo sale de las medidas de este archivo, y la pared se mide antes de moverla.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]
import numpy as np
from mathutils import Matrix, Vector  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parent))
import metal_con_detalle  # noqa: E402
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
REPORTE = RAIZ / "reports/ventanilla-de-madera.blend"
TEXTURAS_DE_REPORTE = RAIZ / "reports/ventanilla-de-madera-texturas"

PARED = "almacen-col"
MARCO = "local_marco_ventanilla"
VIDRIO = "local_vidrio_ventanilla"
PANO = "local_vidrio_sobre_ventanilla"
TABLA = "local_tabla_ventanilla"
ESCUADRAS = "local_escuadra_ventanilla"
ALUMINIO = "local_aluminio"
MADERA = "SILLA | Patas de madera"
CONJUNTO = "aluminio_del_local"

# El hueco de la pared: de costado a costado, y de la cara de afuera a la de adentro.
HUECO_X = (-1.5, -0.1)
AFUERA, ADENTRO = -6.4, -6.28
DINTEL_VIEJO = 2.44
DINTEL = 2.74
# El marco: sus caras de afuera y de adentro, y sus perfiles.
MARCO_Y = (-6.41, -6.27)
MARCO_X = (-1.54, -1.47, -0.13, -0.05)
# El perfil de abajo queda debajo de la tabla, que se apoya en él.
MARCO_ABAJO = (0.96, 1.03)
# Cuánto entra en la pared el perfil de arriba: el resto asoma en la abertura, como las jambas.
ENTRADA_DEL_DINTEL = 0.04
# El travesaño va sobre la abertura: su canto de abajo es el dintel de antes.
TRAVESANO = (2.44, 2.51)
PERFIL = 0.07
# La tabla: su cara de arriba es la del apoyo de las entregas.
TAPA = 1.08
GROSOR = 0.05
BORDE_DE_ADENTRO = -5.78
LUZ_CON_LA_JAMBA = 0.002
MANIJA = "local_manija_ventanilla"
# La manija: el largo de su barra, su grosor y cuánto se separa del travesaño.
MANIJA_LARGO = 0.16
MANIJA_GROSOR = 0.012
MANIJA_SEPARACION = 0.035
# Las escuadras, medidas desde la pared.
ESCUADRA_X = (-1.3, -0.3)
BARRA = 0.025
BRAZO = 0.40
PARANTE = 0.28
# La franja de tablas limpias del atlas de madera de las sillas, en UV.
MADERA_V = (0.02, 0.27)
TOLERANCIA = 1e-4


def _caja(bm, desde, hasta) -> list:
    """Una caja entre dos esquinas, con una cara por lado y la normal hacia afuera."""
    (x0, y0, z0), (x1, y1, z1) = desde, hasta
    v = [bm.verts.new(p) for p in (
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1),
    )]
    caras = [
        (0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7),
    ]
    return [bm.faces.new([v[i] for i in cara]) for cara in caras]


def _escribir(nombre: str, bm, material: str, como):
    """Deja la malla `bm` en el objeto `nombre`, que se crea junto a `como` si no existe."""
    objeto = bpy.data.objects.get(nombre)
    if objeto is None:
        objeto = bpy.data.objects.new(nombre, bpy.data.meshes.new(nombre))
        for coleccion in como.users_collection:
            coleccion.objects.link(objeto)
    malla = objeto.data
    bm.normal_update()
    bm.to_mesh(malla)
    bm.free()
    malla.materials.clear()
    malla.materials.append(bpy.data.materials[material])
    if not malla.uv_layers:
        malla.uv_layers.new(name="UVMap")
    malla.update()
    return objeto


def subir_el_hueco() -> int:
    """Sube el dintel del hueco de la pared.

    Las dos caras de la pared son polígonos de muchos lados que rodean el hueco, y uno de sus
    bordes pasa justo por arriba del dintel: con sólo subir las esquinas, el polígono se cruza y
    tapa la abertura. Por eso cada cara de la pared se rellena de nuevo entre su borde de afuera
    y el hueco nuevo, con la misma proyección de UV, sin caras sin área ni aristas sueltas.
    """
    objeto = bpy.data.objects[PARED]
    malla = objeto.data
    bm = bmesh.new()
    bm.from_mesh(malla)
    uv = bm.loops.layers.uv.active
    al_mundo = objeto.matrix_world
    al_objeto = al_mundo.inverted()

    def es_del_dintel(vertice) -> bool:
        p = al_mundo @ vertice.co
        return (
            abs(p.z - DINTEL_VIEJO) < TOLERANCIA
            and min(abs(p.x - x) for x in HUECO_X) < TOLERANCIA
            and min(abs(p.y - y) for y in (AFUERA, ADENTRO)) < TOLERANCIA
        )

    del_dintel = [v for v in bm.verts if es_del_dintel(v)]
    if not del_dintel:
        bm.free()
        return 0
    assert len(del_dintel) == 4, f"el hueco tiene {len(del_dintel)} esquinas de dintel"

    def ajuste_de(caras) -> np.ndarray:
        puntos = np.array([[*(al_mundo @ l.vert.co), 1.0] for c in caras for l in c.loops])
        uvs = np.array([tuple(l[uv].uv) for c in caras for l in c.loops])
        ajuste = np.linalg.lstsq(puntos, uvs, rcond=None)[0]
        assert np.abs(puntos @ ajuste - uvs).max() < 1e-3, "la UV de la pared no es plana"
        return ajuste

    def uv_de(vertice, ajuste) -> tuple:
        return tuple(np.array([*(al_mundo @ vertice.co), 1.0]) @ ajuste)

    tocadas = {c for v in del_dintel for c in v.link_faces}
    planos = {}
    for y in (AFUERA, ADENTRO):
        caras = {
            c for c in tocadas
            if all(abs((al_mundo @ v.co).y - y) < TOLERANCIA for v in c.verts)
        }
        planos[y] = (caras, ajuste_de(caras), next(iter(caras)).normal.copy(),
                     next(iter(caras)).material_index)
    de_la_pared = set().union(*(p[0] for p in planos.values()))
    mochetas = {c: ajuste_de([c]) for c in tocadas - de_la_pared
                if not all(v in del_dintel for v in c.verts)}

    for vertice in del_dintel:
        p = al_mundo @ vertice.co
        p.z = DINTEL
        vertice.co = al_objeto @ p
    for cara, ajuste in mochetas.items():
        for lazo in cara.loops:
            lazo[uv].uv = uv_de(lazo.vert, ajuste)

    for caras, ajuste, normal, material in planos.values():
        borde = {
            lazo.edge for cara in caras for lazo in cara.loops
            if sum(1 for c in lazo.edge.link_faces if c in caras) == 1
        }
        de_adentro = {arista for cara in caras for arista in cara.edges} - borde
        bmesh.ops.delete(bm, geom=list(caras), context="FACES_ONLY")
        bmesh.ops.delete(bm, geom=list(de_adentro), context="EDGES")
        relleno = bmesh.ops.triangle_fill(
            bm, edges=list(borde), use_beauty=True, use_dissolve=False, normal=normal
        )
        nuevas = [g for g in relleno["geom"] if isinstance(g, bmesh.types.BMFace)]
        assert nuevas, "la pared no se pudo rellenar alrededor del hueco"
        for cara in nuevas:
            assert cara.calc_area() > 1e-8, "el relleno de la pared dejó una cara sin área"
            if cara.normal.dot(normal) < 0:
                cara.normal_flip()
            cara.material_index = material
            for lazo in cara.loops:
                lazo[uv].uv = uv_de(lazo.vert, ajuste)
    assert not [a for a in bm.edges if not a.link_faces], "quedó una arista suelta en la pared"
    bm.normal_update()
    bm.to_mesh(malla)
    bm.free()
    malla.update()
    return len(del_dintel)


def rehacer_el_marco() -> None:
    marco = bpy.data.objects[MARCO]
    y0, y1 = MARCO_Y
    x0, x1, x2, x3 = MARCO_X
    arriba = DINTEL + ENTRADA_DEL_DINTEL
    bm = bmesh.new()
    _caja(bm, (x0, y0, MARCO_ABAJO[0]), (x1, y1, arriba))
    _caja(bm, (x2, y0, MARCO_ABAJO[0]), (x3, y1, arriba))
    for abajo, tope in (MARCO_ABAJO, TRAVESANO, (arriba - PERFIL, arriba)):
        _caja(bm, (x1, y0, abajo), (x2, y1, tope))
    bm.transform(marco.matrix_world.inverted())
    _escribir(MARCO, bm, ALUMINIO, marco)


def poner_el_pano() -> None:
    vidrio = bpy.data.objects[VIDRIO]
    pano = bpy.data.objects.get(PANO)
    if pano is None:
        pano = vidrio.copy()
        pano.data = vidrio.data.copy()
        pano.name = pano.data.name = PANO
        for coleccion in vidrio.users_collection:
            coleccion.objects.link(pano)
    al_objeto = pano.matrix_world.inverted()
    al_mundo = vidrio.matrix_world
    arriba = DINTEL + ENTRADA_DEL_DINTEL - PERFIL
    viejos = [al_mundo @ v.co for v in vidrio.data.vertices]
    x_medio = sum(p.x for p in viejos) / len(viejos)
    z_medio = sum(p.z for p in viejos) / len(viejos)
    for vertice, viejo in zip(pano.data.vertices, viejos):
        x = MARCO_X[1] if viejo.x < x_medio else MARCO_X[2]
        z = TRAVESANO[1] if viejo.z < z_medio else arriba
        vertice.co = al_objeto @ Vector((x, viejo.y, z))
    pano.data.update()


def poner_la_tabla() -> None:
    marco = bpy.data.objects[MARCO]
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    piso = TAPA - GROSOR
    izquierda, derecha = MARCO_X[1] + LUZ_CON_LA_JAMBA, MARCO_X[2] - LUZ_CON_LA_JAMBA
    piezas = [((izquierda, AFUERA, piso), (derecha, BORDE_DE_ADENTRO, TAPA))]
    largo = derecha - izquierda
    fondo = BORDE_DE_ADENTRO - AFUERA
    v0, v1 = MADERA_V
    for desde, hasta in piezas:
        for cara in _caja(bm, desde, hasta):
            vertical = abs(cara.normal.z) < 0.5
            for lazo in cara.loops:
                p = lazo.vert.co
                # La veta corre a lo largo de la tabla. Los cantos toman la tabla de al lado.
                if vertical and abs(cara.normal.x) > 0.5:
                    u, a = (p.y - AFUERA) / fondo, (p.z - piso) / GROSOR * 0.12
                elif vertical:
                    u, a = (p.x - izquierda) / largo, (p.z - piso) / GROSOR * 0.12
                else:
                    u, a = (p.x - izquierda) / largo, (p.y - AFUERA) / fondo
                lazo[uv].uv = (u, v0 + (v1 - v0) * a)
    bm.transform(marco.matrix_world.inverted())
    _escribir(TABLA, bm, MADERA, marco)


def poner_las_escuadras() -> None:
    marco = bpy.data.objects[MARCO]
    bm = bmesh.new()
    techo = TAPA - GROSOR
    medio = BARRA / 2
    # Arrancan en la cara del marco: el parante baja por delante del perfil de abajo.
    pared = MARCO_Y[1]
    for x in ESCUADRA_X:
        _caja(bm, (x - medio, pared, techo - BARRA), (x + medio, pared + BRAZO, techo))
        _caja(bm, (x - medio, pared, techo - PARANTE), (x + medio, pared + BARRA, techo - BARRA))
        # La tornapunta, del pie del parante a la punta del brazo.
        pie = Vector((x, pared + BARRA, techo - PARANTE + medio))
        punta = Vector((x, pared + BRAZO - BARRA, techo - BARRA))
        largo = (punta - pie).length
        barra = _caja(bm, (-medio * 0.8, 0.0, -medio * 0.8), (medio * 0.8, largo, medio * 0.8))
        giro = Matrix.Rotation(math.atan2(punta.z - pie.z, punta.y - pie.y), 4, "X")
        bmesh.ops.transform(
            bm, matrix=Matrix.Translation(pie) @ giro,
            verts=list({v for cara in barra for v in cara.verts}),
        )
    bm.transform(marco.matrix_world.inverted())
    _escribir(ESCUADRAS, bm, ALUMINIO, marco)


def poner_la_manija() -> None:
    marco = bpy.data.objects[MARCO]
    bm = bmesh.new()
    centro = (MARCO_X[1] + MARCO_X[2]) / 2
    alto = (TRAVESANO[0] + TRAVESANO[1]) / 2
    cara = MARCO_Y[1]
    g = MANIJA_GROSOR / 2
    barra = cara + MANIJA_SEPARACION
    _caja(bm, (centro - MANIJA_LARGO / 2, barra - MANIJA_GROSOR, alto - g),
          (centro + MANIJA_LARGO / 2, barra, alto + g))
    for lado in (-1, 1):
        x = centro + lado * (MANIJA_LARGO / 2 - MANIJA_GROSOR)
        _caja(bm, (x - g, cara, alto - g), (x + g, barra - MANIJA_GROSOR, alto + g))
    bm.transform(marco.matrix_world.inverted())
    _escribir(MANIJA, bm, ALUMINIO, marco)


def main() -> None:
    configurar()
    movidos = subir_el_hueco()
    print(f"pared: {movidos} esquinas del dintel subidas a {DINTEL}")
    rehacer_el_marco()
    poner_el_pano()
    poner_la_tabla()
    poner_las_escuadras()
    poner_la_manija()
    bpy.context.view_layer.update()
    conjunto = next(c for c in metal_con_detalle.CONJUNTOS if c.nombre == CONJUNTO)
    aplicar = "--aplicar" in sys.argv
    print(metal_con_detalle.aplicar(
        conjunto, metal_con_detalle.CARPETA if aplicar else TEXTURAS_DE_REPORTE
    ))
    for nombre in (MARCO, PANO, TABLA, ESCUADRAS, MANIJA):
        objeto = bpy.data.objects[nombre]
        puntos = [objeto.matrix_world @ v.co for v in objeto.data.vertices]
        print(nombre, [
            (round(min(p[i] for p in puntos), 3), round(max(p[i] for p in puntos), 3))
            for i in range(3)
        ], f"{sum(len(p.vertices) - 2 for p in objeto.data.polygons)} triángulos")
    if aplicar:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        REPORTE.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(REPORTE), check_existing=False)
        print(f"prueba guardada en {REPORTE}")


if __name__ == "__main__":
    main()
