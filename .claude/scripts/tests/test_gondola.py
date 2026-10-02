"""Los tests de `lib/gondola.py`: cuántas unidades entran en un estante, dónde va cada una y cómo
se escribe eso para Godot.

Todo lo que se prueba acá corre sin Blender. Lo que sólo Blender contesta —dónde está la chapa de
cada estante— lo mide `blender/acomodar.py`, y el resultado lo miran los tests del juego sobre la
disposición que queda en el repo.
"""

import math
import unittest

from lib.gondola import (
    AIRE,
    MARGEN,
    Envase,
    NodoDeMalla,
    alto_en_la_rampa,
    alinear_frentes,
    actualizar_contorno,
    ancho_de_la_tanda,
    apagar_las_unidades,
    base_en_godot,
    centros,
    columnas_que_entran,
    copia_relativa,
    escribir_disposicion,
    escribir_escena_de_mallas,
    flotantes_de_la_copia,
    fondo_del_estante,
    fondo_nuevo,
    franja_libre,
    nombre_en_godot,
    numero_de_escena,
    numero_de_recurso,
    paso,
    punto_en_godot,
    repartir,
    ruta_de_la_malla,
    slug,
    sobrante,
    tanda,
    transform_de_escena,
)

CAJA = Envase(ancho=0.30, fondo=0.10, alto=0.40)
LATA = Envase(ancho=0.18, fondo=0.18, alto=0.23)

#: Lo que se echa hacia atrás una unidad sobre la rampa de una cabecera, contra su chapa: la
#: chapa baja once grados hacia el pasillo y la unidad sube otro tanto, como la ponía el artista.
INCLINACION = 2 * math.asin(0.19)


class Repartir(unittest.TestCase):
    def test_el_contorno_sigue_el_tamano_y_centro_nuevos_sin_tocar_otras_formas(self):
        texto = (
            '[sub_resource type="BoxShape3D" id="contorno"]\nsize = Vector3(9, 9, 9)\n\n'
            '[sub_resource type="BoxShape3D" id="otro"]\nsize = Vector3(8, 8, 8)\n\n'
            '[node name="Forma" type="CollisionShape3D" parent="mueble/Contorno"]\n'
            'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 9, 9, 9)\n'
            'shape = SubResource("contorno")\n'
        )
        nuevo = actualizar_contorno(texto, "contorno", "mueble", (1, 2, 3), (4, 5, 6))
        self.assertIn('id="contorno"]\nsize = Vector3(4, 5, 6)', nuevo)
        self.assertIn('id="otro"]\nsize = Vector3(8, 8, 8)', nuevo)
        self.assertIn('Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 1, 2, 3)', nuevo)
        self.assertEqual(nuevo, actualizar_contorno(nuevo, "contorno", "mueble", (1, 2, 3), (4, 5, 6)))

    def test_el_zocalo_no_sobresale_del_frente_de_los_estantes_superiores(self):
        self.assertEqual(alinear_frentes([0.0, 0.0, 0.0], [0.3, 0.4, 0.6]), [0.6] * 3)

    def test_alinear_no_borra_la_tanda_fija_del_zocalo_si_necesita_mas_fondo(self):
        self.assertEqual(alinear_frentes([0.0, 0.0, 0.0], [0.8, 0.4, 0.6]), [0.8] * 3)

    def test_alinear_considera_el_panel_de_cada_estante_y_expande_un_zocalo_hundido(self):
        zocalo, arriba = alinear_frentes([-0.2, 0.0], [0.1, 0.4])
        self.assertAlmostEqual(zocalo, 0.6)
        self.assertAlmostEqual(arriba, 0.4)

    def test_una_tanda_sola_ocupa_el_estante_de_punta_a_punta(self):  # AC-STK-051
        (cuenta,) = repartir(3.5, [CAJA])
        libre = sobrante(3.5, [CAJA], [cuenta])
        self.assertGreaterEqual(libre, 0.0)
        # Ni una columna más entraría.
        self.assertLess(libre, paso(CAJA))

    def test_dos_tandas_ocupan_una_mitad_cada_una(self):  # AC-STK-051
        for largo in (1.9, 3.5, 3.512):
            for envases in ([CAJA, LATA], [LATA, CAJA], [CAJA, CAJA]):
                cuentas = repartir(largo, envases)
                mitad = (largo - AIRE) / 2
                for envase, cuenta in zip(envases, cuentas):
                    ocupado = ancho_de_la_tanda(envase, cuenta)
                    self.assertLessEqual(ocupado, mitad + 1e-9)
                    # Ni una columna más entraría en su mitad.
                    self.assertGreater(ocupado + paso(envase), mitad)

    def test_las_dos_mitades_difieren_en_menos_que_la_unidad_mas_ancha(self):  # AC-STK-051
        ancha = Envase(ancho=0.44, fondo=0.13, alto=0.45)
        for envases in ([CAJA, LATA], [ancha, LATA], [LATA, ancha]):
            cuentas = repartir(3.512, envases)
            ocupados = [ancho_de_la_tanda(e, c) for e, c in zip(envases, cuentas)]
            self.assertLess(abs(ocupados[0] - ocupados[1]), max(paso(e) for e in envases))

    def test_si_una_tanda_no_entra_en_su_mitad_es_un_error_y_no_se_acomoda(self):
        with self.assertRaises(ValueError):
            repartir(0.5, [CAJA, LATA])
        with self.assertRaises(ValueError):
            repartir(0.2, [CAJA])

    def test_columnas_que_entran_es_el_borde_exacto(self):
        largo = ancho_de_la_tanda(CAJA, 5)
        self.assertEqual(columnas_que_entran(CAJA, largo), 5)
        self.assertEqual(columnas_que_entran(CAJA, largo - 0.001), 4)


