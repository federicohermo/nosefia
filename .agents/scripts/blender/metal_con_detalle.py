"""Le da detalle a los metales del almacén: manchas de agua, rayones, mugre y satinado gastado.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/metal_con_detalle.py -- [--aplicar]

Sin `--aplicar` pinta en una carpeta temporal y no guarda nada. Con `--aplicar` escribe las
texturas en `assets/source/textures/metal/` y guarda la fuente canónica. Después van
`armar_atlas.py`, `exportar_modelo.py` y `assets/models/extraer_mallas.gd`. Si cambia una malla
del salón o del baño, también `hornear.py` y `hornear.py --sin-luz`: Godot rehace la UV del mapa
de luz.

## Por qué

El acero del baño, la base de las mesas y el mostrador eran un color liso con un solo brillo. Un
acero de verdad lleva manchas de agua, rayones, mugre en los encuentros y un satinado que se
gasta donde se toca. La pintura sale de la geometría (`metal_detalle.py`): cada texel sabe su
altura y su distancia al borde de su plano.

## Qué cambia

- Cada material de `CONJUNTOS` gana un color y un mapa ORM. Los materiales de un mismo conjunto
  comparten el par: no suma ni un dibujo ni una superficie.
- Las caras de esos materiales cambian de UV. **La geometría no se toca.** Ninguna cara se suma:
  sólo se parten vértices en las costuras de las islas.
- Las caras de un objeto con modificador `Bevel` van a un parche liso del atlas. El bisel
  interpola la UV entre dos islas lejanas y dibujaría una raya de basura.
- Corre dos veces y da lo mismo: la UV y las texturas salen sólo de la geometría y de las
  recetas.

## El acero de las cabinas y del mostrador

`bano_acero` es acero inoxidable satinado: el tono es parejo, no lleva huellas y sólo alguna
marca de agua chica cerca del piso. Las manchas redondas claras y oscuras repartidas por el perfil
no se leían como acero. Un cepillado de líneas largas y contrastadas tampoco: se leía como madera.
`MOSTRADOR | Acero satinado` va limpio y parejo, sin manchas de agua, nubes ni rayones: sólo el
grano fino del satinado y el reflejo de la sonda.

## Lo que no cambia

La grilla, el panel perforado y la ranura de los parantes de la góndola conservan su arte.
"""

import hashlib
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import metal_detalle as metal  # noqa: E402

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
from lib.consola import configurar  # noqa: E402

configurar()

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
CARPETA = RAIZ / "assets/source/textures/metal"


@dataclass(frozen=True)
class Conjunto:
    """Los materiales que comparten un par de texturas."""

    nombre: str
    lado: int
    densidad: float
    recetas: dict[str, "metal.Receta"]


def _srgb(lineal: float) -> float:
    return lineal * 12.92 if lineal <= 0.0031308 else 1.055 * lineal ** (1 / 2.4) - 0.055


def _receta(lineal, rugosidad, metal_, suelo, **resto) -> "metal.Receta":
    color = tuple(round(_srgb(c), 4) for c in lineal)
    return metal.Receta(color=color, rugosidad=rugosidad, metal=metal_, suelo=suelo, **resto)


#: El piso del local queda a esta altura en el modelo.
SUELO = 0.1

#: El tono liso que tenía cada material, en lineal. Es el tono medio que se conserva.
CONJUNTOS = (
    Conjunto(
        "acero_del_bano",
        1024,
        420.0,
        {
            "bano_acero": _receta((0.52, 0.57, 0.57), 0.30, 0.75, SUELO, semilla=3,
                                  manchas=0.06, huellas=0.0, rayones=0.3, mugre=0.5,
                                  variacion=0.2),
            "bano_griferia": _receta((0.52, 0.57, 0.57), 0.16, 0.75, SUELO, semilla=5,
                                     rayones=0.6, manchas=0.3, mugre=0.5, variacion=0.3),
            "bano_desague": _receta((0.52, 0.57, 0.57), 0.20, 0.75, SUELO, semilla=7,
                                    rayones=0.6, manchas=0.3, mugre=0.5, variacion=0.3),
        },
    ),
    Conjunto(
        "cromo_de_las_mesas",
        512,
        420.0,
        {"MESA | Base cromada": _receta((0.75, 0.76, 0.78), 0.25, 0.90, SUELO, semilla=11,
                                        manchas=0.25, mugre=0.5, variacion=0.3)},
    ),
    Conjunto(
        "acero_del_mostrador",
        1024,
        380.0,
        {"MOSTRADOR | Acero satinado": _receta((0.37, 0.37, 0.37), 0.32, 0.84, SUELO,
                                               semilla=13, manchas=0.0, mugre=0.0,
                                               rayones=0.0, huellas=0.0, variacion=0.0)},
    ),
)


