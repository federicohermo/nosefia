"""Actualizar dos veces una escena no agrega formas físicas huérfanas."""

import unittest

from lib.integracion_modelo import bloques, poner, propiedad, ruta, trasladar_sin_girar


class ComposicionDelModelo(unittest.TestCase):
    def test_reubicar_una_bolsa_conserva_el_giro_de_la_boca_del_tacho(self):
        bloque = ('[node name="BolsaDeBasura2" parent="."]\n'
                  'transform = Transform3D(0,0,-1,0,1,0,1,0,0,4,5,6)\n')
        self.assertEqual(
            trasladar_sin_girar(bloque, (7, 8, 9)),
            'Transform3D(0.000000000,0.000000000,-1.000000000,'
            '0.000000000,1.000000000,0.000000000,1.000000000,0.000000000,0.000000000,'
            '7.000000000,8.000000000,9.000000000)',
        )

    def test_actualizar_un_volumen_no_duplica_el_nodo_ni_su_forma(self):
        texto = '[node name="Volumen" type="CollisionShape3D" parent="Mueble/Cuerpo"]\n'
        escena = bloques(texto)
        for _ in range(3):
            poner(escena, 'Mueble/Cuerpo/Volumen', {'shape': 'SubResource("nueva")'})
        self.assertEqual(sum(ruta(b) == 'Mueble/Cuerpo/Volumen' for b in escena), 1)
        self.assertEqual(''.join(escena).count('shape ='), 1)
        self.assertIn('shape = SubResource("nueva")', ''.join(escena))

    def test_quitar_una_pose_heredada_conserva_el_comportamiento_del_mueble(self):
        texto = ('[node name="Mueble" parent="."]\ntransform = Transform3D()\n'
                 'script = ExtResource("puesto")\n')
        actualizado = propiedad(texto, 'transform', None)
        self.assertNotIn('transform =', actualizado)
        self.assertIn('script = ExtResource("puesto")', actualizado)

    def test_las_rutas_de_nodos_no_confunden_una_raiz_con_sus_hijos(self):
        self.assertEqual(ruta('[node name="Cuerpo" parent="Mueble"]'), 'Mueble/Cuerpo')
        self.assertEqual(ruta('[node name="Mueble" parent="."]'), 'Mueble')
        self.assertIsNone(ruta('[sub_resource type="BoxShape3D" id="forma"]'))
