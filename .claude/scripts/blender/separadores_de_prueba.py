"""Arma los separadores de la góndola para el mapa de las jornadas de prueba.

    blender --background --python-exit-code 1 --python \\
        .claude/scripts/blender/separadores_de_prueba.py -- --aplicar
    python .claude/scripts/exportar_modelo.py
    python .claude/scripts/integrar_modelo.py
    python .claude/scripts/actualizar_apoyos.py

Sin `--aplicar` guarda en `reports/separadores-de-prueba.blend` y el `.blend` del repo queda como
estaba.

**Los separadores son bandejas a medida.** Cada una lleva en el frente la tira del producto que
tiene encima, y su ancho sale de las unidades de ese producto. El mapa de prueba pone otro
producto en el mismo tramo, así que pide sus propias bandejas: una copia de cada cara, con el
sufijo `-prueba`, que el juego muestra en las jornadas de prueba en lugar de la del mapa completo.

**El molde de cada bandeja es la del mismo producto en el mapa completo.** Trae el perfil y la
tira que pintó el artista. Si el producto no tiene bandeja propia pero sí tira en el atlas, el
molde es la bandeja de una unidad del producto de ancho más parecido, con la tira cambiada de
fila. Un producto sin tira no lleva bandeja, y el script lo nombra.

Las bandejas de un tramo cuyo producto no cambia se copian tal cual. Los separadores del mapa
completo no se tocan.

**Es idempotente.** Si las copias ya existen, se borran y se vuelven a hacer.
"""

import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
sys.path.insert(0, str(RAIZ / ".claude/scripts/blender"))
from lib.consola import configurar  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
PREFIJO = "gondolanueva2-"
SUFIJO = "-frente"
COPIA = "-prueba"
TIRAS = "topes_a_medida.png"
RUTA_DE_LAS_TIRAS = "//../source/textures/store/topes_a_medida.png"
#: Las filas del atlas de tiras, de arriba hacia abajo. Todas tienen el mismo alto.
FILAS = (
    "OREMOS", "PEPITO", "SALADICK", "PROGRES", "CHISITOS", "LAYSNNT", "BURBALOO", "JORGILLO",
    "DON_SATURADOS", "PETISAS", "FEEL_RICKY_FORT", "COSA_DE_MANI", "FLIM_POF",
)
#: Dos caras a menos de esto a lo largo del estante son de la misma bandeja.
JUNTA = 0.001
#: Lo menos que se separan dos bandejas vecinas.
ENTRE_BANDEJAS = 0.003
#: Hasta dónde, por encima o por debajo de la base de una tanda, está el piso de su bandeja.
ALTURA = 0.03
#: Menos que lo que separa dos estantes y más que el alto de una bandeja: el frente de una
#: bandeja arranca más arriba que su piso y sigue siendo del mismo estante.
ENTRE_ESTANTES = 0.15
#: La franja del frente y la del fondo de una bandeja, en fracción de su fondo.
BORDE = 0.2


