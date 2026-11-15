"""Lleva a 8 cm de frente los perfiles de aluminio de los ventanales y rehace sus UV.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/ensanchar_marcos_de_ventanal.py -- [--aplicar]

Sin `--aplicar` guarda `reports/ensanchar-marcos-de-ventanal.blend`, con las texturas nuevas en
`reports/ensanchar-marcos-de-ventanal-texturas/`, y no toca la fuente. Con `--aplicar` guarda la
fuente y escribe `aluminio_del_local_{color,orm}.png` en `assets/source/textures/metal/`. Después
van `armar_atlas.py`, `exportar_modelo.py` y `assets/models/extraer_mallas.gd`.

## Por qué

Los parantes y los travesaños medían 5 cm de frente contra paños de 1,85 por 3,35 m, y el marco
se leía como un hilo. Cada perfil muestra 8 cm de frente. El fondo de 11 cm no cambia.

## Qué cambia

- `local_marco_ventanal-col` y `local_marco_frente-col`: sus cinco parantes, el travesaño de la
  mitad, el de abajo y el de arriba.
- **Parantes y travesaño de la mitad** crecen desde su eje, parejo a los dos lados.
- **Abajo** el perfil crece hacia arriba desde el piso terminado (`z = 0,1022`) hasta 8 cm
  visibles. En el ventanal queda de `0,1022` a `0,1822`. En el frente es la base de 2,5 cm que ya
  existía, hundida en el piso: sube de `0,127` a `0,1822`. El zócalo perimetral se corta en los
  ejes de los parantes de punta y por delante del marco no pasa: el perfil queda a la vista, y el
  zócalo termina contra el parante, como en una carpintería.
- **Arriba** el perfil crece hacia abajo desde su canto de arriba (`3,4685`), que ya está 3 cm
  debajo del cielorraso (`3,50`): queda de `3,3885` a `3,4685`.
- **El paso de las puertas no se achica.** Las jambas (`3,3934..3,4434` y `6,364..6,414`) crecen
  sólo hacia su paño fijo: la cara que mira a las hojas queda donde estaba. Entre ellas, el umbral
  (`0,077..0,127`) y el canto de abajo del travesaño (`2,568`) no se mueven, y el travesaño crece
  sólo hacia arriba: la hoja mide `2,593` de alto.
- **Los vidrios no se tocan.** Cada borde de un paño cae sobre el eje de un parante, adentro de
  los 8 cm. Abajo entran en el perfil de 8 cm desde el piso y arriba terminan en `3,4496`, a 6 cm
  adentro del perfil de arriba.
- Las UV de `local_aluminio` se rehacen enteras con `metal_con_detalle.py`: el atlas se vuelve a
  empaquetar con la geometría nueva y repinta el mismo conjunto.

## Cómo

Las dos mallas son sólidos cerrados de una sola pieza, con vértices sólo en los bordes de cada
perfil. Cada borde de parante y cada canto de travesaño pasa a su valor nuevo, con una
interpolación lineal entre ellos. Una deformación monótona por eje no cambia la topología, las
caras siguen planas y el material y el suavizado de cada cara quedan como estaban.

Cada travesaño lista los cantos en que puede estar: el original, el que dejó una corrida anterior
y el destino. La corrida mide cuál es y lo lleva al destino. Es idempotente: sobre el `.blend`
original, sobre el de la primera corrida o sobre el de ahora, termina en la misma geometría, y si
ya está no mueve un vértice. Las UV salen siempre de la geometría que hay, y repetirlas escribe los
mismos bytes.

## Lo que cuesta

0 triángulos, 0 materiales, 0 texturas nuevas. Cambian las colisiones de los dos marcos: el
descompuesto convexo sale de esas mallas.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]
import numpy as np
from mathutils.bvhtree import BVHTree  # type: ignore[import-not-found]

sys.path.insert(0, str(Path(__file__).resolve().parent))
import metal_con_detalle  # noqa: E402
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.consola import configurar  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
REPORTE = RAIZ / "reports/ensanchar-marcos-de-ventanal.blend"
TEXTURAS_DE_REPORTE = RAIZ / "reports/ensanchar-marcos-de-ventanal-texturas"
MEDIDAS = RAIZ / "reports/ensanchar-marcos-de-ventanal.json"

ANCHO = 0.08
MITAD = ANCHO / 2
MITAD_ACTUAL = 0.025
TOLERANCIA = 5e-4
CONJUNTO = "aluminio_del_local"


@dataclass(frozen=True)
class Parante:
    """Un parante vertical por su eje, y cuánto crece hacia cada lado de ese eje."""

    eje: float
    hacia_menos: float = MITAD - MITAD_ACTUAL
    hacia_mas: float = MITAD - MITAD_ACTUAL

    @property
    def bordes(self) -> tuple[tuple[float, float], tuple[float, float]]:
        menos = self.eje - MITAD_ACTUAL
        mas = self.eje + MITAD_ACTUAL
        return (menos, menos - self.hacia_menos), (mas, mas + self.hacia_mas)


@dataclass(frozen=True)
class Tramo:
    """Un travesaño sobre un tramo del largo, con los cantos que puede tener y el que va a tener.

    `conocidos` son los pares `(abajo, arriba)` en que puede estar hoy: el original, el que dejó
    una corrida anterior y el destino. Así la corrida sirve sobre cualquiera de esos `.blend`.
    Los límites `desde`/`hasta` van en los ejes de los parantes, que no se mueven.
    """

    conocidos: tuple[tuple[float, float], ...]
    destino: tuple[float, float]
    desde: float = -1e3
    hasta: float = 1e3

    def contiene(self, u: float) -> bool:
        return self.desde <= u < self.hasta


@dataclass(frozen=True)
class Marco:
    objeto: str
    eje_largo: int
    parantes: tuple[Parante, ...]
    tramos: tuple[Tramo, ...]


# El piso terminado queda en z = 0,102237 y el cielorraso en 3,50. Los perfiles de abajo y de arriba
# muestran 8 cm: el de abajo crece hacia arriba desde el piso y el de arriba, hacia abajo desde
# su canto de arriba, que ya está 3 cm debajo del cielorraso.
PISO = 0.102237
BASE_DEL_VENTANAL = (PISO, PISO + ANCHO)
CANTO_DE_ARRIBA = 3.468511
ARRIBA_ORIGINAL = 3.447519
ARRIBA_DEL_VENTANAL = (CANTO_DE_ARRIBA - ANCHO, CANTO_DE_ARRIBA)

# `local_marco_ventanal-col`: los paños van entre los ejes de los parantes, de y = -1,5 a 6,1. El
# zócalo (`local_zocalo_perimetral`) se corta justo en esos dos ejes y por delante del marco no
# pasa: el travesaño de abajo queda a la vista, de 0,1022 a 0,1822.
VENTANAL = Marco(
    "local_marco_ventanal-col",
    1,
    tuple(Parante(eje) for eje in (-1.5, 0.4, 2.3, 4.2, 6.1)),
    (
        Tramo(
            ((PISO, PISO + 0.05), (PISO - 0.015, PISO + 0.065), BASE_DEL_VENTANAL),
            BASE_DEL_VENTANAL,
        ),
        Tramo(((2.568, 2.618), (2.553, 2.633)), (2.553, 2.633)),
        Tramo(((ARRIBA_ORIGINAL, CANTO_DE_ARRIBA), ARRIBA_DEL_VENTANAL), ARRIBA_DEL_VENTANAL),
    ),
)

# `local_marco_frente-col`: las jambas de las puertas están en 3,4184 y 6,389. La hoja izquierda
# arranca en 3,4184 y la derecha termina en 6,389, y el paso queda entre las caras interiores de
# las jambas (3,4434 y 6,364). Cada jamba crece sólo hacia su paño fijo. El umbral de las puertas
# (la base de 2,5 cm, de 0,077 a 0,127) y el canto de abajo de su travesaño no cambian.
JAMBA_IZQUIERDA = Parante(3.4184, hacia_menos=ANCHO - 2 * MITAD_ACTUAL, hacia_mas=0.0)
JAMBA_DERECHA = Parante(6.389, hacia_menos=0.0, hacia_mas=ANCHO - 2 * MITAD_ACTUAL)
FIJOS_DEL_FRENTE = ((-1e3, JAMBA_IZQUIERDA.eje), (JAMBA_DERECHA.eje, 1e3))
PUERTAS = (JAMBA_IZQUIERDA.eje, JAMBA_DERECHA.eje)
HUNDIDA = 0.077
BASE_DEL_FRENTE = (HUNDIDA, PISO + ANCHO)
CANTO_DE_ARRIBA_FRENTE = 3.468727
ARRIBA_DEL_FRENTE = (CANTO_DE_ARRIBA_FRENTE - ANCHO, CANTO_DE_ARRIBA_FRENTE)


def _tramos_del_frente() -> tuple[Tramo, ...]:
    tramos = [
        Tramo(((HUNDIDA, 0.127), BASE_DEL_FRENTE), BASE_DEL_FRENTE, desde, hasta)
        for desde, hasta in FIJOS_DEL_FRENTE
    ]
    tramos += [
        Tramo(((2.568, 2.618), (2.553, 2.633)), (2.553, 2.633), desde, hasta)
        for desde, hasta in FIJOS_DEL_FRENTE
    ]
    puertas = (2.568, 2.568 + ANCHO)
    tramos.append(Tramo(((2.568, 2.618), puertas), puertas, *PUERTAS))
    tramos.append(
        Tramo(((ARRIBA_ORIGINAL, CANTO_DE_ARRIBA_FRENTE), ARRIBA_DEL_FRENTE), ARRIBA_DEL_FRENTE)
    )
    return tuple(tramos)


FRENTE = Marco(
    "local_marco_frente-col",
    0,
    (Parante(1.65), JAMBA_IZQUIERDA, Parante(4.85), JAMBA_DERECHA, Parante(7.87)),
    _tramos_del_frente(),
)

MARCOS = (VENTANAL, FRENTE)


def _interpolar(valor: float, conocidos: list[tuple[float, float]]) -> float:
    """El valor nuevo de una coordenada, lineal entre los bordes conocidos."""
    for viejo, nuevo in conocidos:
        if abs(valor - viejo) < TOLERANCIA:
            return nuevo
    viejos = [v for v, _ in conocidos]
    if valor < viejos[0] or valor > viejos[-1]:
        return valor
    return float(np.interp(valor, viejos, [n for _, n in conocidos]))


def _mapa_del_largo(marco: Marco) -> list[tuple[float, float]]:
    conocidos = [borde for parante in marco.parantes for borde in parante.bordes]
    conocidos.sort()
    viejos = [v for v, _ in conocidos]
    assert all(b - a > 2 * TOLERANCIA for a, b in zip(viejos, viejos[1:])), marco.objeto
    return conocidos


def _alturas_en(objeto, tramo: Tramo, eje_largo: int) -> list[float]:
    mundo = objeto.matrix_world
    puntos = [mundo @ v.co for v in objeto.data.vertices]
    return [p.z for p in puntos if tramo.contiene(p[eje_largo])]


def _estan(alturas: list[float], cantos: tuple[float, float]) -> bool:
    return all(any(abs(z - c) < TOLERANCIA for z in alturas) for c in cantos)


def _resolver(objeto, marco: Marco) -> list[tuple[Tramo, tuple[float, float]]]:
    """El par `(abajo, arriba)` en que está hoy cada tramo, o falla si no es ninguno conocido."""
    resueltos = []
    for tramo in marco.tramos:
        alturas = _alturas_en(objeto, tramo, marco.eje_largo)
        hoy = next((c for c in tramo.conocidos if _estan(alturas, c)), None)
        assert hoy is not None, f"{marco.objeto}: un travesaño no está en ningún estado conocido"
        resueltos.append((tramo, hoy))
    return resueltos


def _nueva_altura(resueltos, u: float, z: float) -> float:
    for tramo, (abajo, arriba) in resueltos:
        nuevo_abajo, nuevo_arriba = tramo.destino
        if not tramo.contiene(u) or not abajo - TOLERANCIA <= z <= arriba + TOLERANCIA:
            continue
        if (abajo, arriba) == tramo.destino:
            return z
        if abs(z - arriba) < TOLERANCIA and arriba == nuevo_arriba:
            return z
        if abs(z - abajo) < TOLERANCIA and abajo == nuevo_abajo:
            return z
        fraccion = (z - abajo) / (arriba - abajo)
        return nuevo_abajo + fraccion * (nuevo_arriba - nuevo_abajo)
    return z


def _geometria(objeto) -> dict:
    malla = objeto.data
    bm = bmesh.new()
    bm.from_mesh(malla)
    bm.faces.ensure_lookup_table()
    mundo = objeto.matrix_world
    resultado = {
        "vertices": len(malla.vertices),
        "caras": len(malla.polygons),
        "manifold": all(e.is_manifold for e in bm.edges),
        "euler": len(bm.verts) - len(bm.edges) + len(bm.faces),
        "volumen": abs(bm.calc_volume(signed=True)),
        "area": sum(c.calc_area() for c in bm.faces),
        "sin_area": sum(1 for c in bm.faces if c.calc_area() < 1e-10),
        "normales": [tuple(c.normal) for c in bm.faces],
        "alabeo": max(
            max(abs((v.co - c.verts[0].co).dot(c.normal)) for v in c.verts) for c in bm.faces
        ),
    }
    bm.free()
    puntos = np.array([tuple(mundo @ v.co) for v in malla.vertices])
    resultado["caja"] = [puntos.min(axis=0).round(4).tolist(), puntos.max(axis=0).round(4).tolist()]
    return resultado


def _anchos_de_parantes(objeto, marco: Marco) -> list[float]:
    """El ancho medido en la malla de cada parante: de un borde de abajo al borde que le sigue."""
    mundo = objeto.matrix_world
    largo = sorted({round((mundo @ v.co)[marco.eje_largo], 4) for v in objeto.data.vertices})
    anchos = []
    for parante in marco.parantes:
        (viejo_menos, nuevo_menos), (viejo_mas, nuevo_mas) = parante.bordes
        for menos, mas in ((viejo_menos, viejo_mas), (nuevo_menos, nuevo_mas)):
            if any(abs(c - menos) < TOLERANCIA for c in largo) and any(
                abs(c - mas) < TOLERANCIA for c in largo
            ):
                anchos.append(round(mas - menos, 4))
                break
    return anchos


def _estado(objeto, marco: Marco) -> str:
    """`viejo`, `nuevo` o falla si la malla quedó a medias."""
    anchos = _anchos_de_parantes(objeto, marco)
    assert len(anchos) == len(marco.parantes), (marco.objeto, anchos)
    ya = [abs(a - ANCHO) < TOLERANCIA for a in anchos]
    sin_cambio = [abs(a - 2 * MITAD_ACTUAL) < TOLERANCIA for a in anchos]
    if all(sin_cambio):
        return "viejo"
    if all(ya) and not any(sin_cambio):
        return "nuevo"
    raise AssertionError(f"{marco.objeto} a medias: {anchos}")


def _ensanchar(objeto, marco: Marco, mover_parantes: bool) -> dict:
    assert objeto.data.users == 1, f"{objeto.name} comparte su malla"
    assert not objeto.data.has_custom_normals, f"{objeto.name} tiene normales propias"
    antes = _geometria(objeto)
    mapa = _mapa_del_largo(marco)
    resueltos = _resolver(objeto, marco)
    malla = objeto.data
    mundo = objeto.matrix_world
    inversa = mundo.inverted()
    asignaciones = []
    for vertice in malla.vertices:
        p = mundo @ vertice.co
        u, z = p[marco.eje_largo], p[2]
        nuevo = p.copy()
        if mover_parantes:
            nuevo[marco.eje_largo] = _interpolar(u, mapa)
        nuevo[2] = _nueva_altura(resueltos, u, z)
        if (nuevo - p).length > 1e-7:
            asignaciones.append((vertice.index, inversa @ nuevo))
    if not asignaciones:
        return {"movidos": 0}
    for indice, local in asignaciones:
        malla.vertices[indice].co = local
    malla.update()
    despues = _geometria(objeto)
    assert despues["manifold"] and antes["manifold"], objeto.name
    assert despues["euler"] == antes["euler"], objeto.name
    assert despues["sin_area"] == 0, f"{objeto.name}: quedó una cara sin área"
    assert despues["alabeo"] < max(antes["alabeo"], 1e-6) + 1e-6, (
        f"{objeto.name}: una cara dejó de ser plana ({despues['alabeo']:.2e})"
    )
    cambiadas = sum(
        1 for a, b in zip(antes["normales"], despues["normales"])
        if sum(x * y for x, y in zip(a, b)) < 0.999
    )
    assert cambiadas == 0, f"{objeto.name}: {cambiadas} caras giraron"
    assert despues["volumen"] > antes["volumen"] - 1e-9, objeto.name
    assert _estado(objeto, marco) == "nuevo", objeto.name
    for tramo, hoy in _resolver(objeto, marco):
        assert hoy == tramo.destino, f"{objeto.name}: un travesaño no llegó a {tramo.destino}"
    return {"movidos": len(asignaciones), "antes": _resumen(antes), "despues": _resumen(despues)}


def _resumen(datos: dict) -> dict:
    return {k: v for k, v in datos.items() if k != "normales"}


def _arbol(objeto) -> BVHTree:
    bm = bmesh.new()
    bm.from_mesh(objeto.data)
    bm.transform(objeto.matrix_world)
    arbol = BVHTree.FromBMesh(bm)
    bm.free()
    return arbol


def _distancia(a, b) -> float:
    """La distancia más corta entre las superficies de dos objetos, de vértice a superficie."""
    arbol_a, arbol_b = _arbol(a), _arbol(b)
    pares = [
        (arbol_b, a.matrix_world @ v.co) for v in a.data.vertices
    ] + [(arbol_a, b.matrix_world @ v.co) for v in b.data.vertices]
    return min(arbol.find_nearest(punto)[3] for arbol, punto in pares)


def _huecos_de_luz(marco_objeto, vecinos) -> list[dict]:
    """Distancia más corta entre el marco y cada objeto cercano, en metros."""
    salida = [
        {"objeto": vecino.name, "distancia": round(_distancia(marco_objeto, vecino), 4)}
        for vecino in vecinos
    ]
    return sorted(salida, key=lambda d: d["distancia"])


def _vecinos(marcos) -> list:
    exceptuados = {m.objeto for m in marcos}
    cajas = []
    for marco in marcos:
        objeto = bpy.data.objects[marco.objeto]
        puntos = np.array([tuple(objeto.matrix_world @ v.co) for v in objeto.data.vertices])
        cajas.append((puntos.min(axis=0) - 0.25, puntos.max(axis=0) + 0.25))
    cercanos = []
    for objeto in bpy.data.objects:
        if objeto.type != "MESH" or objeto.name in exceptuados or not objeto.data.vertices:
            continue
        if objeto.name.startswith("local_vidrio") or "-noimp" in objeto.name:
            continue
        puntos = np.array([tuple(objeto.matrix_world @ v.co) for v in objeto.data.vertices])
        for minimo, maximo in cajas:
            if (puntos.max(axis=0) >= minimo).all() and (puntos.min(axis=0) <= maximo).all():
                cercanos.append(objeto)
                break
    return cercanos


def _uv() -> str:
    conjunto = next(c for c in metal_con_detalle.CONJUNTOS if c.nombre == CONJUNTO)
    if "--aplicar" in sys.argv:
        destino = metal_con_detalle.CARPETA
    else:
        destino = TEXTURAS_DE_REPORTE
    return metal_con_detalle.aplicar(conjunto, destino)


def main() -> None:
    configurar()
    marcos = [(bpy.data.objects[m.objeto], m) for m in MARCOS]
    estados = {m.objeto: _estado(o, m) for o, m in marcos}
    assert len(set(estados.values())) == 1, f"un marco ya está y el otro no: {estados}"
    resultado: dict = {"estado_inicial": next(iter(estados.values()))}
    vecinos = _vecinos(MARCOS)
    resultado["luz_antes"] = {
        m.objeto: _huecos_de_luz(o, vecinos)[:12] for o, m in marcos
    }
    resultado["geometria"] = {
        m.objeto: _ensanchar(o, m, resultado["estado_inicial"] == "viejo") for o, m in marcos
    }
    bpy.context.view_layer.update()
    if not any(g["movidos"] for g in resultado["geometria"].values()):
        print("los perfiles ya están como van; sólo se rehacen las UV")
    resultado["luz_despues"] = {
        m.objeto: _huecos_de_luz(o, vecinos)[:12] for o, m in marcos
    }
    resultado["anchos"] = {m.objeto: _anchos_de_parantes(o, m) for o, m in marcos}
    resultado["uv"] = _uv()
    print(resultado["uv"])
    for _, m in marcos:
        print(f"{m.objeto}: parantes de {resultado['anchos'][m.objeto]} m")
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        REPORTE.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(REPORTE), check_existing=False)
        MEDIDAS.write_text(json.dumps(resultado, indent=1, default=float), encoding="utf-8")
        print(f"prueba guardada en {REPORTE}")


if __name__ == "__main__":
    main()
