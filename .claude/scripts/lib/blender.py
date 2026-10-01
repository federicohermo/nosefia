"""Dónde está Blender, y qué decir cuando no está.

Mismo diseño que `godot.py`, y por el mismo motivo: el entorno se **inyecta** en vez de leerse,
así que se puede probar «no está declarada» en una máquina que sí la tiene.

**La versión importa y no es un detalle.** El par `.blend` ↔ `.glb` se midió con Blender 5.2.1:
dos versiones del exportador devuelven datos de vértice distintos para la misma malla, así que
exportar con otra deja un diff binario enorme que no corresponde a ningún cambio del modelo.

**Y acá viven las reglas de la exportación**, no en `blender/exportar.py`: allá corre el Python
de Blender, y ningún test lo puede importar. Qué modificador se apaga, qué colección no viaja, y
con qué lado viaja cada textura.
"""

import json
import os
import struct
import unicodedata
import zlib
from collections.abc import Callable

from lib.repo import RAIZ

#: La variable donde vive la ruta, cuando el ejecutable no está en el PATH.
VARIABLE = "BLENDER_BIN"

#: La serie con la que se midió el par. Ver el encabezado.
SERIE = "5.2"

#: Dónde lo deja el instalador de Windows. Se prueban en orden y gana la primera que existe.
UBICACIONES_WINDOWS = (
    rf"C:\Program Files\Blender Foundation\Blender {SERIE}\blender.exe",
    rf"C:\Program Files\Blender Foundation\Blender {SERIE}\blender-launcher.exe",
)


def resolver(
    entorno: dict[str, str],
    existe: Callable[[str], bool] = os.path.isfile,
    ubicaciones: tuple[str, ...] = UBICACIONES_WINDOWS,
) -> tuple[str | None, str | None]:
    """El ejecutable y de dónde salió, o `(None, None)`.

    El orden es deliberado: **la variable gana**. Quien la declaró eligió una versión, y que el
    instalador haya dejado otra en su lugar de siempre no puede pisar esa elección.
    """
    declarado = entorno.get(VARIABLE, "").strip().strip('"')
    if declarado and existe(declarado):
        return declarado, VARIABLE
    for ruta in ubicaciones:
        if existe(ruta):
            return ruta, "instalación"
    return None, None


def como_declararlo(entorno: dict[str, str]) -> str:
    """El mensaje de un Blender que no se encontró, con la salida escrita.

    Bloquear sin decir cómo salir produce el reflejo de saltear el bloqueo.
    """
    declarado = entorno.get(VARIABLE, "").strip().strip('"')
    if declarado:
        return (
            f"`{VARIABLE}` está declarada y apunta a un archivo que no existe:\n  {declarado}\n"
            "Corregila, o borrala para que se busque en la instalación."
        )
    return (
        f"No se encontró Blender {SERIE}. Declaralo una vez en `{VARIABLE}`:\n\n"
        f'  setx {VARIABLE} "C:\\Program Files\\Blender Foundation\\Blender {SERIE}\\blender.exe"\n\n'
        "Y abrí una terminal nueva: un proceso hereda el entorno de su padre y no lo relee."
    )

#: El modificador que se apaga al exportar. Es un **nombre**, no un tipo: son Geometry Nodes
#: llamados así, y apagar por tipo `ARRAY` no apaga ninguno.
MODIFICADOR = "Array"


def es_un_array(nombre: str) -> bool:
    """Si un modificador es uno de los que llenan el estante, y por lo tanto hay que apagarlo.

    **Cuenta el sufijo de Blender.** Al duplicar un objeto, Blender numera el modificador
    copiado: `Array.001`, `Array.002`. Comparar el nombre exacto contra `Array` deja pasar todos
    los duplicados, y el producto sale multiplicado igual — que es justo la falla que apagar por
    nombre venía a evitar.

    Medido el 2026-09-18 sobre el `.blend` del almacén: **36 `Array` y 34 `Array.001`**. Con la
    comparación exacta, 34 productos salían al doble o al cuádruple de vértices, y el `.glb`
    dejaba de corresponder a su fuente sin que el comando de exportar dijera nada.
    """
    return nombre == MODIFICADOR or nombre.startswith(MODIFICADOR + ".")


#: La colección donde viven las copias de cada producto. **No se exporta**: el juego las dibuja
#: con un `MultiMesh`, y horneadas en el `.glb` cada producto se vería dos veces. Queda visible
#: en Blender —el artista acomoda las copias ahí— y la excluye el exportador.
COLECCION_DE_GUIA = "guia"

