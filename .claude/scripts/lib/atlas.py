"""Los atlas de etiquetas de producto y de cajas: qué entra en cada uno y dónde.

Un atlas **no baja dibujos**: Compatibility dibuja una vez por superficie, comparta o no la
textura. Sirve para poder **unir** objetos que hoy llevan texturas distintas, y para que treinta
y tantas cajas dejen de ser treinta y tantos objetos de textura. Por eso va después de unir
mallas y por eso no cambia ni un píxel de lo que se ve.

## Lo que decide este módulo, sin tocar un archivo de imagen

- **Qué texturas entran** (`ETIQUETAS`, `CAJAS`), por la ruta de su fuente.
- **A qué atlas va cada una**: uno por formato. Lo opaco se comprime en BC1 y lo que tiene alfa
  en BC3, y un atlas es de un solo formato.
- **Dónde cae cada una** (`acomodar`): en estantes, ordenadas de mayor a menor, con un borde de
  `BORDE` píxeles alrededor que repite el último píxel de la textura. Sin el borde, el mip chico
  de una etiqueta toma píxeles de la vecina. La textura empieza en un múltiplo de `ALINEACION`:
  así los bloques de BC1 y BC3 de sus primeros mips cuentan desde la misma esquina que cuando
  viajaba suelta.
- **El tope**: ningún atlas pasa de `TOPE` por lado, que es lo que garantiza la web.
- **A dónde van las UV** (`uv_en_el_atlas`) y **si el atlas está al día** (`desfasaje`).

La textura entra con **el tamaño con el que viaja hoy** (`lib/blender.achicada`): el atlas no
baja resolución. Si el artista cambia una textura por otra de otro tamaño, el atlas se acomoda
de nuevo y las UV de todas las que se movieron se reescriben solas.

`blender/armar_atlas.py` lee los píxeles y escribe los PNG; el manifiesto que deja al lado
(`MANIFIESTO`) es lo que lee el exportador y lo que compara el test.
"""

import hashlib
import json
import unicodedata
from dataclasses import dataclass
from pathlib import Path

from lib import biseles
from lib.blender import LADO_MAXIMO, achicada, grupo_de
from lib.repo import RAIZ

#: Las rutas de abajo, y las del manifiesto, son relativas a esta carpeta.
ASSETS = RAIZ / "assets"

#: Donde el artista deja su arte de origen: `lib.blender.FUENTES`.
FUENTES = ASSETS / "source"

#: Dónde se escribe cada atlas y su manifiesto. Está en `source/` porque no lo importa Godot:
#: viaja adentro del `.glb`, o lo lee la caja desde `assets/boxes/`.
CARPETA = FUENTES / "atlas"
MANIFIESTO = CARPETA / "atlas.json"

#: El lado del bloque de BC1 y BC3.
BLOQUE = 4

#: Dónde puede empezar la textura de una celda: en un múltiplo de esto, en x y en y. **No es sólo
#: el bloque.** El mip `k` de una textura se comprime en bloques de 4 que cuentan desde su propia
#: esquina. En el atlas cuentan desde la del atlas: si la textura no empieza en un múltiplo de
#: `4 * 2**k`, los bloques de ese mip agrupan otros píxeles y la compresión da otro ruido. Medido
#: en la web con 4: 7,7 % de los píxeles de una vista de góndola difería en más de 8 niveles. Con
#: 16 los mips 0, 1 y 2, que son los que se ven, comprimen igual que la textura suelta.
ALINEACION = 16

#: Píxeles que repite cada textura alrededor de sí misma. Múltiplo de `ALINEACION`, para que la
#: textura siga alineada, y alcanza para que los primeros cuatro mips no mezclen vecinas.
BORDE = 16

#: El lado más grande de un atlas, en píxeles. El de la placa más chica que juega.
TOPE = 4096

BC1 = "bc1"
BC3 = "bc3"