class Centros(unittest.TestCase):
    def test_el_sobrante_se_reparte_entre_los_dos_bordes(self):
        cuentas = [3, 2]
        largo = 2.0
        filas = centros(largo, [CAJA, LATA], cuentas)
        izquierda = filas[0][0] - CAJA.ancho / 2
        derecha = largo - (filas[1][-1] + LATA.ancho / 2)
        self.assertAlmostEqual(izquierda, derecha)
        self.assertAlmostEqual(izquierda * 2, sobrante(largo, [CAJA, LATA], cuentas))

    def test_dos_tandas_vecinas_se_separan_con_el_aire_de_siempre(self):
        filas = centros(2.0, [CAJA, LATA], [3, 2])
        hueco = (filas[1][0] - LATA.ancho / 2) - (filas[0][-1] + CAJA.ancho / 2)
        self.assertAlmostEqual(hueco, AIRE)


class LaTanda(unittest.TestCase):
    def test_primero_la_fila_de_atras_y_al_final_la_de_adelante(self):
        lugares = tanda(CAJA, [0.2, 0.5, 0.8])
        self.assertEqual([l.fila for l in lugares], ["atras"] * 3 + ["adelante"] * 3)
        # Cada fila de izquierda a derecha: lo último del bloque es lo que el jugador repone.
        self.assertEqual([l.columna for l in lugares], [0, 1, 2, 0, 1, 2])

    def test_la_fila_de_adelante_toca_el_frente_y_la_de_atras_va_pegada(self):
        lugares = tanda(CAJA, [0.2])
        atras, adelante = lugares
        self.assertAlmostEqual(adelante.v - CAJA.fondo / 2, MARGEN)
        self.assertAlmostEqual(atras.v - adelante.v, CAJA.fondo + AIRE)

    def test_el_estante_tiene_el_fondo_de_dos_unidades_del_mas_profundo(self):
        fondo = fondo_del_estante([CAJA, LATA])
        self.assertAlmostEqual(fondo, 2 * LATA.fondo + AIRE + 2 * MARGEN)
        # Y la fila de atrás del más profundo termina justo antes del margen del fondo.
        atras = tanda(LATA, [0.1])[0]
        self.assertAlmostEqual(atras.v + LATA.fondo / 2 + MARGEN, fondo)


