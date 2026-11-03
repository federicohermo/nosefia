"""Aplica las recetas de `lib/superficies.py` a los materiales del modelo. Corre adentro de Blender.

    blender --background assets/models/SEPT_JUEGOS_PROTOTIPO.blend --python-exit-code 1 \
        --python .claude/scripts/blender/mejorar_superficies.py -- [--solo MATERIAL ...] [--sin-guardar]

Lo lanza `mejorar_superficies.py` de la raíz. **No se corre a mano.** Por cada receta escribe un
color nuevo y un mapa de rugosidad, apunta el material a los dos y guarda el `.blend`. Las
imágenes originales no se tocan.

## Cómo es la variación

Todo ruido sale de filtrar ruido blanco en el espacio de Fourier, así que **es periódico**: un
piso que se repite cada metro no deja una costura. La media de cada canal del color vuelve a
su valor original, para que la superficie no cambie de tono ni de brillo.

## Lo que muerde

- **Las texturas empaquetadas** (la chapa de la góndola) traen la ruta de otra máquina. Se leen
  de los píxeles, no del archivo, y el material apunta al archivo nuevo.
- **Hornear cambia la escena.** El motor, el mundo, las muestras y qué objetos se dibujan. Se
  guarda el estado antes y se devuelve antes de guardar el `.blend`.
"""

import sys
from pathlib import Path

import bpy  # type: ignore[import-not-found]  # sólo existe adentro de Blender
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from blender import hornear_biseles as bake  # noqa: E402
from lib import biseles, superficies  # noqa: E402
from lib.blender import achicada, LADO_MAXIMO, MUEBLES  # noqa: E402

LADO_DEL_COLOR = LADO_MAXIMO[MUEBLES]
NEGRO = 0.04


def _leer(imagen: "bpy.types.Image", ancho: int, alto: int) -> np.ndarray:
    """Los píxeles RGBA de una imagen, de arriba a abajo, llevada a `ancho x alto`."""
    copia = imagen.copy()
    try:
        if tuple(copia.size) != (ancho, alto):
            copia.scale(ancho, alto)
        datos = np.empty(ancho * alto * 4, dtype=np.float32)
        copia.pixels.foreach_get(datos)
        return np.ascontiguousarray(datos.reshape(alto, ancho, 4)[::-1])
    finally:
        bpy.data.images.remove(copia)


def _ruido(alto: int, ancho: int, periodos: float, semilla: int) -> np.ndarray:
    """Ruido periódico de desvío 1, con unos `periodos` ciclos a lo largo de la imagen."""
    azar = np.random.default_rng(semilla)
    blanco = azar.standard_normal((alto, ancho)).astype(np.float32)
    espectro = np.fft.rfft2(blanco)
    ky = np.fft.fftfreq(alto)[:, None] * alto
    kx = np.fft.rfftfreq(ancho)[None, :] * ancho
    filtro = np.exp(-((np.sqrt(kx**2 + ky**2) / periodos) ** 2))
    suave = np.fft.irfft2(espectro * filtro, s=(alto, ancho)).astype(np.float32)
    return suave / max(float(suave.std()), 1e-6)


def _luminancia(rgb: np.ndarray) -> np.ndarray:
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def _variar(rgb: np.ndarray, receta: superficies.Receta, semilla: int) -> np.ndarray:
    alto, ancho = rgb.shape[:2]
    luz = _luminancia(rgb)
    factor = (
        1.0
        + receta.mancha * _ruido(alto, ancho, receta.manchas_por_lado, semilla)
        + receta.grano * _ruido(alto, ancho, alto / 3.0, semilla + 1)
    )
    if receta.mugre > 0.0:
        oscuro = 1.0 - np.clip((luz - 0.08) / 0.4, 0.0, 1.0)
        mancha = 0.5 + 0.5 * np.tanh(_ruido(alto, ancho, receta.manchas_por_lado * 2, semilla + 2))
        factor = factor * (1.0 - receta.mugre * oscuro * (0.4 + 0.6 * mancha))
    salida = rgb * factor[..., None]
    return np.clip(salida, 0.0, 1.0)


def _devolver_la_media(nuevo: np.ndarray, original: np.ndarray) -> np.ndarray:
    """Lleva la media de cada canal, sobre lo que no es negro, a la que tenía el original."""
    mascara = _luminancia(original) > NEGRO
    if not mascara.any():
        return nuevo
    antes = original[mascara].mean(axis=0)
    despues = np.maximum(nuevo[mascara].mean(axis=0), 1e-6)
    return np.clip(np.where(mascara[..., None], nuevo * (antes / despues), nuevo), 0.0, 1.0)


