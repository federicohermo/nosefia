"""Devuelve la segunda isla a su altura achicada. Se aplica una sola vez.

    blender --background --python-exit-code 1 --python \
        .claude/scripts/blender/achicar_gondola_b.py -- --aplicar

Sin `--aplicar` guarda en `reports/achicar-gondola-b.blend` y el `.blend` del repo queda como
estaba. Después va el resto de la cadena.

**Cada estante baja entero, con su chapa, su ménsula y su etiqueta.** Lo que está entre dos
estantes, como los parantes y el panel, se encoge. En una cara encogida la textura conserva su
escala: las UV se recalculan con la misma relación entre el espacio y la imagen que tenían antes.

**La cabecera del exhibidor no cambia.** Las bandejas y las unidades de las otras caras bajan con
su estante. Termina con un error si la isla ya tiene esa altura.
"""

import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
sys.path.insert(0, str(RAIZ / ".claude/scripts/blender"))
from lib.consola import configurar  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
#: La altura de la etiqueta de cada estante de cada cara, de abajo hacia arriba, y la del mueble.
ALTURAS = {
    "gondolanueva2-este-noimp": ((0.316, 0.716, 1.116, 1.516), 1.821),
    "gondolanueva2-oeste-noimp": ((0.316, 0.716, 1.116, 1.516), 1.821),
    "gondolanueva2-norte-noimp": ((0.316, 0.677, 1.077, 1.477), 1.821),
}
BANDEJAS_DE_LOS_LATERALES = {
    "gondolanueva2-este-frente": "gondolanueva2-este-noimp",
    "gondolanueva2-oeste-frente": "gondolanueva2-oeste-noimp",
}
CABECERA = ("gondolanueva2-norte-frente", "gondolanueva2-norte-noimp")
ETIQUETA = "GONDOLA | Etiqueta por grupo de productos"
#: Lo que baja con un estante, desde el borde de arriba de su etiqueta: la ménsula por debajo y la
#: chapa con su labio por encima.
DEBAJO_DE_LA_ETIQUETA = 0.14
ENCIMA_DE_LA_ETIQUETA = 0.05
#: Dos etiquetas a menos de esto en altura son del mismo estante.
MISMO_ESTANTE = 0.03


def _objeto(nombre):
    objeto = bpy.data.objects.get(nombre)
    if objeto is None:
        raise SystemExit(f"Falta el objeto «{nombre}» en {FUENTE.name}; no se guardó nada.")
    return objeto


def _puntos(objeto):
    return [objeto.matrix_world @ v.co for v in objeto.data.vertices]


def estantes(objeto):
    """El borde de arriba de la etiqueta de cada estante, de abajo hacia arriba."""
    malla = objeto.data
    bordes = []
    for cara in malla.polygons:
        material = objeto.material_slots[cara.material_index].material
        if material is None or material.name != ETIQUETA:
            continue
        bordes.append(max((objeto.matrix_world @ malla.vertices[v].co).z for v in cara.vertices))
    salida = []
    for borde in sorted(bordes):
        if salida and borde - salida[-1] < MISMO_ESTANTE:
            salida[-1] = max(salida[-1], borde)
        else:
            salida.append(borde)
    return salida


def subida(objeto, nuevos, techo_nuevo):
    """Una función de la altura vieja a la nueva: cada estante va entero y el resto se ajusta."""
    viejos = estantes(objeto)
    if len(viejos) != len(nuevos):
        raise SystemExit(f"{objeto.name} no tiene {len(nuevos)} estantes.")
    piso = min(p.z for p in _puntos(objeto))
    techo = max(p.z for p in _puntos(objeto))
    if abs(techo - techo_nuevo) < 0.01:
        raise SystemExit(f"{objeto.name} ya tiene esa altura; no se guardó nada.")
    fijos = [(piso, piso, 0.0)]
    for viejo, nuevo in zip(viejos, nuevos):
        fijos.append((viejo - DEBAJO_DE_LA_ETIQUETA, viejo + ENCIMA_DE_LA_ETIQUETA, nuevo - viejo))
    fijos.append((techo, techo, techo_nuevo - techo))

    def nueva(z):
        for desde, hasta, corrimiento in fijos:
            if desde <= z <= hasta:
                return z + corrimiento
        for (_, a, da), (b, _, db) in zip(fijos, fijos[1:]):
            if a < z < b:
                return a + da + (z - a) * ((b + db) - (a + da)) / (b - a)
        return z + fijos[-1][2]

    return nueva, [(v, n - v) for v, n in zip(viejos, nuevos)]


