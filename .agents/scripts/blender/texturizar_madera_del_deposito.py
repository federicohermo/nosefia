"""Texturizar la madera de los pallets del depósito: tablas de tono parejo, veta, nudos y uso.

    blender assets/models/SEPT_JUEGOS_PROTOTIPO.blend --background --python-exit-code 1 \
        --python .claude/scripts/blender/texturizar_madera_del_deposito.py -- [--aplicar]

Sin `--aplicar` escribe la imagen en `build/madera/` y cambia sólo la sesión de Blender. Con
`--aplicar` escribe `assets/source/textures/warehouse/final/deposito_madera_tablas.png` y guarda
el `.blend`. Después va `exportar_modelo.py`.

## Por qué

La madera de los pallets y de los estantes era un tile de 128 px que se repetía cada 75 cm, con
el mismo tono en todas las tablas y el filtro pixelado marcando cada texel. Se leía como un
color parejo con ruido. Una tabla de pallet de verdad tiene su propio tono, su veta y sus
nudos; el canto está gastado y claro; hay mugre en las puntas y donde se juntan las tablas; y
cada travesaño lleva sus clavos.

La primera versión de la imagen tenía ocho tiras, y los dieciocho pallets de estante compartían
una malla: todos mostraban las mismas cinco tablas en el mismo orden. Y los tonos de las tiras
iban de 0,70 a 1,38 de la madera base, así que entre una tabla y la de al lado había un salto
de claro a oscuro que en un pallet de verdad no existe.

## Qué cambia

- **Una imagen de 1024×1024 con dieciséis tiras de 64 px.** Doce son tablas del tablero y cuatro,
  de patines, travesaños y tacos. La veta corre a lo largo de la tira. Cada tira lleva sus
  anillos, sus poros y sus nudos.
- **El tono es parejo.** Cada tira se corrige para que su luz media quede a menos de un 6 % de la
  madera base, se le saca la variación ancha de tono, y ningún punto de la cara baja de un piso:
  los nudos y las rajaduras se quedan, sin manchas negras anchas. Sólo quedan oscuros los clavos
  y la junta fina entre tablas.
- **Uso**, pintado en el color: canto aclarado por el roce y una junta oscura al pie, mugre más
  densa hacia las puntas, rajaduras en las puntas, rayones finos a lo largo y clavos con su
  aureola de óxido sobre cada travesaño.
- **El testero** de la tabla (el corte de la punta) tiene su propia banda en el extremo derecho
  de cada tira, con anillos de crecimiento y más oscura.
- **Cada pallet tiene su malla y sus UV.** Los dieciocho pallets de estante compartían una malla
  (`Pallet estante.001`); el script le da a cada uno una copia. Cada tabla de cada pallet toma
  una tira de las doce, y puede ir espejada en u (la veta corre al revés: los clavos caen igual,
  porque están simétricos) y en v. Ningún pallet repite en el mismo lugar la tira y el espejo de
  otro. La elección sale del nombre del objeto: la misma entrada da las mismas UV. La u corre
  de punta a punta del pallet, sea cual sea su largo, para que los clavos caigan sobre los
  travesaños. Los patines, los travesaños y los tacos toman tiras y tramos propios, sin clavos.
  Si el exportador une los pallets en una malla, la UV de cada uno viaja con sus vértices.
- **El material** `deposito_madera_listones` apunta a la imagen nueva.

## Lo que cuesta

Ningún triángulo, ningún material ni dibujo más. La textura sigue en 1024×1024: el mismo peso en
memoria de video. Las mallas de los dieciocho pallets de estante pasan de una compartida a
dieciocho propias: 240 triángulos cada una, la misma geometría. Si los pallets quedan como
objetos sueltos en el `.glb`, son diecisiete mallas más, de unos 16 KB de vértices cada una. Un
dibujo por pallet, como antes.

Es determinista y idempotente: la misma entrada da los mismos bytes.
"""

import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from detalle_de_madera import (  # noqa: E402
    desenfocar,
    rayones,
    ruido,
    suave,
    tabla,
)