def _aire(color: np.ndarray, receta: superficies.Receta, material) -> np.ndarray:
    """Suma la oclusión, el bisel y el polvo de la malla del mueble que usa el material."""
    elegido = None
    for objeto in sorted(bpy.data.objects, key=lambda o: o.name):
        if objeto.type != "MESH":
            continue
        usadas = {c.material_index for c in objeto.data.polygons}
        for indice, ranura in enumerate(objeto.material_slots):
            if ranura.material == material and indice in usadas:
                elegido = (objeto, indice)
                break
        if elegido:
            break
    if elegido is None:
        raise SystemExit(f"ningún objeto usa el material {receta.material}")
    alto, ancho = color.shape[:2]
    copia = bake.copiar(elegido[0])
    capa = bake.capa_de(copia, elegido[1], ancho, alto)
    luz, brillo = capa[..., 0:1], capa[..., 1:2]
    salida = color.copy()
    salida[..., :3] = biseles.componer(color[..., :3], luz, brillo)
    if receta.polvo > 0.0:
        arriba = bake.hornear(copia, elegido[1], ancho, alto, "EMIT", _normal_hacia_arriba)
        mascara = np.clip((arriba - 0.85) / 0.15, 0.0, 1.0)[..., None]
        gris = np.array([0.62, 0.60, 0.56], dtype=np.float32)
        salida[..., :3] += receta.polvo * mascara * (gris - salida[..., :3])
    malla = copia.data
    bpy.data.objects.remove(copia)
    bpy.data.meshes.remove(malla)
    return np.clip(salida, 0.0, 1.0)


def _normal_hacia_arriba(nodos, emision) -> None:
    plana = nodos.nodes.new("ShaderNodeNewGeometry")
    separar = nodos.nodes.new("ShaderNodeSeparateXYZ")
    nodos.links.new(plana.outputs["True Normal"], separar.inputs[0])
    nodos.links.new(separar.outputs["Z"], emision.inputs["Color"])