class UnaSolaFila(unittest.TestCase):
    def test_la_tanda_de_una_fila_es_toda_de_adelante(self):  # AC-STK-030
        lugares = tanda(CAJA, [0.2, 0.5, 0.8], filas=1)
        self.assertEqual([l.fila for l in lugares], ["adelante"] * 3)
        self.assertEqual([l.columna for l in lugares], [0, 1, 2])
        # Va donde va la fila de adelante de cualquier tanda: contra el frente útil.
        self.assertEqual(lugares, tanda(CAJA, [0.2, 0.5, 0.8])[3:])

    def test_una_fila_pide_el_fondo_de_una_sola_unidad(self):
        self.assertAlmostEqual(fondo_del_estante([LATA], filas=[1]), LATA.fondo + 2 * MARGEN)

    def test_el_estante_no_crece_para_el_producto_de_una_fila(self):
        # Dos filas de una caja de 40 cm de fondo pedirían 80: en una sola, manda la lata.
        honda = Envase(ancho=0.31, fondo=0.40, alto=0.27)
        chata = Envase(ancho=0.25, fondo=0.25, alto=0.09)
        self.assertAlmostEqual(
            fondo_del_estante([honda, chata], filas=[1, 2]), fondo_del_estante([chata])
        )
        self.assertAlmostEqual(
            fondo_nuevo(0.01, [honda, chata], 0.12, filas=[1, 2]),
            0.01 + fondo_del_estante([chata]) + 0.12,
        )

    def test_en_la_rampa_una_fila_llega_hasta_su_cabeza(self):
        fondo = fondo_del_estante([CAJA], INCLINACION, filas=[1])
        (unidad,) = tanda(CAJA, [0.2], INCLINACION, filas=1)
        cabeza = (
            unidad.v + CAJA.fondo / 2 * math.cos(INCLINACION) + CAJA.alto * math.sin(INCLINACION)
        )
        self.assertAlmostEqual(cabeza + MARGEN, fondo)


class EnLaRampa(unittest.TestCase):
    def test_en_un_estante_plano_nada_cambia(self):
        self.assertEqual(tanda(CAJA, [0.2, 0.5], 0.0), tanda(CAJA, [0.2, 0.5]))
        self.assertEqual(fondo_del_estante([CAJA, LATA], 0.0), fondo_del_estante([CAJA, LATA]))
        self.assertEqual(alto_en_la_rampa(CAJA, 0.0), CAJA.alto)

    def test_las_dos_filas_echadas_no_se_meten_una_en_la_otra(self):
        atras, adelante = tanda(CAJA, [0.2], INCLINACION)
        # Medida a lo hondo de la unidad, que está echada, la separación es la unidad y el aire.
        separacion = (atras.v - adelante.v) * math.cos(INCLINACION)
        self.assertAlmostEqual(separacion, CAJA.fondo + AIRE)

    def test_echada_lo_mas_adelante_es_su_canto_de_abajo_y_va_detras_del_margen(self):
        adelante = tanda(CAJA, [0.2], INCLINACION)[1]
        self.assertAlmostEqual(adelante.v - CAJA.fondo / 2 * math.cos(INCLINACION), MARGEN)

    def test_el_estante_de_una_rampa_alcanza_para_la_cabeza_de_la_fila_de_atras(self):
        fondo = fondo_del_estante([CAJA], INCLINACION)
        atras = tanda(CAJA, [0.2], INCLINACION)[0]
        # Echada hacia atrás, lo más hondo de la unidad es su canto de arriba.
        cabeza = (
            atras.v + CAJA.fondo / 2 * math.cos(INCLINACION) + CAJA.alto * math.sin(INCLINACION)
        )
        self.assertAlmostEqual(cabeza + MARGEN, fondo)
        self.assertGreater(fondo, fondo_del_estante([CAJA]))

    def test_echada_pide_mas_alto_libre(self):
        self.assertAlmostEqual(
            alto_en_la_rampa(CAJA, INCLINACION),
            CAJA.alto * math.cos(INCLINACION) + CAJA.fondo * math.sin(INCLINACION),
        )

    def test_el_estante_se_achica_con_la_rampa(self):
        self.assertAlmostEqual(
            fondo_nuevo(0.01, [CAJA], 0.12, INCLINACION),
            0.01 + fondo_del_estante([CAJA], INCLINACION) + 0.12,
        )


class LoQueTapaElMueble(unittest.TestCase):
    def test_el_labio_de_adelante_y_la_tapa_de_atras_recortan_el_fondo(self):
        # Libre de sobra en el medio; el labio corta los primeros 8 mm y la tapa los últimos 12 cm.
        muestras = [(v / 1000, 0.1 if v < 8 or v > 580 else 0.5) for v in range(0, 700, 4)]
        desde, hasta = franja_libre(muestras, 0.40)
        self.assertAlmostEqual(desde, 0.008)
        self.assertAlmostEqual(hasta, 0.58)

    def test_un_producto_bajo_entra_debajo_de_la_tapa(self):
        muestras = [(v / 1000, 0.39 if v > 580 else 0.5) for v in range(0, 700, 4)]
        self.assertEqual(franja_libre(muestras, 0.30), (0.0, 0.696))

    def test_sin_lugar_libre_el_tramo_queda_vacio(self):
        desde, hasta = franja_libre([(0.0, 0.1), (0.1, 0.1)], 0.4)
        self.assertEqual(hasta - desde, 0.0)

    def test_el_estante_se_achica_con_lo_que_tapa_el_mueble(self):
        self.assertAlmostEqual(
            fondo_nuevo(0.01, [CAJA], 0.12), 0.01 + fondo_del_estante([CAJA]) + 0.12
        )


