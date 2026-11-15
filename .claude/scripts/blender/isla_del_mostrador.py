"""Cierra con un tramo corto de mostrador el hueco entre la compuerta y la pared del ventanal.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/isla_del_mostrador.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/isla-del-mostrador.blend` y no modifica el `.blend` del repo.
Con `--aplicar`, guarda la fuente canónica en su lugar. Va después de
`ajustar_compuerta_mostrador.py` y `retirar_mostrador_de_la_pared.py`, y antes de
`armar_atlas.py`, `exportar_modelo.py`, `integrar_modelo.py` y `hornear.py`.

## Por qué

Entre la compuerta y la pared oeste quedaban unos 40 cm por donde se veía el piso y el jugador
podía pasar de largo, esquivando la compuerta.

## Qué cambia

- **`mostrador_isla-col`**, un objeto nuevo: un tramo de mostrador con el mismo perfil que
  `EscritorioComputadora-col` (zócalo de acero, frente de madera, tapa de mármol con su vuelo), el
  mismo alto y el mismo fondo que su brazo. Todo sale de la malla del mostrador: el perfil, el
  alto y el fondo no tienen números fijos.
- **Su extremo oeste** queda a `LUZ_PARED` de la cara interior de `local_marco_ventanal-col`.
- **Su extremo este** queda a `HOLGURA` de lo más al oeste que alcanza la compuerta al girar. La
  bisagra está en el lado del mostrador (este) y la hoja abre hacia adentro, al sur: la punta libre
  traza un arco de radio igual a lo que separa el perno de su esquina más lejana, y el punto más
  al oeste de ese arco queda un poco más allá del canto cerrado de la hoja. La isla se apoya en
  ese punto: con la compuerta cerrada queda a tope y al girar no la toca.
- **La UV** repite la del mostrador: el frente de madera sale de `listonar_frente_de_madera.py`
  (listones enteros y misma franja de la imagen); la tapa usa metros del mundo, como la del
  mostrador; el acero copia la de las caras vecinas del zócalo, a la misma escala.
- **La colisión** sale de su malla: el sufijo `-col` y `medir_volumenes.py` (ver `NOMBRES`) la
  incluyen en la cadena.

## Lo que cuesta

Un objeto de 68 triángulos, sin materiales ni texturas nuevas: usa los tres del mostrador. Es
idempotente: borra la isla anterior y la rehace con las medidas que lee de la escena.
"""

from __future__ import annotations

import math
import sys
from dataclasses import dataclass
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]
import numpy as np
from mathutils import Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.consola import configurar  # noqa: E402

import listonar_frente_de_madera as listonar  # noqa: E402

ISLA = "mostrador_isla-col"
MALLA = "Mostrador_isla"
MOSTRADOR = "EscritorioComputadora-col"
COMPUERTA = "compuerta_mostrador"
MARCO = "local_marco_ventanal-col"
COLECCION = "gondola"
MODIFICADOR = "Smooth by Angle"
MESADA = "MOSTRADOR | Mesada blanca"
MADERA = "MOSTRADOR | Frente de madera"
ACERO = "MOSTRADOR | Acero satinado"
PRUEBA = RAIZ / "reports/isla-del-mostrador.blend"

#: El aire entre la pared y la isla, en metros.
LUZ_PARED = 0.05
#: El aire entre la isla y lo más al oeste que alcanza la hoja al girar.
HOLGURA = 0.003
#: Dónde cae el perno de la bisagra respecto de la caja de la compuerta: el tambor de 19 × 18 mm.
#: Es el que pone `lib/volumenes_modelo.py`.
PERNO_X = 0.0095
PERNO_Y = 0.009
#: Dos alturas a menos de esto son el mismo nivel del perfil.
IGUAL = 1e-5
#: El brazo del mostrador que da a la isla llega hasta acá; el otro brazo va al este de acá.
LIMITE_DEL_BRAZO_X = 0.0


@dataclass(frozen=True)
class Medidas:
    x_oeste: float
    x_este: float
    y_sur: float
    y_norte: float
    #: (altura, cuánto se retira del borde de la tapa) de cada nivel, de abajo hacia arriba.
    perfil: tuple[tuple[float, float], ...]
    pared_x: float
    perno: tuple[float, float]
    radio: float


def _objeto(nombre: str):
    objeto = bpy.data.objects.get(nombre)
    if objeto is None:
        raise SystemExit(f"falta el objeto {nombre}; no se guardó nada")
    return objeto


