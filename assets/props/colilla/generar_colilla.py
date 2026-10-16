"""Regenera la malla propia de colilla sin depender del modelo del local."""
from pathlib import Path


def generar(destino: Path) -> None:
    partes = [
        ("Filtro", -0.030, 0.024, 0.007, "Color(0.70, 0.39, 0.12, 1)"),
        ("Papel", 0.004, 0.044, 0.007, "Color(0.86, 0.82, 0.69, 1)"),
        ("Quemado", 0.029, 0.006, 0.0075, "Color(0.18, 0.15, 0.12, 1)"),
        ("Ceniza", 0.034, 0.004, 0.006, "Color(0.48, 0.46, 0.43, 1)"),
    ]
    lineas = ['[gd_scene format=3]', '']
    for nombre, _, largo, radio, color in partes:
        lineas += [
            f'[sub_resource type="StandardMaterial3D" id="material_{nombre}"]',
            f'albedo_color = {color}', 'roughness = 1.0', '',
            f'[sub_resource type="CylinderMesh" id="malla_{nombre}"]',
            f'material = SubResource("material_{nombre}")',
            f'top_radius = {radio}', f'bottom_radius = {radio}', f'height = {largo}',
            'radial_segments = 10', 'rings = 1', '',
        ]
    lineas += ['[node name="ColillaVisual" type="Node3D"]', '']
    for nombre, centro, _, _, _ in partes:
        lineas += [
            f'[node name="{nombre}" type="MeshInstance3D" parent="."]',
            f'position = Vector3({centro}, 0, 0)',
            'rotation = Vector3(0, 0, -1.570796326794897)',
            f'mesh = SubResource("malla_{nombre}")', 'gi_mode = 2', '',
        ]
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text('\n'.join(lineas), encoding='utf-8', newline='\n')


if __name__ == '__main__':
    generar(Path(__file__).with_name('colilla_visual.tscn'))
