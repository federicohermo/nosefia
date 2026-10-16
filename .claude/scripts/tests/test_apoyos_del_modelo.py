"""La geometría regenerada conserva soporte, huecos y todos los bloques ajenos."""

import json
import struct
import unittest
from pathlib import Path

from lib.apoyos_del_modelo import (
    actualizar_apoyos, grupos_convexos, mallas_del_glb, poner_compuesto, prismas_verticales,
)


def prisma(x0, z0, x1, z1):
    arriba = [(x0, 1, z0), (x1, 1, z0), (x1, 1, z1), (x0, 1, z1)]
    caras = [arriba[:3], [arriba[0], arriba[2], arriba[3]]]
    return caras + [[(p[0], 0, p[2]) for p in cara] for cara in caras]


def contiene_xz(puntos, x, z):
    a, b, c = puntos[:3]
    signos = [(q[0] - p[0]) * (z - p[2]) - (q[2] - p[2]) * (x - p[0])
              for p, q in [(a, b), (b, c), (c, a)]]
    return all(s >= -1e-9 for s in signos) or all(s <= 1e-9 for s in signos)


def glb(modelo, datos):
    prosa = json.dumps(modelo).encode()
    prosa += b' ' * (-len(prosa) % 4)
    datos += b'\0' * (-len(datos) % 4)
    chunks = struct.pack('<I4s', len(prosa), b'JSON') + prosa
    chunks += struct.pack('<I4s', len(datos), b'BIN\0') + datos
    return struct.pack('<4sII', b'glTF', 2, 12 + len(chunks)) + chunks


class RielConHueco(unittest.TestCase):
    def test_la_u_sostiene_los_tres_brazos_y_no_llena_el_aire(self):  # AC-PLY-099
        caras = prisma(0, 0, 3, .1) + prisma(0, .1, .1, 2) + prisma(2.9, .1, 3, 2)
        piezas = prismas_verticales(caras)
        for x, z in [(1.5, .05), (.05, 1), (2.95, 1)]:
            self.assertTrue(any(contiene_xz(p, x, z) for p in piezas))
        self.assertFalse(any(contiene_xz(p, 1.5, 1) for p in piezas))

    def test_el_encuentro_oblicuo_conserva_sus_vertices_y_espesor(self):
        arriba = [(0, 1, 0), (2, 1, .00265), (.1, 1, .06)]
        abajo = [(p[0], 0, p[2]) for p in arriba]
        self.assertEqual(prismas_verticales([arriba, abajo]), [arriba + abajo])

    def test_rechaza_contornos_distintos_en_ambas_bases(self):
        with self.assertRaisesRegex(ValueError, 'contorno'):
            prismas_verticales([[(0, 1, 0), (1, 1, 0), (0, 1, 1)],
                                [(0, 0, 0), (2, 0, 0), (0, 0, 1)]])

    def test_rechaza_vacio_plano_y_un_tercer_nivel(self):
        for caras in [[], [[(0, 1, 0), (1, 1, 0), (0, 1, 1)]],
                      prisma(0, 0, 1, 1) + [[(0, .5, 0), (1, .5, 0), (0, .5, 1)]]]:
            with self.subTest(caras=caras), self.assertRaises(ValueError):
                prismas_verticales(caras)


class LecturaLocalDelGlb(unittest.TestCase):
    def test_conserva_ejes_locales_y_offsets_sin_aplicar_otra_vez_la_traslacion(self):
        vertices = [(1., 2., 3.), (4., 2., 3.), (1., 2., 6.)]
        datos = b'1234' + b''.join(struct.pack('<3f', *p) + b'xxxx' for p in vertices)
        datos += struct.pack('<3H', 0, 1, 2)
        modelo = {
            'asset': {'version': '2.0'},
            'buffers': [{'byteLength': len(datos)}],
            'bufferViews': [{'buffer': 0, 'byteOffset': 4, 'byteLength': 48, 'byteStride': 16},
                            {'buffer': 0, 'byteOffset': 52, 'byteLength': 6}],
            'accessors': [{'bufferView': 0, 'componentType': 5126, 'count': 3, 'type': 'VEC3'},
                          {'bufferView': 1, 'componentType': 5123, 'count': 3, 'type': 'SCALAR'}],
            'meshes': [{'primitives': [{'attributes': {'POSITION': 0}, 'indices': 1}]}],
            'nodes': [{'name': 'mueble-col', 'mesh': 0, 'translation': [100, 200, 300]}],
        }
        self.assertEqual(mallas_del_glb(glb(modelo, datos), ['mueble']), {'mueble': [vertices]})

    def test_un_glb_invalido_o_una_malla_ausente_no_da_un_escenario_vacio_en_verde(self):
        with self.assertRaises(ValueError):
            mallas_del_glb(b'no es un glb', ['mueble'])
        with self.assertRaisesRegex(ValueError, 'mueble'):
            mallas_del_glb(glb({'asset': {'version': '2.0'}, 'nodes': []}, b''), ['mueble'])


