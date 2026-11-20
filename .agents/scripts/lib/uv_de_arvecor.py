"""Reglas geométricas para la etiqueta y el cuello metálico de la lata de Arvecor.

Vive en `lib/` sin importar `bpy` para que la suite del harness ejerza la lógica de partición y
continuidad UV sin levantar Blender.
"""

from dataclasses import dataclass
import math

Punto = tuple[float, float, float]
Uv = tuple[float, float]


@dataclass(frozen=True)
class Cara:
    """Una cara poligonal con sus índices de vértice y su UV por esquina."""

    indice: int
    vertices: tuple[int, ...]
    uvs: tuple[Uv, ...]


def centro_xy(vertices: list[Punto]) -> tuple[float, float]:
    """El eje del envase en el plano horizontal."""
    if not vertices:
        raise ValueError("la malla no tiene vértices")
    total = float(len(vertices))
    return (
        sum(p[0] for p in vertices) / total,
        sum(p[1] for p in vertices) / total,
    )


def radio_exterior(vertices: list[Punto], centro: tuple[float, float]) -> float:
    """El mayor radio horizontal del envase alrededor de `centro`."""
    cx, cy = centro
    return max(math.hypot(p[0] - cx, p[1] - cy) for p in vertices)


def es_cara_del_cuerpo_cilindrico(
    vertices: list[Punto],
    indices: tuple[int, ...],
    radio_maximo: float,
    centro: tuple[float, float] = (0.0, 0.0),
    tolerancia_radio: float = 0.002,
    tolerancia_z: float = 0.0005,
) -> bool:
    """Si una cara pertenece a la pared vertical exterior donde va la etiqueta.

    Las caras planas (tapas) tienen altura nula y las del bisel, el hombro o el cuello tienen al
    menos un vértice por dentro del radio exterior.
    """
    if len(indices) != 4:
        return False
    zs = [vertices[i][2] for i in indices]
    if max(zs) - min(zs) <= tolerancia_z:
        return False
    cx, cy = centro
    return all(
        abs(math.hypot(vertices[i][0] - cx, vertices[i][1] - cy) - radio_maximo)
        <= tolerancia_radio
        for i in indices
    )


def _separar_abajo_y_arriba(
    vertices: list[Punto], indices: tuple[int, ...]
) -> tuple[list[int], list[int]]:
    if len(indices) != 4:
        raise ValueError(f"se esperaba un cuadrilátero y llegaron {len(indices)} vértices")
    ordenados = sorted(indices, key=lambda i: vertices[i][2])
    return ordenados[:2], ordenados[2:]


def _vertice_debajo(vertices: list[Punto], superior: int, inferiores: list[int]) -> int:
    sx, sy, _ = vertices[superior]
    return min(
        inferiores,
        key=lambda i: (vertices[i][0] - sx) ** 2 + (vertices[i][1] - sy) ** 2,
    )


def alinear_banda_superior(
    vertices: list[Punto],
    inferiores: list[Cara],
    superiores: list[Cara],
    v_superior: float,
) -> list[Cara]:
    """Continúa las UV de la banda superior del cuerpo exactamente desde la banda inferior.

    Cada cara superior comparte su arista horizontal baja con una cara de la banda inferior.
    Copiar `u` y `v` desde esa arista elimina cortes horizontales y caras desplazadas.
    """
    por_arista: dict[frozenset[int], dict[int, Uv]] = {}
    for cara in inferiores:
        _, altos = _separar_abajo_y_arriba(vertices, cara.vertices)
        por_arista[frozenset(altos)] = dict(zip(cara.vertices, cara.uvs))

    resultado: list[Cara] = []
    for cara in superiores:
        bajos, _ = _separar_abajo_y_arriba(vertices, cara.vertices)
        uv_inferior = por_arista.get(frozenset(bajos))
        if uv_inferior is None:
            raise ValueError(
                f"la cara {cara.indice} no comparte arista superior con la banda inferior"
            )
        nuevas: list[Uv] = []
        for indice in cara.vertices:
            if indice in uv_inferior:
                nuevas.append(uv_inferior[indice])
            else:
                debajo = _vertice_debajo(vertices, indice, bajos)
                nuevas.append((uv_inferior[debajo][0], v_superior))
        resultado.append(Cara(cara.indice, cara.vertices, tuple(nuevas)))
    return resultado


def corregir_franja_metalica(
    vertices: list[Punto],
    hombro: list[Cara],
    cuello: list[Cara],
    u_rango: tuple[float, float],
    v_rango: tuple[float, float],
) -> tuple[list[Cara], list[Cara]]:
    """Mantiene el hombro dentro de la franja plateada y despliega el cuello sobre ella.

    En el modelo original el cuello colapsaba sus cuatro esquinas sobre el borde circular de la
    tapa, cayendo en el fondo negro de la textura.
    """
    u_min, u_max = u_rango
    v_min, v_max = v_rango
    if u_min >= u_max or v_min >= v_max:
        raise ValueError("los rangos de la franja metálica deben ser crecientes")

    hombro_corregido: list[Cara] = []
    por_arista: dict[frozenset[int], dict[int, float]] = {}
    for cara in hombro:
        uvs = tuple((min(u_max, max(u_min, u)), v) for u, v in cara.uvs)
        ajustada = Cara(cara.indice, cara.vertices, uvs)
        hombro_corregido.append(ajustada)
        _, altos = _separar_abajo_y_arriba(vertices, cara.vertices)
        por_arista[frozenset(altos)] = {
            vertice: uv[0] for vertice, uv in zip(cara.vertices, uvs)
        }

    cuello_corregido: list[Cara] = []
    for cara in cuello:
        bajos, _ = _separar_abajo_y_arriba(vertices, cara.vertices)
        u_inferior = por_arista.get(frozenset(bajos))
        if u_inferior is None:
            raise ValueError(
                f"la cara {cara.indice} del cuello no comparte arista con el hombro"
            )
        nuevas: list[Uv] = []
        for indice in cara.vertices:
            if indice in u_inferior:
                nuevas.append((u_inferior[indice], v_min))
            else:
                debajo = _vertice_debajo(vertices, indice, bajos)
                nuevas.append((u_inferior[debajo], v_max))
        cuello_corregido.append(Cara(cara.indice, cara.vertices, tuple(nuevas)))
    return hombro_corregido, cuello_corregido
