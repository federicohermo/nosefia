"""Un semiespacio recorta el casco sin aproximar ni rellenar su parte vacía."""

from itertools import combinations


def recortar(puntos, normal, distancia, positivo=True):
    signo = 1 if positivo else -1
    valores = [signo * (sum(a * b for a, b in zip(p, normal)) - distancia) for p in puntos]
    resultado = [p for p, d in zip(puntos, valores) if d >= -1e-7]
    for i, j in combinations(range(len(puntos)), 2):
        a, b = valores[i], valores[j]
        if a * b >= 0:
            continue
        t = a / (a - b)
        resultado.append(tuple(puntos[i][e] + t * (puntos[j][e] - puntos[i][e])
                               for e in range(3)))
    return sorted({tuple(round(c, 7) for c in p) for p in resultado})