def _puntos(objeto) -> list[Vector]:
    return [objeto.matrix_world @ v.co for v in objeto.data.vertices]


def _con_material(objeto, nombre: str):
    indices = {i for i, m in enumerate(objeto.data.materials) if m is not None and m.name == nombre}
    return [p for p in objeto.data.polygons if p.material_index in indices]


def _perfil(mostrador) -> tuple[tuple[float, float], ...]:
    """Cada nivel del perfil del mostrador, leído en su extremo oeste."""
    puntos = _puntos(mostrador)
    borde = min(p.x for p in puntos)
    niveles: dict[float, float] = {}
    for p in puntos:
        if p.x - borde > 0.02:
            continue
        clave = next((z for z in niveles if abs(z - p.z) < IGUAL), p.z)
        retiro = p.x - borde
        if clave in niveles and abs(niveles[clave] - retiro) > 1e-4:
            raise SystemExit(f"el perfil del mostrador tiene dos retiros a z={p.z:.4f}")
        niveles[clave] = retiro
    return tuple(sorted(niveles.items()))


def medir() -> Medidas:
    mostrador = _objeto(MOSTRADOR)
    compuerta = _objeto(COMPUERTA)
    marco = _objeto(MARCO)

    tapa = [
        mostrador.matrix_world @ mostrador.data.vertices[v].co
        for p in _con_material(mostrador, MESADA)
        for v in p.vertices
    ]
    brazo = [p for p in tapa if p.x < LIMITE_DEL_BRAZO_X]
    y_sur, y_norte = min(p.y for p in brazo), max(p.y for p in brazo)

    hoja = _puntos(compuerta)
    perno = (max(p.x for p in hoja) - PERNO_X, min(p.y for p in hoja) + PERNO_Y)
    radio = max(math.hypot(p.x - perno[0], p.y - perno[1]) for p in hoja)
    pared_x = max(p.x for p in _puntos(marco))

    return Medidas(
        x_oeste=pared_x + LUZ_PARED,
        x_este=perno[0] - radio - HOLGURA,
        y_sur=y_sur,
        y_norte=y_norte,
        perfil=_perfil(mostrador),
        pared_x=pared_x,
        perno=perno,
        radio=radio,
    )


def _material_de(z_abajo: float, z_arriba: float) -> str:
    """Qué material lleva la franja entre dos niveles, como en el mostrador."""
    if z_arriba <= 0.2475:
        return ACERO
    if z_arriba <= 1.1045:
        return MADERA
    return MESADA


def construir(m: Medidas):
    centro = Vector(((m.x_oeste + m.x_este) / 2, (m.y_sur + m.y_norte) / 2, m.perfil[0][0]))
    malla = bpy.data.meshes.new(MALLA)
    nombres = (MESADA, MADERA, ACERO)
    for nombre in nombres:
        material = bpy.data.materials.get(nombre)
        if material is None:
            raise SystemExit(f"falta el material {nombre}; no se guardó nada")
        malla.materials.append(material)

    bm = bmesh.new()
    anillos = []
    for z, retiro in m.perfil:
        esquinas = (
            (m.x_oeste + retiro, m.y_sur + retiro),
            (m.x_este - retiro, m.y_sur + retiro),
            (m.x_este - retiro, m.y_norte - retiro),
            (m.x_oeste + retiro, m.y_norte - retiro),
        )
        anillos.append(
            [bm.verts.new((x - centro.x, y - centro.y, z - centro.z)) for x, y in esquinas]
        )
    for (z0, _), (z1, _), abajo, arriba in zip(m.perfil, m.perfil[1:], anillos, anillos[1:]):
        indice = nombres.index(_material_de(z0, z1))
        for k in range(4):
            cara = bm.faces.new((abajo[k], abajo[(k + 1) % 4], arriba[(k + 1) % 4], arriba[k]))
            cara.material_index = indice
    bm.faces.new(anillos[0][::-1]).material_index = nombres.index(ACERO)
    bm.faces.new(anillos[-1]).material_index = nombres.index(MESADA)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(malla)
    bm.free()
    for p in malla.polygons:
        p.use_smooth = True

    objeto = bpy.data.objects.new(ISLA, malla)
    objeto.location = centro
    bpy.data.collections[COLECCION].objects.link(objeto)
    modificador = objeto.modifiers.new(MODIFICADOR, "NODES")
    modificador.node_group = bpy.data.node_groups[MODIFICADOR]
    return objeto