RAIZ = Path(__file__).resolve().parents[3]
DESTINO = RAIZ / "assets/source/textures/warehouse/final/deposito_madera_tablas.png"
PRUEBA = RAIZ / "build" / "madera" / DESTINO.name
MATERIAL = "deposito_madera_listones"
PREFIJO = "deposito_pallet_"

N = 1024
TIRAS = 16
ALTO_TIRA = N // TIRAS
#: Las primeras tiras son tablas del tablero; las últimas, patines, travesaños y tacos.
TIRAS_DE_TABLA = 12
#: Hasta dónde llega la cara de la tabla en u. De ahí al borde va el testero.
LARGO_CARA = 960
SEMILLA = 20261110
SEMILLA_UV = 20261111
#: El color de siempre de esta madera, en sRGB: el promedio del tile de 128 px.
BASE = np.array([0.376, 0.223, 0.130], dtype=np.float32)
#: La luz media de cada tira respecto de la madera base. Se queda a menos de un 10 %: entre una
#: tabla y la de al lado sólo cambia la veta y un tono apenas distinto.
FACTORES = (0.97, 1.03, 1.00, 1.05, 0.95, 1.02, 0.98, 1.04, 0.96, 1.01, 0.99, 1.06,
            0.92, 0.96, 0.90, 0.94)
#: Ningún punto de la cara baja de esta fracción de la luz media de su tira, clavos y juntas
#: aparte: así los nudos y las rajaduras no dejan manchas negras anchas.
PISO_DE_LUZ = 0.55
#: Cuánto de la variación ancha de tono de cada tira se corrige.
CORRECCION_ANCHA = 0.8
#: La proporción del largo del pallet donde cae el centro de cada travesaño y su clavo.
CLAVOS_U = (0.06 / 1.64, 0.5, 1 - 0.06 / 1.64)
#: Los tramos de la tira que toman los travesaños, los tacos y los cantos, sin clavos.
TRAMO_TRAVESANO = (0.08, 0.44)
TRAMO_TACO = (0.56, 0.64)
FILAS_DE_CANTO = (24, 31)
MARGEN_V = 7
ALTO_UTIL_V = 50


def _tono(azar: np.random.Generator, factor: float):
    gris = azar.uniform(0.0, 0.22)
    base = BASE * factor
    luz = base.mean()
    base = base * (1 - gris) + luz * gris
    return np.clip(base * 1.22, 0, 1), np.clip(base * 0.72, 0, 1)


def _luz(color: np.ndarray) -> np.ndarray:
    return color.mean(axis=2)


