"""Lleva el frente de los estantes de las dos piezas largas de `A` a la línea del frente de `A.sur`.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/emparejar_fondo_de_las_piezas_largas.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/emparejar-fondo-de-las-piezas-largas.blend` y no modifica el
`.blend` del repo. Con `--aplicar`, guarda la fuente canónica en su lugar. Después va la cadena
entera, igual que para `gondola_a_la_pared.py`.

## Por qué

Las tres piezas de la pared este quedan una junto a la otra. Vistas de costado, los estantes de
las dos caras largas (`este` y `oeste`, de unos 0,485 m de fondo) terminaban más adelante que los
de la cabecera que cierra el grupo (`sur`, de unos 0,42 m): la línea del frente no seguía.

## Qué cambia

- **El borde del frente de cada estante viaja rígido hacia la pared**: el labio, la etiqueta, la
  tira de publicidad (`-frente`) y lo que los une. La cuenta sale de la pieza: se busca el hueco
  más grande a lo fondo —el que hay entre el labio y los parantes de atrás— y todo lo que está
  delante de él se corre `d`, la diferencia entre el frente de la pieza y el de `A.sur`. La chapa
  y las ménsulas, que cruzan ese hueco, se encogen. Las UV conservan la escala de la textura.
- **Se leen las posiciones del `.blend`**: `d` no es un número fijo.
- **Las unidades corren con el labio**, y después cada tanda se desliza lo que haga falta para
  apoyar y no tocar el mueble. Si una tanda no entra con sus dos filas, el script la nombra y no
  guarda nada.
- El zócalo y el estante de abajo siguen la misma línea porque son parte del mismo borde.

## Lo que cuesta

0 triángulos, 0 materiales y 0 texturas. Es idempotente: si los frentes ya coinciden, no cambia
nada.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Matrix, Vector  # type: ignore[import-not-found]
from mathutils.bvhtree import BVHTree  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
sys.path.insert(0, str(RAIZ / ".claude/scripts/blender"))
import acomodar  # noqa: E402
import gondola_a_la_pared as pared  # noqa: E402
from lib.consola import configurar  # noqa: E402
from lib.gondola_a_la_pared import agrupar  # noqa: E402

LARGAS = ("este", "oeste")
PIEZA_DE_REFERENCIA = "sur"
#: Dos vértices a menos de esto, a lo fondo, son del mismo grupo.
SEPARACION_ENTRE_GRUPOS = 0.012
#: Dos medidas a menos de esto son la misma.
IGUAL = 1e-3
PREFIJOS = tuple(f"A.{cara}." for cara in LARGAS)


def _frente(pieza) -> float:
    return min(p.x for p in pared._puntos(pieza.cuerpo))


def _recorrido(pieza, corrimiento: float):
    """La función de la posición vieja a la nueva a lo fondo: todo lo que está delante del hueco
    más grande se corre `corrimiento`, y lo que cruza ese hueco se encoge."""
    xs = [p.x for p in pared._puntos(pieza.cuerpo)]
    grupos = agrupar(xs, SEPARACION_ENTRE_GRUPOS)
    huecos = [(b[0] - a[1], a[1], b[0]) for a, b in zip(grupos, grupos[1:])]
    ancho, desde, hasta = max(huecos)
    if ancho <= corrimiento + IGUAL:
        raise SystemExit(f"el hueco de {ancho:.3f} m no alcanza para correr {corrimiento:.3f} m")

    def nuevo(x: float) -> float:
        if x <= desde + IGUAL / 10:
            return x + corrimiento
        if x >= hasta:
            return x
        return desde + corrimiento + (x - desde) * (hasta - desde - corrimiento) / (hasta - desde)

    return nuevo


def _tandas() -> dict[str, list]:
    por_tanda: dict[str, list] = {}
    for unidad in pared._unidades_de(PREFIJOS):
        por_tanda.setdefault(str(unidad["tanda"]), []).append(unidad)
    return por_tanda


def emparejar() -> bool:
    bpy.context.view_layer.update()
    piezas = pared._piezas()
    referencia = _frente(piezas[PIEZA_DE_REFERENCIA])
    corrimientos = {n: referencia - _frente(piezas[n]) for n in LARGAS}
    if all(abs(c) < IGUAL for c in corrimientos.values()):
        print("las piezas largas ya tienen el frente de A.sur; no cambia nada")
        return False
    if any(abs(c - corrimientos["este"]) > IGUAL for c in corrimientos.values()):
        raise SystemExit(f"las piezas largas no están a la misma distancia: {corrimientos}")
    corrimiento = corrimientos["este"]
    if corrimiento < IGUAL:
        raise SystemExit(f"el frente de A.sur no está detrás del de las largas: {corrimiento}")
    gondola = pared._objeto(pared.A)
    for nombre in LARGAS:
        pieza = piezas[nombre]
        nuevo = _recorrido(pieza, corrimiento)

        def movida(punto: Vector, nuevo=nuevo) -> Vector:
            return Vector((nuevo(punto.x), punto.y, punto.z))

        pared._mover_vertices(pieza.cuerpo, None, movida, True)
        pared._mover_vertices(gondola, pieza.vertices, movida, True)
        if pieza.baranda is not None:
            pared._mover_vertices(
                pieza.baranda, None, lambda p: p + Vector((corrimiento, 0.0, 0.0)), False
            )
    adelante = Matrix.Translation((corrimiento, 0.0, 0.0))
    movidas = pared._mover_unidades(PREFIJOS, adelante)
    bpy.context.view_layer.update()
    print(f"frente de las piezas largas corrido {corrimiento:+.4f} m; {movidas} unidades")
    _deslizar_las_tandas()
    return True


def _mover_a_lo_fondo(unidades, delta: float, estante) -> None:
    corrimiento = estante.v * delta
    for unidad in unidades:
        escala = unidad.scale.copy()
        unidad.matrix_world = Matrix.Translation(corrimiento) @ unidad.matrix_world
        unidad.scale = escala


def _extremo(unidades, estante, atras: bool) -> float:
    """Lo más atrás (o lo más adelante) que llegan las unidades, a lo fondo del estante."""
    puntos = [
        (u.matrix_world @ v.co - estante.origen).dot(estante.v)
        for u in unidades for v in u.data.vertices
    ]
    return max(puntos) if atras else min(puntos)


def _encajar(estante, bm, arbol, unidades, desde_el_frente: bool):
    """Lo más adelante (o lo más atrás) que entran unas unidades, o `None` si no entran."""
    salto = -0.12 if desde_el_frente else 0.12
    posiciones = [(u, Matrix.Translation(estante.v * salto) @ u.matrix_world) for u in unidades]
    delta = acomodar.medir_encaje(estante, bm, arbol, [], posiciones)
    return None if delta is None else salto + delta


def _deslizar_las_tandas() -> None:
    """Cada tanda se desliza a lo fondo lo que haga falta para apoyar sin tocar el mueble.

    Si las dos filas juntas no entran, cada fila va lo más cerca que puede de su borde: la de
    adelante contra el labio y la de atrás contra el panel. Quedan separadas por lo que sobre.
    """
    objeto, bm, estantes = acomodar.medir("A")
    arbol = BVHTree.FromBMesh(bm)
    justas = []
    no_entran = []
    for clave, unidades in sorted(_tandas().items()):
        estante = estantes[clave.split("/")[0]]
        posiciones = [(u, u.matrix_world.copy()) for u in unidades]
        delta = acomodar.medir_encaje(estante, bm, arbol, [], posiciones)
        if delta is not None:
            if abs(delta) > 1e-6:
                print(f"{clave}: se desliza {delta:+.4f} m a lo fondo")
                _mover_a_lo_fondo(unidades, delta, estante)
            continue
        filas = {}
        for unidad in unidades:
            filas.setdefault(str(unidad["fila"]), []).append(unidad)
        if set(filas) != {"adelante", "atras"}:
            no_entran.append(f"{clave} (sin dos filas)")
            continue
        adelante = _encajar(estante, bm, arbol, filas["adelante"], True)
        atras = _encajar(estante, bm, arbol, filas["atras"], False)
        if adelante is None or atras is None:
            no_entran.append(f"{clave} (una fila sola no entra)")
            continue
        for fila, delta in (("adelante", adelante), ("atras", atras)):
            _mover_a_lo_fondo(filas[fila], delta, estante)
        aire = _extremo(filas["atras"], estante, False) - _extremo(filas["adelante"], estante, True)
        print(
            f"{clave}: fondo {estante.fondo:.3f}; adelante "
            f"{_extremo(filas['adelante'], estante, False):.3f} a "
            f"{_extremo(filas['adelante'], estante, True):.3f}, atras "
            f"{_extremo(filas['atras'], estante, False):.3f} a "
            f"{_extremo(filas['atras'], estante, True):.3f}"
        )
        if aire < 0:
            no_entran.append(f"{clave} (se pisan {-aire * 1000:.0f} mm)")
        else:
            justas.append(f"{clave}: {aire * 1000:.0f} mm de aire entre filas")
    bm.free()
    for texto in justas:
        print(f"justa: {texto}")
    if no_entran:
        raise SystemExit(
            "no entran con sus dos filas en el fondo nuevo: " + ", ".join(no_entran)
            + "; no se guardó nada"
        )
    bpy.context.view_layer.update()


def verificar() -> None:
    piezas = pared._piezas()
    referencia = _frente(piezas[PIEZA_DE_REFERENCIA])
    for nombre in LARGAS:
        frente = _frente(piezas[nombre])
        if abs(frente - referencia) > IGUAL:
            raise SystemExit(f"el frente de {nombre} está a {frente - referencia:+.4f} de A.sur")
    pared._verificar_mallas()
    pared._verificar_apoyos(
        {c: None for c in acomodar.ESTANTES if c.startswith(PREFIJOS)}, "A", PREFIJOS
    )
    print(f"los estantes de las piezas largas tienen el frente en x={referencia:.3f}, como A.sur")


def main() -> None:
    configurar()
    emparejar()
    verificar()
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        destino = RAIZ / "reports/emparejar-fondo-de-las-piezas-largas.blend"
        destino.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
        print(f"prueba guardada en {destino}")


if __name__ == "__main__":
    main()
