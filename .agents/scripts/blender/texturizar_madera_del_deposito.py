"""Texturizar la madera de los pallets del depósito: tablas con tono propio, veta, nudos y uso.

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

## Qué cambia

- **Una imagen de 1024×1024 con ocho tiras**, una por tabla distinta. La veta corre a lo largo
  de la tira. Cada tira lleva su tono, sus anillos, sus poros y sus nudos.
- **Uso**, pintado en el color: canto aclarado por el roce y una junta oscura al pie, mugre más
  densa hacia las puntas, rajaduras en las puntas, manchas anchas, rayones finos a lo largo y
  clavos con su aureola de óxido sobre cada travesaño.
- **El testero** de la tabla (el corte de la punta) tiene su propia banda en el extremo derecho
  de cada tira, con anillos de crecimiento y más oscura.
- **Las UV** de las dos mallas de pallet (`Pallet estante` y `Pallet piso`) se rehacen. Cada
  tabla del tablero toma una tira distinta. La u corre de punta a punta del pallet, sea cual sea
  su largo: así los clavos caen sobre los travesaños en los dos. Estirar la veta a lo largo no
  se nota. Los patines, los travesaños y los tacos toman tiras y tramos propios, sin clavos.
- **El material** `deposito_madera_listones` apunta a la imagen nueva.

## Lo que cuesta

Ningún triángulo, ningún material ni dibujo más. La textura pasa de 128×128 a 1024×1024: el PNG
fuente pesa 735 KB y 1 MB comprimida en memoria de video. La malla es la misma: las UV no suman
vértices salvo los que parte el exportador en los cantos.

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
TIRAS = 8
ALTO_TIRA = N // TIRAS
#: Hasta dónde llega la cara de la tabla en u. De ahí al borde va el testero.
LARGO_CARA = 960
SEMILLA = 20261110
#: El color de siempre de esta madera, en sRGB: el promedio del tile de 128 px.
BASE = np.array([0.376, 0.223, 0.130], dtype=np.float32)
#: La proporción del largo del pallet donde cae el centro de cada travesaño y su clavo.
CLAVOS_U = (0.06 / 1.64, 0.5, 1 - 0.06 / 1.64)
#: Los tramos de la tira que toman los travesaños, los tacos y los cantos, sin clavos.
TRAMO_TRAVESANO = (0.08, 0.44)
TRAMO_TACO = (0.56, 0.64)
FILAS_DE_CANTO = (48, 63)
MARGEN_V = 14
ALTO_UTIL_V = 100


def _tono(azar: np.random.Generator, factor: float):
    gris = azar.uniform(0.0, 0.34)
    base = BASE * factor
    luz = base.mean()
    base = base * (1 - gris) + luz * gris
    return np.clip(base * 1.2, 0, 1), np.clip(base * 0.7, 0, 1)


def _tira(indice: int, azar: np.random.Generator, factor: float) -> np.ndarray:
    """Una tira de (ALTO_TIRA, N, 3): la cara de la tabla y su testero."""
    claro, oscuro = _tono(azar, factor)
    cara = tabla(LARGO_CARA, ALTO_TIRA, azar, claro, oscuro, nudos=int(azar.choice([0, 1, 1, 2])))
    cara = np.transpose(cara, (1, 0, 2))
    alto, largo = cara.shape[:2]
    u = np.arange(largo, dtype=np.float32)[None, :]
    v = np.arange(alto, dtype=np.float32)[:, None]

    # Mugre y desgaste: más oscuro hacia las puntas y donde se acumula la suciedad.
    puntas = np.broadcast_to(suave(120, 0, u) + suave(largo - 120, largo, u), (alto, largo))
    manchas = ruido(alto, largo, 2, 6, azar, 3)
    sucio = np.clip(0.55 * puntas + 0.9 * suave(0.55, 0.9, manchas), 0, 1)
    cara = cara * (1 - 0.34 * sucio)[..., None]

    # El canto: se gasta y aclara, con una junta oscura al pie.
    borde = np.minimum(v, alto - 1 - v)
    irregular = ruido(alto, largo, 1, 14, azar, 2)
    gastado = suave(7.0, 1.5, borde) * (0.45 + 0.9 * irregular)
    cara = cara + (np.array([0.95, 0.78, 0.55]) - cara) * (0.34 * gastado)[..., None]
    junta = suave(3.0, 0.5, borde)
    cara = cara * (1 - 0.62 * junta)[..., None]

    # Las rajaduras de las puntas, a lo largo de la veta.
    peso = np.clip(puntas, 0, 1)
    rajaduras = rayones(alto, largo, 40, 46, azar, angulo=0.0, dispersion=0.05, peso=peso)
    cara = cara * (1 - 0.7 * rajaduras)[..., None]

    # Rayones finos a lo largo, claros y oscuros, y unos cruzados más cortos.
    claros = rayones(alto, largo, 26, 170, azar, angulo=0.0, dispersion=0.06)
    oscuros = rayones(alto, largo, 18, 120, azar, angulo=0.0, dispersion=0.08)
    cruzados = rayones(alto, largo, 14, 40, azar)
    cara = cara + (np.array([0.85, 0.66, 0.46]) - cara) * (0.20 * claros)[..., None]
    cara = cara * (1 - 0.35 * np.maximum(oscuros, cruzados))[..., None]

    # Los clavos: cabeza oscura con un punto de luz y la aureola de óxido.
    yc = np.array([alto * 0.3, alto * 0.7])
    for fraccion in CLAVOS_U:
        xc = fraccion * LARGO_CARA
        for cy in yc:
            d = np.sqrt((u - xc) ** 2 + ((v - cy) * 1.15) ** 2)
            cara = cara * (1 - 0.35 * suave(9.0, 3.5, d))[..., None]
            cabeza = suave(3.4, 2.2, d)
            hierro = np.array([0.20, 0.17, 0.15]) + 0.18 * suave(1.6, 0.0, d)[..., None]
            cara = cara * (1 - cabeza)[..., None] + hierro * cabeza[..., None]

    tira = np.zeros((alto, N, 3), dtype=np.float32)
    tira[:, :LARGO_CARA] = cara

    # El testero: anillos de crecimiento a lo ancho de la tabla, más oscuro que la cara.
    ancho_t = N - LARGO_CARA
    tu = np.arange(ancho_t, dtype=np.float32)[None, :]
    tv = np.arange(alto, dtype=np.float32)[:, None]
    ondas = ruido(alto, ancho_t, 3, 2, azar, 2)
    anillos = 0.5 + 0.5 * np.sin((tu / ancho_t * 3.0 + (tv / alto - 0.5) ** 2 * 5.0 + ondas * 2) * np.pi * 2)
    testero = (oscuro * 0.82)[None, None, :] * (0.78 + 0.34 * anillos)[..., None]
    testero = testero * (1 - 0.3 * suave(0.5, 1.0, ruido(alto, ancho_t, 6, 4, azar, 2)))[..., None]
    tira[:, LARGO_CARA:] = testero
    return tira


def pintar() -> np.ndarray:
    """La imagen entera, (N, N, 3) en sRGB 0..1, con la fila 0 abajo."""
    azar = np.random.default_rng(SEMILLA)
    factores = (0.78, 1.26, 0.94, 1.38, 0.86, 1.12, 0.70, 1.04)
    tiras = [_tira(i, azar, f) for i, f in enumerate(factores)]
    imagen = np.concatenate(tiras, axis=0)
    # Un velo parejo de polvo da el aire de toda la madera.
    polvo = desenfocar(ruido(N, N, 8, 8, azar, 3), 3)
    imagen = imagen * (0.94 + 0.12 * polvo)[..., None]
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


def reasignar_uv(malla, semilla_de_tiras: int) -> dict:
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

    # Cada tabla del tablero toma una tira distinta, y las vecinas no se parecen. Los demás
    # miembros toman las tiras 5 a 7.
    for i, c in enumerate(ordenadas("tabla", lambda c: c["min"][1])):
        c["tira"] = (i * 3 + semilla_de_tiras) % 5
    for i, c in enumerate(ordenadas("patin", lambda c: c["min"][1])):
        c["tira"] = 5 + (i + semilla_de_tiras) % 3
    for i, c in enumerate(ordenadas("travesano", lambda c: c["min"][0])):
        c["tira"] = 5 + (i + 1 + semilla_de_tiras) % 3
    for i, c in enumerate(ordenadas("taco", lambda c: (c["min"][1], c["min"][0]))):
        c["tira"] = 5 + (i + 2 + semilla_de_tiras) % 3

    def v_de(tira, fila):
        return (tira * ALTO_TIRA + fila) / N

    cuenta = {"tabla": 0, "travesano": 0, "taco": 0, "patin": 0}
    for c in cajas:
        grupo, minimo, maximo, tipo, tira = c["grupo"], c["min"], c["max"], c["tipo"], c["tira"]
        cuenta[tipo] += 1
        ancho_u = LARGO_CARA / N
        for p in grupo:
            normal = p.normal
            for lazo, i in zip(p.loop_indices, p.vertices):
                x, y, z = malla.vertices[i].co
                fx, fy, fz = (_fraccion(x, minimo[0], maximo[0]), _fraccion(y, minimo[1], maximo[1]),
                              _fraccion(z, minimo[2], maximo[2]))
                if tipo in ("tabla", "patin"):
                    if abs(normal.z) > 0.9:
                        u = fx * ancho_u
                        v = v_de(tira, MARGEN_V + fy * ALTO_UTIL_V) if tipo == "patin" else v_de(tira, fy * ALTO_TIRA)
                    elif abs(normal.y) > 0.9:
                        u = fx * ancho_u
                        v = v_de(tira, FILAS_DE_CANTO[0] + fz * (FILAS_DE_CANTO[1] - FILAS_DE_CANTO[0]))
                    else:
                        u = ancho_u + fz * (1 - ancho_u)
                        v = v_de(tira, fy * ALTO_TIRA if tipo == "tabla" else MARGEN_V + fy * ALTO_UTIL_V)
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
                        u, v = a + fx * (b - a), v_de(tira, MARGEN_V + fz * 50)
                    else:
                        u, v = a + fy * (b - a), v_de(tira, MARGEN_V + fz * 50)
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
    mallas = {o.data.name: o.data for o in bpy.data.objects
              if o.type == "MESH" and o.name.startswith(PREFIJO)}
    for orden, nombre in enumerate(sorted(mallas)):
        malla = mallas[nombre]
        print(nombre, reasignar_uv(malla, 2 * orden), "usuarios:", malla.users)
        malla.update()
    print("imagen:", destino)
    if aplicar:
        bpy.ops.wm.save_mainfile()
        print("fuente guardada")


if __name__ == "__main__":
    main()
