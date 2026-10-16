"""La fase de las juntas depende del mundo, no del origen de cada objeto."""


def coordenada_del_piso(punto, cobertura=2.0):
    return punto[0] / cobertura, punto[1] / cobertura


def coordenada_del_zocalo(punto, normal, suelo, cobertura=2.0):
    if abs(normal[2]) > .5:
        return coordenada_del_piso(punto, cobertura)
    horizontal = punto[1] if abs(normal[0]) > .5 else punto[0]
    return horizontal / cobertura, (punto[2] - suelo) / cobertura