#: Qué entra, por la ruta de su fuente. Una textura nueva es una línea. La compara `NFC`: «ó»
#: llega como un carácter o como «o» más el acento suelto, según el programa que escribió el
#: nombre.
ETIQUETAS = (
    "source/products-textured/Actroncito/Actroncito completo.png",
    "source/products-textured/Durextra/Durextra completo_1.png",
    "source/products-textured/Burbaloo/Burbaloo completo_1.png",
    "source/products-textured/Zucarachas/Zucarachas completo_1.png",
    "source/products-textured/Lay´snt´t/Lay´snt´t completo_1.png",
    "source/textures/props/progres.png",
    "source/textures/props/jorgillata.png",
    "source/products-textured/Arvejas/arvecor.png",
    "source/products-textured/chizitos/chisito.png",
    "source/products-textured/galletitas/pepito.png",
    "source/products-textured/galletitas/saladick.png",
    "source/products-textured/Wakas/wakasfideos.png",
    "source/products-textured/Cora cola/cora cola.png",
    "source/products-textured/cereales/frot lups.png",
    "source/products-textured/Marolini/fideos marolini.png",
    "source/products-cam/amargadito/amargadito completo.png",
    "source/products-cam/cindolor/cindolor completo.png",
    "source/products-cam/flim pof/flim pof completo.png",
    "source/products-cam/don saturados/Don Saturados completo.png",
    "source/products-cam/petisas/petisas completo.png",
    "source/products-cam/macumbas/macumbas completo.png",
    "source/products-cam/NUEVOS 22-9/Cosa de maní/cosa de mani interno.png",
    "source/products-cam/NUEVOS 22-9/fernet-god/fernetgod textura.png",
    "source/products-cam/NUEVOS 22-9/Mayonchis/mayonchis@300x.png",
    "source/products-cam/NUEVOS 22-9/Oaaaa/oaaaa completo.png",
    "source/products-cam/NUEVOS 22-9/Terminator/Terminator completo.png",
    "source/textures/props/atun marranos.png",
    "source/products-cam/SEI TUQUI/sei_tuqui.png",
    "source/textures/props/textura poético.png",
    "source/textures/props/jabón liquido rosa.png",
    "source/textures/props/jabón liquido amarillo.png",
    "source/textures/props/jabón liquido.png",
    "source/textures/props/soap-labels/jabon_amarillo_sin_margenes.png",
    "source/textures/props/soap-labels/jabon_azul_sin_margenes.png",
    "source/textures/props/soap-labels/jabon_rosa_sin_margenes.png",
    "source/products-cam/don saturados/Don Saturados costado.png",
    "source/products-cam/petisas/petisas costado.png",
    "source/products-cam/macumbas/macumbas costado.png",
)

#: Qué grupos arma hoy el atlas. Un grupo entra cuando todo lo que lo consume está listo: las
#: UV del modelo para las etiquetas, el código de la caja para las cajas. Un grupo que no está
#: acá no aparece en el manifiesto, y sus texturas siguen viajando sueltas.
ETIQUETAS_DE_PRODUCTO = "etiquetas"
CAJAS = "cajas"
GRUPOS_ACTIVOS = (ETIQUETAS_DE_PRODUCTO, CAJAS)

#: Las cajas del depósito: copias en ASCII de la etiqueta de cada producto, a 512 por lado. Entra
#: todo PNG de la carpeta: una caja nueva es un archivo nuevo. Está en `source/` porque Godot no
#: la importa: lo que importa es el atlas, que va en `DESTINO_DE_LAS_CAJAS`.
CARPETA_DE_CAJAS = "source/boxes"
DESTINO_DE_LAS_CAJAS = "boxes"
LADO_DE_LAS_CAJAS = 512


def es_caja(clave: str) -> bool:
    return clave.startswith(CARPETA_DE_CAJAS + "/")


#: El atlas de las cajas se importa en Godot, y lo lee el juego: vive junto a las cajas. El de
#: las etiquetas viaja adentro del `.glb`: vive en `CARPETA`, que Godot no importa.
PREFIJO_DE_LAS_CAJAS = "atlas_cajas"
REPARTO_DE_LAS_CAJAS = ASSETS / DESTINO_DE_LAS_CAJAS / "atlas_de_cajas.json"


def carpeta_del_atlas(archivo: str) -> Path:
    if archivo.startswith(PREFIJO_DE_LAS_CAJAS):
        return ASSETS / DESTINO_DE_LAS_CAJAS
    return CARPETA


def normalizar(ruta: str) -> str:
    return unicodedata.normalize("NFC", ruta)