class Registro:
    """Una malla con caras de un material, y lo que hace falta para pintarle la UV."""

    def __init__(self, objeto, material: str):
        self.objeto = objeto
        self.malla = objeto.data
        self.material = material
        indices = [
            i for i, m in enumerate(self.malla.materials) if m is not None and m.name == material
        ]
        self.poligonos = [p for p in self.malla.polygons if p.material_index in indices]
        n = len(self.malla.vertices)
        local = np.empty(n * 3, dtype=np.float64)
        self.malla.vertices.foreach_get("co", local)
        local = local.reshape(n, 3)
        matriz = np.array(objeto.matrix_world, dtype=np.float64)
        self.posiciones = local @ matriz[:3, :3].T + matriz[:3, 3]
        self.lisa = any(m.type == "BEVEL" for m in objeto.modifiers)
        forma = [tuple(p.vertices) for p in self.poligonos]
        base = (
            tuple(map(tuple, np.round(local, 5).tolist())),
            tuple(forma),
            tuple(map(tuple, np.round(matriz[:3, :3], 4).tolist())),
        )
        self.clave = hashlib.sha1(repr((base, material, self.lisa)).encode()).hexdigest()
        self.islas: list = []
        self.sin_area: list[int] = []
        self.maestro: "Registro | None" = None


def _registros(material: str) -> list[Registro]:
    por_malla: dict[str, list] = {}
    for objeto in sorted(bpy.data.objects, key=lambda o: o.name):
        if objeto.type == "MESH":
            por_malla.setdefault(objeto.data.name_full, []).append(objeto)
    registros = []
    for objetos in por_malla.values():
        if not any(m is not None and m.name == material for m in objetos[0].data.materials):
            continue
        registro = Registro(objetos[0], material)
        if not registro.poligonos:
            continue
        # Una malla compartida con un objeto de Bevel también queda lisa.
        registro.lisa = any(m.type == "BEVEL" for o in objetos for m in o.modifiers)
        registros.append(registro)
    return registros


def _preparar(conjunto: Conjunto) -> tuple[list, list, dict]:
    """Los registros, todas las islas del conjunto y la receta de cada material."""
    recetas = list(conjunto.recetas.values())
    registros, islas = [], []
    numero = 0
    maestros: dict[str, Registro] = {}
    for material, receta in conjunto.recetas.items():
        for registro in _registros(material):
            registros.append(registro)
            if registro.lisa:
                continue
            clave = registro.clave
            if clave in maestros:
                registro.maestro = maestros[clave]
                continue
            maestros[clave] = registro
            poligonos = [list(p.vertices) for p in registro.poligonos]
            registro.islas, registro.sin_area = metal.armar_islas(registro.posiciones, poligonos)
            for isla in registro.islas:
                isla.receta = receta
                isla.numero = numero
                numero += 1
                islas.append(isla)
    return registros, islas, {r: i for i, r in enumerate(recetas)}


def _escribir_uv(registro: Registro, conjunto: Conjunto, densidad: float, indices: dict) -> None:
    malla = registro.malla
    capa = malla.uv_layers.active or malla.uv_layers[0]
    receta = conjunto.recetas[registro.material]
    parche = metal.parche_liso(receta, conjunto.lado, indices[receta])
    if registro.lisa:
        for poligono in registro.poligonos:
            for lazo in poligono.loop_indices:
                capa.data[lazo].uv = parche
        return
    fuente = registro.maestro or registro
    posiciones = fuente.posiciones
    for isla in fuente.islas:
        for cara in isla.caras:
            destino = registro.poligonos[cara]
            origen = fuente.poligonos[cara]
            for lazo, vertice in zip(destino.loop_indices, origen.vertices):
                capa.data[lazo].uv = metal.uv_de(isla, posiciones[vertice], densidad, conjunto.lado)
    for cara in fuente.sin_area:
        for lazo in registro.poligonos[cara].loop_indices:
            capa.data[lazo].uv = parche


