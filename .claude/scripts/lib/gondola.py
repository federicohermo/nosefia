"""Cómo se llena un estante: cuántas unidades de cada producto entran, dónde va cada una, y cómo
se escribe eso para Godot.

Es la mitad del acomodador que no necesita Blender. La otra mitad —medir los estantes del
`.blend`, achicarlos y poner las copias— vive en `blender/acomodar.py`, y la que lee el `.blend`
para escribir la disposición en `blender/disponer.py`. Todo lo que decide está acá, donde la
suite del harness lo puede ejercer: adentro de Blender corre otro Python y nada se puede importar
desde un test.

## El estante, en sus propias coordenadas

Un estante se describe con tres ejes: `u` a lo largo, de izquierda a derecha para quien lo mira
desde el pasillo; `v` hacia adentro, desde el frente útil —detrás del labio— hasta el fondo; y la
normal de la chapa. Acá sólo importan `u` y `v`: dónde queda la chapa en el mundo lo sabe Blender.

## Dos filas, y el estante del tamaño de las dos

Cada tanda tiene dos filas, una detrás de la otra. La de adelante toca el frente útil y la de
atrás va pegada a ella, con el mismo aire que separa dos unidades vecinas. El estante se achica
hasta la profundidad de dos unidades del producto más profundo que lleva: más hondo queda un
hueco detrás de la fila de atrás, que desde el pasillo se lee como mercadería que falta.
"""

from __future__ import annotations

import math
import re
import unicodedata
from collections.abc import Sequence
from dataclasses import dataclass

#: El aire entre dos unidades vecinas, a lo largo del estante y entre las dos filas, en metros.
#: Sin aire, dos cajas que se tocan titilan donde se superponen sus caras. Con 6 mm, la
#: bandeja de la heladera —1,083 m— daba cinco latas de Coracola de frente y no seis: la
#: sexta no entraba por 3 mm. Medido el 2026-09-29.
AIRE = 0.004

#: Lo que queda libre detrás del labio y delante del panel del fondo, en metros. Es lo que evita
#: que una unidad pise el labio de la bandeja —medido el 2026-09-21: una fila de Malbardo
#: quedaba montada sobre él— o se meta en el panel.
MARGEN = 0.004

#: Lo que sobra de un estante por menos que esto se reparte entre los dos bordes. Dejarlo todo de
#: un lado hace que la tanda sobresalga de ese lado, que es donde se ve.
SOBRANTE_TOLERADO = 0.05

#: Los decimales con que se escribe una posición en un `.tscn`, que es lo que hace el editor.
DECIMALES_DE_ESCENA = 6


@dataclass(frozen=True)
class Envase:
    """Lo que ocupa una unidad parada de frente al pasillo, en metros."""

    ancho: float
    fondo: float
    alto: float


@dataclass(frozen=True)
class Lugar:
    """Una unidad de una tanda: en qué fila y columna está, y su centro en el estante."""

    fila: str
    columna: int
    u: float
    v: float


def paso(envase: Envase) -> float:
    """Lo que ocupa una columna a lo largo del estante, con el aire que la separa de la próxima."""
    return envase.ancho + AIRE


def fondo_del_estante(envases: Sequence[Envase]) -> float:
    """La profundidad útil que necesita un estante para dos filas de su producto más profundo."""
    if not envases:
        raise ValueError("un estante sin productos no tiene fondo")
    return 2 * MARGEN + 2 * max(e.fondo for e in envases) + AIRE


def ancho_de_la_tanda(envase: Envase, columnas: int) -> float:
    """Lo que ocupa una tanda a lo largo, sin el aire que la separaría de la siguiente."""
    return columnas * paso(envase) - AIRE


def columnas_que_entran(envase: Envase, largo: float) -> int:
    """Cuántas columnas de ese envase entran solas en un estante de ese largo."""
    return max(0, math.floor((largo + AIRE) / paso(envase) + 1e-9))