def _tira(indice: int, azar: np.random.Generator, factor: float) -> np.ndarray:
    """Una tira de (ALTO_TIRA, N, 3): la cara de la tabla y su testero."""
    claro, oscuro = _tono(azar, factor)
    cara = tabla(
        LARGO_CARA, ALTO_TIRA, azar, claro, oscuro, nudos=int(azar.choice([0, 1, 1, 2])), contraste=1.1
    )
    cara = np.transpose(cara, (1, 0, 2))
    alto, largo = cara.shape[:2]
    u = np.arange(largo, dtype=np.float32)[None, :]
    v = np.arange(alto, dtype=np.float32)[:, None]
    objetivo = BASE.mean() * factor

    # El tono parejo: se saca la variación ancha de claro a oscuro y quedan la veta y los nudos.
    luz = _luz(cara)
    ancha = desenfocar(luz, 28)
    cara = cara * ((luz.mean() / np.maximum(ancha, 1e-3)) ** CORRECCION_ANCHA)[..., None]

    # Mugre y desgaste: más oscuro hacia las puntas y donde se acumula la suciedad.
    puntas = np.broadcast_to(suave(120, 0, u) + suave(largo - 120, largo, u), (alto, largo))
    manchas = ruido(alto, largo, 2, 6, azar, 3)
    sucio = np.clip(0.55 * puntas + 0.9 * suave(0.55, 0.9, manchas), 0, 1)
    cara = cara * (1 - 0.2 * sucio)[..., None]

    # El canto: se gasta y aclara.
    borde = np.minimum(v, alto - 1 - v)
    irregular = ruido(alto, largo, 1, 14, azar, 2)
    gastado = suave(3.5, 0.8, borde) * (0.45 + 0.9 * irregular)
    cara = cara + (np.array([0.95, 0.78, 0.55]) - cara) * (0.3 * gastado)[..., None]

    # Las rajaduras de las puntas, a lo largo de la veta.
    peso = np.clip(puntas, 0, 1)
    rajaduras = rayones(alto, largo, 20, 46, azar, angulo=0.0, dispersion=0.05, peso=peso)
    cara = cara * (1 - 0.4 * rajaduras)[..., None]

    # Rayones finos a lo largo, claros y oscuros, y unos cruzados más cortos.
    claros = rayones(alto, largo, 13, 170, azar, angulo=0.0, dispersion=0.06)
    oscuros = rayones(alto, largo, 9, 120, azar, angulo=0.0, dispersion=0.08)
    cruzados = rayones(alto, largo, 7, 40, azar)
    cara = cara + (np.array([0.85, 0.66, 0.46]) - cara) * (0.20 * claros)[..., None]
    cara = cara * (1 - 0.25 * np.maximum(oscuros, cruzados))[..., None]

    # Ningún punto baja del piso de luz: los nudos se leen, sin manchas negras.
    luz = _luz(cara)
    cara = cara * np.maximum(1.0, PISO_DE_LUZ * luz.mean() / np.maximum(luz, 1e-3))[..., None]

    # La luz media de la tira queda en su objetivo, antes de la junta y los clavos.
    cara = cara * (objetivo / _luz(cara).mean())

    # La junta oscura al pie del canto.
    junta = suave(1.5, 0.3, borde)
    cara = cara * (1 - 0.5 * junta)[..., None]

    # Los clavos: cabeza oscura con un punto de luz y la aureola de óxido.
    yc = np.array([alto * 0.3, alto * 0.7])
    for fraccion in CLAVOS_U:
        xc = fraccion * LARGO_CARA
        for cy in yc:
            d = np.sqrt((u - xc) ** 2 + ((v - cy) * 1.15) ** 2)
            cara = cara * (1 - 0.3 * suave(7.0, 2.5, d))[..., None]
            cabeza = suave(2.6, 1.6, d)
            hierro = np.array([0.20, 0.17, 0.15]) + 0.18 * suave(1.2, 0.0, d)[..., None]
            cara = cara * (1 - cabeza)[..., None] + hierro * cabeza[..., None]

    tira = np.zeros((alto, N, 3), dtype=np.float32)
    tira[:, :LARGO_CARA] = cara

    # El testero: anillos de crecimiento a lo ancho de la tabla, más oscuro que la cara.
    ancho_t = N - LARGO_CARA
    tu = np.arange(ancho_t, dtype=np.float32)[None, :]
    tv = np.arange(alto, dtype=np.float32)[:, None]
    ondas = ruido(alto, ancho_t, 3, 2, azar, 2)
    anillos = 0.5 + 0.5 * np.sin((tu / ancho_t * 3.0 + (tv / alto - 0.5) ** 2 * 5.0 + ondas * 2) * np.pi * 2)
    testero = (oscuro * 0.9)[None, None, :] * (0.82 + 0.28 * anillos)[..., None]
    testero = testero * (1 - 0.2 * suave(0.5, 1.0, ruido(alto, ancho_t, 6, 4, azar, 2)))[..., None]
    tira[:, LARGO_CARA:] = testero
    return tira


def pintar() -> np.ndarray:
    """La imagen entera, (N, N, 3) en sRGB 0..1, con la fila 0 abajo."""
    azar = np.random.default_rng(SEMILLA)
    tiras = [_tira(i, azar, f) for i, f in enumerate(FACTORES)]
    imagen = np.concatenate(tiras, axis=0)
    # Un velo parejo de polvo da el aire de toda la madera.
    polvo = desenfocar(ruido(N, N, 8, 8, azar, 3), 3)
    imagen = imagen * (0.97 + 0.06 * polvo)[..., None]
    # La imagen conserva la luz media de la madera que reemplaza: el detalle no la oscurece.
    imagen = imagen * (BASE.mean() / imagen.mean())
    return np.clip(imagen, 0.0, 1.0)