def _uv_conservada(bm, cara, capa, viejas):
    """Las UV de una cara que se estiró, con la misma relación entre espacio e imagen."""
    import numpy as np

    puntos = np.array([[*viejas[v.index], 1.0] for v in cara.verts])
    uvs = np.array([tuple(l[capa].uv) for l in cara.loops])
    relacion, *_ = np.linalg.lstsq(puntos, uvs, rcond=None)
    for lazo in cara.loops:
        nueva = np.array([*lazo.vert.co, 1.0]) @ relacion
        lazo[capa].uv = (float(nueva[0]), float(nueva[1]))


def subir(objeto, nueva):
    """Mueve cada vértice a su altura nueva y recalcula las UV de las caras que se estiraron."""
    bm = bmesh.new()
    bm.from_mesh(objeto.data)
    mundo = objeto.matrix_world
    inversa = mundo.inverted()
    viejas = {v.index: tuple(v.co) for v in bm.verts}
    corrimientos = {}
    for v in bm.verts:
        p = mundo @ v.co
        corrimientos[v.index] = nueva(p.z) - p.z
        v.co = inversa @ Vector((p.x, p.y, p.z + corrimientos[v.index]))
    capas = list(bm.loops.layers.uv.values())
    estiradas = 0
    for cara in bm.faces:
        valores = [corrimientos[v.index] for v in cara.verts]
        if max(valores) - min(valores) > 1e-5:
            estiradas += 1
            for capa in capas:
                _uv_conservada(bm, cara, capa, viejas)
    bm.to_mesh(objeto.data)
    bm.free()
    objeto.data.update()
    print(f"{objeto.name}: {estiradas} caras estiradas")


def subir_bandejas(objeto, estantes_y_corrimientos):
    """Cada bandeja se mueve lo que se mueve el estante en que se apoya."""
    mundo = objeto.matrix_world
    inversa = mundo.inverted()
    for v in objeto.data.vertices:
        p = mundo @ v.co
        corrimiento = 0.0
        for borde, sube in estantes_y_corrimientos:
            if p.z >= borde - ENCIMA_DE_LA_ETIQUETA:
                corrimiento = sube
        v.co = inversa @ Vector((p.x, p.y, p.z + corrimiento))
    objeto.data.update()


def unidades_de(cara):
    """Las unidades y copias rotuladas de una cara, cada una con el nivel de su estante."""
    prefijo = f"{cara}."
    return [(o, int(str(o["tanda"])[len(prefijo):].split("/")[0])) for o in bpy.data.objects
            if str(o.get("tanda", "")).startswith(prefijo)]


def subir_unidades(cara, estantes_y_corrimientos):
    """Cada unidad se mueve lo que se mueve su estante."""
    for unidad, nivel in unidades_de(cara):
        unidad.matrix_world = (Matrix.Translation((0, 0, estantes_y_corrimientos[nivel][1]))
                               @ unidad.matrix_world)


def _cara(nombre):
    """La cara del reparto que dibuja un objeto de la segunda isla: `B.este`, `B.norte`..."""
    return "B." + nombre.split("-")[1]


def achicar():
    norte, cuerpo_norte = (_objeto(n) for n in CABECERA)
    corrimientos = {}
    for nombre, (nuevos, techo) in ALTURAS.items():
        objeto = _objeto(nombre)
        nueva, corrimientos[nombre] = subida(objeto, nuevos, techo)
        subir(objeto, nueva)
    for bandejas, cuerpo in BANDEJAS_DE_LOS_LATERALES.items():
        subir_bandejas(_objeto(bandejas), corrimientos[cuerpo])
        subir_unidades(_cara(bandejas), corrimientos[cuerpo])
    subir_bandejas(norte, corrimientos[cuerpo_norte.name])
    subir_unidades(_cara(norte.name), corrimientos[cuerpo_norte.name])


if __name__ == "__main__":
    configurar()
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    achicar()
    prueba = RAIZ / "reports/achicar-gondola-b.blend"
    destino = FUENTE if "--aplicar" in sys.argv else prueba
    destino.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