def repartir(largo: float, envases: Sequence[Envase], minimos: Sequence[int]) -> list[int]:
    """Cuántas columnas lleva cada tanda de un estante, de izquierda a derecha.

    Cada tanda arranca con su mínimo, y el estante se llena de punta a punta agregando una
    columna por vez a la tanda **más angosta** que todavía entre: así las tandas de un mismo
    estante terminan de anchos parecidos, y no una enorme al lado de una de dos unidades.

    Lo que no alcanza ni para una columna más queda como sobrante, y lo reparte `centros()`.
    Si los mínimos no entran, es un error del reparto y no algo que se acomode en silencio.
    """
    if len(envases) != len(minimos):
        raise ValueError("un mínimo por tanda")
    cuentas = list(minimos)
    if _ocupado(envases, cuentas) > largo + 1e-9:
        raise ValueError(
            f"los mínimos ocupan {_ocupado(envases, cuentas):.3f} m y el estante mide {largo:.3f}"
        )
    while True:
        candidatas = [
            i
            for i in range(len(envases))
            if _ocupado(envases, [c + (j == i) for j, c in enumerate(cuentas)]) <= largo + 1e-9
        ]
        if not candidatas:
            return cuentas
        angosta = min(candidatas, key=lambda i: (cuentas[i] * paso(envases[i]), i))
        cuentas[angosta] += 1


def rebajar(largo: float, envases: Sequence[Envase], pedidos: Sequence[int]) -> list[int]:
    """Los mínimos que de verdad entran: se le saca una columna por vez a la tanda más ancha.

    Es lo que pasa cuando un producto pide más fila de adelante de la que el estante da: un
    paquete de treinta centímetros no llena ocho columnas en una cabecera de un metro setenta.
    Ninguna tanda baja de una columna; si ni así entran, el reparto está mal y es un error.
    """
    cuentas = list(pedidos)
    while _ocupado(envases, cuentas) > largo + 1e-9:
        bajables = [i for i, c in enumerate(cuentas) if c > 1]
        if not bajables:
            raise ValueError(f"ni una columna de cada tanda entra en {largo:.3f} m")
        ancha = max(bajables, key=lambda i: (cuentas[i] * paso(envases[i]), -i))
        cuentas[ancha] -= 1
    return cuentas


def sobrante(largo: float, envases: Sequence[Envase], cuentas: Sequence[int]) -> float:
    """Lo que queda libre de un estante una vez puestas todas sus tandas."""
    return largo - _ocupado(envases, cuentas)


def centros(largo: float, envases: Sequence[Envase], cuentas: Sequence[int]) -> list[list[float]]:
    """El centro a lo largo de cada columna de cada tanda, con el sobrante repartido en los bordes.

    El sobrante va la mitad a cada lado: la mercadería queda centrada en el estante, y ningún
    borde se ve más vacío que el otro.
    """
    inicio = sobrante(largo, envases, cuentas) / 2
    salida = []
    for envase, cuenta in zip(envases, cuentas):
        salida.append([inicio + j * paso(envase) + envase.ancho / 2 for j in range(cuenta)])
        inicio += cuenta * paso(envase)
    return salida


def tanda(envase: Envase, centros_u: Sequence[float]) -> list[Lugar]:
    """Las unidades de una tanda: la fila de atrás entera y después la de adelante, cada una de
    izquierda a derecha.

    **El orden es el del dibujo.** El juego corta las copias de un bloque por el final para
    mostrar sólo lo repuesto, así que lo que va último es lo que el jugador llena: la fila de
    adelante, empezando por su izquierda.
    """
    adelante = MARGEN + envase.fondo / 2
    atras = adelante + envase.fondo + AIRE
    lugares = [Lugar("atras", j, u, atras) for j, u in enumerate(centros_u)]
    lugares += [Lugar("adelante", j, u, adelante) for j, u in enumerate(centros_u)]
    return lugares


