"""Cómo se llena un estante: cuántas unidades de cada producto entran, dónde va cada una, y cómo
se escribe eso para Godot.

Es la mitad del acomodador que no necesita Blender. La otra mitad —medir los estantes del
`.blend`, contrastar sus mallas y poner las copias— vive en `blender/acomodar.py`, y la que lee el `.blend`
para escribir la disposición en `blender/disponer.py`. Todo lo que decide está acá, donde la
suite del harness lo puede ejercer: adentro de Blender corre otro Python y nada se puede importar
desde un test.

## El estante, en sus propias coordenadas

Un estante se describe con tres ejes: `u` a lo largo, de izquierda a derecha para quien lo mira
desde el pasillo; `v` hacia adentro, desde el frente útil —detrás del labio— hasta el fondo; y la
normal de la chapa. Acá sólo importan `u` y `v`: dónde queda la chapa en el mundo lo sabe Blender.

## Dos filas, o una según el reparto aprobado

En una tanda de dos filas, una queda detrás de la otra. La de adelante toca el frente útil y la de
atrás va pegada a ella, con `AIRE` de por medio. Las chapas conservan
su geometría. El acomodador mide el apoyo y las intersecciones de las unidades para ubicar la
tanda sobre ellas sin cambiar la separación de sus filas.

Los productos declarados de una fila llevan sólo la de adelante. Una tanda reponible que no
entra con las filas declaradas falla; el acomodador no reduce sus filas ni agranda el mueble.

## Mitad y mitad, o el estante entero

Dos tandas se reparten el estante en partes iguales, y cada una llena la suya. Una tanda sola lo
ocupa de punta a punta.

## En la rampa de una cabecera, la unidad se apoya de plano

La chapa de una cabecera baja hacia el pasillo, y la unidad se apoya entera sobre ella, como en
un estante plano. Echada hacia atrás tocaba la chapa sólo con su canto de atrás, y una caja honda
flotaba adelante hasta 4 cm.
"""

from __future__ import annotations

import math
import re
import unicodedata
from collections.abc import Callable, Sequence
from dataclasses import dataclass

#: El aire mínimo entre las dos filas de una tanda, en metros. Con 4 mm se leían como un solo
#: bloque.
AIRE = 0.02

#: Hasta dónde crece ese aire si el estante tiene fondo de sobra, en metros. Más atrás, la fila
#: de atrás queda en la sombra del panel y se lee como un hueco.
AIRE_MAXIMO = 0.05

#: El hueco mínimo del reparto completo, en metros. Decide cuántas columnas entran.
#: La prueba conserva esos cupos y puede comprimir la separación para mantener los márgenes.
HUECO_MINIMO = 0.01

#: Lo que queda libre detrás del labio y delante del panel del fondo, en metros. Es lo que evita
#: que una unidad pise el labio de la bandeja —medido el 2026-09-21: una fila de Malbardo
#: quedaba montada sobre él— o se meta en el panel.
MARGEN = 0.004

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


def desplazamiento_que_entra(
    desde: float, hasta: float, paso_medido: float, entra: Callable[[float], bool]
) -> float | None:
    """La traslación más cercana a la original con apoyo y sin intersecciones medidos.

    El intervalo viene de los contactos de todas las unidades con la chapa física; `entra`
    contrasta sus mallas con los obstáculos. Se prueban los extremos exactos y el paso vigente,
    sin convertir el margen entre envases y labio en una exigencia nueva sobre sus apoyos.
    """
    if not all(math.isfinite(n) for n in (desde, hasta, paso_medido)) or paso_medido <= 0:
        raise ValueError("el intervalo de apoyo debe ser finito y el paso positivo")
    if desde > hasta:
        return None
    candidatos = {desde, hasta}
    if desde <= 0 <= hasta:
        candidatos.add(0.0)
    candidatos.update(i * paso_medido for i in range(
        math.ceil(desde / paso_medido), math.floor(hasta / paso_medido) + 1
    ))
    for candidato in sorted(candidatos, key=lambda v: (abs(v), v)):
        if entra(candidato):
            return candidato
    return None


def paso(envase: Envase) -> float:
    """Lo que ocupa una columna a lo largo del estante, con el aire que la separa de la próxima."""
    return envase.ancho + HUECO_MINIMO