@dataclass(frozen=True)
class Entrada:
    """Una textura que entra a un atlas, con el tamaño con el que viaja."""

    ruta: str
    ancho: int
    alto: int
    formato: str
    huella: str


@dataclass(frozen=True)
class Colocada:
    """Dónde cayó una textura: su esquina superior izquierda, **sin** contar el borde."""

    entrada: Entrada
    x: int
    y: int


@dataclass(frozen=True)
class Atlas:
    archivo: str
    ancho: int
    alto: int
    formato: str
    colocadas: tuple[Colocada, ...]


def _arriba(valor: int, multiplo: int = ALINEACION) -> int:
    return -(-valor // multiplo) * multiplo


def _estantes(entradas: list[Entrada], ancho: int, borde: int) -> tuple[list[tuple[Entrada, int, int]], int]:
    colocadas = []
    x = y = alto_de_fila = 0
    for entrada in entradas:
        celda_ancho, celda_alto = entrada.ancho + 2 * borde, entrada.alto + 2 * borde
        if x + celda_ancho > ancho:
            y += _arriba(alto_de_fila)
            x = alto_de_fila = 0
        colocadas.append((entrada, x + borde, y + borde))
        x += _arriba(celda_ancho)
        alto_de_fila = max(alto_de_fila, celda_alto)
    return colocadas, y + _arriba(alto_de_fila)


def _una_hoja(entradas: list[Entrada], borde: int, tope: int) -> tuple[int, int, list] | None:
    """La hoja de menor área que contiene a todas, o `None` si ninguna entra bajo el tope."""
    ordenadas = sorted(entradas, key=lambda e: (-e.alto, -e.ancho, normalizar(e.ruta)))
    ancho_minimo = max(e.ancho + 2 * borde for e in entradas)
    mejor = None
    for ancho in range(_arriba(ancho_minimo), tope + 1, ALINEACION):
        colocadas, alto = _estantes(ordenadas, ancho, borde)
        if alto > tope:
            continue
        if mejor is None or ancho * alto < mejor[0] * mejor[1]:
            mejor = (ancho, alto, colocadas)
    return mejor


def acomodar(
    entradas: list[Entrada], nombre: str, borde: int = BORDE, tope: int = TOPE
) -> list[Atlas]:
    """Reparte las entradas, de un mismo formato, en tantos atlas como hagan falta.

    Es **determinista**: las mismas entradas dan los mismos atlas, y por eso el test puede
    comparar el manifiesto contra lo que saldría hoy. Con una sola hoja posible, el archivo se
    llama `<nombre>.png`; con varias, `<nombre>_0.png`, `<nombre>_1.png`...
    """
    if not entradas:
        return []
    formatos = {e.formato for e in entradas}
    if len(formatos) != 1:
        raise ValueError(f"un atlas es de un solo formato, y llegaron {sorted(formatos)}")
    for entrada in entradas:
        if max(entrada.ancho, entrada.alto) + 2 * borde > tope:
            raise ValueError(f"{entrada.ruta} mide {entrada.ancho}x{entrada.alto}: no entra en {tope}")
    formato = entradas[0].formato
    pendientes = sorted(entradas, key=lambda e: (-e.alto, -e.ancho, normalizar(e.ruta)))
    hojas: list[tuple[int, int, list]] = []
    while pendientes:
        completa = _una_hoja(pendientes, borde, tope)
        if completa is not None:
            hojas.append(completa)
            break
        cuantas = len(pendientes)
        while cuantas > 1 and _una_hoja(pendientes[:cuantas], borde, tope) is None:
            cuantas -= 1
        hojas.append(_una_hoja(pendientes[:cuantas], borde, tope))  # type: ignore[arg-type]
        pendientes = pendientes[cuantas:]
    atlas = []
    for numero, (ancho, alto, colocadas) in enumerate(hojas):
        archivo = f"{nombre}.png" if len(hojas) == 1 else f"{nombre}_{numero}.png"
        atlas.append(
            Atlas(
                archivo, ancho, alto, formato, tuple(Colocada(e, x, y) for e, x, y in colocadas)
            )
        )
    return atlas


def uv_en_el_atlas(colocada: Colocada, atlas: Atlas, u: float, v: float) -> tuple[float, float]:
    """La UV de una textura entera, llevada a su lugar en el atlas.

    `v` crece hacia arriba, como en Blender y en glTF una vez volteada; la fila 0 del PNG es
    la de arriba, así que el lado de la celda se mide desde el borde superior.
    """
    entrada = colocada.entrada
    nueva_u = (colocada.x + u * entrada.ancho) / atlas.ancho
    nueva_v = 1.0 - (colocada.y + (1.0 - v) * entrada.alto) / atlas.alto
    return nueva_u, nueva_v


def huella_de(archivo: Path) -> str:
    return hashlib.sha256(archivo.read_bytes()).hexdigest()


def huella_de_la_fuente(clave: str) -> str:
    """La huella de una fuente del atlas: la etiqueta y, si la tiene, su capa de biseles.

    Con la capa adentro, cambiarla deja el atlas viejo, y `--comprobar` lo dice.
    """
    contenido = (ASSETS / clave).read_bytes()
    capa = biseles.ruta_de_la_capa(clave)
    if capa.is_file():
        contenido += capa.read_bytes()
    return hashlib.sha256(contenido).hexdigest()


def a_manifiesto(atlas_por_grupo: dict[str, list[Atlas]], huellas_de_atlas: dict[str, str]) -> dict:
    return {
        "borde": BORDE,
        "tope": TOPE,
        "atlas": [
            {
                "archivo": atlas.archivo,
                "ancho": atlas.ancho,
                "alto": atlas.alto,
                "formato": atlas.formato,
                "huella": huellas_de_atlas.get(atlas.archivo, ""),
                "entradas": [
                    {
                        "ruta": c.entrada.ruta,
                        "ancho": c.entrada.ancho,
                        "alto": c.entrada.alto,
                        "huella": c.entrada.huella,
                        "x": c.x,
                        "y": c.y,
                    }
                    for c in atlas.colocadas
                ],
            }
            for lista in atlas_por_grupo.values()
            for atlas in lista
        ],
    }


def escribir(manifiesto: dict, destino: Path = MANIFIESTO) -> None:
    destino.parent.mkdir(parents=True, exist_ok=True)
    texto = json.dumps(manifiesto, ensure_ascii=False, indent=1, sort_keys=False) + "\n"
    destino.write_text(texto, encoding="utf-8", newline="\n")


def leer(origen: Path = MANIFIESTO) -> dict:
    return json.loads(origen.read_text(encoding="utf-8"))


def ancho_alto_png(datos: bytes) -> tuple[int, int] | None:
    """El tamaño de un PNG, leído de su cabecera. `None` si no es un PNG."""
    if not datos.startswith(b"\x89PNG\r\n\x1a\n") or len(datos) < 24:
        return None
    return int.from_bytes(datos[16:20], "big"), int.from_bytes(datos[20:24], "big")


def desfasaje(
    manifiesto: dict, fuentes_actuales: dict[str, Entrada], atlas_en_disco: dict[str, bytes]
) -> list[str]:
    """Por qué el atlas no corresponde a sus fuentes. Vacío si está al día.

    `fuentes_actuales` es `ruta -> Entrada` tal como viajaría hoy. Se comparan tres cosas: que
    cada fuente siga siendo la misma —su tamaño, su formato y su contenido—, que no haya una
    fuente nueva ni una borrada, y que el PNG de cada atlas exista, mida lo que dice el
    manifiesto y sea el mismo archivo que se selló.
    """
    motivos = []
    previas = {e["ruta"]: (a["formato"], e) for a in manifiesto["atlas"] for e in a["entradas"]}
    for ruta in sorted(set(previas) - set(fuentes_actuales)):
        motivos.append(f"{ruta}: está en el atlas y ya no existe como fuente")
    for ruta in sorted(set(fuentes_actuales) - set(previas)):
        motivos.append(f"{ruta}: es una fuente nueva y no está en el atlas")
    for ruta, actual in sorted(fuentes_actuales.items()):
        if ruta not in previas:
            continue
        formato, previa = previas[ruta]
        if (previa["ancho"], previa["alto"]) != (actual.ancho, actual.alto):
            motivos.append(
                f"{ruta}: cambió de {previa['ancho']}x{previa['alto']} "
                f"a {actual.ancho}x{actual.alto}"
            )
        elif formato != actual.formato:
            motivos.append(f"{ruta}: pasó de {formato} a {actual.formato}")
        elif previa["huella"] != actual.huella:
            motivos.append(f"{ruta}: la textura cambió desde que se armó el atlas")
    for atlas in manifiesto["atlas"]:
        datos = atlas_en_disco.get(atlas["archivo"])
        if datos is None:
            motivos.append(f"{atlas['archivo']}: falta el PNG del atlas")
            continue
        if ancho_alto_png(datos) != (atlas["ancho"], atlas["alto"]):
            motivos.append(f"{atlas['archivo']}: el PNG no mide lo que dice el manifiesto")
        elif hashlib.sha256(datos).hexdigest() != atlas["huella"]:
            motivos.append(f"{atlas['archivo']}: el PNG no es el que se selló")
    return motivos


def claves_de_las_fuentes() -> list[str]:
    """Toda textura que debería estar en el atlas: la tabla de etiquetas y cada PNG de cajas."""
    claves = list(ETIQUETAS) if ETIQUETAS_DE_PRODUCTO in GRUPOS_ACTIVOS else []
    if CAJAS in GRUPOS_ACTIVOS:
        cajas = sorted((ASSETS / CARPETA_DE_CAJAS).glob("*.png"))
        claves += [f"{CARPETA_DE_CAJAS}/{p.name}" for p in cajas]
    return claves


def lado_de(clave: str) -> int:
    """El lado más grande con el que viaja hoy una textura."""
    if es_caja(clave):
        return LADO_DE_LAS_CAJAS
    return LADO_MAXIMO[grupo_de(clave.removeprefix("source/"))]


def fuentes_del_disco(manifiesto: dict) -> dict[str, Entrada]:
    """Cada fuente tal como viajaría hoy, leída del disco.

    El formato (BC1 o BC3) sale de mirar los píxeles, que acá no se leen: se toma del manifiesto
    mientras el archivo sea el mismo, y si cambió, el cambio ya lo dice la huella.
    """
    formatos = {e["ruta"]: a["formato"] for a in manifiesto["atlas"] for e in a["entradas"]}
    fuentes = {}
    for clave in claves_de_las_fuentes():
        archivo = ASSETS / clave
        if not archivo.is_file():
            continue
        medidas = ancho_alto_png(archivo.read_bytes()[:32])
        if medidas is None:
            raise ValueError(f"{clave} no es un PNG: el atlas sólo lee PNG")
        ancho, alto = achicada(*medidas, lado_de(clave))
        fuentes[clave] = Entrada(clave, ancho, alto, formatos.get(clave, ""), huella_de_la_fuente(clave))
    return fuentes


def desfasaje_con_el_disco(manifiesto: dict, carpeta: Path | None = None) -> list[str]:
    """`desfasaje` contra las fuentes y los PNG que hay hoy. Sin `carpeta`, los del árbol."""
    en_disco = {}
    for a in manifiesto["atlas"]:
        archivo = (carpeta or carpeta_del_atlas(a["archivo"])) / a["archivo"]
        if archivo.is_file():
            en_disco[a["archivo"]] = archivo.read_bytes()
    return desfasaje(manifiesto, fuentes_del_disco(manifiesto), en_disco)


def reparto_de_las_cajas(manifiesto: dict) -> dict:
    """Lo que el juego necesita saber del atlas de cajas: en qué atlas y en qué rectángulo,
    en píxeles, está la etiqueta de cada una. La clave es el nombre del PNG sin extensión, que
    es el `Producto.Id` en minúsculas."""
    atlas = {}
    cajas = {}
    for hoja in manifiesto["atlas"]:
        if not hoja["archivo"].startswith(PREFIJO_DE_LAS_CAJAS):
            continue
        atlas[hoja["archivo"]] = [hoja["ancho"], hoja["alto"]]
        for e in hoja["entradas"]:
            nombre = e["ruta"].rsplit("/", 1)[-1].removesuffix(".png")
            cajas[nombre] = {
                "atlas": hoja["archivo"],
                "rect": [e["x"], e["y"], e["ancho"], e["alto"]],
            }
    return {"atlas": atlas, "cajas": dict(sorted(cajas.items()))}