class DeBlenderAGodot(unittest.TestCase):
    def test_un_punto_de_blender_es_x_z_menos_y_en_godot(self):
        self.assertEqual(punto_en_godot((1.0, 2.0, 3.0)), (1.0, 3.0, -2.0))

    def test_la_base_de_actroncito_da_la_del_contenido(self):
        # Medida del `.blend` del 2026-09-29 y de `contenido_del_estante.tscn` de ese día: la
        # unidad de Actroncito tiene el eje X local en +Z, el Y en +X y el Z en +Y, con escala.
        blender = ((0.0, 0.2334, 0.0), (0.0, 0.0, 0.1552), (0.1337, 0.0, 0.0))
        godot = base_en_godot(blender)
        esperada = ((0.0, 0.0, -0.2334), (0.1337, 0.0, 0.0), (0.0, -0.1552, 0.0))
        for fila, fila_esperada in zip(godot, esperada):
            for valor, valor_esperado in zip(fila, fila_esperada):
                self.assertAlmostEqual(valor, valor_esperado)

    def test_una_copia_con_la_vuelta_del_modelo_no_gira(self):
        base = ((0.0, 0.2, 0.0), (0.0, 0.0, 0.15), (0.13, 0.0, 0.0))
        relativa = copia_relativa(base, base)
        for i in range(3):
            for j in range(3):
                self.assertAlmostEqual(relativa[i][j], 1.0 if i == j else 0.0)

    def test_la_copia_se_escribe_en_tres_filas_de_cuatro(self):
        identidad = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))
        self.assertEqual(
            flotantes_de_la_copia(identidad, (1.0, 2.0, 3.0)),
            [1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 2.0, 0.0, 0.0, 1.0, 3.0],
        )


class Nombres(unittest.TestCase):
    def test_el_nodo_importado_pierde_el_sufijo_y_el_punto(self):
        # Pares medidos sobre `estructura_del_almacen.tscn`, que nombra los nodos del `.glb`.
        pares = {
            "snackpapas1-convcol.003": "snackpapas1_003",
            "Zucarachas-fondo-col.020": "Zucarachas-fondo_020",
            "bebida helada02-este2-convcol": "bebida helada02-este2",
            "alfajorescaja2-2oeste1-col": "alfajorescaja2-2oeste1",
            "fideos3-col.": "fideos3_",
            "gondolanueva-col.001": "gondolanueva_001",
        }
        for blender, godot in pares.items():
            self.assertEqual(nombre_en_godot(blender), godot)

    def test_el_archivo_de_un_producto_no_lleva_acentos_ni_espacios(self):
        self.assertEqual(slug("Cosa de Maní"), "cosa_de_mani")
        self.assertEqual(slug("Actroncito"), "actroncito")
        self.assertEqual(ruta_de_la_malla("Feel Ricky Fort"), (
            "res://assets/models/producto_feel_ricky_fort.res"
        ))