class Bandeja:
    """Las caras de una bandeja, en sus ejes: a lo ancho, hacia adentro desde el frente, y alto."""

    def __init__(self, objeto, caras, eje):
        self.objeto = objeto
        puntos = [p for cara in caras for p, _ in cara]
        alto = max(puntos, key=lambda p: p.z)
        medio = (min(p[1 - eje] for p in puntos) + max(p[1 - eje] for p in puntos)) / 2
        afuera = Vector((0, 0, 0))
        afuera[1 - eje] = 1.0 if alto[1 - eje] > medio else -1.0
        self.afuera = afuera
        self.derecha = (-afuera).cross(Vector((0, 0, 1)))
        self.frente = max(p.dot(afuera) for p in puntos)
        self.fondo = self.frente - min(p.dot(afuera) for p in puntos)
        self.base = min(p.z for p in puntos)
        self.desde = min(p.dot(self.derecha) for p in puntos)
        self.ancho = max(p.dot(self.derecha) for p in puntos) - self.desde
        # Un estante de cabecera sube hacia adentro: la bandeja guarda su forma sobre esa
        # pendiente, y al copiarla toma la del estante al que llega.
        hondura = [(self.frente - p.dot(afuera)) / self.fondo for p in puntos]
        self.adelante = min(p.z for p, h in zip(puntos, hondura) if h < BORDE)
        self.pendiente = min(p.z for p, h in zip(puntos, hondura) if h > 1 - BORDE) - self.adelante
        self.caras = [
            [(Vector(((p.dot(self.derecha) - self.desde) / self.ancho,
                      (self.frente - p.dot(afuera)) / self.fondo, 0.0)), uv, p.z)
             for p, uv in cara]
            for cara in caras
        ]
        for cara in self.caras:
            for local, _, z in cara:
                local.z = z - self.adelante - local.y * self.pendiente
        self.caras = [[(local, uv) for local, uv, _ in cara] for cara in self.caras]
        self.unidades = []
        self.margen = None

    def contiene(self, caja):
        a = min(caja[0].dot(self.derecha), caja[1].dot(self.derecha))
        b = max(caja[0].dot(self.derecha), caja[1].dot(self.derecha))
        return (abs(min(caja[0].z, caja[1].z) - self.base) < ALTURA
                and self.desde - 0.005 <= a and b <= self.desde + self.ancho + 0.005
                and _cruza_en_profundidad(self, caja))

    def colocar(self, como, centro, ancho, desplazar_v=0.0):
        """Las caras de esta bandeja con el lugar, el ancho y el fondo de `como`."""
        salida = []
        for cara in self.caras:
            nueva = []
            for local, uv in cara:
                punto = (como.derecha * (centro + (local.x - 0.5) * ancho)
                         + como.afuera * (como.frente - local.y * como.fondo)
                         + Vector((0, 0, como.adelante + local.y * como.pendiente + local.z)))
                nueva.append((punto, (uv[0], uv[1] + desplazar_v)))
            salida.append(nueva)
        return salida


def _extension(puntos, eje):
    return max(p[eje] for p in puntos) - min(p[eje] for p in puntos)


def _cruza_en_profundidad(bandeja, caja):
    vs = (caja[0].dot(bandeja.afuera), caja[1].dot(bandeja.afuera))
    return min(vs) < bandeja.frente and max(vs) > bandeja.frente - bandeja.fondo


def _objeto(nombre):
    objeto = bpy.data.objects.get(nombre)
    if objeto is None:
        raise SystemExit(f"Falta el objeto «{nombre}» en {FUENTE.name}; no se guardó nada.")
    return objeto


def bandejas_de(objeto):
    """Las bandejas de una cara: sus caras agrupadas por estante y por tramo del estante."""
    malla = objeto.data
    uvs = malla.uv_layers.active.data
    caras = [
        [(objeto.matrix_world @ malla.vertices[v].co, tuple(uvs[l].uv))
         for v, l in zip(p.vertices, p.loop_indices)]
        for p in malla.polygons
    ]
    puntos = [p for cara in caras for p, _ in cara]
    eje = 0 if _extension(puntos, 0) > _extension(puntos, 1) else 1
    por_estante = {}
    for cara in caras:
        piso = min(p.z for p, _ in cara)
        clave = next((k for k in por_estante if abs(k - piso) < ENTRE_ESTANTES), piso)
        por_estante.setdefault(clave, []).append(cara)
    salida = []
    for _, del_estante in sorted(por_estante.items()):
        del_estante.sort(key=lambda c: min(p[eje] for p, _ in c))
        grupos = []
        for cara in del_estante:
            desde = min(p[eje] for p, _ in cara)
            hasta = max(p[eje] for p, _ in cara)
            if grupos and desde <= grupos[-1][1] + JUNTA:
                grupos[-1][1] = max(grupos[-1][1], hasta)
                grupos[-1][2].append(cara)
            else:
                grupos.append([desde, hasta, [cara]])
        salida += [Bandeja(objeto, g[2], eje) for g in grupos]
    return salida


