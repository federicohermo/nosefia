"""Hornea la variación grande de las paredes pintadas: la foto mezclada en el editor de nodos, sin repetirse.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/hornear_paredes.py -- [--aplicar]

Sin `--aplicar` escribe en una carpeta temporal. Con `--aplicar` escribe `ARCHIVO`. El `.blend`
no cambia. Después va `paredes_con_foto.py`, que compensa el brillo con `MEDIA`.

## Por qué

La pared lleva la foto de una pared real repetida cada pocos metros (`paredes_con_foto.py`). Su
grano fino no delata la repetición, pero sus retoques y manchas sí. Bajarles el contraste los
escondía junto con el detalle.

## Qué hace

Arma en el editor de nodos de Blender un material que no se repite y lo hornea con Cycles:

- **Cuatro muestras de la foto** (`painted_plaster_wall`, CC0), cada una corrida y girada 90
  grados respecto de la anterior, elegidas por tres ruidos en zonas de menos de un metro: donde
  una muestra repetiría un retoque, otra pone uno distinto.
- **Un ruido de tono** de varios metros, apenas más claro o más oscuro.
- **Todo cierra sobre sí mismo cada `METROS_DEL_MOSAICO`**: las muestras de la foto porque su
  período lo divide, y los ruidos porque se leen sobre un toro. Así el juego la repite sin
  costura, en coordenadas del mundo (`importar_modelo.gd`), y la repetición cae más lejos que
  el largo de cualquier pared.

El resultado es el brillo relativo de cada punto, gris y con media `MEDIA`. El juego la
multiplica sobre el color de la pared como textura de detalle. Lleva sólo la variación grande:
el grano fino lo pone `paredes_con_foto.py`.

## Lo que cuesta

Una textura de `LADO`, compartida por el salón y el baño, y tres lecturas más por pixel de
pared. Ningún triángulo, material ni dibujo más. Es idempotente: la semilla de los ruidos y la
foto son fijas.
"""

import sys
import tempfile
from pathlib import Path

import bpy  # type: ignore[import-not-found]
import numpy as np