def _imagen(ruta: Path, espacio: str) -> "bpy.types.Image":
    imagen = bpy.data.images.load(str(ruta), check_existing=True)
    imagen.reload()
    imagen.filepath = bpy.path.relpath(str(ruta))
    imagen.colorspace_settings.name = espacio
    return imagen


def _cablear(material, color: Path, orm: Path) -> None:
    arbol = material.node_tree
    nodos = arbol.nodes
    principal = nodos.get("Principled BSDF")
    nodo_color = nodos.get("Metal color") or nodos.new("ShaderNodeTexImage")
    nodo_color.name = nodo_color.label = "Metal color"
    nodo_color.image = _imagen(color, "sRGB")
    nodo_color.interpolation = "Closest"
    nodo_orm = nodos.get("Metal ORM") or nodos.new("ShaderNodeTexImage")
    nodo_orm.name = nodo_orm.label = "Metal ORM"
    nodo_orm.image = _imagen(orm, "Non-Color")
    nodo_orm.interpolation = "Closest"
    separar = nodos.get("Metal ORM separado") or nodos.new("ShaderNodeSeparateColor")
    separar.name = separar.label = "Metal ORM separado"
    separar.mode = "RGB"
    nodo_color.location = (-700, 300)
    nodo_orm.location = (-700, -100)
    separar.location = (-420, -100)
    enlaces = arbol.links
    enlaces.new(nodo_color.outputs["Color"], principal.inputs["Base Color"])
    enlaces.new(nodo_orm.outputs["Color"], separar.inputs["Color"])
    enlaces.new(separar.outputs["Green"], principal.inputs["Roughness"])
    enlaces.new(separar.outputs["Blue"], principal.inputs["Metallic"])


def aplicar(conjunto: Conjunto, destino: Path) -> str:
    registros, islas, indices = _preparar(conjunto)
    recetas = list(conjunto.recetas.values())
    reservado = metal.LADO_DEL_PARCHE * 2
    densidad = metal.elegir_densidad(
        islas, conjunto.lado, conjunto.densidad, reservado=reservado
    )
    color, orm = metal.armar_atlas(islas, recetas, conjunto.lado, densidad)
    destino.mkdir(parents=True, exist_ok=True)
    ruta_color = destino / f"{conjunto.nombre}_color.png"
    ruta_orm = destino / f"{conjunto.nombre}_orm.png"
    ruta_color.write_bytes(metal.png_de(color))
    ruta_orm.write_bytes(metal.png_de(metal.reducir_a_la_mitad(orm)))
    for registro in registros:
        _escribir_uv(registro, conjunto, densidad, indices)
    for nombre in conjunto.recetas:
        _cablear(bpy.data.materials[nombre], ruta_color, ruta_orm)
    lisas = sum(1 for r in registros if r.lisa)
    for registro in sorted(registros, key=lambda r: -sum(i.ancho * i.alto for i in r.islas))[:5]:
        area = sum(i.ancho * i.alto for i in registro.islas)
        print(f"  {registro.objeto.name}: {len(registro.islas)} islas, {area:.2f} m2")
    return (
        f"{conjunto.nombre}: {len(registros)} mallas ({lisas} lisas), {len(islas)} islas, "
        f"{sum(i.ancho * i.alto for i in islas):.1f} m2, {densidad:.0f} texeles/m, "
        f"color {ruta_color.stat().st_size:,} B, "
        f"orm {ruta_orm.stat().st_size:,} B"
    )


def main() -> None:
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    guardar = "--aplicar" in argumentos
    destino = CARPETA if guardar else Path(tempfile.mkdtemp(prefix="metal_con_detalle_"))
    for conjunto in CONJUNTOS:
        print(aplicar(conjunto, destino))
    if guardar:
        bpy.ops.wm.save_mainfile()
        print(f"guardado: {FUENTE}")
    else:
        print(f"sin --aplicar: texturas en {destino}")


if __name__ == "__main__":
    main()