# --- La UV -------------------------------------------------------------------------------------


def _uv_de_la_tapa(objeto) -> None:
    """Metros del mundo, como la tapa del mostrador: `u` corre a lo largo de la cara, `v` es la
    altura, y la cara de arriba va en planta."""
    capa = objeto.data.uv_layers.active.data
    matriz = objeto.matrix_world
    for p in _con_material(objeto, MESADA):
        arriba = abs(p.normal.z) > 0.99
        en_x = abs(p.normal.x) > abs(p.normal.y)
        for bucle, v in zip(p.loop_indices, p.vertices):
            punto = matriz @ objeto.data.vertices[v].co
            if arriba:
                capa[bucle].uv = (punto.x, punto.y)
            else:
                capa[bucle].uv = (punto.y if en_x else punto.x, punto.z)


def _clase_de_cara(p, puntos: list[Vector]) -> tuple[str, str]:
    """(lado, tipo) de una cara de acero: el lado al que mira y si es el zócalo, el chaflán de
    abajo o la base."""
    zs = [q.z for q in puntos]
    if max(zs) - min(zs) < 1e-4:
        return "abajo", "base"
    lado = ("x" if abs(p.normal.x) > abs(p.normal.y) else "y") + (
        "+" if (p.normal.x if abs(p.normal.x) > abs(p.normal.y) else p.normal.y) > 0 else "-"
    )
    return lado, "chaflan" if max(zs) - min(zs) < 0.01 else "zocalo"


def _a_lo_largo(lado: str, punto: Vector) -> float:
    return punto.y if lado.startswith("x") else punto.x


def _donantes(mostrador) -> dict:
    """Las caras de acero del extremo oeste del mostrador, de donde la isla copia la UV."""
    capa = mostrador.data.uv_layers.active.data
    matriz = mostrador.matrix_world
    donantes = {}
    for p in _con_material(mostrador, ACERO):
        puntos = [matriz @ mostrador.data.vertices[v].co for v in p.vertices]
        if min(q.x for q in puntos) > -1.0:
            continue
        lado, tipo = _clase_de_cara(p, puntos)
        donantes[(lado, tipo)] = (puntos, [tuple(capa[b].uv) for b in p.loop_indices])
    return donantes


def _uv_del_acero(objeto, mostrador) -> None:
    """Cada cara de acero toma una transformación afín (a lo largo, altura) → UV de la cara
    vecina del mostrador que mira para el mismo lado, y la aplica con su propio largo."""
    donantes = _donantes(mostrador)
    capa = objeto.data.uv_layers.active.data
    matriz = objeto.matrix_world
    for p in _con_material(objeto, ACERO):
        puntos = [matriz @ objeto.data.vertices[v].co for v in p.vertices]
        lado, tipo = _clase_de_cara(p, puntos)
        if tipo == "base":
            _, uvs = donantes[("abajo", "base")]
            for bucle, uv in zip(p.loop_indices, uvs):
                capa[bucle].uv = uv
            continue
        donante_lado = "x-" if lado == "x+" else lado
        otros, uvs = donantes[(donante_lado, tipo)]
        ejes = [(_a_lo_largo(donante_lado, q), q.z) for q in otros]
        sistema = np.array([[1.0, s, z] for s, z in ejes])
        coef, *_ = np.linalg.lstsq(sistema, np.array(uvs), rcond=None)
        inicio_donante = min(s for s, _ in ejes)
        inicio_propio = min(_a_lo_largo(lado, q) for q in puntos)
        for bucle, q in zip(p.loop_indices, puntos):
            s = inicio_donante + _a_lo_largo(lado, q) - inicio_propio
            capa[bucle].uv = tuple(float(c) for c in np.array([1.0, s, q.z]) @ coef)


def _uv_de_la_madera(objeto) -> list[str]:
    """La misma imagen y la misma franja que el mostrador: sólo cambia la geometría."""
    nombres = list(listonar.OBJETOS)
    pies = {n: min(listonar.alturas(_objeto(n))) for n in nombres}
    altos = [
        max(listonar.alturas(_objeto(de_quien))) - pies[n]
        for n, (de_quien, _) in listonar.OBJETOS.items()
    ]
    filas_pie, filas = listonar.apilar(altos)
    v_liso = (filas / listonar.LADO_PX + 0.008, 0.992)
    fila = dict(zip(nombres, filas_pie))[MOSTRADOR]
    return listonar.uv_de(objeto, pies[MOSTRADOR], fila, v_liso)


