"""Lleva el cuerpo de la góndola al tono de `lib/gondolas.py`. Corre en Blender.

    blender --background assets/models/SEPT_JUEGOS_PROTOTIPO.blend --python-exit-code 1 \
        --python .claude/scripts/blender/aclarar_gondolas.py -- [--sin-guardar]

Lo lanza `aclarar_gondolas.py` de la raíz. **No se corre a mano.**

## Lo que muerde

- **Son imágenes empaquetadas** con la ruta de otra máquina. Se leen de los píxeles, y el material
  apunta al PNG nuevo. La original queda sin usuarios y se pierde al guardar: para repetir hay
  que restaurar el `.blend` con git. La herramienta se niega a aplicarse dos veces.
- **El color base de Blender es lineal y la imagen no.** Aquí todo se hace sobre valores de imagen.
- **`Image.pixels` va de abajo hacia arriba**, igual que lo que lee `_pixeles`: se escribe en el
  mismo orden. Invertir las filas al escribir da vuelta la textura.
"""

import sys
from pathlib import Path

import bmesh  # type: ignore[import-not-found]
import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import mathutils  # type: ignore[import-not-found]
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from lib import gondolas  # noqa: E402


def _pixeles(imagen: "bpy.types.Image") -> np.ndarray:
    ancho, alto = imagen.size
    datos = np.empty(ancho * alto * 4, dtype=np.float32)
    imagen.pixels.foreach_get(datos)
    return datos.reshape(alto, ancho, 4)


def agujeros(rgba: np.ndarray, tipo: str) -> np.ndarray:
    """Los píxeles que son agujero: `oscuros` bajo el umbral, `claros` sobre el nivel del metal."""
    luz = rgba[..., :3].mean(axis=-1)
    if tipo == "oscuros":
        return luz < gondolas.UMBRAL_OSCURO
    return luz > float(np.median(luz)) + gondolas.SALTO_DE_RANURA


def aclarar(
    rgba: np.ndarray,
    tono: tuple[float, float, float] = gondolas.TONO,
    quietos: np.ndarray | None = None,
) -> np.ndarray:
    """La imagen con cada canal multiplicado para llegar al tono, sin pasar de 1.

    Los píxeles de `quietos` no cuentan para la media ni cambian.
    """
    if quietos is None:
        quietos = np.zeros(rgba.shape[:2], dtype=bool)
    metal = ~quietos
    medias = tuple(float(rgba[..., c][metal].mean()) for c in range(3))
    nuevo = rgba.copy()
    for canal, factor in enumerate(gondolas.factores(medias, tono)):
        nuevo[..., canal][metal] = np.clip(rgba[..., canal][metal] * factor, 0.0, 1.0)
    return nuevo


def elevar(rgba: np.ndarray, piso: tuple[float, float, float]) -> np.ndarray:
    """La imagen con su negro subido hasta el piso. El blanco queda en 1."""
    nuevo = rgba.copy()
    for canal, nivel in enumerate(piso):
        nuevo[..., canal] = nivel + rgba[..., canal] * (1.0 - nivel)
    return nuevo


def _escribir(rgba: np.ndarray, destino: Path) -> None:
    """Escribe el PNG con `Image.save`, que no aplica la transformación de vista de la escena."""
    alto, ancho = rgba.shape[:2]
    imagen = bpy.data.images.new(destino.stem, ancho, alto, alpha=False)
    try:
        imagen.colorspace_settings.name = "sRGB"
        imagen.pixels.foreach_set(np.ascontiguousarray(rgba).reshape(-1))
        imagen.file_format = "PNG"
        imagen.filepath_raw = str(destino)
        destino.parent.mkdir(parents=True, exist_ok=True)
        imagen.save()
    finally:
        bpy.data.images.remove(imagen)


def aplicar(
    nombre: str, nivel: tuple[float, float, float], transformar=aclarar
) -> str:
    original = bpy.data.images.get(nombre)
    if original is None:
        raise SystemExit(f"el modelo no tiene la imagen {nombre}")
    nodos = [
        (m, n) for m in bpy.data.materials if m.use_nodes for n in m.node_tree.nodes
        if n.type == "TEX_IMAGE" and n.image == original
    ]
    if not nodos:
        raise SystemExit(f"{nombre} ya no la usa ningún material: ¿ya está aplicada? Restaurá el .blend")
    rgba = _pixeles(original)
    antes = [round(float(rgba[..., c].mean()), 3) for c in range(3)]
    if nombre in gondolas.AGUJEROS:
        nuevo = transformar(rgba, nivel, agujeros(rgba, gondolas.AGUJEROS[nombre]))
    else:
        nuevo = transformar(rgba, nivel)
    destino = gondolas.ruta_de_la_textura(nombre)
    _escribir(nuevo, destino)
    imagen = bpy.data.images.load(str(destino), check_existing=False)
    imagen.colorspace_settings.name = "sRGB"
    for _, nodo in nodos:
        nodo.image = imagen
    despues = [round(float(nuevo[..., c].mean()), 3) for c in range(3)]
    return f"gondola: {nombre} {antes} -> {despues} en {len(nodos)} nodos"


