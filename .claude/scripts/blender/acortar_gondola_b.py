"""Acorta la góndola isla (`B`): sus dos caras largas pasan a medir `LARGO_DE_LA_CARA`.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/acortar_gondola_b.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/acortar-gondola-b.blend` y no modifica el `.blend` del repo.
Con `--aplicar`, guarda la fuente canónica en su lugar. Después va la cadena entera:
`separadores_de_prueba.py --aplicar`, `armar_atlas.py`, `exportar_modelo.py`, `disponer.py`,
`disponer_prueba.py`, `integrar_modelo.py`, `actualizar_apoyos.py`, `extraer_mallas.gd` y
`hornear.py` con y sin `--sin-luz`.

## Qué cambia

- **Cada cara larga pasa de 3,04 m a `LARGO_DE_LA_CARA`.** Es la cuenta que acorta las caras de
  `A` (`lib/gondola_a_la_pared.py`): cada grupo de vértices viaja entero y lo que hay entre dos
  grupos se encoge. Las UV de las dos capas conservan la escala de la textura.
- **El extremo sur no se mueve**: es el que da a la entrada y queda alineado con el grupo de la
  pared este. La cara pierde todo por el norte.
- **Las cabeceras no cambian de tamaño.** La sur se queda donde está y la norte, con sus unidades,
  viaja pegada al extremo nuevo de las caras.
- **Las unidades de las caras largas vuelven a repartirse** con el acomodador: cada estante mide
  menos y entran menos columnas. Cada unidad conserva su profundidad, su altura y su giro.
- **Las bandejas de las caras largas se rehacen** (`-frente`): llevan la tira del producto que
  tienen encima y su ancho sale de las unidades, así que siguen a las columnas nuevas. Cada
  bandeja es copia de la que el mismo producto tenía.

## Por qué sólo se mueven los `-noimp`

El modificador `Muebles` de `B` arma su geometría uniendo los cuatro `-noimp`, y la malla propia de
`B` no entra en el resultado: quedó de antes de que la isla bajara de altura y ya no coincide con
ellos. Se mueven los `-noimp`, y el acomodador mide la unión que arma el modificador, que es lo que
ve Godot, y no la malla propia.

## Lo que cuesta

0 materiales y 0 texturas adicionales. Menos triángulos: hay menos bandejas y menos unidades. Es
idempotente: si las caras ya miden `LARGO_DE_LA_CARA`, no cambia nada.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]
from mathutils import Matrix  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
sys.path.insert(0, str(RAIZ / ".claude/scripts/blender"))
import acomodar  # noqa: E402
import disponer  # noqa: E402
import gondola_a_la_pared as pared  # noqa: E402
import separadores_de_prueba as separadores  # noqa: E402
from lib.consola import configurar  # noqa: E402

B = "gondolanueva2-col"
PREFIJO = "gondolanueva2"
PIEZAS = ("este", "oeste", "norte", "sur")
LARGAS = ("este", "oeste")
#: Lo que mide cada cara larga de `B`, de punta a punta de su malla. Cuatro columnas de cada
#: producto de la cara de Laysnnt y Chisitos entran en su mitad, con aire y sin que entre una
#: quinta.
LARGO_DE_LA_CARA = 2.04
#: La separación entre el extremo de una cara larga y el de la cabecera que la cierra.
JUNTA_CON_LA_CABECERA = 0.005
#: Dos medidas a menos de esto son la misma.
IGUAL = 1e-3
#: Cuántas columnas de cada producto lleva cada estante de la cara de Laysnnt y Chisitos.
COLUMNAS_DE_LA_VARA = 4


def medir_la_union(letra: str):
    """Los estantes de `B` como los arma el modificador `Muebles`, y no como los guarda su malla.

    Lo mismo que `acomodar.medir`, pero sobre la malla evaluada: es la geometría de los `-noimp`.
    El número de lado de esa malla no coincide con el de la propia, y por eso el nombre de cada
    cara sale de su forma y de dónde está: una chapa más larga en Y es de una cara larga.
    """
    objeto = bpy.data.objects[acomodar.MUEBLES[letra]]
    evaluado = objeto.evaluated_get(bpy.context.evaluated_depsgraph_get())
    malla = evaluado.to_mesh()
    bm = bmesh.new()
    bm.from_mesh(malla)
    evaluado.to_mesh_clear()
    bm.transform(objeto.matrix_world)
    lado = bm.faces.layers.int["lado_de_estante"]
    nivel = bm.faces.layers.int["nivel_de_estante"]
    centro = objeto.matrix_world.translation
    regiones: dict[tuple[int, int], list] = {}
    for cara in bm.faces:
        if cara[lado]:
            regiones.setdefault((cara[lado], cara[nivel]), []).append(cara)
    estantes = {}
    for (_, altura), caras in sorted(regiones.items()):
        mayor = max(caras, key=lambda c: c.calc_area())
        corrimiento = mayor.calc_center_median() - centro
        xs = [v.co.x for v in mayor.verts]
        ys = [v.co.y for v in mayor.verts]
        if max(ys) - min(ys) > max(xs) - min(xs):
            cara = "este" if corrimiento.x > 0 else "oeste"
        else:
            cara = "norte" if corrimiento.y > 0 else "sur"
        clave = f"{letra}.{cara}.{altura}"
        estantes[clave] = acomodar.Estante(clave, caras, mayor)
    return objeto, bm, estantes


def _largo(pieza) -> float:
    ys = [p.y for p in pared._puntos(pieza.cuerpo)]
    return max(ys) - min(ys)


def _bandejas_de_ahora(frentes: dict) -> tuple:
    """Las bandejas de las caras largas con lo que hace falta para rehacerlas: el molde de cada
    producto y, por tanda, la bandeja que tiene debajo. Se leen antes de mover nada."""
    bandejas = [b for objeto in frentes.values() for b in separadores.bandejas_de(objeto)]
    tandas = disponer.tandas_del_blend()
    moldes = separadores.moldes(bandejas, tandas)
    debajo = {}
    for clave, copias in tandas.items():
        if not clave.startswith(tuple(f"B.{cara}." for cara in LARGAS)):
            continue
        propias = [
            b for b in bandejas
            if b.unidades and any(
                b.contiene(separadores._caja(u)) for u in copias if u["fila"] == "adelante"
            )
        ]
        if propias:
            debajo[clave] = propias[0]
    return moldes, debajo


def _rehacer_las_bandejas(frentes: dict, moldes: dict, debajo: dict) -> None:
    """Una bandeja nueva por cada grupo de unidades de cada tanda, con el molde de su producto."""
    tandas = disponer.tandas_del_blend()
    nuevas = {objeto.name: [] for objeto in frentes.values()}
    for clave, como in sorted(debajo.items()):
        unidades = [u for u in tandas[clave] if u["fila"] == "adelante"]
        molde = moldes[str(tandas[clave][0]["producto"])]
        bordes = [
            c + s * a / 2 for c, a in separadores._centros(unidades, como.derecha) for s in (-1, 1)
        ]
        margen = max(molde.margen, 0.0)
        limites = (min(bordes) - margen, max(bordes) + margen)
        nuevas[como.objeto.name] += separadores.bandejas_nuevas(como, molde, 0.0, unidades, limites)
    for objeto in frentes.values():
        _escribir(objeto, nuevas[objeto.name])


def _escribir(objeto, caras) -> None:
    """Deja en la malla de `objeto` sólo `caras`, en coordenadas del mundo, con su UV."""
    bm = bmesh.new()
    bm.from_mesh(objeto.data)
    bmesh.ops.delete(bm, geom=list(bm.verts), context="VERTS")
    capa = bm.loops.layers.uv.active
    inversa = objeto.matrix_world.inverted()
    for cara in caras:
        nueva = bm.faces.new([bm.verts.new(inversa @ p) for p, _ in cara])
        for lazo, (_, uv) in zip(nueva.loops, cara):
            lazo[capa].uv = uv
    bm.to_mesh(objeto.data)
    bm.free()
    objeto.data.update()
    print(f"{objeto.name}: {len(caras)} caras")


def acortar() -> bool:
    bpy.context.view_layer.update()
    piezas = pared._piezas(B, PREFIJO, PIEZAS, False)
    largos = {n: _largo(piezas[n]) for n in LARGAS}
    if any(abs(largo - LARGO_DE_LA_CARA) < IGUAL for largo in largos.values()):
        if any(abs(largo - LARGO_DE_LA_CARA) >= IGUAL for largo in largos.values()):
            raise SystemExit(f"las caras de B no miden lo mismo: {largos}; no se guardó nada")
        print("B ya tiene el largo pedido; no cambia nada")
        return False
    if abs(largos["este"] - largos["oeste"]) > IGUAL:
        raise SystemExit(f"las caras de B no miden lo mismo: {largos}; no se guardó nada")
    perdido = largos["este"] - LARGO_DE_LA_CARA
    frentes = {n: pared._objeto(f"{PREFIJO}-{n}-frente") for n in LARGAS}
    moldes, debajo = _bandejas_de_ahora(frentes)
    gondola = pared._objeto(B)
    for nombre in LARGAS:
        pared._acortar(
            piezas[nombre], gondola, LARGO_DE_LA_CARA, centrada=False, con_baranda=False
        )
    hacia_el_sur = Matrix.Translation((0.0, -perdido, 0.0))
    pared._mover_pieza(piezas["norte"], hacia_el_sur, gondola)
    movidas = pared._mover_unidades(("B.norte.",), hacia_el_sur)
    bpy.context.view_layer.update()
    unidades = pared._repartir_las_caras_largas(piezas, "B", LARGAS, medir_la_union)
    _rehacer_las_bandejas(frentes, moldes, debajo)
    print(
        f"caras largas de B de {largos['este']:.3f} a {LARGO_DE_LA_CARA:.3f} m; cabecera norte "
        f"corrida {-perdido:+.3f} con {movidas} unidades; {unidades} unidades en las caras largas"
    )
    return True


def verificar() -> None:
    """Las caras miden lo pedido, el extremo sur sigue donde estaba y las cabeceras, juntas a sus
    extremos; la cara de Laysnnt y Chisitos lleva cuatro columnas de cada uno por estante."""
    piezas = pared._piezas(B, PREFIJO, PIEZAS, False)
    for nombre in LARGAS:
        largo = _largo(piezas[nombre])
        if abs(largo - LARGO_DE_LA_CARA) > IGUAL:
            raise SystemExit(f"la cara {nombre} de B mide {largo:.3f} m")
    ys = {n: [p.y for p in pared._puntos(piezas[n].cuerpo)] for n in PIEZAS}
    for nombre in LARGAS:
        for cabecera, junta in (
            (min(ys[nombre]) - max(ys["sur"]), "sur"), (min(ys["norte"]) - max(ys[nombre]), "norte"),
        ):
            if abs(cabecera - JUNTA_CON_LA_CABECERA) > IGUAL:
                raise SystemExit(f"la cabecera {junta} no queda junta a la cara {nombre}")
    cuentas: dict[str, int] = {}
    for unidad in pared._unidades_de(("B.este.",)):
        if str(unidad["fila"]) == "adelante":
            tanda = str(unidad["tanda"])
            cuentas[tanda] = cuentas.get(tanda, 0) + 1
    for nivel in (0, 1):
        for columna in (0, 1):
            tanda = f"B.este.{nivel}/{columna}"
            if cuentas.get(tanda) != COLUMNAS_DE_LA_VARA:
                raise SystemExit(f"{tanda} lleva {cuentas.get(tanda)} columnas")
    print(
        "B queda con caras de "
        f"{LARGO_DE_LA_CARA:.2f} m y {COLUMNAS_DE_LA_VARA} columnas de Laysnnt y de Chisitos "
        "por estante"
    )


def main() -> None:
    configurar()
    acortar()
    verificar()
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        destino = RAIZ / "reports/acortar-gondola-b.blend"
        destino.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
        print(f"prueba guardada en {destino}")


if __name__ == "__main__":
    main()