def alinear_frentes(fondos: Sequence[float], requeridos: Sequence[float]) -> list[float]:
    """Alinea también el zócalo sin perder las tandas que necesitan más fondo."""
    frente = max(f + r for f, r in zip(fondos, requeridos))
    return [frente - fondo for fondo in fondos]


def fondo_del_estante(envases: Sequence[Envase], filas: Sequence[int] | None = None) -> float:
    """La profundidad útil que necesita un estante para su tanda más honda.

    `filas` dice cuántas filas tiene la tanda de cada envase; sin ella, todas tienen dos.
    """
    if not envases:
        raise ValueError("un estante sin productos no tiene fondo")
    return 2 * MARGEN + max(
        (n - 1) * (e.fondo + AIRE) + e.fondo
        for e, n in zip(envases, filas or [2] * len(envases))
    )


def ancho_de_la_tanda(envase: Envase, columnas: int) -> float:
    """Lo que ocupa una tanda a lo largo, sin el aire que la separaría de la siguiente."""
    return columnas * paso(envase) - HUECO_MINIMO


def columnas_que_entran(envase: Envase, largo: float) -> int:
    """Cuántas columnas de ese envase entran solas en un estante de ese largo."""
    return max(0, math.floor((largo + HUECO_MINIMO) / paso(envase) + 1e-9))


def repartir(largo: float, envases: Sequence[Envase]) -> list[int]:
    """Cuántas columnas lleva cada tanda de un estante, de izquierda a derecha.

    El estante se parte en tantas partes iguales como tandas lleva, y cada tanda llena la suya:
    dos tandas ocupan una mitad cada una, y sus largos difieren en menos de una unidad de la más
    ancha. Una tanda sola ocupa el estante de punta a punta.

    Lo que no alcanza ni para una columna más queda como sobrante, y lo reparte `centros()`.
    Una tanda que no entra en su parte es un error del reparto y no algo que se acomode en
    silencio.
    """
    parte = (largo - (len(envases) - 1) * HUECO_MINIMO) / len(envases)
    cuentas = [columnas_que_entran(envase, parte) for envase in envases]
    if 0 in cuentas:
        raise ValueError(f"una tanda no entra en su parte del estante, de {parte:.3f} m")
    return cuentas


def sobrante(largo: float, envases: Sequence[Envase], cuentas: Sequence[int]) -> float:
    """Lo que queda libre de un estante una vez puestas todas sus tandas."""
    return largo - _ocupado(envases, cuentas)


def centros(largo: float, envases: Sequence[Envase], cuentas: Sequence[int]) -> list[list[float]]:
    """El centro a lo largo de cada columna de cada tanda, de punta a punta del estante.

    Todos los huecos del estante miden lo mismo, también el que separa dos tandas: lo que sobra
    se reparte entre ellos, y ningún borde queda vacío. Una unidad sola va al medio.
    """
    libre = sobrante(largo, envases, cuentas)
    if libre < -1e-9:
        raise ValueError("las columnas no entran conservando el hueco mínimo")
    unidades = sum(cuentas)
    if unidades == 1:
        return [[largo / 2] if cuenta else [] for cuenta in cuentas]
    hueco = HUECO_MINIMO + libre / (unidades - 1)
    inicio = 0.0
    salida = []
    for envase, cuenta in zip(envases, cuentas):
        salida.append([inicio + j * (envase.ancho + hueco) + envase.ancho / 2 for j in range(cuenta)])
        inicio += cuenta * (envase.ancho + hueco)
    return salida


def tanda(
    envase: Envase, centros_u: Sequence[float], filas: int = 2, fondo: float = 0.0
) -> list[Lugar]:
    """Las unidades de una tanda: la fila de atrás entera y después la de adelante, cada una de
    izquierda a derecha. Una tanda de una sola fila es toda de adelante.

    `fondo` es la profundidad libre del estante: lo que sobra detrás de las dos filas separa la
    de atrás, entre `AIRE` y `AIRE_MAXIMO`.

    **El orden es el del dibujo.** El juego corta las copias de un bloque por el final para
    mostrar sólo lo repuesto, así que lo que va último es lo que el jugador llena: la fila de
    adelante, empezando por su izquierda.
    """
    adelante = MARGEN + envase.fondo / 2
    aire = min(max(fondo - 2 * MARGEN - 2 * envase.fondo, AIRE), AIRE_MAXIMO)
    atras = adelante + envase.fondo + aire
    lugares = [Lugar("atras", j, u, atras) for j, u in enumerate(centros_u)] if filas == 2 else []
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