def franja_libre(muestras: Sequence[tuple[float, float]], alto: float) -> tuple[float, float]:
    """El tramo de fondo más largo donde entra de alto lo que va en el estante.

    `muestras` son pares `(v, lo que hay libre encima de la chapa en v)`, en orden de `v`. Lo que
    corta el alto es el mueble mismo: el labio de una cabecera por delante, la tapa del panel
    por detrás en el estante de arriba, el dintel de la heladera. Una unidad parada ahí lo
    atraviesa, y desde el pasillo se ve.

    Devuelve `(desde, hasta)`: el primer y el último `v` libres del tramo. Sin ninguno libre,
    devuelve un tramo vacío en el frente.
    """
    mejor = (0.0, 0.0)
    hallado = False
    inicio = None
    for v, libre in muestras:
        if libre < alto:
            inicio = None
            continue
        if inicio is None:
            inicio = v
        if not hallado or v - inicio > mejor[1] - mejor[0]:
            mejor = (inicio, v)
            hallado = True
    return mejor


def fondo_nuevo(adelante: float, envases: Sequence[Envase], atras: float) -> float:
    """La profundidad a la que se achica un estante: sus dos filas, más lo que el mueble tapa.

    `adelante` es lo que el labio le quita al frente y `atras` lo que la tapa del panel le quita
    al fondo: ahí no entra el producto de alto, y achicar la chapa sin contarlo lo metería
    debajo de la tapa.
    """
    return adelante + fondo_del_estante(envases) + atras


def _ocupado(envases: Sequence[Envase], cuentas: Sequence[int]) -> float:
    usados = [(e, c) for e, c in zip(envases, cuentas) if c > 0]
    if not usados:
        return 0.0
    return sum(c * paso(e) for e, c in usados) - AIRE


# --- De Blender a Godot ----------------------------------------------------------------------

#: Blender es Z arriba y Godot Y arriba: un punto (x, y, z) de Blender es (x, z, -y) en Godot. Es
#: el cambio que hace el exportador de glTF con `export_yup`, así que lo que se mide en el
#: `.blend` cae exactamente sobre lo que Godot importa del `.glb`.
A_GODOT = ((1.0, 0.0, 0.0), (0.0, 0.0, 1.0), (0.0, -1.0, 0.0))

#: El cambio inverso: de Godot a Blender.
A_BLENDER = ((1.0, 0.0, 0.0), (0.0, 0.0, -1.0), (0.0, 1.0, 0.0))

Matriz = tuple[tuple[float, float, float], tuple[float, float, float], tuple[float, float, float]]
Vector = tuple[float, float, float]


def producto(a: Matriz, b: Matriz) -> Matriz:
    return tuple(
        tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3)
    )  # type: ignore[return-value]


def aplicar(a: Matriz, v: Vector) -> Vector:
    return tuple(sum(a[i][k] * v[k] for k in range(3)) for i in range(3))  # type: ignore[return-value]


def inversa(a: Matriz) -> Matriz:
    """La inversa de una 3×3 por cofactores. Las bases de acá tienen escala: no son ortonormales."""
    det = (
        a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1])
        - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0])
        + a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0])
    )
    if abs(det) < 1e-12:
        raise ValueError("la base no tiene inversa")
    cof = [
        [
            (a[(i + 1) % 3][(j + 1) % 3] * a[(i + 2) % 3][(j + 2) % 3])
            - (a[(i + 1) % 3][(j + 2) % 3] * a[(i + 2) % 3][(j + 1) % 3])
            for j in range(3)
        ]
        for i in range(3)
    ]
    return tuple(tuple(cof[j][i] / det for j in range(3)) for i in range(3))  # type: ignore[return-value]


def base_en_godot(base_blender: Matriz) -> Matriz:
    """La base de un objeto de Blender, escrita como la importa Godot."""
    return producto(producto(A_GODOT, base_blender), A_BLENDER)


def punto_en_godot(punto_blender: Vector) -> Vector:
    return aplicar(A_GODOT, punto_blender)


def copia_relativa(base_de_la_copia: Matriz, base_del_modelo: Matriz) -> Matriz:
    """La vuelta que el `MultiMesh` le aplica a una copia, en Godot.

    El puesto hornea la vuelta del modelo en la malla que dibuja, así que cada copia lleva sólo
    lo que la diferencia de él: `base_de_la_copia · base_del_modelo⁻¹`. Una copia enlazada con la
    misma vuelta que el modelo da la identidad.
    """
    return producto(base_de_la_copia, inversa(base_del_modelo))