def paleta() -> str:
    """Los píxeles grises de la paleta pasan a su tono, y la imagen se guarda como PNG.

    El rojo también emite: una segunda imagen, con sólo el rojo, alimenta la emisión.
    """
    original = bpy.data.images.get(gondolas.PALETA)
    if original is None:
        raise SystemExit(f"el modelo no tiene la imagen {gondolas.PALETA}")
    nodos = [
        (m, n) for m in bpy.data.materials if m.use_nodes for n in m.node_tree.nodes
        if n.type == "TEX_IMAGE" and n.image == original
    ]
    if not nodos:
        raise SystemExit(f"{gondolas.PALETA} ya no la usa ningún material: ¿ya está aplicada?")
    rgba = _pixeles(original).copy()
    for columna in gondolas.PIXELES_GRISES:
        rgba[0, columna, :3] = gondolas.TONO_DE_LA_PALETA
    rgba[0, gondolas.PIXEL_DEL_EXHIBIDOR, :3] = gondolas.TONO_APARTE
    rgba[0, gondolas.PIXEL_DE_LAS_JUNTAS, :3] = gondolas.TONO_DE_LAS_JUNTAS
    rgba[0, gondolas.PIXEL_ROJO, :3] = gondolas.ROJO
    emision = np.zeros_like(rgba)
    emision[..., 3] = 1.0
    emision[0, gondolas.PIXEL_ROJO, :3] = np.array(gondolas.ROJO) * gondolas.EMISION_ROJO
    for imagen_nueva, nombre in ((rgba, gondolas.PALETA), (emision, gondolas.EMISION)):
        _escribir(imagen_nueva, gondolas.ruta_de_la_textura(nombre))
    imagen = bpy.data.images.load(str(gondolas.ruta_de_la_textura(gondolas.PALETA)), check_existing=False)
    imagen.colorspace_settings.name = "sRGB"
    luz = bpy.data.images.load(str(gondolas.ruta_de_la_textura(gondolas.EMISION)), check_existing=False)
    luz.colorspace_settings.name = "sRGB"
    for material, nodo in nodos:
        nodo.image = imagen
        nodo.interpolation = "Closest"
        if any(e.to_socket.name == "Base Color" for e in nodo.outputs["Color"].links):
            next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs[
                "Roughness"
            ].default_value = gondolas.RUGOSIDAD_DE_LA_PALETA
            _emitir(material, nodo, luz)
    return (
        f"gondola: paleta, grises {gondolas.PIXELES_GRISES}, rojo {gondolas.PIXEL_ROJO} que emite "
        f"y exhibidor {gondolas.PIXEL_DEL_EXHIBIDOR} en {len(nodos)} nodos"
    )


def _emitir(material: "bpy.types.Material", paleta_: "bpy.types.Node", luz: "bpy.types.Image") -> None:
    """Conecta la imagen de emisión al material, con las mismas coordenadas que la paleta."""
    arbol = material.node_tree
    principal = next(n for n in arbol.nodes if n.type == "BSDF_PRINCIPLED")
    nodo = arbol.nodes.new("ShaderNodeTexImage")
    nodo.image = luz
    nodo.interpolation = "Closest"
    nodo.location = (paleta_.location.x, paleta_.location.y - 300)
    for enlace in paleta_.inputs["Vector"].links:
        arbol.links.new(enlace.from_socket, nodo.inputs["Vector"])
    arbol.links.new(nodo.outputs["Color"], principal.inputs["Emission Color"])
    principal.inputs["Emission Strength"].default_value = 1.0


def dielectricos() -> list[str]:
    informe = []
    for nombre, rugosidad in gondolas.DIELECTRICOS.items():
        material = bpy.data.materials.get(nombre)
        if material is None:
            raise SystemExit(f"el modelo no tiene el material {nombre}")
        principal = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        principal.inputs["Metallic"].default_value = 0.0
        principal.inputs["Roughness"].default_value = rugosidad
        informe.append(f"gondola: {nombre} dieléctrico, rugosidad {rugosidad}")
    return informe


