"""Le da detalle de metal satinado usado al baño, las mesas, el mostrador y los ventanales.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/metal_con_detalle.py -- [--aplicar] \
        [--combinacion {sutil,usado}]

Sin `--aplicar` pinta en una carpeta temporal y no guarda nada. Con `--aplicar` escribe las
texturas en `assets/source/textures/metal/` y guarda la fuente canónica. Después van
`armar_atlas.py`, `exportar_modelo.py` y `assets/models/extraer_mallas.gd`.

## Por qué

El metal liso se lee como plástico gris. En el salón, las mesas y el baño hay sondas de reflejos
(`ReflectionProbe`). Lo que más lee el ojo en el metal es el cambio de rugosidad en el canal G del
mapa ORM. Las huellas, los rayones finos y la suciedad de los encuentros cambian tanto el color
como la rugosidad. Las gotas chicas de agua sólo aparecen cerca del piso del baño.

## Qué cambia

- Cada conjunto gana una textura de color y un mapa ORM de igual resolución en
  `assets/source/textures/metal/`.
- Las caras tapadas contra el piso, el techo o la calle van al parche liso para ganar densidad en
  las caras visibles.
- Los marcos huecos de `local_aluminio` alojan las islas menores adentro de sus vanos vacíos sin
  tocar la geometría ni desarmar el mapa de luz horneado.
- **No suma materiales, llamadas de dibujo ni triángulos (`0` triángulos sumados).**
- Es idempotente: dos corridas sobre la misma geometría escriben los mismos bytes.

## Lo que cuesta

Cuatro pares de texturas (`1024×1024` en baño, mostrador y aluminio; `512×512` en las mesas) y
`0` triángulos.
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

#: Caras exteriores o embutidas en el cielorraso del frente y el ventanal lateral del salón.
PLANOS_EXTERIORES_LOCAL: tuple[tuple[tuple[float, float, float], float], ...] = (
    ((0.0, 0.0, 1.0), 3.44),
    ((0.0, -1.0, 0.0), 6.34),
    ((-1.0, 0.0, 0.0), 2.54),
)


@dataclass(frozen=True)
class Conjunto:
    """Los materiales que comparten un par de texturas."""

    nombre: str
    lado: int
    densidad: float
    recetas: dict[str, "metal.Receta"]
    planos_ocultos: tuple[tuple[tuple[float, float, float], float], ...] = ()


def _srgb(lineal: float) -> float:
    return lineal * 12.92 if lineal <= 0.0031308 else 1.055 * lineal ** (1 / 2.4) - 0.055


def _receta(lineal, rugosidad, metal_, suelo, **resto) -> "metal.Receta":
    color = tuple(round(_srgb(c), 4) for c in lineal)
    return metal.Receta(color=color, rugosidad=rugosidad, metal=metal_, suelo=suelo, **resto)


#: El piso del local queda a esta altura en el modelo.
SUELO = 0.1

#: Dos combinaciones calibradas a escala real para comparar en el juego:
#: - `sutil`: grano satinado fino, huellas discretas y rayones moderados.
#: - `usado`: contraste franco de rugosidad en huellas, rayones y encuentros sobre reflejos limpios.
COMBINACIONES: dict[str, tuple[Conjunto, ...]] = {
    "sutil": (
        Conjunto(
            "acero_del_bano",
            1024,
            420.0,
            {
                "bano_acero": _receta(
                    (0.52, 0.57, 0.57), 0.28, 0.78, SUELO, semilla=3,
                    manchas=0.45, altura_agua=0.25, huellas=0.60, rayones=0.60,
                    mugre=0.20, variacion=0.10, satinado=0.95, escala_rugosidad=1.0,
                ),
                "bano_griferia": _receta(
                    (0.52, 0.57, 0.57), 0.16, 0.80, SUELO, semilla=5,
                    manchas=0.35, altura_agua=1.10, huellas=0.45, rayones=0.55,
                    mugre=0.22, variacion=0.10, satinado=0.70, escala_rugosidad=1.0,
                ),
                "bano_desague": _receta(
                    (0.52, 0.57, 0.57), 0.20, 0.78, SUELO, semilla=7,
                    manchas=0.45, altura_agua=0.45, huellas=0.0, rayones=0.60,
                    mugre=0.28, variacion=0.12, satinado=0.75, escala_rugosidad=1.0,
                ),
            },
        ),
        Conjunto(
            "cromo_de_las_mesas",
            512,
            450.0,
            {
                "MESA | Base cromada": _receta(
                    (0.75, 0.76, 0.78), 0.22, 0.90, SUELO, semilla=11,
                    manchas=0.0, huellas=0.55, rayones=0.65,
                    mugre=0.20, variacion=0.09, satinado=0.90, escala_rugosidad=1.0,
                ),
            },
        ),
        Conjunto(
            "acero_del_mostrador",
            1024,
            420.0,
            {
                # `importar_modelo.gd` multiplica `roughness` por 0,5 en el mostrador: 0,48 en el
                # ORM deja 0,24 efectivo en Godot, y `escala_rugosidad` compensa esa mitad.
                "MOSTRADOR | Acero satinado": _receta(
                    (0.37, 0.37, 0.37), 0.48, 0.85, SUELO, semilla=13,
                    manchas=0.0, huellas=0.55, rayones=0.62,
                    mugre=0.18, variacion=0.08, satinado=1.0, escala_rugosidad=1.60,
                ),
            },
        ),
        Conjunto(
            "aluminio_del_local",
            1024,
            320.0,
            {
                "local_aluminio": _receta(
                    (0.33, 0.36, 0.34), 0.30, 0.85, SUELO, semilla=17,
                    manchas=0.0, huellas=0.65, rayones=0.68,
                    mugre=0.50, variacion=0.10, satinado=0.95, escala_rugosidad=1.05,
                ),
            },
            planos_ocultos=PLANOS_EXTERIORES_LOCAL,
        ),
    ),
    "usado": (
        Conjunto(
            "acero_del_bano",
            1024,
            420.0,
            {
                "bano_acero": _receta(
                    (0.52, 0.57, 0.57), 0.26, 0.78, SUELO, semilla=3,
                    manchas=0.68, altura_agua=0.27, huellas=0.95, rayones=0.92,
                    mugre=0.22, variacion=0.12, satinado=1.15, escala_rugosidad=1.28,
                ),
                "bano_griferia": _receta(
                    (0.52, 0.57, 0.57), 0.15, 0.80, SUELO, semilla=5,
                    manchas=0.45, altura_agua=1.10, huellas=0.65, rayones=0.75,
                    mugre=0.24, variacion=0.12, satinado=0.85, escala_rugosidad=1.20,
                ),
                "bano_desague": _receta(
                    (0.52, 0.57, 0.57), 0.19, 0.78, SUELO, semilla=7,
                    manchas=0.55, altura_agua=0.45, huellas=0.0, rayones=0.75,
                    mugre=0.30, variacion=0.12, satinado=0.85, escala_rugosidad=1.20,
                ),
            },
        ),
        Conjunto(
            "cromo_de_las_mesas",
            512,
            450.0,
            {
                "MESA | Base cromada": _receta(
                    (0.75, 0.76, 0.78), 0.20, 0.90, SUELO, semilla=11,
                    manchas=0.0, huellas=0.85, rayones=0.95,
                    mugre=0.22, variacion=0.10, satinado=1.05, escala_rugosidad=1.28,
                ),
            },
        ),
        Conjunto(
            "acero_del_mostrador",
            1024,
            420.0,
            {
                "MOSTRADOR | Acero satinado": _receta(
                    (0.37, 0.37, 0.37), 0.45, 0.85, SUELO, semilla=13,
                    manchas=0.0, huellas=0.88, rayones=0.90,
                    mugre=0.20, variacion=0.10, satinado=1.15, escala_rugosidad=1.85,
                ),
            },
        ),
        Conjunto(
            "aluminio_del_local",
            1024,
            320.0,
            {
                "local_aluminio": _receta(
                    (0.33, 0.36, 0.34), 0.28, 0.85, SUELO, semilla=17,
                    manchas=0.0, huellas=0.95, rayones=0.95,
                    mugre=0.78, variacion=0.11, satinado=1.12, escala_rugosidad=1.30,
                ),
            },
            planos_ocultos=PLANOS_EXTERIORES_LOCAL,
        ),
    ),
}

COMBINACION_POR_DEFECTO = "usado"
CONJUNTOS = COMBINACIONES[COMBINACION_POR_DEFECTO]


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


def _objetos_por_malla(material: str) -> list[list]:
    por_malla: dict[str, list] = {}
    for objeto in sorted(bpy.data.objects, key=lambda o: o.name):
        if objeto.type == "MESH":
            por_malla.setdefault(objeto.data.name_full, []).append(objeto)
    salida = []
    for objetos in por_malla.values():
        if any(m is not None and m.name == material for m in objetos[0].data.materials):
            salida.append(objetos)
    return salida


def _registros(material: str) -> list[Registro]:
    registros = []
    for objetos in _objetos_por_malla(material):
        lisa = any(m.type == "BEVEL" for o in objetos for m in o.modifiers)
        registro = Registro(objetos[0], material)
        if not registro.poligonos:
            continue
        registro.lisa = lisa
        registros.append(registro)
    return registros


def _preparar(conjunto: Conjunto) -> tuple[list, list, dict]:
    """Los registros, todas las islas del conjunto y el índice de cada receta."""
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
            registro.islas, registro.sin_area = metal.armar_islas(
                registro.posiciones,
                poligonos,
                suelo_oculto=receta.suelo,
                planos_ocultos=conjunto.planos_ocultos,
            )
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
                capa.data[lazo].uv = metal.uv_de(
                    isla, posiciones[vertice], densidad, conjunto.lado
                )
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
    ruta_orm.write_bytes(metal.png_de(orm))
    for registro in registros:
        _escribir_uv(registro, conjunto, densidad, indices)
    for nombre in conjunto.recetas:
        _cablear(bpy.data.materials[nombre], ruta_color, ruta_orm)
    lisas = sum(1 for r in registros if r.lisa)
    for registro in sorted(registros, key=lambda r: -sum(i.area_real for i in r.islas))[:5]:
        area = sum(i.area_real for i in registro.islas)
        print(f"  {registro.objeto.name}: {len(registro.islas)} islas, {area:.2f} m2")
    return (
        f"{conjunto.nombre}: {len(registros)} mallas ({lisas} lisas), {len(islas)} islas, "
        f"{sum(i.area_real for i in islas):.1f} m2, {densidad:.0f} texeles/m, "
        f"+0 tris, color {ruta_color.stat().st_size:,} B, "
        f"orm {ruta_orm.stat().st_size:,} B"
    )


def main() -> None:
    argumentos = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    guardar = "--aplicar" in argumentos
    nombre_comb = COMBINACION_POR_DEFECTO
    if "--combinacion" in argumentos:
        nombre_comb = argumentos[argumentos.index("--combinacion") + 1]
    if nombre_comb not in COMBINACIONES:
        opciones = ", ".join(sorted(COMBINACIONES))
        raise SystemExit(f"combinación desconocida: {nombre_comb!r} (opciones: {opciones})")
    conjuntos = COMBINACIONES[nombre_comb]
    destino = CARPETA if guardar else Path(tempfile.mkdtemp(prefix=f"metal_{nombre_comb}_"))
    print(f"combinación: {nombre_comb}")
    for conjunto in conjuntos:
        print(aplicar(conjunto, destino))
    if guardar:
        bpy.ops.wm.save_mainfile()
        print(f"guardado: {FUENTE}")
    else:
        print(f"sin --aplicar: texturas en {destino}")


if __name__ == "__main__":
    main()
