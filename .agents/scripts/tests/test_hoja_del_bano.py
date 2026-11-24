"""La hoja del baño queda con dos caras planas de un solo cuadrilátero, conservando la rejilla."""

import importlib.util
import math
import sys
import types
import unittest
from pathlib import Path
from unittest import mock

from lib.hoja_del_bano import (
    desviacion_maxima_de_caras_grandes,
    esquinas_exteriores,
    hoja_ya_plana,
    plano_exterior_por_lado,
    proyectar_uv_afin,
)
from lib.repo import RAIZ


def _hoja_con_panel_hundido(
    ancho: float = 1.2,
    alto: float = 2.0,
    espesor: float = 0.08,
    hundimiento: float = 0.01,
) -> tuple[list[tuple[float, float, float]], list[tuple[int, int, int, int]], set[int]]:
    ext = espesor / 2.0
    intr = ext - hundimiento
    mx = ancho * 0.1
    mz = alto * 0.1
    vertices = [
        (0.0, -ext, 0.0),
        (ancho, -ext, 0.0),
        (ancho, -ext, alto),
        (0.0, -ext, alto),
        (0.0, ext, 0.0),
        (ancho, ext, 0.0),
        (ancho, ext, alto),
        (0.0, ext, alto),
        (mx, -intr, mz),
        (ancho - mx, -intr, mz),
        (ancho - mx, -intr, alto - mz),
        (mx, -intr, alto - mz),
        (mx, intr, mz),
        (ancho - mx, intr, mz),
        (ancho - mx, intr, alto - mz),
        (mx, intr, alto - mz),
    ]
    caras: list[tuple[int, int, int, int]] = []
    for i in range(4):
        j = (i + 1) % 4
        caras.extend([(i, j, 8 + j, 8 + i), (4 + j, 4 + i, 12 + i, 12 + j), (j, i, 4 + i, 4 + j)])
    caras.extend([(8, 9, 10, 11), (15, 14, 13, 12)])
    return vertices, caras, set(range(len(vertices)))


class _Vec:
    def __init__(self, coords: tuple[float, float, float]):
        self.x, self.y, self.z = (float(c) for c in coords)

    def __iter__(self):
        return iter((self.x, self.y, self.z))


def _objeto_hoja_ya_plana():
    verts = [
        types.SimpleNamespace(co=_Vec(c))
        for c in (
            (0.0, -0.04, 0.0),
            (1.2, -0.04, 0.0),
            (1.2, -0.04, 2.0),
            (0.0, -0.04, 2.0),
            (0.0, 0.04, 0.0),
            (1.2, 0.04, 0.0),
            (1.2, 0.04, 2.0),
            (0.0, 0.04, 2.0),
        )
    ]
    caras = [
        types.SimpleNamespace(
            index=0, vertices=(0, 1, 2, 3), material_index=1, use_smooth=False,
            normal=_Vec((0.0, -1.0, 0.0)), loop_indices=(0, 1, 2, 3),
        ),
        types.SimpleNamespace(
            index=1, vertices=(7, 6, 5, 4), material_index=0, use_smooth=False,
            normal=_Vec((0.0, 1.0, 0.0)), loop_indices=(4, 5, 6, 7),
        ),
        types.SimpleNamespace(
            index=2, vertices=(1, 0, 4, 5), material_index=0, use_smooth=False,
            normal=_Vec((0.0, 0.0, -1.0)), loop_indices=(8, 9, 10, 11),
        ),
        types.SimpleNamespace(
            index=3, vertices=(2, 1, 5, 6), material_index=0, use_smooth=False,
            normal=_Vec((1.0, 0.0, 0.0)), loop_indices=(12, 13, 14, 15),
        ),
        types.SimpleNamespace(
            index=4, vertices=(3, 2, 6, 7), material_index=0, use_smooth=False,
            normal=_Vec((0.0, 0.0, 1.0)), loop_indices=(16, 17, 18, 19),
        ),
        types.SimpleNamespace(
            index=5, vertices=(0, 3, 7, 4), material_index=0, use_smooth=False,
            normal=_Vec((-1.0, 0.0, 0.0)), loop_indices=(20, 21, 22, 23),
        ),
    ]
    mat_blanco = types.SimpleNamespace(name="bano_entrada_blanca")
    nodo_tex = types.SimpleNamespace(type="TEX_IMAGE", extension="EXTEND")
    mat_rejilla = types.SimpleNamespace(
        name="bano_rejilla_texturizada",
        node_tree=types.SimpleNamespace(nodes=[nodo_tex]),
    )
    uv_layer = types.SimpleNamespace(
        name="UVMap", data=[types.SimpleNamespace(uv=(0.0, 0.0)) for _ in range(24)]
    )
    malla = types.SimpleNamespace(
        users=1,
        vertices=verts,
        polygons=caras,
        materials=[mat_blanco, mat_rejilla],
        uv_layers=[uv_layer],
    )
    identidad = [[1.0 if r == c else 0.0 for c in range(4)] for r in range(4)]
    return types.SimpleNamespace(
        name="puerta2-col",
        type="MESH",
        data=malla,
        matrix_world=identidad,
        matrix_local=identidad,
        parent=None,
    )


