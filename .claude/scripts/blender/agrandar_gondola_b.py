"""Lleva la segunda isla a la altura de la primera e invierte las bandejas de sus cabeceras.

    blender --background --python-exit-code 1 --python \\
        .claude/scripts/blender/agrandar_gondola_b.py -- --aplicar

Sin `--aplicar` guarda en `reports/agrandar-gondola-b.blend` y el `.blend` del repo queda como
estaba. Es una edición de un solo paso: después van `acomodar.py` y el resto de la cadena.

**Los estantes de cada cara quedan a la altura de los de la misma cara de la primera isla.** La
altura de un estante sale del borde de arriba de su etiqueta, en las dos islas. Cada estante sube
entero, con su chapa, su ménsula y su etiqueta; lo que está entre dos estantes, como los parantes
y el panel, se estira. En una cara estirada la textura conserva su escala: las UV se recalculan
con la misma relación entre el espacio y la imagen que tenían antes.

**La cabecera del exhibidor no cambia.** Las bandejas de los laterales suben con su estante. Las
de las dos cabeceras se intercambian, porque sus productos se intercambian en el reparto: cada
una pasa a la otra, a la misma distancia del medio de su estante.

**No es idempotente**: correrlo dos veces sube la isla dos veces. Por eso termina con un error
si la segunda isla ya tiene la altura de la primera.
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
#: Cada cara que sube, con la cara de la primera isla cuya altura toma.
CARAS = {
    "gondolanueva2-este-noimp": "gondolanueva-este-noimp",
    "gondolanueva2-oeste-noimp": "gondolanueva-oeste-noimp",
    "gondolanueva2-norte-noimp": "gondolanueva-norte-noimp",
}
BANDEJAS_DE_LOS_LATERALES = {
    "gondolanueva2-este-frente": "gondolanueva2-este-noimp",
    "gondolanueva2-oeste-frente": "gondolanueva2-oeste-noimp",
}
CABECERA_QUE_SUBE = ("gondolanueva2-norte-frente", "gondolanueva2-norte-noimp")
CABECERA_DEL_EXHIBIDOR = "gondolanueva2-sur-frente"
ETIQUETA = "GONDOLA | Etiqueta por grupo de productos"
#: Lo que sube con un estante, desde el borde de arriba de su etiqueta: la ménsula por debajo y la
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


def subida(objeto, modelo):
    """Una función de la altura vieja a la nueva: cada estante sube entero y el resto se estira."""
    viejos, nuevos = estantes(objeto), estantes(modelo)
    if len(viejos) != len(nuevos):
        raise SystemExit(f"{objeto.name} y {modelo.name} no tienen los mismos estantes.")
    piso = min(p.z for p in _puntos(objeto))
    techo = max(p.z for p in _puntos(objeto))
    techo_nuevo = max(p.z for p in _puntos(modelo))
    if abs(techo - techo_nuevo) < 0.01:
        raise SystemExit(f"{objeto.name} ya tiene la altura de {modelo.name}; no se guardó nada.")
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
    """Cada bandeja sube lo que sube el estante en que se apoya."""
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
    """Cada unidad sube lo que sube su estante."""
    for unidad, nivel in unidades_de(cara):
        unidad.matrix_world = (Matrix.Translation((0, 0, estantes_y_corrimientos[nivel][1]))
                               @ unidad.matrix_world)


def _marco(como, medio):
    """Los ejes del estante de una bandeja, con el origen en el medio de su frente."""
    adentro = (-como.afuera * como.fondo + Vector((0, 0, como.pendiente))).normalized()
    arriba = como.derecha.cross(adentro)
    origen = como.derecha * medio + como.afuera * como.frente + Vector((0, 0, como.adelante))
    marco = Matrix.Identity(4)
    for columna, eje in enumerate((como.derecha, adentro, arriba, origen)):
        for fila in range(3):
            marco[fila][columna] = eje[fila]
    return marco


def _por_estante(bandejas):
    import separadores_de_prueba as sp

    salida = {}
    for bandeja in bandejas:
        clave = next((k for k in salida if abs(k - bandeja.base) < sp.ENTRE_ESTANTES),
                     bandeja.base)
        salida.setdefault(clave, []).append(bandeja)
    return [salida[k] for k in sorted(salida)]


def _medio(bandejas):
    return (min(b.desde for b in bandejas) + max(b.desde + b.ancho for b in bandejas)) / 2


def invertir_cabeceras(norte, sur):
    """Las bandejas y las unidades de cada cabecera pasan a la otra, centradas en su estante como
    estaban: las unidades con el mismo movimiento que sus bandejas, y con otro rótulo."""
    import separadores_de_prueba as sp

    de_norte, de_sur = _por_estante(sp.bandejas_de(norte)), _por_estante(sp.bandejas_de(sur))
    if len(de_norte) != len(de_sur):
        raise SystemExit("Las cabeceras no tienen los mismos estantes; no se guardó nada.")
    unidades = {"B.norte": unidades_de("B.norte"), "B.sur": unidades_de("B.sur")}
    para_norte, para_sur = [], []
    for origenes, destinos, salida, de, a in (
        (de_sur, de_norte, para_norte, "B.sur", "B.norte"),
        (de_norte, de_sur, para_sur, "B.norte", "B.sur"),
    ):
        for nivel, (de_aca, de_alla) in enumerate(zip(origenes, destinos)):
            como = de_alla[0]
            medio_aca = _medio(de_aca)
            medio_alla = _medio(de_alla)
            for bandeja in de_aca:
                centro = medio_alla + bandeja.desde + bandeja.ancho / 2 - medio_aca
                salida += bandeja.colocar(como, centro, bandeja.ancho)
            movimiento = _marco(como, medio_alla) @ _marco(de_aca[0], medio_aca).inverted()
            for unidad, suyo in unidades[de]:
                if suyo == nivel:
                    unidad.matrix_world = movimiento @ unidad.matrix_world
                    unidad["tanda"] = a + str(unidad["tanda"])[len(de):]
    _reemplazar(norte, para_norte)
    _reemplazar(sur, para_sur)


def _cara(nombre):
    """La cara del reparto que dibuja un objeto de la segunda isla: `B.este`, `B.norte`..."""
    return "B." + nombre.split("-")[1]


def _reemplazar(objeto, caras):
    vieja = objeto.data
    nombre = vieja.name
    malla = bpy.data.meshes.new(nombre)
    for material in vieja.materials:
        malla.materials.append(material)
    bm = bmesh.new()
    capa = bm.loops.layers.uv.new(vieja.uv_layers.active.name)
    inversa = objeto.matrix_world.inverted()
    for cara in caras:
        nueva = bm.faces.new([bm.verts.new(inversa @ p) for p, _ in cara])
        for lazo, (_, uv) in zip(nueva.loops, cara):
            lazo[capa].uv = uv
    bm.to_mesh(malla)
    bm.free()
    objeto.data = malla
    bpy.data.meshes.remove(vieja)
    malla.name = nombre
    print(f"{objeto.name}: {len(caras)} caras")


def agrandar():
    norte, cuerpo_norte = (_objeto(n) for n in CABECERA_QUE_SUBE)
    sur = _objeto(CABECERA_DEL_EXHIBIDOR)
    corrimientos = {}
    for nombre, modelo in CARAS.items():
        objeto = _objeto(nombre)
        nueva, corrimientos[nombre] = subida(objeto, _objeto(modelo))
        subir(objeto, nueva)
    for bandejas, cuerpo in BANDEJAS_DE_LOS_LATERALES.items():
        subir_bandejas(_objeto(bandejas), corrimientos[cuerpo])
    for bandejas, cuerpo in BANDEJAS_DE_LOS_LATERALES.items():
        subir_unidades(_cara(bandejas), corrimientos[cuerpo])
    subir_bandejas(norte, corrimientos[cuerpo_norte.name])
    subir_unidades(_cara(norte.name), corrimientos[cuerpo_norte.name])
    invertir_cabeceras(norte, sur)


if __name__ == "__main__":
    configurar()
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    agrandar()
    prueba = RAIZ / "reports/agrandar-gondola-b.blend"
    destino = FUENTE if "--aplicar" in sys.argv else prueba
    destino.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