def fondo_nuevo(
    adelante: float,
    envases: Sequence[Envase],
    atras: float,
    filas: Sequence[int] | None = None,
) -> float:
    """La profundidad a la que se achica un estante: su tanda más honda, más lo que el mueble tapa.

    `adelante` es lo que el labio le quita al frente y `atras` lo que la tapa del panel le quita
    al fondo: ahí no entra el producto de alto, y achicar la chapa sin contarlo lo metería
    debajo de la tapa.
    """
    return adelante + fondo_del_estante(envases, filas) + atras


def _ocupado(envases: Sequence[Envase], cuentas: Sequence[int]) -> float:
    usados = [(e, c) for e, c in zip(envases, cuentas) if c > 0]
    if not usados:
        return 0.0
    return sum(c * paso(e) for e, c in usados) - HUECO_MINIMO


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

    La usa la generación de escenas para conservar las rutas de los recursos de producto.
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
    productos_de_las_guias: Sequence[int] = (),
    filas_de_adelante_de_las_guias: Sequence[int] = (),
) -> str:
    """El texto de la disposición, siempre igual para los mismos datos: el diff lo lee alguien."""

    def enteros(numeros: Sequence[int]) -> str:
        return "PackedInt32Array(" + ", ".join(str(n) for n in numeros) + ")"

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
        f"filas_de_adelante = {enteros(filas_de_adelante)}\n"
        f"productos_de_las_guias = {enteros(productos_de_las_guias)}\n"
        f"filas_de_adelante_de_las_guias = {enteros(filas_de_adelante_de_las_guias)}\n"
    )


def ordenar_copias_por_frente(bloque: list[float], frente: Vector) -> list[float]:
    """El orden lógico sigue las filas y sus columnas aunque el artista cambie sus rótulos.

    El juego infiere el frente de una fila única por el sentido de sus columnas. Ordenar por
    los números heredados de Blender puede invertirlo sin mover una sola unidad visible.
    """
    copias = [bloque[i:i + 12] for i in range(0, len(bloque), 12)]
    lateral = (frente[2], 0.0, -frente[0])

    def orden(copia: list[float]) -> tuple[float, float]:
        origen = (copia[3], copia[7], copia[11])
        fondo = sum(a * b for a, b in zip(origen, frente))
        columna = sum(a * b for a, b in zip(origen, lateral))
        # La escritura de matrices conserva pequeños errores entre copias de la misma fila.
        return round(fondo, 4), columna

    return [valor for copia in sorted(copias, key=orden) for valor in copia]


def separar_filas(filas: list[str]) -> tuple[list[int], int]:
    """El orden de una tanda fija para el juego, y cuántas copias tiene su fila de adelante.

    Va la fila de atrás primero y la de adelante al final, igual que una tanda reponible: el juego
    corta las copias por el final, y lo que se repone es la fila de adelante.
    """
    atras = [i for i, fila in enumerate(filas) if fila != "adelante"]
    frente = [i for i, fila in enumerate(filas) if fila == "adelante"]
    return atras + frente, len(frente)


@dataclass(frozen=True)
class NodoDeMalla:
    """Un hijo de las escenas del estante: una malla oculta con la vuelta de su modelo."""

    nombre: str
    malla: str
    base: Matriz
    origen: Vector
    frente: Vector | None = None
    producto_id: int | None = None


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
        if nodo.frente is not None:
            lineas.append("metadata/frente_del_modelo = Vector3("
                          + ", ".join(numero_de_escena(v) for v in nodo.frente) + ")")
        if nodo.producto_id is not None:
            lineas.append(f"metadata/producto_id = {nodo.producto_id}")
    return "\n".join(lineas) + "\n"


_CABECERA = re.compile(
    r"^\[(?:gd_scene|gd_resource|ext_resource|sub_resource|resource|node|connection|editable)\b",
    re.MULTILINE,
)
_NODO_APAGADO = re.compile(
    r'\[node name="([^"]+)" parent="([^"]+)"'
    r'( groups=\["geometria_de_referencia"\])?\]\nvisible = false\n*\Z'
)


def _cuerpo_apagado(ruta: str) -> str:
    return f'[node name="StaticBody3D" parent="{ruta}"]\ncollision_layer = 0\ncollision_mask = 0'