# ---------------------------------------------------------------------------------------------
# Lo que sigue necesita Blender.
# ---------------------------------------------------------------------------------------------


def _caja(poligonos, malla):
    """Los límites de las caras de una caja, en la malla."""
    puntos = [malla.vertices[i].co for p in poligonos for i in p.vertices]
    minimo = [min(p[k] for p in puntos) for k in range(3)]
    maximo = [max(p[k] for p in puntos) for k in range(3)]
    return minimo, maximo


def _tipo(minimo, maximo):
    alto = maximo[2] - minimo[2]
    if minimo[2] > 0.099:
        return "tabla"
    if minimo[2] > 0.079:
        return "travesano"
    if minimo[2] > 0.019 and alto > 0.05:
        return "taco"
    return "patin"


def _fraccion(valor, minimo, maximo):
    return 0.0 if maximo == minimo else (valor - minimo) / (maximo - minimo)


def variantes_de_las_tablas(indice: int, previas: list, cuantas: int) -> list:
    """Qué tira y qué espejo toma cada tabla de un pallet: `[(tira, espejo)]`, con espejo 0..3.

    Sale sólo del índice del pallet. Ninguna tabla repite, en su lugar, la tira y el espejo de un
    pallet anterior, y las tiras de un mismo pallet son distintas.
    """
    azar = np.random.default_rng(SEMILLA_UV + indice)
    for _ in range(10_000):
        tiras = azar.permutation(TIRAS_DE_TABLA)[:cuantas]
        espejos = azar.integers(0, 4, cuantas)
        elegidas = [(int(t), int(e)) for t, e in zip(tiras, espejos)]
        if all(a != b for previa in previas for a, b in zip(elegidas, previa)):
            return elegidas
    raise AssertionError("No hay variantes libres para este pallet.")


def reasignar_uv(malla, indice: int, previas: list) -> dict:
    """Rehace las UV de un pallet. Cada caja son seis caras seguidas."""
    capa = malla.uv_layers.active.data
    assert len(malla.polygons) % 6 == 0, "El pallet no es una pila de cajas conocida."
    cajas = []
    for inicio in range(0, len(malla.polygons), 6):
        grupo = [malla.polygons[inicio + k] for k in range(6)]
        minimo, maximo = _caja(grupo, malla)
        cajas.append({"grupo": grupo, "min": minimo, "max": maximo, "tipo": _tipo(minimo, maximo)})

    def ordenadas(tipo, clave):
        return sorted((c for c in cajas if c["tipo"] == tipo), key=clave)

    tablas = ordenadas("tabla", lambda c: c["min"][1])
    elegidas = variantes_de_las_tablas(indice, previas, len(tablas))
    previas.append(elegidas)
    for c, (tira, espejo) in zip(tablas, elegidas):
        c["tira"], c["espejo"] = tira, espejo
    # Los demás miembros toman las cuatro últimas tiras, y cada pallet las reparte distinto.
    estructura = TIRAS_DE_TABLA
    for i, c in enumerate(ordenadas("patin", lambda c: c["min"][1])):
        c["tira"], c["espejo"] = estructura + (i + indice) % 4, 0
    for i, c in enumerate(ordenadas("travesano", lambda c: c["min"][0])):
        c["tira"], c["espejo"] = estructura + (i + 1 + indice) % 4, 0
    for i, c in enumerate(ordenadas("taco", lambda c: (c["min"][1], c["min"][0]))):
        c["tira"], c["espejo"] = estructura + (i + 2 + indice) % 4, 0

    def v_de(tira, fila):
        return (tira * ALTO_TIRA + fila) / N

    cuenta = {"tabla": 0, "travesano": 0, "taco": 0, "patin": 0}
    for c in cajas:
        grupo, minimo, maximo, tipo, tira = c["grupo"], c["min"], c["max"], c["tipo"], c["tira"]
        espejo_u, espejo_v = bool(c["espejo"] & 1), bool(c["espejo"] & 2)
        cuenta[tipo] += 1
        ancho_u = LARGO_CARA / N
        for p in grupo:
            normal = p.normal
            for lazo, i in zip(p.loop_indices, p.vertices):
                x, y, z = malla.vertices[i].co
                fx, fy, fz = (_fraccion(x, minimo[0], maximo[0]), _fraccion(y, minimo[1], maximo[1]),
                              _fraccion(z, minimo[2], maximo[2]))
                if tipo in ("tabla", "patin"):
                    # Los clavos están simétricos: espejar en u los deja sobre los travesaños.
                    gx = 1 - fx if espejo_u else fx
                    gy = 1 - fy if espejo_v else fy
                    if abs(normal.z) > 0.9:
                        u = gx * ancho_u
                        v = v_de(tira, MARGEN_V + gy * ALTO_UTIL_V) if tipo == "patin" else v_de(tira, gy * ALTO_TIRA)
                    elif abs(normal.y) > 0.9:
                        u = gx * ancho_u
                        v = v_de(tira, FILAS_DE_CANTO[0] + fz * (FILAS_DE_CANTO[1] - FILAS_DE_CANTO[0]))
                    else:
                        u = ancho_u + fz * (1 - ancho_u)
                        v = v_de(tira, gy * ALTO_TIRA if tipo == "tabla" else MARGEN_V + gy * ALTO_UTIL_V)
                elif tipo == "travesano":
                    a, b = TRAMO_TRAVESANO
                    if abs(normal.z) > 0.9:
                        u = a + fy * (b - a)
                        v = v_de(tira, MARGEN_V + fx * ALTO_UTIL_V)
                    elif abs(normal.x) > 0.9:
                        u = a + fy * (b - a)
                        v = v_de(tira, FILAS_DE_CANTO[0] + fz * (FILAS_DE_CANTO[1] - FILAS_DE_CANTO[0]))
                    else:
                        u = ancho_u + fz * (1 - ancho_u)
                        v = v_de(tira, MARGEN_V + fx * ALTO_UTIL_V)
                else:  # taco
                    a, b = TRAMO_TACO
                    if abs(normal.z) > 0.9:
                        u, v = a + fx * (b - a), v_de(tira, MARGEN_V + fy * ALTO_UTIL_V)
                    elif abs(normal.y) > 0.9:
                        u, v = a + fx * (b - a), v_de(tira, MARGEN_V + fz * 25)
                    else:
                        u, v = a + fy * (b - a), v_de(tira, MARGEN_V + fz * 25)
                capa[lazo].uv = (u, v)
    return cuenta