class LaEscritura(unittest.TestCase):
    def test_los_numeros_del_recurso_llevan_seis_cifras_y_el_ruido_es_cero(self):
        self.assertEqual(numero_de_recurso(-3.388727), "-3.38873")
        self.assertEqual(numero_de_recurso(1.0), "1")
        self.assertEqual(numero_de_recurso(2.44534e-17), "0")
        self.assertEqual(numero_de_recurso(-0.0), "0")

    def test_los_numeros_de_la_escena_llevan_seis_decimales_sin_ceros_de_mas(self):
        self.assertEqual(numero_de_escena(-3.3887271), "-3.388727")
        self.assertEqual(numero_de_escena(1.0), "1")
        self.assertEqual(numero_de_escena(-0.0000001), "0")

    def test_el_transform_va_con_la_base_por_filas_y_el_origen_al_final(self):
        base = ((0.0, 0.0, -0.233377), (0.133667, 0.0, 0.0), (0.0, -0.155248, 0.0))
        self.assertEqual(
            transform_de_escena(base, (-3.388727, 0.925808, -1.188861)),
            "Transform3D(0, 0, -0.233377, 0.133667, 0, 0, 0, -0.155248, 0, "
            "-3.388727, 0.925808, -1.188861)",
        )

    def test_la_disposicion_se_escribe_igual_para_los_mismos_datos(self):
        texto = escribir_disposicion([[1.0, 0.5]], [], [4], "uid://x", "uid://y")
        self.assertEqual(texto, escribir_disposicion([[1.0, 0.5]], [], [4], "uid://x", "uid://y"))
        self.assertIn("principales = Array[PackedFloat32Array]([PackedFloat32Array(1, 0.5)])", texto)
        self.assertIn("guias = Array[PackedFloat32Array]([])", texto)
        self.assertIn("filas_de_adelante = PackedInt32Array(4)", texto)

    def test_la_escena_comparte_un_recurso_por_malla(self):
        identidad = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))
        nodos = [
            NodoDeMalla("Guia00", "res://a.res", identidad, (0.0, 0.0, 0.0)),
            NodoDeMalla("Guia01", "res://b.res", identidad, (0.0, 0.0, 0.0)),
            NodoDeMalla("Guia02", "res://a.res", identidad, (0.0, 0.0, 0.0)),
        ]
        texto = escribir_escena_de_mallas("Guia", nodos)
        self.assertEqual(texto.count("[ext_resource"), 2)
        self.assertEqual(texto.count('mesh = ExtResource("malla0")'), 2)
        self.assertTrue(texto.startswith("[gd_scene format=3]\n"))

    def test_una_escena_sin_mallas_es_solo_la_raiz(self):
        self.assertEqual(
            escribir_escena_de_mallas("Guia", []),
            '[gd_scene format=3]\n\n[node name="Guia" type="Node3D"]\n',
        )


def _apagada(padre, nombre):
    ruta = nombre if padre == "." else f"{padre}/{nombre}"
    return (
        f'[node name="{nombre}" parent="{padre}"]\nvisible = false\n\n'
        f'[node name="StaticBody3D" parent="{ruta}"]\n'
        "collision_layer = 0\ncollision_mask = 0\n\n"
    )


ANTES = '[gd_scene format=3]\n\n[node name="Estructura" instance=ExtResource("modelo")]\n\n'
LUZ = '[node name="Luz" type="OmniLight3D" parent="heladeranueva"]\nlight_energy = 0.85\n'


class LasUnidadesApagadas(unittest.TestCase):
    def test_se_cambian_las_viejas_por_las_nuevas_en_el_mismo_lugar(self):
        escena = ANTES + _apagada("gondolanueva", "wakas_021") + _apagada(".", "petisas") + LUZ
        rutas = ["heladeranueva/terminator", "cindolor", "gondolanueva2/duronga"]
        self.assertEqual(
            apagar_las_unidades(escena, rutas),
            ANTES
            + _apagada(".", "cindolor")
            + _apagada("gondolanueva2", "duronga")
            + _apagada("heladeranueva", "terminator")
            + LUZ,
        )

    def test_volver_a_apagar_las_mismas_no_cambia_un_byte(self):
        escena = ANTES + _apagada("gondolanueva", "oremos") + LUZ
        texto = apagar_las_unidades(escena, ["gondolanueva/oremos", "gondolanueva/chisitos2"])
        otra_vez = apagar_las_unidades(texto, ["gondolanueva/chisitos2", "gondolanueva/oremos"])
        self.assertEqual(otra_vez, texto)

    def test_un_nodo_apagado_con_otras_propiedades_no_es_una_unidad_y_se_queda(self):
        otro = '[node name="Cartel" parent="."]\nvisible = false\ncast_shadow = 0\n\n'
        escena = ANTES + otro + _apagada("gondolanueva", "oremos") + LUZ
        texto = apagar_las_unidades(escena, [])
        self.assertEqual(texto, ANTES + otro + LUZ)

    def test_una_escena_sin_unidades_apagadas_es_un_error(self):
        with self.assertRaises(ValueError):
            apagar_las_unidades(ANTES + LUZ, ["gondolanueva/oremos"])


if __name__ == "__main__":
    unittest.main()