#: El lado más grande que puede tener una textura del modelo, en píxeles. Ningún grupo lo pasa
#: al exportar, y Godot importa cada textura que extrae del `.glb` con este límite
#: (`process/size_limit`): son dos redes, y una textura que se cuele por la primera no llega a
#: la placa de video más grande que esto.
LADO_TOPE = 1024

#: Los tres grupos en los que se reparten las texturas del modelo.
PRODUCTOS = "productos"
MUEBLES = "muebles"
EDIFICIO = "edificio"

#: El lado máximo, en píxeles, con el que viaja en el `.glb` cada textura de cada grupo.
#:
#: **Lo decide el usuario mirando capturas** (#267). Una etiqueta de producto ocupa pocos
#: píxeles en pantalla y filtra pixelado, así que se prueba a 512. Un mueble o una pared se ven
#: de cerca, y quedan en 1024: Godot ya los importaba con ese límite, así que en pantalla no
#: cambian.
LADO_MAXIMO = {PRODUCTOS: 512, MUEBLES: 1024, EDIFICIO: 1024}

#: Donde vive el arte de origen del artista. Las rutas del `.blend` apuntan acá.
FUENTES = RAIZ / "assets" / "source"

#: De dónde sale cada grupo: una carpeta de `FUENTES`, o un archivo suelto que el artista guardó
#: en la carpeta de otro. Gana la entrada más larga que calce, así que el archivo le gana a su
#: carpeta. Lo que no calza con ninguna es mueble, y también lo empaquetado con la ruta de otra
#: máquina —la góndola, el inodoro, la bacha, la placa del techo—, que no sale de `FUENTES`.
#:
#: **`textures/props/` no alcanza como carpeta.** Es la utilería, y junta la caja registradora,
#: el balde, la mopa, el tablero de luz y el portón con cinco etiquetas: el alfajor Jorgillo, las
#: papas Prongles, la lata de Marranos, la caja de Feel Ricky Fort y el bidón de jabón. Esas
#: cinco van con nombre. El día que el artista las mueva a una carpeta de producto, su entrada
#: sobra, y `test_cada_origen_de_la_tabla_existe` da rojo si queda apuntando a la nada.
ORIGEN_DE_CADA_GRUPO = {
    "products-cam": PRODUCTOS,
    "products-textured": PRODUCTOS,
    "textures/props/atun marranos.png": PRODUCTOS,
    "textures/props/cereal textura.png": PRODUCTOS,
    "textures/props/jabón liquido.png": PRODUCTOS,
    "textures/props/jorgillata.png": PRODUCTOS,
    "textures/props/progres.png": PRODUCTOS,
    "third-party/128x128/Bricks": EDIFICIO,
}


def grupo_de(ruta_en_fuentes: str | None) -> str:
    """El grupo de una imagen, por la ruta de su archivo adentro de `FUENTES`, con `/`.

    `None` es una imagen que no sale de ahí. Las rutas se comparan normalizadas: «ó» llega como
    un carácter o como «o» más el acento suelto, según qué programa la escribió, y para el
    disco es el mismo archivo.
    """
    if ruta_en_fuentes is None:
        return MUEBLES
    ruta = unicodedata.normalize("NFC", ruta_en_fuentes)
    elegido, grupo = "", MUEBLES
    for origen, suyo in ORIGEN_DE_CADA_GRUPO.items():
        origen = unicodedata.normalize("NFC", origen)
        calza = ruta == origen or ruta.startswith(origen + "/")
        if calza and len(origen) > len(elegido):
            elegido, grupo = origen, suyo
    return grupo


def achicada(ancho: int, alto: int, lado_maximo: int) -> tuple[int, int]:
    """El tamaño con el que viaja una imagen: el suyo si entra, y si no, con el lado mayor en el
    máximo y el otro en proporción. **Nunca agranda**: el máximo es un techo, y una madera de
    128 px sigue en 128.
    """
    if max(ancho, alto) <= lado_maximo:
        return ancho, alto
    if ancho >= alto:
        return lado_maximo, max(1, round(alto * lado_maximo / ancho))
    return max(1, round(ancho * lado_maximo / alto)), lado_maximo


#: Con lo que empieza todo PNG.
FIRMA_PNG = b"\x89PNG\r\n\x1a\n"