def asperos() -> list[str]:
    informe = []
    for nombre, rugosidad in gondolas.ASPEROS.items():
        material = bpy.data.materials.get(nombre)
        if material is None:
            raise SystemExit(f"el modelo no tiene el material {nombre}")
        next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs[
            "Roughness"
        ].default_value = rugosidad
        informe.append(f"gondola: {nombre} rugosidad {rugosidad}")
    return informe


def _pixel_de_la_paleta(cara, uv) -> int:
    return int(sum(uv.data[i].uv[0] for i in cara.loop_indices) / len(cara.loop_indices) * 5)


def _caras_con_pixel(objeto, pixel: int) -> list:
    malla = objeto.data
    uv = malla.uv_layers.active
    paleta_ = [
        i for i, m in enumerate(objeto.material_slots) if m.material and m.material.name == "GONDOLA | Paleta"
    ]
    return [
        c for c in malla.polygons
        if c.material_index in paleta_ and _pixel_de_la_paleta(c, uv) == pixel
    ]


def juntas() -> list[str]:
    """Las tiras del fondo del exhibidor van a medio camino entre un estante y el siguiente.

    Son seis a 25 cm una de otra y los estantes están a 40: no pueden ir todas en medio. Quedan las
    de cada hueco, y la de arriba va a medio camino entre el último estante y el tope.
    """
    objetos = [bpy.data.objects[n] for n in gondolas.CARAS_DEL_EXHIBIDOR]
    alturas = sorted(
        round(max((o.matrix_world @ o.data.vertices[v].co).z for v in c.vertices), 3)
        for o in objetos
        for c in _caras_con_pixel(o, gondolas.PIXEL_DEL_EXHIBIDOR)
        if (o.matrix_world.to_3x3() @ c.normal).z > 0.9
    )
    estantes: list[float] = []
    for altura in alturas:
        if estantes and altura - estantes[-1] < 0.1:
            estantes[-1] = altura
        else:
            estantes.append(altura)
    techo = max((o.matrix_world @ v.co).z for o in objetos for v in o.data.vertices)
    if len(estantes) != 4:
        raise SystemExit(f"el exhibidor ya no es el de siempre: {len(estantes)} estantes")
    huecos = [(a + b) / 2 for a, b in zip(estantes, estantes[1:])] + [(estantes[-1] + techo) / 2]
    niveles_que_quedan = {0: 0, 2: 1, 4: 2, 5: 3}
    informe = []
    for objeto in objetos:
        malla = objeto.data
        mundo = objeto.matrix_world
        de_las_juntas = _caras_con_pixel(objeto, gondolas.PIXEL_DE_LAS_JUNTAS)
        if not de_las_juntas:
            continue
        propias = {c.index for c in de_las_juntas}
        usadas = {v for c in malla.polygons if c.index not in propias for v in c.vertices}
        if any(v in usadas for c in de_las_juntas for v in c.vertices):
            raise SystemExit(f"{objeto.name}: una tira comparte vértices con otra cara")
        niveles: dict[int, list] = {}
        for cara in de_las_juntas:
            z = min((mundo @ malla.vertices[v].co).z for v in cara.vertices)
            niveles.setdefault(round((z - 0.35) / 0.25), []).append(cara)
        quitar = []
        for nivel, de_este_nivel in sorted(niveles.items()):
            if nivel not in niveles_que_quedan:
                quitar += de_este_nivel
                continue
            z = min((mundo @ malla.vertices[v].co).z for c in de_este_nivel for v in c.vertices)
            destino = huecos[niveles_que_quedan[nivel]]
            local = mundo.to_3x3().inverted() @ mathutils.Vector((0.0, 0.0, destino - (z + 0.005)))
            for v in {v for c in de_este_nivel for v in c.vertices}:
                malla.vertices[v].co += local
            informe.append(f"gondola: {objeto.name} junta de {z:.2f} a {destino:.2f}")
        barra = bmesh.new()
        barra.from_mesh(malla)
        barra.faces.ensure_lookup_table()
        bmesh.ops.delete(barra, geom=[barra.faces[c.index] for c in quitar], context="FACES")
        barra.to_mesh(malla)
        barra.free()
        informe.append(f"gondola: {objeto.name}, {len(quitar)} caras de juntas de más quitadas")
    return informe