def _caja(unidad):
    puntos = [unidad.matrix_world @ v.co for v in unidad.data.vertices]
    return (Vector([min(p[i] for p in puntos) for i in range(3)]),
            Vector([max(p[i] for p in puntos) for i in range(3)]))


def moldes(bandejas, tandas):
    """La bandeja que se copia para cada producto: la de menos unidades de las que tiene."""
    por_producto = {}
    for copias in tandas.values():
        producto = str(copias[0]["producto"])
        for unidad in copias:
            if unidad["fila"] != "adelante":
                continue
            caja = _caja(unidad)
            for bandeja in bandejas:
                if bandeja.contiene(caja):
                    bandeja.unidades.append(producto)
                    us = (caja[0].dot(bandeja.derecha), caja[1].dot(bandeja.derecha))
                    margen = min(min(us) - bandeja.desde,
                                 bandeja.desde + bandeja.ancho - max(us))
                    bandeja.margen = margen if bandeja.margen is None else min(
                        bandeja.margen, margen)
    for bandeja in bandejas:
        if bandeja.unidades:
            producto = bandeja.unidades[0]
            actual = por_producto.get(producto)
            if actual is None or len(bandeja.unidades) < len(actual.unidades):
                por_producto[producto] = bandeja
    return por_producto


def molde_prestado(producto, por_producto, anchos):
    """La bandeja de una unidad del producto de ancho más parecido, y cuánto se corre su tira."""
    if producto not in FILAS:
        return None, 0.0
    unitarias = {p: b for p, b in por_producto.items() if len(b.unidades) == 1 and p in FILAS}
    prestado = min(unitarias, key=lambda p: (abs(anchos[p] - anchos[producto]), p))
    corrimiento = (FILAS.index(prestado) - FILAS.index(producto)) / len(FILAS)
    return unitarias[prestado], corrimiento


def _centros(unidades, derecha):
    return sorted(
        (sum(c.dot(derecha) for c in _caja(u)) / 2, abs(_caja(u)[1].dot(derecha) - _caja(u)[0].dot(derecha)))
        for u in unidades
    )


def bandejas_nuevas(como, molde, corrimiento, unidades, limites):
    """Una bandeja por cada grupo de unidades: el ancho del molde, o el del grupo con el margen
    del molde si las unidades quedan más separadas, sin pasar la mitad del aire con sus vecinas."""
    por_bandeja = len(molde.unidades)
    centros = _centros(unidades, como.derecha)
    grupos = [centros[i:i + por_bandeja] for i in range(0, len(centros), por_bandeja)]
    medios = [sum(c for c, _ in g) / len(g) for g in grupos]
    salida = []
    for i, medio in enumerate(medios):
        izquierda = limites[0] if i == 0 else (
            grupos[i - 1][-1][0] + grupos[i - 1][-1][1] / 2 + grupos[i][0][0] - grupos[i][0][1] / 2
        ) / 2 + ENTRE_BANDEJAS / 2
        derecha = limites[1] if i == len(grupos) - 1 else (
            grupos[i][-1][0] + grupos[i][-1][1] / 2 + grupos[i + 1][0][0] - grupos[i + 1][0][1] / 2
        ) / 2 - ENTRE_BANDEJAS / 2
        grupo = grupos[i][-1][0] + grupos[i][-1][1] / 2 - grupos[i][0][0] + grupos[i][0][1] / 2
        ancho = min(max(molde.ancho, grupo + 2 * max(molde.margen, 0.0)),
                    2 * (medio - izquierda), 2 * (derecha - medio))
        salida += molde.colocar(como, medio, ancho, corrimiento)
    return salida