def enlazar_imagen(ruta: Path, relativa: bool):
    import bpy  # type: ignore[import-not-found]

    material = bpy.data.materials[MATERIAL]
    nodos = material.node_tree.nodes
    nodo = next(n for n in nodos if n.type == "TEX_IMAGE")
    for imagen in list(bpy.data.images):
        if imagen.filepath and Path(bpy.path.abspath(imagen.filepath)).name == ruta.name:
            bpy.data.images.remove(imagen)
    imagen = bpy.data.images.load(str(ruta), check_existing=False)
    if relativa:
        imagen.filepath = "//../source/textures/warehouse/final/" + ruta.name
    imagen.colorspace_settings.name = "sRGB"
    nodo.image = imagen
    nodo.interpolation = "Closest"
    return imagen


def main() -> None:
    import bpy  # type: ignore[import-not-found]

    from detalle_de_plastico import escribir_png
    from lib.consola import configurar

    configurar()
    aplicar = "--aplicar" in sys.argv
    destino = DESTINO if aplicar else PRUEBA
    destino.parent.mkdir(parents=True, exist_ok=True)
    escribir_png(pintar(), destino)
    enlazar_imagen(destino, relativa=aplicar)
    objetos = sorted((o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith(PREFIJO)),
                     key=lambda o: o.name)
    previas: list = []
    for indice, objeto in enumerate(objetos):
        # Un pallet con malla compartida recibe su copia: así su UV es suya.
        if objeto.data.users > 1:
            objeto.data = objeto.data.copy()
            objeto.data.name = "Pallet " + objeto.name.removeprefix(PREFIJO)
        malla = objeto.data
        print(objeto.name, reasignar_uv(malla, indice, previas), "malla:", malla.name, "usuarios:", malla.users)
        malla.update()
    print("imagen:", destino)
    if aplicar:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