def traseras() -> list[str]:
    """El lado de adentro de los laterales del exhibidor, de un azul liso."""
    liso = bpy.data.materials.new(gondolas.AZUL_LISO)
    liso.use_nodes = True
    principal = next(n for n in liso.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    principal.inputs["Base Color"].default_value = tuple(
        gondolas.a_lineal(c) for c in gondolas.COLOR_DEL_AZUL_LISO
    ) + (1.0,)
    principal.inputs["Roughness"].default_value = 0.7
    liso.use_backface_culling = True
    for nombre in gondolas.LATERALES:
        bpy.data.materials[nombre].use_backface_culling = True
    informe = []
    for objeto in (bpy.data.objects[n] for n in gondolas.CARAS_DEL_EXHIBIDOR):
        malla = objeto.data
        barra = bmesh.new()
        barra.from_mesh(malla)
        barra.faces.ensure_lookup_table()
        laterales = [
            f for f in barra.faces
            if malla.materials[f.material_index] and malla.materials[f.material_index].name in gondolas.LATERALES
        ]
        if not laterales:
            barra.free()
            continue
        malla.materials.append(liso)
        copia = bmesh.ops.duplicate(barra, geom=laterales)["geom"]
        nuevas = [e for e in copia if isinstance(e, bmesh.types.BMFace)]
        bmesh.ops.reverse_faces(barra, faces=nuevas)
        for cara in nuevas:
            cara.material_index = len(malla.materials) - 1
            for vertice in cara.verts:
                vertice.co += cara.normal * 0.002
        barra.to_mesh(malla)
        barra.free()
        informe.append(f"gondola: {objeto.name}, {len(nuevas)} laterales con respaldo liso")
    if not informe:
        raise SystemExit("no se encontró ningún lateral de exhibidor")
    return informe


def salon() -> list[str]:
    """La base de las mesas toma el cromo, y las patas de las sillas toman madera."""
    acero = bpy.data.materials.get(gondolas.ACERO)
    cromo = bpy.data.materials.get(gondolas.CROMO)
    if acero is None or cromo is None:
        raise SystemExit(f"el modelo no tiene {gondolas.ACERO} o {gondolas.CROMO}")
    base = cromo.copy()
    base.name = gondolas.BASE_DE_MESA
    principal_base = next(n for n in base.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    principal_base.inputs["Roughness"].default_value = gondolas.RUGOSIDAD_DEL_CROMO
    principal_base.inputs["Metallic"].default_value = gondolas.METAL_DE_MESA
    patas = bpy.data.materials.new(gondolas.PATAS_DE_SILLA)
    patas.use_nodes = True
    principal = next(n for n in patas.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    principal.inputs["Base Color"].default_value = tuple(gondolas.a_lineal(c) for c in gondolas.MADERA) + (1.0,)
    principal.inputs["Roughness"].default_value = 0.6
    principal.inputs["Metallic"].default_value = 0.0
    informe = []
    for malla, nuevo in ((gondolas.MALLA_DE_MESA, base), (gondolas.MALLA_DE_SILLA, patas)):
        datos = bpy.data.meshes.get(malla)
        if datos is None:
            raise SystemExit(f"el modelo no tiene la malla {malla}")
        cambiadas = 0
        for i, material in enumerate(datos.materials):
            if material is acero:
                datos.materials[i] = nuevo
                cambiadas += 1
        if cambiadas != 1:
            raise SystemExit(f"{malla}: se esperaba un solo {gondolas.ACERO}, hay {cambiadas}")
        informe.append(f"gondola: {malla} {gondolas.ACERO} -> {nuevo.name}")
    return informe


def colores_lisos() -> list[str]:
    informe = []
    for nombre, tono in gondolas.COLORES_LISOS.items():
        lineal = tuple(gondolas.a_lineal(c) for c in tono) + (1.0,)
        material = bpy.data.materials.get(nombre)
        if material is None:
            raise SystemExit(f"el modelo no tiene el material {nombre}")
        principal = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        antes = tuple(round(x, 3) for x in principal.inputs["Base Color"].default_value[:3])
        principal.inputs["Base Color"].default_value = lineal
        informe.append(f"gondola: {nombre} {antes} -> {tuple(round(x, 3) for x in lineal[:3])}")
    return informe


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    for nombre, tono in gondolas.TEXTURAS.items():
        print(aplicar(nombre, tono))
    for nombre, piso in gondolas.PISOS.items():
        print(aplicar(nombre, piso, elevar))
    for nombre in gondolas.SIN_TINTE:
        material = bpy.data.materials.get(nombre)
        if material is None:
            raise SystemExit(f"el modelo no tiene el material {nombre}")
        next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs[
            "Base Color"
        ].default_value = (1.0, 1.0, 1.0, 1.0)
        print(f"gondola: {nombre} sin tinte")
    print(paleta())
    for linea in colores_lisos() + dielectricos() + asperos() + salon() + juntas() + traseras():
        print(linea)
    if "--sin-guardar" not in sys.argv:
        bpy.ops.file.make_paths_relative()
        bpy.ops.wm.save_mainfile()
        print("guardado:", bpy.data.filepath)


if __name__ == "__main__":
    main()