def _rugosidad(color: np.ndarray, receta: superficies.Receta, semilla: int) -> np.ndarray:
    claro, oscuro, variacion = receta.rugosidad
    alto, ancho = color.shape[:2]
    paso = max(1, min(alto, ancho) // superficies.LADO_DE_LA_RUGOSIDAD)
    chico = color[: alto - alto % paso : paso, : ancho - ancho % paso : paso, :3]
    luz = _luminancia(chico)
    oscuridad = 1.0 - np.clip((luz - 0.08) / 0.5, 0.0, 1.0)
    mancha = _ruido(chico.shape[0], chico.shape[1], receta.manchas_por_lado * 2, semilla + 3)
    valores = claro + (oscuro - claro) * oscuridad + variacion * 0.5 * mancha
    return np.clip(valores, 0.04, 1.0).astype(np.float32)


def _escribir(pixeles: np.ndarray, destino: Path, espacio: str) -> None:
    """Escribe el PNG con `Image.save`, que no aplica la transformación de vista de la escena."""
    alto, ancho = pixeles.shape[:2]
    con_alfa = pixeles.ndim == 3 and pixeles.shape[2] == 4 and bool(pixeles[..., 3].min() < 0.999)
    imagen = bpy.data.images.new(destino.stem, ancho, alto, alpha=con_alfa)
    try:
        imagen.colorspace_settings.name = espacio
        imagen.alpha_mode = "STRAIGHT"
        rgba = np.ones((alto, ancho, 4), dtype=np.float32)
        if pixeles.ndim == 2:
            rgba[..., :3] = pixeles[..., None]
        else:
            rgba[..., : pixeles.shape[2]] = pixeles
        imagen.pixels.foreach_set(np.ascontiguousarray(rgba[::-1]).reshape(-1))
        imagen.file_format = "PNG"
        imagen.filepath_raw = str(destino)
        destino.parent.mkdir(parents=True, exist_ok=True)
        imagen.save()
    finally:
        bpy.data.images.remove(imagen)


def _principal(material) -> "bpy.types.ShaderNodeBsdfPrincipled":
    return next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def _nodo_de_color(material) -> "bpy.types.ShaderNodeTexImage | None":
    """La textura que alimenta el color base, o `None` si el color es liso."""
    for nodo in material.node_tree.nodes:
        if nodo.type == "TEX_IMAGE" and nodo.image and any(
            enlace.to_node.type == "BSDF_PRINCIPLED" and enlace.to_socket.name == "Base Color"
            for enlace in nodo.outputs["Color"].links
        ):
            return nodo
    return None


def _color_liso(material) -> np.ndarray:
    """Un cuadrado de `LADO_DEL_COLOR` con el color base del material.

    El color base de Blender es lineal y la imagen se guarda en sRGB: sin la conversión, la
    superficie sale más oscura que antes.
    """
    base = np.array(_principal(material).inputs["Base Color"].default_value, dtype=np.float32)
    lineal = np.clip(base[:3], 0.0, 1.0)
    base[:3] = np.where(
        lineal <= 0.0031308, 12.92 * lineal, 1.055 * np.power(lineal, 1 / 2.4) - 0.055
    )
    return np.broadcast_to(base, (LADO_DEL_COLOR, LADO_DEL_COLOR, 4)).copy()


def _apuntar(material, nodo, receta: superficies.Receta) -> None:
    arbol = material.node_tree
    principal = _principal(material)
    color = bpy.data.images.load(str(superficies.ruta_del_color(receta)), check_existing=False)
    color.colorspace_settings.name = "sRGB"
    if nodo is None:
        nodo = arbol.nodes.new("ShaderNodeTexImage")
        nodo.location = (principal.location.x - 400, principal.location.y)
        arbol.links.new(nodo.outputs["Color"], principal.inputs["Base Color"])
        principal.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
    nodo.image = color
    if receta.suavizar:
        nodo.interpolation = "Linear"
    rugosidad = bpy.data.images.load(
        str(superficies.ruta_de_la_rugosidad(receta)), check_existing=False
    )
    rugosidad.colorspace_settings.name = "Non-Color"
    for viejo in [n for n in arbol.nodes if n.name == "Rugosidad"]:
        arbol.nodes.remove(viejo)
    mapa = arbol.nodes.new("ShaderNodeTexImage")
    mapa.name = mapa.label = "Rugosidad"
    mapa.image = rugosidad
    mapa.interpolation = "Linear"
    mapa.location = (nodo.location.x, nodo.location.y - 300)
    origen = nodo.inputs["Vector"].links[0].from_socket if nodo.inputs["Vector"].links else None
    if origen is not None:
        arbol.links.new(origen, mapa.inputs["Vector"])
    arbol.links.new(mapa.outputs["Color"], principal.inputs["Roughness"])


def aplicar(receta: superficies.Receta, semilla: int) -> str:
    material = bpy.data.materials.get(receta.material)
    if material is None or not material.use_nodes:
        raise SystemExit(f"el modelo no tiene el material {receta.material}")
    if "Rugosidad" in material.node_tree.nodes:
        raise SystemExit(
            f"{receta.material} ya tiene la receta aplicada. La textura original se perdió del "
            "material: restaurá el .blend con git y repetí."
        )
    nodo = _nodo_de_color(material)
    if nodo is None:
        original = _color_liso(material)
    else:
        original = _leer(nodo.image, *achicada(*nodo.image.size, LADO_DEL_COLOR))
    alto, ancho = original.shape[:2]
    color = original.copy()
    color[..., :3] = _variar(original[..., :3], receta, semilla)
    color[..., :3] = _devolver_la_media(color[..., :3], original[..., :3])
    if receta.aire:
        color = _aire(color, receta, material)
    rugosidad = _rugosidad(color, receta, semilla)
    _escribir(color, superficies.ruta_del_color(receta), "sRGB")
    _escribir(rugosidad, superficies.ruta_de_la_rugosidad(receta), "Non-Color")
    _apuntar(material, nodo, receta)
    return f"superficie: {receta.material} color {ancho}x{alto} rugosidad {rugosidad.shape[1]}x{rugosidad.shape[0]}"


def _estado_de_la_escena() -> dict:
    """Lo que el horneado cambia de la escena y que el `.blend` no puede guardar cambiado."""
    escena = bpy.context.scene
    return {
        "motor": escena.render.engine,
        "mundo": escena.world,
        "muestras": escena.cycles.samples,
        "dispositivo": escena.cycles.device,
        "ruido": escena.cycles.use_denoising,
        "seleccion": escena.render.bake.use_selected_to_active,
        "ocultos": {o.name: o.hide_render for o in bpy.data.objects},
    }


def _restaurar(estado: dict) -> None:
    escena = bpy.context.scene
    horneado = escena.world
    escena.render.engine = estado["motor"]
    escena.world = estado["mundo"]
    if horneado is not None and horneado is not estado["mundo"]:
        bpy.data.worlds.remove(horneado)
    escena.cycles.samples = estado["muestras"]
    escena.cycles.device = estado["dispositivo"]
    escena.cycles.use_denoising = estado["ruido"]
    escena.render.bake.use_selected_to_active = estado["seleccion"]
    for objeto in bpy.data.objects:
        objeto.hide_render = estado["ocultos"].get(objeto.name, False)


def _argumentos() -> tuple[set[str], bool]:
    entrada = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    solo: set[str] = set()
    while "--solo" in entrada:
        i = entrada.index("--solo")
        solo.add(entrada[i + 1])
        del entrada[i : i + 2]
    return solo, "--sin-guardar" in entrada


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    solo, sin_guardar = _argumentos()
    estado = _estado_de_la_escena()
    bake.preparar_la_escena()
    for numero, receta in enumerate(superficies.RECETAS):
        if solo and receta.material not in solo:
            continue
        print(aplicar(receta, 1000 + numero))
    _restaurar(estado)
    if not sin_guardar:
        bpy.ops.file.make_paths_relative()
        bpy.ops.wm.save_mainfile()
        print("guardado:", bpy.data.filepath)


if __name__ == "__main__":
    main()