def flotantes_de_la_copia(base: Matriz, origen: Vector) -> list[float]:
    """Una copia como la espera el `buffer` de un `MultiMesh`: tres filas de cuatro."""
    return [
        base[0][0], base[0][1], base[0][2], origen[0],
        base[1][0], base[1][1], base[1][2], origen[1],
        base[2][0], base[2][1], base[2][2], origen[2],
    ]  # fmt: skip


# --- La escritura ----------------------------------------------------------------------------


def numero_de_recurso(valor: float) -> str:
    """Un flotante de un `PackedFloat32Array` con seis cifras significativas, como Godot.

    El ruido de punto flotante —un `2.4e-17` donde tenía que haber cero— se escribe cero: no
    cambia nada en el juego y ensucia cada diff del recurso.
    """
    if abs(valor) < 5e-7:
        return "0"
    texto = f"{valor:.6g}"
    return "0" if texto in ("-0", "0") else texto


def numero_de_escena(valor: float) -> str:
    """Un flotante de un `.tscn`: seis decimales, sin ceros de más."""
    texto = f"{valor:.{DECIMALES_DE_ESCENA}f}".rstrip("0").rstrip(".")
    return "0" if texto in ("-0", "") else texto


def transform_de_escena(base: Matriz, origen: Vector) -> str:
    """Un `Transform3D` como lo escribe Godot: la base por filas y después el origen."""
    numeros = [base[i][j] for i in range(3) for j in range(3)] + list(origen)
    return "Transform3D(" + ", ".join(numero_de_escena(n) for n in numeros) + ")"


def slug(nombre: str) -> str:
    """El nombre de archivo de un producto: minúsculas, sin acentos y con guion bajo.

    La misma regla vive en `assets/models/extraer_mallas.gd`, que es quien escribe la malla: si
    difieren, la escena apunta a un archivo que nadie escribió.
    """
    sin_acentos = unicodedata.normalize("NFKD", nombre).encode("ascii", "ignore").decode()
    return "_".join(sin_acentos.lower().split())


def ruta_de_la_malla(nombre: str) -> str:
    return f"res://assets/models/producto_{slug(nombre)}.res"


#: Los sufijos que el importador de Godot lee del nombre de un objeto y le saca al nodo: `-col`
#: arma un cuerpo con la malla, `-convcol` uno convexo. `-noimp` no llega a importarse.
SUFIJOS_DE_IMPORTACION = ("-convcol", "-col")


def nombre_en_godot(nombre_en_blender: str) -> str:
    """Cómo se llama en la escena importada el nodo de un objeto del `.blend`.

    El importador saca el sufijo aunque lo siga el número que Blender agrega al duplicar
    —`snackpapas1-convcol.003` es `snackpapas1_003`—, y el punto, que Godot no admite en un
    nombre de nodo, pasa a guion bajo.
    """
    nombre = nombre_en_blender
    for sufijo in SUFIJOS_DE_IMPORTACION:
        indice = nombre.find(sufijo)
        if indice >= 0:
            nombre = nombre[:indice] + nombre[indice + len(sufijo) :]
            break
    return nombre.replace(".", "_")


def escribir_disposicion(
    principales: Sequence[Sequence[float]],
    guias: Sequence[Sequence[float]],
    filas_de_adelante: Sequence[int],
    uid: str,
    uid_del_script: str,
) -> str:
    """El texto de la disposición, siempre igual para los mismos datos: el diff lo lee alguien."""

    def arreglo(bloques: Sequence[Sequence[float]]) -> str:
        cuerpos = [
            "PackedFloat32Array(" + ", ".join(numero_de_recurso(n) for n in b) + ")"
            for b in bloques
        ]
        return "Array[PackedFloat32Array]([" + ", ".join(cuerpos) + "])"

    return (
        f'[gd_resource type="Resource" script_class="DisposicionDeLaGondola" format=3'
        f' uid="{uid}"]\n\n'
        f'[ext_resource type="Script" uid="{uid_del_script}"'
        ' path="res://src/escenas/puestos/disposicion_de_la_gondola.gd" id="script"]\n\n'
        "[resource]\n"
        'script = ExtResource("script")\n'
        f"principales = {arreglo(principales)}\n"
        f"guias = {arreglo(guias)}\n"
        "filas_de_adelante = PackedInt32Array("
        + ", ".join(str(n) for n in filas_de_adelante)
        + ")\n"
    )


