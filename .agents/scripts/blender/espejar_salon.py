"""Espeja horizontalmente las mesas, sillas y góndolas centrales del salón.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/espejar_salon.py -- [--aplicar]

Sin `--aplicar`, escribe en `reports/espejar-salon.blend` y no modifica el `.blend` del repo.
Con `--aplicar`, guarda la fuente canónica en su lugar. Después corren
`separadores_de_prueba.py --aplicar`, `armar_atlas.py`, `exportar_modelo.py`, `disponer.py`,
`disponer_prueba.py`, `integrar_modelo.py`, `actualizar_apoyos.py`, `extraer_mallas.gd` y
`hornear.py`.

## Por qué

El salón intercambia las mesas y sillas con las dos góndolas centrales mediante un reflejo
respecto de `x = 2,96` (`x' = 5,92 - x`). Las góndolas pasan al lado este mirando a sus pasillos
reflejados. Las mesas y sillas pasan al ventanal oeste conservando los anchos de paso.

## Qué cambia

- **Mesas y sillas** (`salon_mesa_1..3-col`, `salon_silla_{1,2,3}{a,b}-col`): reflejan su `x`
  respecto de `2,96` con escala positiva. Las sillas invierten su giro en `Z` para seguir mirando
  a su mesa.
- **Estructura de góndolas** (`gondolanueva-col`, `gondolanueva2-col`, sus hijos `-noimp` y los
  frentes de alambre): reflejan su geometría respecto de `2,96` e invierten sus caras para mantener
  normales salientes. Intercambian `este` con `oeste` y desespejan `U` en carteles laterales y
  portaprecios.
- **Separadores con marca** (`gondolanueva2-*-frente`): giran 180 grados en `Z` sobre su centro en
  laterales y se trasladan en `X` en cabeceras. Así las tiras de `topes_a_medida.png` quedan al
  derecho.
- **Unidades exhibidas** (`tanda` de `A` y `B`): reflejan el centro real de su malla respecto de
  `2,96` con determinante positivo y actualizan su rótulo `tanda`.
- **Corrimiento de `A`** (`gondolanueva-col` y todo lo que cuelga de ella): después del reflejo, la
  góndola se corre hacia el centro hasta que su pasillo con el zócalo de la pared este mida
  `PASILLO_A_PARED_ESTE`. Ver esa constante.

## Lo que cuesta

0 triángulos, 0 materiales y 0 texturas adicionales. Es idempotente: si las góndolas ya están al
este del plano y las mesas al oeste, no vuelve a reflejar, y el corrimiento de `A` sale de su
posición de ahora.
"""

from __future__ import annotations

import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]
from mathutils import Matrix, Vector  # type: ignore[import-not-found]

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

X_ESPEJO = 2.96
DOS_X_ESPEJO = 2.0 * X_ESPEJO
#: El borde que el jugador ve en la pared este: la cara interior del zócalo, medida con un rayo
#: contra `local_zocalo_perimetral`. La pared (`almacen-col`) queda 0,016 más atrás.
PARED_ESTE_X = 7.854

#: El pasillo, de malla a malla, entre `A` y la pared este. Antes del espejo medía 1,793 entre `A`
#: y el marco del ventanal (cara interior en -2,460), y 1,914 entre `A` y `B`. El plano del espejo
#: queda 0,526 más cerca de la pared este que del ventanal, así que el reflejo dejaba 1,267
#: contra el zócalo. Para volver a 1,793 hacía falta 0,526 más, y el pasillo entre góndolas habría
#: pasado de 1,914 a 1,388. Se reparte esa diferencia en partes iguales: cada pasillo pierde 0,263
#: y queda en 1,530 y 1,651.
PASILLO_A_PARED_ESTE = 1.53
JUNTA_BANDEJA = 0.001
ENTRE_ESTANTES = 0.15

MESAS = ("salon_mesa_1-col", "salon_mesa_2-col", "salon_mesa_3-col")
SILLAS = (
    "salon_silla_1a-col",
    "salon_silla_1b-col",
    "salon_silla_2a-col",
    "salon_silla_2b-col",
    "salon_silla_3a-col",
    "salon_silla_3b-col",
)
GONDOLAS = (("A", "gondolanueva-col"), ("B", "gondolanueva2-col"))

