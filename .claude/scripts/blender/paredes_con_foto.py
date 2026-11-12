"""Las paredes pintadas del salón y del baño llevan la foto de una pared real, repetida a escala.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/paredes_con_foto.py -- [--aplicar]

Sin `--aplicar` escribe las texturas en una carpeta temporal y no guarda nada. Con `--aplicar`
escribe en `assets/source/textures/store/` y guarda la fuente canónica. Después van
`armar_atlas.py`, `exportar_modelo.py`, `hornear.py` y `hornear.py --sin-luz`: cambia la UV.

## Por qué

`paredes_pintadas.py`, que reemplaza, metía todas las paredes de un recinto en una sola textura
de 1024: 69 texeles por metro en el salón. La foto de la pared, de más de 1.000 por metro,
quedaba reducida quince veces, y la pared se leía como una mancha borrosa.

## Qué cambia

- **La textura es el grano fino de la foto**: `painted_plaster_wall` de Poly Haven, CC0, en
  `assets/source/textures/third-party/painted_plaster_wall/`. Cubre `METROS` por lado y es
  continua en los bordes, así que se repite sin costura. Se reduce a `LADO`, se queda sólo con
  los rasgos de menos de `MANCHA` texeles y se tiñe al tono de cada pared. El grano no delata la
  repetición; los retoques y manchas sí, y por eso los pone aparte `hornear_paredes.py`, sin
  repetirse, como textura de detalle que el juego multiplica encima (`importar_modelo.gd`).
- **La UV es una proyección en metros** según hacia dónde mira cada cara: la foto mide lo mismo
  en todas las paredes, en las jambas y en los cantos del material. Cada pared la toma con un
  corrimiento propio.

## Lo que cuesta

Una textura de `LADO` por material, la misma cantidad que antes. Ningún triángulo ni dibujo
más.

Es idempotente.
"""

import sys
import tempfile
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import hornear_paredes as variacion  # noqa: E402
import metal_detalle as metal  # noqa: E402
from lib.consola import configurar  # noqa: E402

FUENTE = RAIZ / "assets/models/SEPT_JUEGOS_PROTOTIPO.blend"
CARPETA = RAIZ / "assets/source/textures/store"
FOTO = RAIZ / "assets/source/textures/third-party/painted_plaster_wall/painted_plaster_wall_diff_2k.jpg"
#: El lado de la pared que cubre la foto, según su página.
METROS = 2.5
#: El tamaño, en texeles, desde el que un rasgo de la foto es variación grande y no grano: unos
#: 2 cm. Lo de más no va acá, porque se repetiría: lo pone sin repetirse `hornear_paredes.py`.
MANCHA = 8.0
LADO = 1024
EDIFICIO = "almacen-col"
#: Material, archivo y tono medio de cada pared, en valores de imagen.
#: Y cuánto del grano de la foto conserva, y si lleva la variación grande de `hornear_paredes.py`.
#: El usuario pidió el baño más liso que el salón: poco grano y sin variación.
PAREDES = (
    ("local_pared_pintada", "pared_del_salon_color.png", (206, 209, 203), 0.7, True),
    ("bano_pared_clara", "pared_del_bano_color.png", (229, 232, 230), 0.3, False),
)


def _lineal(srgb: np.ndarray) -> np.ndarray:
    return np.where(srgb <= 0.04045, srgb / 12.92, ((srgb + 0.055) / 1.055) ** 2.4)


def _srgb(lineal: np.ndarray) -> np.ndarray:
    return np.where(lineal <= 0.0031308, lineal * 12.92, 1.055 * np.power(lineal, 1 / 2.4) - 0.055)