@dataclass(frozen=True)
class NodoDeMalla:
    """Un hijo de las escenas del estante: una malla oculta con la vuelta de su modelo."""

    nombre: str
    malla: str
    base: Matriz
    origen: Vector


def escribir_escena_de_mallas(raiz: str, nodos: Sequence[NodoDeMalla]) -> str:
    """El texto de una escena con un `MeshInstance3D` oculto por nodo, en el orden dado.

    Las mallas repetidas comparten un único `ext_resource`: la escena de las guías nombra muchas
    veces la misma malla, y un recurso por nodo la cargaría una vez por cada uno.
    """
    rutas: list[str] = []
    for nodo in nodos:
        if nodo.malla not in rutas:
            rutas.append(nodo.malla)
    lineas = ["[gd_scene format=3]", ""]
    for i, ruta in enumerate(rutas):
        lineas.append(f'[ext_resource type="ArrayMesh" path="{ruta}" id="malla{i}"]')
    if rutas:
        lineas.append("")
    lineas.append(f'[node name="{raiz}" type="Node3D"]')
    for nodo in nodos:
        lineas += [
            "",
            f'[node name="{nodo.nombre}" type="MeshInstance3D" parent="."]',
            f"transform = {transform_de_escena(nodo.base, nodo.origen)}",
            "visible = false",
            f'mesh = ExtResource("malla{rutas.index(nodo.malla)}")',
            "gi_mode = 2",
        ]
    return "\n".join(lineas) + "\n"


_CABECERA = re.compile(
    r"^\[(?:gd_scene|gd_resource|ext_resource|sub_resource|resource|node|connection|editable)\b",
    re.MULTILINE,
)
_NODO_APAGADO = re.compile(r'\[node name="([^"]+)" parent="([^"]+)"\]\nvisible = false\n*\Z')


def _cuerpo_apagado(ruta: str) -> str:
    return f'[node name="StaticBody3D" parent="{ruta}"]\ncollision_layer = 0\ncollision_mask = 0'


def _unidad_apagada(ruta: str) -> str:
    padre, _, nombre = ruta.rpartition("/")
    return (
        f'[node name="{nombre}" parent="{padre or "."}"]\nvisible = false\n\n'
        f"{_cuerpo_apagado(ruta)}\n\n"
    )


def apagar_las_unidades(texto: str, rutas: Sequence[str]) -> str:
    """La escena de la estructura con la unidad horneada de cada producto apagada.

    El `.glb` trae una unidad de cada producto, y la escena la apaga: la dibuja el `MultiMesh` de
    su tanda. Una unidad apagada son dos bloques exactos —el nodo sin `visible` y su cuerpo sin
    capa—, y sólo esos se reemplazan: un nodo apagado con otra propiedad no es una unidad. Las
    nuevas van donde estaba la primera vieja, en orden, y así la segunda corrida no cambia nada.
    Cada ruta es la del nodo adentro del modelo, con `/` entre el mueble y la unidad.
    """
    inicios = [m.start() for m in _CABECERA.finditer(texto)]
    secciones = [texto[a:b] for a, b in zip(inicios, inicios[1:] + [len(texto)])]
    salida = [texto[: inicios[0]]] if inicios else [texto]
    lugar = None
    i = 0
    while i < len(secciones):
        apagado = _NODO_APAGADO.match(secciones[i])
        if apagado is not None and i + 1 < len(secciones):
            nombre, padre = apagado.groups()
            ruta = nombre if padre == "." else f"{padre}/{nombre}"
            if secciones[i + 1].rstrip("\n") == _cuerpo_apagado(ruta):
                lugar = len(salida) if lugar is None else lugar
                i += 2
                continue
        salida.append(secciones[i])
        i += 1
    if lugar is None:
        raise ValueError("la escena no tiene unidades apagadas: no se sabe dónde van las nuevas")
    salida.insert(lugar, "".join(_unidad_apagada(r) for r in sorted(set(rutas))))
    return "".join(salida).rstrip("\n") + "\n"