MATERIALES_LATERALES = {"EXHIBIDOR | Lateral", "EXHIBIDOR | Lateral Pepito"}
MATERIAL_ETIQUETA = "GONDOLA | Etiqueta por grupo de productos"
GIRO_MEDIA_VUELTA_Z = Matrix(((-1.0, 0.0, 0.0), (0.0, -1.0, 0.0), (0.0, 0.0, 1.0)))


def _objeto(nombre: str):
    objeto = bpy.data.objects.get(nombre)
    if objeto is None:
        raise ValueError(f"falta el objeto {nombre}")
    return objeto


def _centro_envolvente(puntos: list[Vector]) -> Vector:
    return Vector(
        tuple((min(p[i] for p in puntos) + max(p[i] for p in puntos)) / 2.0 for i in range(3))
    )


def _espejar_malla_local_x(malla, ranuras, cambiar_lados: bool = False) -> None:
    bm = bmesh.new()
    bm.from_mesh(malla)
    for vert in bm.verts:
        vert.co.x = -vert.co.x
    bmesh.ops.reverse_faces(bm, faces=list(bm.faces))
    capa_uv = bm.loops.layers.uv.get("UVMap") or bm.loops.layers.uv.active
    if capa_uv is not None:
        for cara in bm.faces:
            indice = cara.material_index
            nombre = (
                ranuras[indice].material.name
                if indice < len(ranuras) and ranuras[indice].material is not None
                else ""
            )
            if nombre in MATERIALES_LATERALES:
                for lazo in cara.loops:
                    lazo[capa_uv].uv.x = 1.0 - lazo[capa_uv].uv.x
            elif nombre == MATERIAL_ETIQUETA:
                us = [lazo[capa_uv].uv.x for lazo in cara.loops]
                suma = min(us) + max(us)
                for lazo in cara.loops:
                    lazo[capa_uv].uv.x = suma - lazo[capa_uv].uv.x
    if cambiar_lados and "lado_de_estante" in bm.faces.layers.int:
        capa_lado = bm.faces.layers.int["lado_de_estante"]
        for cara in bm.faces:
            if cara[capa_lado] == 1:
                cara[capa_lado] = 2
            elif cara[capa_lado] == 2:
                cara[capa_lado] = 1
    bm.normal_update()
    bm.to_mesh(malla)
    bm.free()
    malla.update()


def _intercambiar_mallas(este, oeste) -> None:
    este.data, oeste.data = oeste.data, este.data
    nombre_este = este.data.name
    nombre_oeste = oeste.data.name
    este.data.name = "__tmp_espejo__"
    oeste.data.name = nombre_este
    este.data.name = nombre_oeste


def _intercambiar_propiedades_laterales(objeto) -> None:
    pares = []
    for clave in list(objeto.keys()):
        if "_este" in clave:
            otra = clave.replace("_este", "_oeste")
            if otra in objeto:
                pares.append((clave, otra))
    for clave_este, clave_oeste in pares:
        objeto[clave_este], objeto[clave_oeste] = objeto[clave_oeste], objeto[clave_este]


def _destinos_de_bandejas(objeto, es_lateral: bool) -> dict[int, Vector]:
    malla = objeto.data
    mundo = objeto.matrix_world
    eje = 1 if es_lateral else 0
    por_estante: dict[float, list[tuple[float, float, list[int]]]] = {}
    for cara in malla.polygons:
        puntos = [mundo @ malla.vertices[i].co for i in cara.vertices]
        piso = min(p.z for p in puntos)
        clave = next((k for k in por_estante if abs(k - piso) < ENTRE_ESTANTES), piso)
        desde = min(p[eje] for p in puntos)
        hasta = max(p[eje] for p in puntos)
        por_estante.setdefault(clave, []).append((desde, hasta, list(cara.vertices)))
    nuevos: dict[int, Vector] = {}
    for tramos in por_estante.values():
        tramos.sort(key=lambda t: t[0])
        grupos: list[list] = []
        for desde, hasta, indices in tramos:
            if grupos and desde <= grupos[-1][1] + JUNTA_BANDEJA:
                grupos[-1][1] = max(grupos[-1][1], hasta)
                grupos[-1][2].update(indices)
            else:
                grupos.append([desde, hasta, set(indices)])
        for desde, hasta, indices in grupos:
            medio = (desde + hasta) / 2.0
            for indice in indices:
                p = mundo @ malla.vertices[indice].co
                if es_lateral:
                    nuevos[indice] = Vector((DOS_X_ESPEJO - p.x, 2.0 * medio - p.y, p.z))
                else:
                    nuevos[indice] = Vector((p.x + DOS_X_ESPEJO - 2.0 * medio, p.y, p.z))
    if len(nuevos) != len(malla.vertices):
        total = len(malla.vertices)
        raise ValueError(f"{objeto.name}: vértices fuera de bandejas ({len(nuevos)}/{total})")
    return nuevos


