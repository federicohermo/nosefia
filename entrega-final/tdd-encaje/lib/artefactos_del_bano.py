"""Separa piezas funcionales para evitar apoyos invisibles entre tanque y tapa."""


def componentes(cantidad_de_vertices, aristas):
    pendientes = set(range(cantidad_de_vertices))
    vecinos = {i: set() for i in pendientes}
    for a, b in aristas:
        vecinos[a].add(b)
        vecinos[b].add(a)
    while pendientes:
        encontrados = set()
        pila = [min(pendientes)]
        while pila:
            i = pila.pop()
            if i in encontrados:
                continue
            encontrados.add(i)
            pila.extend(vecinos[i] - encontrados)
        pendientes -= encontrados
        yield encontrados


def volumen_por_altura(alturas):
    if max(alturas) < .68:
        return 90  # Cuerpo, asiento y bisagras.
    if min(alturas) < .60:
        return 92  # Tanque y su tapa.
    if min(alturas) < .70:
        return 91  # Tapa levantada.
    return None  # El pulsador no levanta el plano de apoyo de todo el tanque.


def corte_horizontal(vertices, caras, altura):
    """Anillos del corte, unidos por los extremos compartidos de cada cara.

    El corte debe evitar caras horizontales coincidentes. Los extremos se cuantizan
    a una micra para unir resultados de interpolaciones hechas en orden inverso.
    """
    vecinos = {}
    for cara in caras:
        puntos = set()
        for i, indice in enumerate(cara):
            a, b = vertices[indice], vertices[cara[(i + 1) % len(cara)]]
            if (a[2] < altura) == (b[2] < altura):
                continue
            factor = (altura - a[2]) / (b[2] - a[2])
            puntos.add(tuple(round(a[j] + (b[j] - a[j]) * factor, 6) for j in (0, 1)))
        if len(puntos) == 2:
            a, b = sorted(puntos)
            vecinos.setdefault(a, set()).add(b)
            vecinos.setdefault(b, set()).add(a)
    assert all(len(contiguos) == 2 for contiguos in vecinos.values()), "corte no cerrado"
    pendientes = set(vecinos)
    anillos = []
    while pendientes:
        inicio = min(pendientes)
        actual, anterior = inicio, None
        anillo = []
        while True:
            anillo.append(actual)
            pendientes.remove(actual)
            siguiente = min(vecinos[actual] - {anterior})
            anterior, actual = actual, siguiente
            if actual == inicio:
                break
        anillos.append(anillo)
    return anillos


def area_firmada(anillo):
    return sum(a[0] * b[1] - b[0] * a[1]
               for a, b in zip(anillo, anillo[1:] + anillo[:1])) / 2


def grilla_del_fondo(borde):
    """Parche de Coons: conserva cuatro lados y reparte los quads entre ellos.

    Los cuatro lados comparten la cantidad de segmentos. El orden del borde comienza
    en una esquina y sigue su perímetro; los índices permiten reutilizar sus vértices
    en la cubeta, sin duplicarlos ni crear una costura abierta.
    """
    if len(borde) < 8 or len(borde) % 4:
        raise ValueError("el fondo necesita cuatro lados con igual cantidad de segmentos")
    n = len(borde) // 4
    fila = n + 1
    indices = ([i for i in range(n)] + [j * fila + n for j in range(n)]
               + [n * fila + i for i in range(n, 0, -1)]
               + [j * fila for j in range(n, 0, -1)])
    vertices = [None] * (fila * fila)
    for indice, punto in zip(indices, borde):
        vertices[indice] = tuple(punto)
    for j in range(1, n):
        v = j / n
        for i in range(1, n):
            u = i / n
            arriba, abajo = vertices[i], vertices[n * fila + i]
            izquierda, derecha = vertices[j * fila], vertices[j * fila + n]
            esquinas = (vertices[0], vertices[n], vertices[n * fila], vertices[-1])
            pesos = ((1-u) * (1-v), u * (1-v), (1-u) * v, u * v)
            vertices[j * fila + i] = tuple(
                (1-v) * arriba[k] + v * abajo[k]
                + (1-u) * izquierda[k] + u * derecha[k]
                - sum(peso * esquina[k] for peso, esquina in zip(pesos, esquinas))
                for k in range(3)
            )
    caras = [(j * fila+i, j * fila+i+1, (j+1) * fila+i+1, (j+1) * fila+i)
             for j in range(n) for i in range(n)]
    return vertices, caras, indices
