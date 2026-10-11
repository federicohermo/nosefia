"""Secciones de montaje; el chaflán deja pasar el espesor de la hoja al girar."""


def seccion_del_poste(eje_x, extremo_x, frente_y, fondo_y):
    return [
        (eje_x + 0.050, frente_y),
        (extremo_x, frente_y),
        (extremo_x, fondo_y),
        (eje_x + 0.015, fondo_y),
    ]


def seccion_del_perfil(x, y, central=False):
    if central:
        puntos = [
            (-0.09, 0.0273), (-0.0353, 0.0273), (-0.0353, -0.09),
            (-0.0273, -0.09), (-0.0273, 0.0273), (0.0273, 0.0273),
            (0.0273, -0.09), (0.0353, -0.09), (0.0353, 0.0273),
            (0.09, 0.0273), (0.09, 0.0353), (-0.09, 0.0353),
        ]
    else:
        puntos = [
            (-0.0353, -0.09), (-0.0273, -0.09), (-0.0273, 0.0273),
            (0.09, 0.0273), (0.09, 0.0353), (-0.0353, 0.0353),
        ]
    return [(x + dx, y + dy) for dx, dy in puntos]
