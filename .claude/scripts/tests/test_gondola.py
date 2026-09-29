"""Los tests de `lib/gondola.py`: cuántas unidades entran en un estante, dónde va cada una y cómo
se escribe eso para Godot.

Todo lo que se prueba acá corre sin Blender. Lo que sólo Blender contesta —dónde está la chapa de
cada estante— lo mide `blender/acomodar.py`, y el resultado lo miran los tests del juego sobre la
disposición que queda en el repo.
"""

import unittest

from lib.gondola import (
    AIRE,
    MARGEN,
    Envase,
    NodoDeMalla,
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
    punto_en_godot,
    rebajar,
    repartir,
    ruta_de_la_malla,
    slug,
    sobrante,
    tanda,
    transform_de_escena,
)

CAJA = Envase(ancho=0.30, fondo=0.10, alto=0.40)
LATA = Envase(ancho=0.18, fondo=0.18, alto=0.23)


class Repartir(unittest.TestCase):
    def test_el_estante_se_llena_hasta_que_no_entra_otra_columna(self):
        cuentas = repartir(3.5, [CAJA, LATA], [8, 1])
        libre = sobrante(3.5, [CAJA, LATA], cuentas)
        self.assertGreaterEqual(libre, 0.0)
        # Ni una columna más de ninguna de las dos entraría.
        self.assertLess(libre, min(CAJA.ancho, LATA.ancho) + AIRE)

    def test_los_minimos_se_respetan(self):
        cuentas = repartir(3.5, [CAJA, LATA], [8, 1])
        self.assertGreaterEqual(cuentas[0], 8)
        self.assertGreaterEqual(cuentas[1], 1)

    def test_lo_que_sobra_va_a_la_tanda_mas_angosta(self):
        # Con 8 de la caja, la lata arranca con una sola y es la más angosta: se lleva todo lo
        # que sobra mientras siga siéndolo.
        cuentas = repartir(3.5, [CAJA, LATA], [8, 1])
        self.assertEqual(cuentas[0], 8)
        self.assertEqual(cuentas[1], 5)

    def test_dos_tandas_iguales_quedan_parejas(self):
        cuentas = repartir(3.5, [CAJA, CAJA], [1, 1])
        self.assertLessEqual(abs(cuentas[0] - cuentas[1]), 1)

    def test_si_los_minimos_no_entran_es_un_error_y_no_se_acomoda(self):
        with self.assertRaises(ValueError):
            repartir(2.0, [CAJA], [8])

    def test_si_lo_pedido_no_entra_se_rebaja_la_tanda_mas_ancha(self):
        # Una cabecera de 1,73 m y un paquete de 30 cm: ocho no entran, cinco sí.
        paquete = Envase(ancho=0.30, fondo=0.09, alto=0.43)
        self.assertEqual(rebajar(1.73, [paquete], [8]), [5])
        # Con otra tanda al lado, la que se rebaja es la ancha y la otra conserva su mínimo.
        self.assertEqual(rebajar(3.5, [CAJA, LATA], [11, 1]), [10, 1])

    def test_lo_que_ya_entra_no_se_rebaja(self):
        self.assertEqual(rebajar(3.5, [CAJA, LATA], [8, 1]), [8, 1])

    def test_si_ni_una_columna_entra_es_un_error(self):
        with self.assertRaises(ValueError):
            rebajar(0.2, [CAJA], [1])

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