def armar():
    import disponer
    import disponer_prueba
    from lib.reparto import partes, producto
    from lib.reparto_de_prueba import CARAS

    imagen = bpy.data.images.get(TIRAS)
    if imagen is None:
        raise SystemExit(f"Falta la imagen «{TIRAS}»; no se guardó nada.")
    imagen.filepath = RUTA_DE_LAS_TIRAS
    for objeto in [o for o in bpy.data.objects if o.name.endswith(SUFIJO + COPIA)]:
        bpy.data.objects.remove(objeto, do_unlink=True)
    caras = [o for o in bpy.data.objects
             if o.type == "MESH" and o.name.startswith(PREFIJO) and o.name.endswith(SUFIJO)]
    if not caras:
        raise SystemExit("No hay separadores en la góndola; no se guardó nada.")
    bandejas = [b for objeto in caras for b in bandejas_de(objeto)]
    completo = disponer.tandas_del_blend()
    por_producto = moldes(bandejas, completo)
    anchos = {}
    for copias in completo.values():
        clave = str(copias[0]["producto"])
        modelo = producto(clave)
        anchos[clave] = disponer_prueba.acomodar.envase_de(modelo, bpy.data.objects[modelo.objeto]).ancho
    por_cara = {}
    for clave, copias in completo.items():
        letra, cara, _ = partes(clave.split("/")[0])
        if f"{letra}.{cara}" in CARAS:
            por_cara.setdefault(f"{letra}.{cara}", {})[clave] = copias
    nuevas = {objeto.name: [] for objeto in caras}
    sin_tira = set()
    temporales = []
    for cara, de_la_cara in sorted(por_cara.items()):
        columnas = disponer_prueba.columnas_de_prueba(cara, de_la_cara)
        for clave, copias in sorted(de_la_cara.items()):
            debajo = [b for b in bandejas if b.unidades and any(
                b.contiene(_caja(u)) for u in copias if u["fila"] == "adelante")]
            if not debajo:
                continue
            nuevo = columnas[int(clave.split("/")[1])]
            if str(copias[0]["producto"]) == nuevo:
                for b in debajo:
                    nuevas[b.objeto.name] += b.colocar(b, b.desde + b.ancho / 2, b.ancho)
                continue
            if nuevo not in anchos:
                modelo = producto(nuevo)
                anchos[nuevo] = disponer_prueba.acomodar.envase_de(
                    modelo, bpy.data.objects[modelo.objeto]).ancho
            molde, corrimiento = por_producto.get(nuevo), 0.0
            if molde is None:
                molde, corrimiento = molde_prestado(nuevo, por_producto, anchos)
            if molde is None:
                sin_tira.add(nuevo)
                continue
            unidades = disponer_prueba.cambiar(copias, nuevo)
            temporales += unidades
            como = debajo[0]
            limites = (min(b.desde for b in debajo), max(b.desde + b.ancho for b in debajo))
            nuevas[como.objeto.name] += bandejas_nuevas(como, molde, corrimiento, unidades, limites)
    for unidad in temporales:
        bpy.data.objects.remove(unidad, do_unlink=True)
    for objeto in caras:
        _escribir(objeto, nuevas[objeto.name])
    for clave in sorted(sin_tira):
        print(f"{clave}: sin tira en el atlas, va sin bandeja")


def _escribir(original, caras):
    malla = bpy.data.meshes.new(original.data.name + COPIA)
    for material in original.data.materials:
        malla.materials.append(material)
    destino = bmesh.new()
    capa = destino.loops.layers.uv.new(original.data.uv_layers.active.name)
    for cara in caras:
        vertices = [destino.verts.new(original.matrix_world.inverted() @ p) for p, _ in cara]
        nueva = destino.faces.new(vertices)
        for lazo, (_, uv) in zip(nueva.loops, cara):
            lazo[capa].uv = uv
    destino.to_mesh(malla)
    destino.free()
    copia = bpy.data.objects.new(original.name + COPIA, malla)
    copia.parent = original.parent
    copia.matrix_world = original.matrix_world.copy()
    for coleccion in original.users_collection:
        coleccion.objects.link(copia)
    print(f"{copia.name}: {len(caras)} caras")


if __name__ == "__main__":
    configurar()
    bpy.ops.wm.open_mainfile(filepath=str(FUENTE), load_ui=False)
    armar()
    prueba = RAIZ / "reports/separadores-de-prueba.blend"
    destino = FUENTE if "--aplicar" in sys.argv else prueba
    destino.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(destino), check_existing=False)