def foto_teñida(tono: tuple[int, int, int], grano: float, con_variacion: bool) -> np.ndarray:
    """La foto reducida a `LADO`, en valores de imagen de 0 a 1, con su media llevada a `tono`."""
    imagen = bpy.data.images.load(str(FOTO), check_existing=False)
    imagen.scale(LADO, LADO)
    pixeles = np.empty(LADO * LADO * 4, dtype=np.float32)
    imagen.pixels.foreach_get(pixeles)
    bpy.data.images.remove(imagen)
    rgb = pixeles.reshape(LADO, LADO, 4)[..., :3].astype(np.float64)
    media = rgb.mean(axis=(0, 1))
    # Separa la mancha grande del detalle fino con un desenfoque gaussiano periódico: la foto es
    # continua en los bordes, así que la FFT no deja costuras.
    f = np.fft.fftfreq(LADO)
    filtro = np.exp(-2 * (np.pi * MANCHA) ** 2 * (f[:, None] ** 2 + f[None, :] ** 2))
    grande = np.stack(
        [np.real(np.fft.ifft2(np.fft.fft2(rgb[..., c]) * filtro)) for c in range(3)], axis=-1
    )
    rgb = media + (rgb - grande) * grano
    # El juego multiplica la variación grande, de media `variacion.MEDIA`, sobre este color: el
    # tono se aclara en la misma proporción para que la pared conserve su brillo.
    objetivo = _lineal(np.array(tono, dtype=np.float64) / 255.0)
    if con_variacion:
        objetivo /= variacion.MEDIA
    rgb *= _srgb(np.clip(objetivo, 0.0, 1.0)) / rgb.mean(axis=(0, 1))
    return np.clip(rgb, 0.0, 1.0)


def proyectar(objeto, material: str) -> int:
    """La UV de cada cara del material, en metros sobre el plano al que más se parece."""
    malla = objeto.data
    mundo = objeto.matrix_world
    giro = mundo.to_3x3()
    nombres = [m.name if m else "" for m in malla.materials]
    capa = malla.uv_layers[0].data
    caras = 0
    for cara in malla.polygons:
        if nombres[cara.material_index] != material:
            continue
        caras += 1
        normal = (giro @ cara.normal).normalized()
        eje = max(range(3), key=lambda i: abs(normal[i]))
        for lazo in cara.loop_indices:
            p = mundo @ malla.vertices[malla.loops[lazo].vertex_index].co
            if eje == 0:
                u, v = p.y * (1 if normal.x < 0 else -1), p.z
            elif eje == 1:
                u, v = p.x * (1 if normal.y > 0 else -1), p.z
            else:
                u, v = p.x, p.y
            # Cada pared toma la foto desde otro punto: la repetición no cae igual en todas.
            plano = round(p[eje] * 4) / 4
            corrimiento = (np.sin(plano * 12.9898 + eje * 78.233) * 43758.5453) % 1.0
            capa[lazo].uv = (u / METROS + corrimiento, v / METROS + corrimiento * 0.37)
    malla.update()
    return caras


def cablear(material: str, ruta: Path, relativa: bool) -> None:
    arbol = bpy.data.materials[material].node_tree
    principal = arbol.nodes["Principled BSDF"]
    nodo = arbol.nodes.get("Pared pintada") or arbol.nodes.new("ShaderNodeTexImage")
    nodo.name = nodo.label = "Pared pintada"
    imagen = bpy.data.images.load(str(ruta), check_existing=True)
    imagen.reload()
    if relativa:
        imagen.filepath = bpy.path.relpath(str(ruta))
    imagen.colorspace_settings.name = "sRGB"
    nodo.image = imagen
    nodo.interpolation = "Linear"
    nodo.extension = "REPEAT"
    arbol.links.new(nodo.outputs["Color"], principal.inputs["Base Color"])


def main() -> None:
    configurar()
    aplicar = "--aplicar" in sys.argv
    destino = CARPETA if aplicar else Path(tempfile.mkdtemp(prefix="paredes_con_foto_"))
    objeto = bpy.data.objects[EDIFICIO]
    for material, archivo, tono, grano, con_variacion in PAREDES:
        ruta = destino / archivo
        ruta.write_bytes(metal.png_de(foto_teñida(tono, grano, con_variacion)))
        caras = proyectar(objeto, material)
        cablear(material, ruta, aplicar)
        print(f"{material}: {caras} caras, {ruta}")
    if aplicar:
        bpy.ops.wm.save_mainfile()
        print(f"guardado: {FUENTE}")


if __name__ == "__main__":
    main()