class TestHojaDelBano(unittest.TestCase):
    def test_las_esquinas_exteriores_arman_dos_caras_planas_sin_inclinacion(self) -> None:
        vertices, caras, cuerpo = _hoja_con_panel_hundido()
        self.assertGreater(desviacion_maxima_de_caras_grandes(vertices, caras), 1.0)

        frente = esquinas_exteriores(vertices, cuerpo, -1)
        dorso = esquinas_exteriores(vertices, cuerpo, 1)

        self.assertEqual(frente, [0, 1, 2, 3])
        self.assertEqual(dorso, [7, 6, 5, 4])
        self.assertLess(desviacion_maxima_de_caras_grandes(vertices, [frente, dorso]), 1e-6)

    def test_proyeccion_uv_conserva_coordenadas_del_panel_al_extender_al_borde(self) -> None:
        referencias = [
            ((0.12, 0.20), (0.0, 0.0)),
            ((1.08, 0.20), (1.0, 0.0)),
            ((1.08, 1.80), (1.0, 1.0)),
            ((0.12, 1.80), (0.0, 1.0)),
        ]
        # En el centro de una ranura dentro del panel, la UV extrapolada coincide con la original.
        uv_centro = proyectar_uv_afin(referencias, (0.60, 0.36))
        self.assertAlmostEqual(uv_centro[0], 0.5, places=6)
        self.assertAlmostEqual(uv_centro[1], 0.1, places=6)
        # En las esquinas exteriores de la hoja, la UV sale fuera de [0, 1] de forma lineal.
        u0, v0 = proyectar_uv_afin(referencias, (0.0, 0.0))
        u1, v1 = proyectar_uv_afin(referencias, (1.2, 2.0))
        self.assertLess(u0, 0.0)
        self.assertLess(v0, 0.0)
        self.assertGreater(u1, 1.0)
        self.assertGreater(v1, 1.0)

    def test_rechaza_cuerpo_sin_espesor(self) -> None:
        planos = [(0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (1.0, 0.0, 2.0), (0.0, 0.0, 2.0)]
        with self.assertRaises(ValueError):
            plano_exterior_por_lado(planos, {0, 1, 2, 3})

    def test_desviacion_mide_el_angulo_de_inclinacion_de_un_trapecio(self) -> None:
        vertices, caras, _ = _hoja_con_panel_hundido(
            ancho=1.0, alto=2.0, espesor=0.08, hundimiento=0.01
        )
        esperado = math.degrees(math.atan2(0.01, 0.1))
        self.assertAlmostEqual(
            desviacion_maxima_de_caras_grandes(vertices, caras), esperado, places=2
        )

    def test_hoja_ya_plana_exige_una_cara_por_lado_sin_inclinacion_y_con_clamp(self) -> None:
        self.assertTrue(
            hoja_ya_plana(["bano_rejilla_texturizada"], ["bano_entrada_blanca"], 0.0, ["EXTEND"])
        )
        self.assertFalse(
            hoja_ya_plana(
                ["bano_entrada_blanca", "bano_rejilla_texturizada"],
                ["bano_entrada_blanca"],
                0.0,
                ["EXTEND"],
            )
        )
        self.assertFalse(
            hoja_ya_plana(["bano_rejilla_texturizada"], ["bano_entrada_blanca"], 2.4, ["EXTEND"])
        )
        self.assertFalse(
            hoja_ya_plana(["bano_rejilla_texturizada"], ["bano_entrada_blanca"], 0.0, ["REPEAT"])
        )

    def test_segunda_corrida_de_aplicar_toma_el_camino_ya_plana_sin_mutar_la_malla(self) -> None:
        hoja = _objeto_hoja_ya_plana()
        identidad = [[1.0 if r == c else 0.0 for c in range(4)] for r in range(4)]
        malla_vacia = types.SimpleNamespace(vertices=[], polygons=[], materials=[], uv_layers=[])
        marco = types.SimpleNamespace(
            name="bano_marco_entrada", type="MESH", data=malla_vacia,
            matrix_world=identidad, matrix_local=identidad, parent=None,
        )
        edificio = types.SimpleNamespace(
            name="almacen-col", type="MESH", data=malla_vacia,
            matrix_world=identidad, matrix_local=identidad, parent=None,
        )

        class _Objetos(dict):
            def __iter__(self):
                return iter(self.values())

        objetos = _Objetos({o.name: o for o in (hoja, marco, edificio)})
        bpy_falso = types.SimpleNamespace(data=types.SimpleNamespace(objects=objetos))
        bmesh_falso = types.SimpleNamespace(
            new=mock.Mock(side_effect=AssertionError("No debe editar bmesh si ya_plana es True"))
        )
        mathutils_falso = types.SimpleNamespace(Matrix=object, Vector=object)
        bvhtree_falso = types.SimpleNamespace(BVHTree=object)

        ruta = RAIZ / ".claude/scripts/blender/aplanar_hoja_del_bano.py"
        spec = importlib.util.spec_from_file_location("_aplanar_hoja_test", ruta)
        modulo = importlib.util.module_from_spec(spec)
        with mock.patch.dict(
            sys.modules,
            {
                "bpy": bpy_falso,
                "bmesh": bmesh_falso,
                "mathutils": mathutils_falso,
                "mathutils.bvhtree": bvhtree_falso,
            },
        ):
            spec.loader.exec_module(modulo)
            estado_antes = modulo._estado(hoja)
            cierre_esperado = {
                "rayos_sin_bloqueo": 0,
                "holgura_minima_mm": 5.2,
                "intersecciones_en_barrido": 0,
            }
            with mock.patch.object(
                modulo, "_verificar_cierre_y_barrido", return_value=cierre_esperado
            ) as verificar:
                informe = modulo.aplicar()

        self.assertTrue(informe["ya_plana"])
        self.assertEqual(informe["caras_eliminadas"], 0)
        self.assertEqual(informe["vertices_eliminados"], 0)
        self.assertEqual(informe["desviacion_despues_grados"], 0.0)
        self.assertEqual(informe["cierre_y_barrido"], cierre_esperado)
        self.assertEqual(modulo._estado(hoja), estado_antes)
        verificar.assert_called_once()
        bmesh_falso.new.assert_not_called()


if __name__ == "__main__":
    unittest.main()