def _aplicar_vertices_mundo(objeto, puntos_mundo: dict[int, Vector]) -> None:
    inversa = objeto.matrix_world.inverted()
    malla = objeto.data
    for indice, punto in puntos_mundo.items():
        malla.vertices[indice].co = inversa @ punto
    malla.update()


def _plan_de_tandas() -> list[tuple]:
    objetos = [
        o
        for o in bpy.context.scene.objects
        if "tanda" in o and str(o["tanda"]).startswith(("A.", "B."))
    ]
    columnas_por_estante: dict[str, set[int]] = {}
    for obj in objetos:
        estante, col = str(obj["tanda"]).split("/")
        columnas_por_estante.setdefault(estante, set()).add(int(col))
    plan = []
    for obj in objetos:
        estante, col_txt = str(obj["tanda"]).split("/")
        letra, cara, nivel = estante.split(".")
        columna = int(col_txt)
        locales = [v.co.copy() for v in obj.data.vertices]
        mundo_viejo = obj.matrix_world.copy()
        centro_viejo = _centro_envolvente([mundo_viejo @ p for p in locales])
        centro_nuevo = Vector((DOS_X_ESPEJO - centro_viejo.x, centro_viejo.y, centro_viejo.z))
        base_vieja = mundo_viejo.to_3x3()
        if cara in ("este", "oeste"):
            nueva_cara = "oeste" if cara == "este" else "este"
            total_cols = len(columnas_por_estante[estante])
            nueva_col = (total_cols - 1 - columna) if total_cols > 1 else columna
            base_nueva = GIRO_MEDIA_VUELTA_Z @ base_vieja
        else:
            nueva_cara = cara
            nueva_col = columna
            base_nueva = base_vieja
        centro_girado = _centro_envolvente([base_nueva @ p for p in locales])
        matriz_nueva = base_nueva.to_4x4()
        matriz_nueva.translation = centro_nuevo - centro_girado
        nueva_tanda = f"{letra}.{nueva_cara}.{nivel}/{nueva_col}"
        plan.append((obj, matriz_nueva, obj.scale.copy(), nueva_tanda))
    return plan


def _limites_x(objeto) -> tuple[float, float]:
    xs = [(objeto.matrix_world @ v.co).x for v in objeto.data.vertices]
    return min(xs), max(xs)


def correr_a() -> bool:
    """Corre `A` hasta que su pasillo con la pared este mida `PASILLO_A_PARED_ESTE`.

    Se calcula desde la posición de ahora y no desde un corrimiento fijo: repetirlo no mueve nada.
    """
    bpy.context.view_layer.update()
    gondola = _objeto("gondolanueva-col")
    _, este = _limites_x(gondola)
    corrimiento = PARED_ESTE_X - PASILLO_A_PARED_ESTE - este
    if abs(corrimiento) < 1e-4:
        print("A ya está a su distancia de la pared este; no cambia nada")
        return False
    gondola.location.x += corrimiento
    bpy.context.view_layer.update()
    oeste, este = _limites_x(gondola)
    _, borde_b = _limites_x(_objeto("gondolanueva2-col"))
    print(
        f"A corrida {corrimiento:+.4f}: pasillo con la pared este {PARED_ESTE_X - este:.4f}, "
        f"pasillo entre góndolas {oeste - borde_b:.4f}"
    )
    return True