def _unidad_apagada(ruta: str, referencia: bool = False) -> str:
    padre, _, nombre = ruta.rpartition("/")
    grupo = ' groups=["geometria_de_referencia"]' if referencia else ""
    return (
        f'[node name="{nombre}" parent="{padre or "."}"{grupo}]\nvisible = false\n\n'
        f"{_cuerpo_apagado(ruta)}\n\n"
    )


def apagar_las_unidades(
    texto: str, rutas: Sequence[str], identidades: Sequence[str]
) -> str:
    """La escena de la estructura con la unidad horneada de cada producto apagada.

    El `.glb` trae una unidad de cada producto, y la escena la apaga: la dibuja el `MultiMesh` de
    su tanda. Una unidad apagada son dos bloques exactos —el nodo sin `visible` y su cuerpo sin
    capa—, y sólo esos se reemplazan: un nodo apagado con otra propiedad no es una unidad. Las
    nuevas van donde estaba la primera vieja, en orden, y así la segunda corrida no cambia nada.
    Cada ruta es la del nodo adentro del modelo, con `/` entre el mueble y la unidad.
    Las identidades son nombres de unidades declaradas por el llamador, independientes
    del padre y de las rutas activas. Incluso sin reemplazos se retiran esas unidades;
    un lector u otra referencia apagada conserva sus bloques aunque tenga el mismo grupo.
    """
    propias = set(identidades)
    inicios = [m.start() for m in _CABECERA.finditer(texto)]
    secciones = [texto[a:b] for a, b in zip(inicios, inicios[1:] + [len(texto)])]
    salida = [texto[: inicios[0]]] if inicios else [texto]
    lugar = None
    referencia = False
    i = 0
    while i < len(secciones):
        apagado = _NODO_APAGADO.match(secciones[i])
        if apagado is not None and i + 1 < len(secciones):
            nombre, padre, grupo = apagado.groups()
            ruta = nombre if padre == "." else f"{padre}/{nombre}"
            if nombre in propias and secciones[i + 1].rstrip("\n") == _cuerpo_apagado(ruta):
                lugar = len(salida) if lugar is None else lugar
                referencia = referencia or grupo is not None
                i += 2
                continue
        salida.append(secciones[i])
        i += 1
    if lugar is None:
        raise ValueError("la escena no tiene unidades apagadas: no se sabe dónde van las nuevas")
    salida.insert(lugar, "".join(_unidad_apagada(r, referencia) for r in sorted(set(rutas))))
    return "".join(salida).rstrip("\n") + "\n"


def separar_reserva(filas: list[str]) -> tuple[list[int], list[int]]:
    """Conserva la fila reponible y una de respaldo; las demás se dibujan como guía fija.

    El artista puede añadir profundidad sin multiplicar los casilleros ni perder las copias.
    """
    frente = [i for i, fila in enumerate(filas) if fila == "adelante"]
    atras = [i for i, fila in enumerate(filas) if fila == "atras"]
    if not frente or len(frente) + len(atras) != len(filas):
        raise ValueError("la tanda necesita una fila de adelante y filas reconocibles")
    if atras and len(atras) < len(frente):
        raise ValueError("la fila de respaldo no alcanza el largo de la fila reponible")
    return atras[:len(frente)] + frente, atras[len(frente):]


def actualizar_contorno(
    texto: str, recurso: str, padre: str, centro: Vector, tamano: Vector
) -> str:
    """Actualiza sólo la caja del jugador: las demás colisiones no cambian con la góndola."""
    tamano_escrito = ", ".join(numero_de_escena(n) for n in tamano)
    patron = (
        rf'(\[sub_resource type="BoxShape3D" id="{re.escape(recurso)}"\]\n)'
        r'size = Vector3\([^\n]*\)'
    )
    texto, formas = re.subn(patron, lambda m: m[1] + f"size = Vector3({tamano_escrito})", texto)
    identidad: Matriz = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    patron = (
        rf'(\[node name="Forma" type="CollisionShape3D" '
        rf'parent="{re.escape(padre)}/Contorno"\]\n)transform = Transform3D\([^\n]*\)'
    )
    texto, centros = re.subn(
        patron, lambda m: m[1] + "transform = " + transform_de_escena(identidad, centro), texto
    )
    if formas != 1 or centros != 1:
        raise ValueError(f"no se encontró el contorno único de {padre}: {formas}, {centros}")
    return texto