def poner_uv(objeto) -> list[str]:
    objeto.data.uv_layers.new(name="UVMap")
    _uv_de_la_tapa(objeto)
    _uv_del_acero(objeto, _objeto(MOSTRADOR))
    return _uv_de_la_madera(objeto)


# --- Lo que se verifica ------------------------------------------------------------------------


def _caja(objeto) -> tuple[Vector, Vector]:
    puntos = _puntos(objeto)
    return (
        Vector([min(p[i] for p in puntos) for i in range(3)]),
        Vector([max(p[i] for p in puntos) for i in range(3)]),
    )


def juego_con_la_hoja(m: Medidas, objeto) -> dict[str, float]:
    """El menor espacio, a lo ancho de la isla, entre su cara este y cualquier punto de la hoja
    mientras gira de 0 a 90 grados hacia cada lado."""
    hoja = [p for p in _puntos(_objeto(COMPUERTA))]
    caja_isla = _caja(objeto)
    resultado = {}
    for nombre, signo in (("al sur (abre hacia adentro)", -1), ("al norte", 1)):
        menor = math.inf
        for grados in range(0, 91):
            angulo = math.radians(grados) * -signo
            c, s = math.cos(angulo), math.sin(angulo)
            for p in hoja:
                dx, dy = p.x - m.perno[0], p.y - m.perno[1]
                x = m.perno[0] + dx * c - dy * s
                y = m.perno[1] + dx * s + dy * c
                if caja_isla[0].y <= y <= caja_isla[1].y:
                    menor = min(menor, x - caja_isla[1].x)
        resultado[nombre] = menor
    return resultado


def informar(m: Medidas, objeto, anchos: list[str]) -> None:
    minimo, maximo = _caja(objeto)
    mostrador_min, _ = _caja(_objeto(MOSTRADOR))
    print(f"{ISLA}: x [{minimo.x:.4f}, {maximo.x:.4f}] y [{minimo.y:.4f}, {maximo.y:.4f}] "
          f"z [{minimo.z:.4f}, {maximo.z:.4f}]")
    print(f"  ancho {maximo.x - minimo.x:.4f} m, fondo {maximo.y - minimo.y:.4f} m, "
          f"alto {maximo.z:.4f} m; {len(objeto.data.polygons)} caras")
    print(f"  luz contra la pared (x={m.pared_x:.4f}): {minimo.x - m.pared_x:.4f} m")
    print(f"  perno de la bisagra ({m.perno[0]:.4f}, {m.perno[1]:.4f}), radio de la hoja "
          f"{m.radio:.4f}: punto más al oeste del giro x={m.perno[0] - m.radio:.4f}")
    compuerta_min, _ = _caja(_objeto(COMPUERTA))
    print(f"  entre la isla y la hoja cerrada: {compuerta_min.x - maximo.x:.4f} m")
    for lado, menor in juego_con_la_hoja(m, objeto).items():
        print(f"  holgura mínima durante el giro {lado}: {menor:.4f} m")
    tapa_mostrador = max(p.z for p in _puntos(_objeto(MOSTRADOR)))
    print(f"  alto de la tapa del mostrador {tapa_mostrador:.4f}, de la isla {maximo.z:.4f}")
    print("  tramos de listones (cm, largo/listón):", " | ".join(anchos))
    vecinos = []
    for otro in bpy.data.objects:
        if otro.type != "MESH" or otro is objeto or not otro.data.vertices:
            continue
        a, b = _caja(otro)
        if b.x - a.x > 5.0 or b.y - a.y > 5.0:
            continue
        solapa = all(a[i] < maximo[i] and b[i] > minimo[i] for i in range(3))
        if solapa:
            vecinos.append(otro.name)
    print("  objetos que se solapan con su caja:", vecinos or "ninguno")


def aislar() -> None:
    previo = bpy.data.objects.get(ISLA)
    if previo is not None:
        malla = previo.data
        bpy.data.objects.remove(previo)
        if malla.users == 0:
            bpy.data.meshes.remove(malla)


def main() -> None:
    configurar()
    aislar()
    medidas = medir()
    objeto = construir(medidas)
    bpy.context.view_layer.update()
    anchos = poner_uv(objeto)
    informar(medidas, objeto, anchos)
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        PRUEBA.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(PRUEBA), check_existing=False)
        print(f"prueba guardada en {PRUEBA}")


if __name__ == "__main__":
    main()