def ya_espejado() -> bool:
    gondola_a = _objeto("gondolanueva-col")
    mesa_1 = _objeto("salon_mesa_1-col")
    a_espejada = gondola_a.location.x > X_ESPEJO
    mesa_espejada = mesa_1.location.x < X_ESPEJO
    if a_espejada != mesa_espejada:
        raise ValueError(
            "estado parcial en el salón: "
            f"gondolanueva-col en x={gondola_a.location.x:.4f}, "
            f"salon_mesa_1-col en x={mesa_1.location.x:.4f}"
        )
    return a_espejada


def espejar() -> bool:
    bpy.context.view_layer.update()
    if ya_espejado():
        print("el salón ya está espejado; no cambia nada")
        return False

    plan_tandas = _plan_de_tandas()
    bandejas_b = {
        cara: _destinos_de_bandejas(
            _objeto(f"gondolanueva2-{cara}-frente"), cara in ("este", "oeste")
        )
        for cara in ("este", "oeste", "norte", "sur")
    }

    for nombre in MESAS:
        mesa = _objeto(nombre)
        mesa.location.x = DOS_X_ESPEJO - mesa.location.x
    for nombre in SILLAS:
        silla = _objeto(nombre)
        silla.location.x = DOS_X_ESPEJO - silla.location.x
        silla.rotation_euler.z = -silla.rotation_euler.z

    for _, nombre in GONDOLAS:
        gondola = _objeto(nombre)
        gondola.location.x = DOS_X_ESPEJO - gondola.location.x
        _espejar_malla_local_x(gondola.data, gondola.material_slots, cambiar_lados=True)
        _intercambiar_propiedades_laterales(gondola)

    bpy.context.view_layer.update()

    for prefijo in ("gondolanueva", "gondolanueva2"):
        for cara in ("este", "oeste", "norte", "sur"):
            hijo = _objeto(f"{prefijo}-{cara}-noimp")
            _espejar_malla_local_x(hijo.data, hijo.material_slots)
        _intercambiar_mallas(_objeto(f"{prefijo}-este-noimp"), _objeto(f"{prefijo}-oeste-noimp"))

    for cara in ("este", "oeste", "sur"):
        frente_a = _objeto(f"gondolanueva-{cara}-frente")
        _espejar_malla_local_x(frente_a.data, frente_a.material_slots)
    _intercambiar_mallas(
        _objeto("gondolanueva-este-frente"), _objeto("gondolanueva-oeste-frente")
    )

    for cara, destinos in bandejas_b.items():
        _aplicar_vertices_mundo(_objeto(f"gondolanueva2-{cara}-frente"), destinos)
    _intercambiar_mallas(
        _objeto("gondolanueva2-este-frente"), _objeto("gondolanueva2-oeste-frente")
    )

    for obj, matriz_nueva, escala, nueva_tanda in plan_tandas:
        obj.matrix_world = matriz_nueva
        obj.scale = escala
        obj["tanda"] = nueva_tanda

    bpy.context.view_layer.update()
    tocados = [
        *(_objeto(nombre) for nombre in (*MESAS, *SILLAS)),
        *(_objeto(nombre) for _, nombre in GONDOLAS),
        *(hijo for _, nombre in GONDOLAS for hijo in _objeto(nombre).children),
        *(obj for obj, _, _, _ in plan_tandas),
    ]
    negativos = sorted({o.name for o in tocados if o.matrix_world.determinant() <= 0.0})
    if negativos:
        raise ValueError(f"objetos espejados con determinante no positivo: {negativos[:5]}")

    print(
        f"espejados {len(MESAS)} mesas, {len(SILLAS)} sillas, 2 góndolas y "
        f"{len(plan_tandas)} unidades respecto de x={X_ESPEJO}"
    )
    return True


def main() -> None:
    configurar()
    espejar()
    correr_a()
    if "--aplicar" in sys.argv:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")
    else:
        destino = RAIZ / "reports/espejar-salon.blend"
        destino.parent.mkdir(parents=True, exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
        print(f"prueba guardada en {destino}")


if __name__ == "__main__":
    main()