class EscrituraAcotada(unittest.TestCase):
    def test_el_orden_de_triangulacion_y_el_cero_negativo_no_cambian_el_recurso(self):
        texto = '[gd_scene format=3]\n\n[node name="Estructura" type="Node3D"]\n'
        a = [(0., 0., 0.), (1., 0., 0.), (0., 1., 0.), (0., 0., 1.)]
        b = [(2., 0., 0.), (3., 0., 0.), (2., 1., 0.), (2., 0., 1.)]
        otra_a = [tuple(-0. if c == 0 else c for c in p) for p in reversed(a)]
        self.assertEqual(poner_compuesto(texto, 'riel', 'ApoyoDelRiel', [a, b], 1),
                         poner_compuesto(texto, 'riel', 'ApoyoDelRiel', [b, otra_a], 1))

    def test_compuesto_idempotente_conserva_capa_y_bloques_ajenos(self):
        texto = ('[gd_scene load_steps=2 format=3]\n\n'
                 '[sub_resource type="BoxShape3D" id="viejo"]\nsize = Vector3(9, 9, 9)\n\n'
                 '[node name="Estructura" type="Node3D"]\n\n'
                 '[node name="Contorno" type="StaticBody3D" parent="mueble"]\n'
                 'collision_layer = 8\ncollision_mask = 0\n\n'
                 '[node name="Forma" type="CollisionShape3D" parent="mueble/Contorno"]\n'
                 'shape = SubResource("viejo")\n\n'
                 '[node name="Ajeno" type="Node3D" parent="."]\nposition = Vector3(7, 8, 9)\n')
        piezas = [[(0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1)],
                  [(2, 0, 0), (3, 0, 0), (2, 1, 0), (2, 0, 1)]]
        nuevo = poner_compuesto(texto, 'mueble', 'Contorno', piezas, 8)
        self.assertEqual(nuevo, poner_compuesto(nuevo, 'mueble', 'Contorno', piezas, 8))
        self.assertEqual(nuevo.count('type="ConvexPolygonShape3D"'), 2)
        self.assertNotIn('id="viejo"', nuevo)
        self.assertIn('collision_layer = 8\ncollision_mask = 0', nuevo)
        self.assertIn(texto[texto.index('[node name="Ajeno"'):], nuevo)

    def test_riel_nuevo_tiene_volumen_y_no_sobrescribe_otro_apoyo(self):
        texto = '[gd_scene format=3]\n\n[node name="Estructura" type="Node3D"]\n'
        puntos = [[(0, 0, 0), (1, 0, 0), (0, 1, 0), (0, 0, 1)]]
        nuevo = poner_compuesto(texto, 'riel', 'ApoyoDelRiel', puntos, 1)
        self.assertIn('parent="riel"', nuevo)
        self.assertIn('collision_layer = 1', nuevo)
        self.assertIn('margin = 0.002', nuevo)
        self.assertEqual(nuevo, poner_compuesto(nuevo, 'riel', 'ApoyoDelRiel', puntos, 1))

    def test_un_compuesto_sin_volumen_no_se_publica(self):
        for piezas in [[], [[(0, 0, 0)]], [[(0, 0, 0), (1, 0, 0), (0, 0, 1), (1, 0, 1)]]]:
            with self.subTest(piezas=piezas), self.assertRaises(ValueError):
                poner_compuesto('[gd_scene format=3]\n', 'mueble', 'Contorno', piezas, 8)


class GeometriaVigente(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raiz = Path(__file__).resolve().parents[3]
        cls.mallas = mallas_del_glb(
            (cls.raiz / 'assets/models/SEPT_JUEGOS_PROTOTIPO.glb').read_bytes(),
            ['bano_riel_frontal', 'gondolanueva', 'gondolanueva2'])

    def test_las_gondolas_iguales_generan_el_mismo_metal_volumetrico(self):
        a = grupos_convexos(self.mallas['gondolanueva'])
        b = grupos_convexos(self.mallas['gondolanueva2'])
        self.assertGreater(len(a), 1, 'Un casco único volvería a rellenar el aire de la cabecera')
        escena = '[gd_scene format=3]\n\n[node name="Estructura" type="Node3D"]\n'
        self.assertEqual(poner_compuesto(escena, 'mueble', 'Contorno', a, 8),
                         poner_compuesto(escena, 'mueble', 'Contorno', b, 8))

    def test_regenerar_el_modelo_dos_veces_conserva_la_escena_entera(self):
        escena = self.raiz / 'src/escenas/puestos/estructura_del_almacen.tscn'
        primero = actualizar_apoyos(escena.read_text(encoding='utf-8'), self.mallas)
        self.assertEqual(primero, actualizar_apoyos(primero, self.mallas))


if __name__ == '__main__':
    unittest.main()