def recomprimir_png(datos: bytes) -> bytes:
    """El mismo PNG con su `IDAT` comprimido al nivel más alto de zlib, o el que llegó si así no
    achica o si no es un PNG.

    **No cambia un píxel.** Se descomprime y se vuelve a comprimir el mismo flujo, con las filas
    ya filtradas, así que decodificado es el mismo byte a byte. Los demás trozos quedan como
    estaban y en su orden, y los `IDAT` partidos se unen en uno, en el lugar del primero.

    Hace falta porque Blender escribe cada PNG con su compresión por defecto, que es floja, y el
    exportador de glTF no deja elegir otra: `Image.save` ignora `quality` en un PNG. Medido el
    2026-09-29: el mismo tamaño con 0, 15, 50, 90 y 100, y el mismo flujo con nivel 9 pesa entre
    un 10 y un 25 % menos.
    """
    if not datos.startswith(FIRMA_PNG):
        return datos
    trozos: list[tuple[bytes, bytes]] = []
    indice = len(FIRMA_PNG)
    while indice + 8 <= len(datos):
        largo, tipo = struct.unpack_from(">I4s", datos, indice)
        trozos.append((tipo, datos[indice + 8 : indice + 8 + largo]))
        indice += 12 + largo
    flujo = b"".join(cuerpo for tipo, cuerpo in trozos if tipo == b"IDAT")
    if not flujo:
        return datos
    apretado = zlib.compress(zlib.decompress(flujo), 9)
    if len(apretado) >= len(flujo):
        return datos
    salida = [FIRMA_PNG]
    puesto = False
    for tipo, cuerpo in trozos:
        if tipo == b"IDAT":
            if puesto:
                continue
            cuerpo, puesto = apretado, True
        crc = zlib.crc32(tipo + cuerpo)
        salida.append(struct.pack(">I", len(cuerpo)) + tipo + cuerpo + struct.pack(">I", crc))
    return b"".join(salida)


def recomprimir_las_imagenes(glb: bytes) -> bytes:
    """El mismo `.glb` con cada imagen PNG recomprimida, como hace `recomprimir_png`.

    Achicar una imagen corre todo lo que viene después en el binario, así que cada vista se
    vuelve a ubicar, en el orden en que estaba y empezando en un múltiplo de 4: es lo que glTF
    pide para que los accesores queden alineados. El resto del JSON no se toca.

    Un `.glb` con vistas fuera del binario propio vuelve como llegó: no es lo que exporta Blender,
    y reubicarlas sin mirar qué son podría romperlo.
    """
    largo_json = struct.unpack_from("<I", glb, 12)[0]
    modelo = json.loads(glb[20 : 20 + largo_json])
    desde_bin = 20 + largo_json
    if desde_bin + 8 > len(glb):
        return glb
    largo_bin, tipo_bin = struct.unpack_from("<I4s", glb, desde_bin)
    vistas = modelo.get("bufferViews", [])
    if tipo_bin != b"BIN\x00" or any(vista.get("buffer", 0) != 0 for vista in vistas):
        return glb
    binario = glb[desde_bin + 8 : desde_bin + 8 + largo_bin]
    imagenes = modelo.get("images", [])
    de_imagen = {imagen["bufferView"] for imagen in imagenes if "bufferView" in imagen}
    nuevo = bytearray()
    for indice in sorted(range(len(vistas)), key=lambda i: vistas[i].get("byteOffset", 0)):
        vista = vistas[indice]
        desde = vista.get("byteOffset", 0)
        datos = binario[desde : desde + vista["byteLength"]]
        if indice in de_imagen:
            datos = recomprimir_png(datos)
        nuevo += bytes(-len(nuevo) % 4)
        vista["byteOffset"] = len(nuevo)
        vista["byteLength"] = len(datos)
        nuevo += datos
    nuevo += bytes(-len(nuevo) % 4)
    modelo["buffers"][0]["byteLength"] = len(nuevo)
    texto = json.dumps(modelo, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    texto += b" " * (-len(texto) % 4)
    total = 12 + 8 + len(texto) + 8 + len(nuevo)
    return b"".join(
        (
            struct.pack("<4sII", b"glTF", 2, total),
            struct.pack("<I4s", len(texto), b"JSON"),
            texto,
            struct.pack("<I4s", len(nuevo), b"BIN\x00"),
            bytes(nuevo),
        )
    )