RAIZ = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(RAIZ / ".claude/scripts"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import metal_detalle as metal  # noqa: E402
from lib.consola import configurar  # noqa: E402

FOTO = RAIZ / "assets/source/textures/third-party/painted_plaster_wall/painted_plaster_wall_diff_2k.jpg"
ARCHIVO = RAIZ / "assets/models/pared_variacion.png"
#: El lado de pared que cubre la foto, según su página.
METROS_DE_LA_FOTO = 2.0
#: Cada cuánto se repite la variación en el juego: múltiplo de `METROS_DE_LA_FOTO` y más largo
#: que la pared más larga del salón.
METROS_DEL_MOSAICO = 14.0
LADO = 1024
#: El brillo medio de la variación, en luz lineal. Queda por debajo de 1 para que lo más claro no
#: se recorte: `paredes_con_foto.py` aclara la pared en la misma proporción.
MEDIA = 0.96
#: Cuánto de su propio contraste conserva la foto, y cuánto varía el tono a gran escala.
CONTRASTE = 0.35
TONO = 0.012
#: El tamaño de las zonas que elige cada muestra, en vueltas del toro: más alto, más chicas.
ESCALA_DE_LA_MEZCLA = 3.0
ESCALA_DEL_TONO = 0.9


def _srgb(lineal: np.ndarray) -> np.ndarray:
    return np.where(lineal <= 0.0031308, lineal * 12.92, 1.055 * np.power(lineal, 1 / 2.4) - 0.055)


class Nodos:
    def __init__(self, material) -> None:
        self.nodos = material.node_tree.nodes
        self.enlaces = material.node_tree.links

    def nuevo(self, tipo: str, **valores):
        nodo = self.nodos.new(tipo)
        for clave, valor in valores.items():
            setattr(nodo, clave, valor)
        return nodo

    def enlazar(self, salida, entrada) -> None:
        self.enlaces.new(salida, entrada)

    def matematica(self, operacion: str, a, b=None):
        nodo = self.nuevo("ShaderNodeMath", operation=operacion)
        for indice, valor in enumerate((a, b)):
            if valor is None:
                continue
            if isinstance(valor, (int, float)):
                nodo.inputs[indice].default_value = valor
            else:
                self.enlazar(valor, nodo.inputs[indice])
        return nodo.outputs[0]


def armar(material, foto) -> None:
    """El árbol de nodos: cuatro muestras de la foto, tres ruidos que eligen entre ellas y el tono."""
    n = Nodos(material)
    n.nodos.clear()
    salida = n.nuevo("ShaderNodeOutputMaterial")
    emision = n.nuevo("ShaderNodeEmission")
    n.enlazar(emision.outputs["Emission"], salida.inputs["Surface"])
    uv = n.nuevo("ShaderNodeTexCoord").outputs["UV"]
    partes = n.nuevo("ShaderNodeSeparateXYZ")
    n.enlazar(uv, partes.inputs[0])

    # Las muestras de la foto: en vueltas de la foto, corridas y giradas de a 90 grados.
    vueltas = METROS_DEL_MOSAICO / METROS_DE_LA_FOTO
    en_fotos = n.nuevo("ShaderNodeVectorMath", operation="SCALE")
    en_fotos.inputs["Scale"].default_value = vueltas
    n.enlazar(uv, en_fotos.inputs[0])
    muestras = []
    for indice, corrimiento in enumerate(
        ((0.0, 0.0, 0.0), (0.37, 0.71, 0.0), (0.83, 0.19, 0.0), (0.58, 0.44, 0.0))
    ):
        corrido = n.nuevo("ShaderNodeVectorMath", operation="ADD")
        corrido.inputs[1].default_value = corrimiento
        n.enlazar(en_fotos.outputs[0], corrido.inputs[0])
        giro = n.nuevo("ShaderNodeVectorRotate", rotation_type="Z_AXIS")
        giro.inputs["Angle"].default_value = np.pi / 2 * indice
        n.enlazar(corrido.outputs[0], giro.inputs["Vector"])
        imagen = n.nuevo("ShaderNodeTexImage", image=foto, interpolation="Cubic", extension="REPEAT")
        n.enlazar(giro.outputs[0], imagen.inputs["Vector"])
        muestras.append(imagen.outputs["Color"])

    # Los ruidos se leen sobre un toro: cierran sobre sí mismos en los bordes del mosaico.
    angulo_u = n.matematica("MULTIPLY", partes.outputs["X"], 2 * np.pi)
    angulo_v = n.matematica("MULTIPLY", partes.outputs["Y"], 2 * np.pi)
    toro = n.nuevo("ShaderNodeCombineXYZ")
    n.enlazar(n.matematica("COSINE", angulo_u), toro.inputs["X"])
    n.enlazar(n.matematica("SINE", angulo_u), toro.inputs["Y"])
    n.enlazar(n.matematica("COSINE", angulo_v), toro.inputs["Z"])
    cuarta = n.matematica("SINE", angulo_v)

    def ruido(escala: float, semilla: float):
        corrido = n.matematica("ADD", cuarta, semilla)
        nodo = n.nuevo("ShaderNodeTexNoise", noise_dimensions="4D")
        nodo.inputs["Scale"].default_value = escala
        nodo.inputs["Detail"].default_value = 3.0
        n.enlazar(toro.outputs[0], nodo.inputs["Vector"])
        n.enlazar(corrido, nodo.inputs["W"])
        return nodo.outputs["Fac"]

    def mezclar(a, b, factor):
        rampa = n.nuevo("ShaderNodeValToRGB")
        rampa.color_ramp.elements[0].position = 0.45
        rampa.color_ramp.elements[1].position = 0.55
        n.enlazar(factor, rampa.inputs["Fac"])
        mezcla = n.nuevo("ShaderNodeMix", data_type="RGBA")
        n.enlazar(rampa.outputs["Color"], mezcla.inputs["Factor"])
        n.enlazar(a, mezcla.inputs["A"])
        n.enlazar(b, mezcla.inputs["B"])
        return mezcla.outputs["Result"]

    foto_mezclada = mezclar(
        mezclar(muestras[0], muestras[1], ruido(ESCALA_DE_LA_MEZCLA, 1.3)),
        mezclar(muestras[2], muestras[3], ruido(ESCALA_DE_LA_MEZCLA, 3.7)),
        ruido(ESCALA_DE_LA_MEZCLA, 5.9),
    )
    gris = n.nuevo("ShaderNodeRGBToBW")
    n.enlazar(foto_mezclada, gris.inputs[0])
    # Rojo: el brillo de la foto mezclada. Verde: el ruido de tono. Se combinan al leer el horneado.
    canales = n.nuevo("ShaderNodeCombineColor")
    n.enlazar(gris.outputs[0], canales.inputs[0])
    n.enlazar(ruido(ESCALA_DEL_TONO, 9.4), canales.inputs[1])
    n.enlazar(canales.outputs[0], emision.inputs["Color"])


def hornear(foto) -> np.ndarray:
    """Hornea el árbol sobre un plano con la UV de 0 a 1 y devuelve rojo y verde en luz lineal."""
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    plano = bpy.context.active_object
    material = bpy.data.materials.new("__variacion_de_las_paredes")
    material.use_nodes = True
    armar(material, foto)
    imagen = bpy.data.images.new("__variacion", LADO, LADO, alpha=False, float_buffer=True)
    destino = material.node_tree.nodes.new("ShaderNodeTexImage")
    destino.image = imagen
    material.node_tree.nodes.active = destino
    plano.data.materials.append(material)
    escena = bpy.context.scene
    antes = (escena.render.engine, escena.cycles.samples, escena.render.bake.margin)
    escena.render.engine = "CYCLES"
    escena.cycles.samples = 16
    escena.render.bake.margin = 0
    bpy.ops.object.bake(type="EMIT")
    escena.render.engine, escena.cycles.samples, escena.render.bake.margin = antes
    pixeles = np.empty(LADO * LADO * 4, dtype=np.float32)
    imagen.pixels.foreach_get(pixeles)
    malla = plano.data
    bpy.data.objects.remove(plano)
    bpy.data.meshes.remove(malla)
    bpy.data.materials.remove(material)
    bpy.data.images.remove(imagen)
    return pixeles.reshape(LADO, LADO, 4)[..., :2].astype(np.float64)


def variacion(horneado: np.ndarray) -> np.ndarray:
    """El brillo relativo de cada punto, con media `MEDIA`, en valores de imagen de 0 a 1."""
    brillo, tono = horneado[..., 0], horneado[..., 1]
    relativo = 1.0 + (brillo / brillo.mean() - 1.0) * CONTRASTE
    relativo *= 1.0 + (tono - tono.mean()) / max(tono.std(), 1e-6) * TONO
    lineal = np.clip(relativo * MEDIA / relativo.mean(), 0.0, 1.0)
    gris = _srgb(lineal)
    return np.repeat(gris[..., None], 3, axis=-1)


def main() -> None:
    configurar()
    destino = ARCHIVO if "--aplicar" in sys.argv else Path(tempfile.mkdtemp()) / ARCHIVO.name
    foto = bpy.data.images.load(str(FOTO), check_existing=True)
    foto.colorspace_settings.name = "sRGB"
    pixeles = variacion(hornear(foto))
    destino.write_bytes(metal.png_de(pixeles))
    print(f"variación: {destino}, media {pixeles.mean():.3f}, desvío {pixeles.std():.3f}")


if __name__ == "__main__":
    main()
