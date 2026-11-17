"""Ensancha la góndola isla (`B`) hasta `ANCHO` y reparte las unidades de sus cabeceras.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/ensanchar_gondola_b.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/ensanchar-gondola-b.blend` y no modifica el `.blend` del repo.
Con `--aplicar`, guarda la fuente canónica en su lugar. Después va la cadena entera, igual que para
`acortar_gondola_b.py`.

## Por qué

Con un metro de ancho, los exhibidores de las dos cabeceras (los azules, con Burbaloo y Jorgillo al
sur y Flim Pof y Cosa de Maní al norte) tenían las unidades apretadas, a 1 cm una de otra.

## Qué cambia

- **La cara este no se mueve**: el pasillo contra las piezas de la pared este sigue midiendo lo
  mismo. La isla crece hacia las mesas, al oeste.
- **La cara oeste viaja rígida** `ensanche` m al oeste, con sus unidades y sus bandejas. Las dos
  caras largas conservan su fondo y sus productos.
- **Las dos cabeceras se estiran** esos metros. Es la cuenta que acorta las caras de `A`
  (`lib/gondola_a_la_pared.py`) con el signo cambiado y espejada, para que crezcan hacia el oeste:
  cada grupo de vértices viaja entero y lo que hay entre dos grupos se estira. Los laterales del
  exhibidor (los carteles) son grupos: viajan rígidos pegados a su borde, el oeste con el
  corrimiento. Las UV de las dos capas conservan la escala de la textura, así que el fondo se
  repite donde se estira una cara, y no se deforma.
- **Las unidades de las cabeceras conservan su cantidad.** Cada tanda se reparte en el estante
  nuevo con el mismo aire entre dos unidades y contra los bordes, centrada. Se leen las posiciones
  del `.blend`: ningún número es fijo.
- **Las bandejas de las cabeceras se rehacen** (`-frente`), como las de las caras largas.

## Por qué sólo se mueven los `-noimp`

Igual que en `acortar_gondola_b.py`: el modificador `Muebles` arma la geometría que ve Godot con
los cuatro `-noimp`, y la malla propia de `B` no entra en el resultado.

## Lo que cuesta

0 materiales y 0 texturas adicionales. Es idempotente: si la isla ya mide `ANCHO`, no cambia nada.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]
from mathutils import Matrix, Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
sys.path.insert(0, str(RAIZ / ".claude/scripts/blender"))
import acortar_gondola_b as isla  # noqa: E402
import gondola_a_la_pared as pared  # noqa: E402
from lib.consola import configurar  # noqa: E402
from lib.gondola_a_la_pared import Recorrido, agrupar  # noqa: E402

B = isla.B
PREFIJO = isla.PREFIJO
PIEZAS = isla.PIEZAS
CABECERAS = ("sur", "norte")
#: Lo que mide la isla de lado a lado, entre los extremos de sus cabeceras.
ANCHO = 1.20
#: Dos medidas a menos de esto son la misma.
IGUAL = 1e-3
#: Dos vértices a menos de esto, a lo ancho, son del mismo grupo.
SEPARACION_ENTRE_GRUPOS = 0.02
PREFIJOS_DE_LAS_CABECERAS = tuple(f"B.{cara}." for cara in CABECERAS)
PREFIJOS = tuple(f"B.{cara}." for cara in PIEZAS)


def _ancho_de_la_isla(piezas) -> float:
    xs = [p.x for nombre in CABECERAS for p in pared._puntos(piezas[nombre].cuerpo)]
    return max(xs) - min(xs)


def _estirar(pieza, ensanche: float, gondola) -> None:
    """Estira una cabecera `ensanche` m hacia el oeste y deja fijo su extremo este."""
    xs = [p.x for p in pared._puntos(pieza.cuerpo)]
    recorrido = Recorrido(
        agrupar([-x for x in xs], SEPARACION_ENTRE_GRUPOS), -ensanche, centrada=False
    )

    def estirada(punto: Vector) -> Vector:
        return Vector((-recorrido(-punto.x), punto.y, punto.z))

    pared._mover_vertices(pieza.cuerpo, None, estirada, True)
    if pieza.vertices:
        pared._mover_vertices(gondola, pieza.vertices, estirada, True)


def _tandas_de(prefijos: tuple[str, ...]) -> dict[str, list]:
    por_tanda: dict[str, list] = {}
    for unidad in pared._unidades_de(prefijos):
        por_tanda.setdefault(str(unidad["tanda"]), []).append(unidad)
    return por_tanda


def _caja_en_x(unidad) -> tuple[float, float]:
    xs = [(unidad.matrix_world @ v.co).x for v in unidad.data.vertices]
    return min(xs), max(xs)


def _desplazar(unidad, dx: float) -> None:
    escala = unidad.scale.copy()
    unidad.matrix_world = Matrix.Translation((dx, 0.0, 0.0)) @ unidad.matrix_world
    unidad.scale = escala


def _repartir_las_unidades(estantes: dict) -> int:
    """Cada tanda de una cabecera, centrada en su estante, con el mismo aire entre las unidades y
    contra los bordes. Conserva la cantidad, el orden, la profundidad y la altura."""
    movidas = 0
    for clave, unidades in sorted(_tandas_de(PREFIJOS_DE_LAS_CABECERAS).items()):
        estante = estantes[clave.split("/")[0]]
        desde = estante.origen.x
        hasta = desde + estante.u.x * estante.largo
        izquierda, derecha = min(desde, hasta), max(desde, hasta)
        filas: dict[str, list] = {}
        for unidad in unidades:
            filas.setdefault(str(unidad["fila"]), []).append(unidad)
        referencia = sorted(filas["adelante"], key=lambda u: sum(_caja_en_x(u)))
        anchos = [_caja_en_x(u)[1] - _caja_en_x(u)[0] for u in referencia]
        aire = (derecha - izquierda - sum(anchos)) / (len(referencia) + 1)
        if aire < 0:
            raise SystemExit(f"{clave}: las unidades no entran en el estante nuevo")
        destinos = []
        cursor = izquierda + aire
        for ancho in anchos:
            destinos.append(cursor + ancho / 2)
            cursor += ancho + aire
        for fila in filas.values():
            ordenadas = sorted(fila, key=lambda u: sum(_caja_en_x(u)))
            if len(ordenadas) != len(destinos):
                raise SystemExit(f"{clave}: las filas no tienen las mismas columnas")
            for unidad, destino in zip(ordenadas, destinos):
                desde_x, hasta_x = _caja_en_x(unidad)
                _desplazar(unidad, destino - (desde_x + hasta_x) / 2)
                movidas += 1
    return movidas


def ensanchar() -> bool:
    bpy.context.view_layer.update()
    piezas = pared._piezas(B, PREFIJO, PIEZAS, False)
    ancho = _ancho_de_la_isla(piezas)
    if abs(ancho - ANCHO) < IGUAL:
        print("B ya tiene el ancho pedido; no cambia nada")
        return False
    ensanche = ANCHO - ancho
    if ensanche <= 0:
        raise SystemExit(f"B mide {ancho:.3f} m, más que los {ANCHO} m pedidos; no se guardó nada")
    frentes = {n: pared._objeto(f"{PREFIJO}-{n}-frente") for n in CABECERAS}
    moldes, debajo = isla._bandejas_de_ahora(frentes, CABECERAS)
    gondola = pared._objeto(B)
    for nombre in CABECERAS:
        _estirar(piezas[nombre], ensanche, gondola)
    al_oeste = Matrix.Translation((-ensanche, 0.0, 0.0))
    pared._mover_pieza(piezas["oeste"], al_oeste, gondola)
    de_la_cara = pared._mover_unidades(("B.oeste.",), al_oeste)
    bpy.context.view_layer.update()
    _, bm, estantes = isla.medir_la_union("B")
    de_las_cabeceras = _repartir_las_unidades(estantes)
    bm.free()
    bpy.context.view_layer.update()
    isla._rehacer_las_bandejas(frentes, moldes, debajo)
    print(
        f"B de {ancho:.3f} a {ANCHO:.2f} m: cara oeste corrida {-ensanche:+.3f} con {de_la_cara} "
        f"unidades; {de_las_cabeceras} unidades de las cabeceras repartidas"
    )
    return True


def verificar() -> None:
    """La isla mide `ANCHO`, la cara este sigue donde estaba, las caras largas conservan su fondo y
    las unidades apoyan y no tocan el mueble."""
    piezas = pared._piezas(B, PREFIJO, PIEZAS, False)
    ancho = _ancho_de_la_isla(piezas)
    if abs(ancho - ANCHO) > IGUAL:
        raise SystemExit(f"B mide {ancho:.3f} m, no {ANCHO}")
    este = [p.x for p in pared._puntos(piezas["este"].cuerpo)]
    oeste = [p.x for p in pared._puntos(piezas["oeste"].cuerpo)]
    if abs((max(este) - min(este)) - (max(oeste) - min(oeste))) > IGUAL:
        raise SystemExit("las dos caras largas no tienen el mismo fondo")
    _, bm, estantes = isla.medir_la_union("B")
    bm.free()
    pared._verificar_apoyos(
        {c: None for c in estantes if c.startswith(PREFIJOS)}, "B", PREFIJOS, isla.medir_la_union
    )
    for clave, unidades in sorted(_tandas_de(PREFIJOS_DE_LAS_CABECERAS).items()):
        adelante = sorted(
            (u for u in unidades if str(u["fila"]) == "adelante"),
            key=lambda u: sum(_caja_en_x(u)),
        )
        huecos = [
            _caja_en_x(b)[0] - _caja_en_x(a)[1] for a, b in zip(adelante, adelante[1:])
        ]
        if huecos and min(huecos) < IGUAL:
            raise SystemExit(f"{clave}: dos unidades se tocan")
    print(f"B queda de {ANCHO:.2f} m y las unidades de sus cabeceras apoyan con aire entre ellas")


def main() -> None:
    configurar()
    ensanchar()
    verificar()
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        destino = RAIZ / "reports/ensanchar-gondola-b.blend"
        destino.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
        print(f"prueba guardada en {destino}")


if __name__ == "__main__":
    main()
