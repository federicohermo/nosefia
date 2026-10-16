"""Agrupa celdas ocupadas sin cerrar los huecos de puertas ni rellenar habitaciones."""


def agrupar(celdas: set[tuple[int, int, int]]) -> list[tuple[tuple, tuple]]:
    pendientes = set(celdas)
    cajas = []
    while pendientes:
        inicio = min(pendientes)
        fin = [n + 1 for n in inicio]
        for eje in range(3):
            while True:
                cara = [range(inicio[i], fin[i]) for i in range(3)]
                cara[eje] = [fin[eje]]
                nueva = {(x, y, z) for x in cara[0] for y in cara[1] for z in cara[2]}
                if not nueva <= pendientes:
                    break
                fin[eje] += 1
        ocupadas = {(x, y, z) for x in range(inicio[0], fin[0])
                    for y in range(inicio[1], fin[1]) for z in range(inicio[2], fin[2])}
        pendientes.difference_update(ocupadas)
        cajas.append((inicio, tuple(fin)))
    return cajas
