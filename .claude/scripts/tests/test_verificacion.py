"""El resumen de `verificar.py`: la línea que se lee y la que se cita.

Existe por un bug medido el 2026-09-02: la última línea del script calculaba los nodos en
verde como `len(resultados) - len(fallaron)`, y un nodo **salteado** devuelve código 0, así
que no está entre los que fallaron y **sumaba al numerador**. La corrida con `tests` salteado
por falta de `GODOT_BIN` imprimía `6/6 nodos en verde`.

Eso contradice lo que el repo tiene escrito en dos lugares —`CLAUDE.md` («un nodo `salteado`
NO es un nodo verde») y el propio campo `salteado` de `Resultado` («se cuenta aparte»)— y
contradice para peor: la columna de estado sí distinguía el salteado, así que la evidencia de
que el nodo no corrió estaba en pantalla, tres líneas más arriba de la frase que decía que
todo estaba en verde. Y la frase es la que citan los criterios de aceptación de los specs.

El resumen vive acá y no en el ejecutable porque es lo que **decide** qué dice la corrida, y
mientras viviera adentro de `verificar.py` la única forma de ejercerlo era lanzar el script
entero — o sea, tener Godot instalado para poder probar qué pasa cuando no lo está.
"""

import unittest

from lib.verificacion import resumen


class Nodo:
    """Lo mínimo que `resumen` mira de un `Resultado`, para no atarlo al ejecutable."""

    def __init__(self, codigo: int = 0, salteado: bool = False) -> None:
        self.codigo = codigo
        self.salteado = salteado


class ResumenDeLaCorrida(unittest.TestCase):
    def test_todos_en_verde_los_cuenta_a_todos(self):
        texto = resumen([Nodo(), Nodo(), Nodo()], 4.4)
        self.assertIn("3/3 nodos en verde", texto)
        self.assertNotIn("salteado", texto)

    def test_un_salteado_no_entra_en_el_numerador(self):
        # El bug, con el nombre puesto: seis nodos, uno salteado, y la línea decía `6/6`.
        texto = resumen([Nodo(), Nodo(), Nodo(), Nodo(), Nodo(), Nodo(salteado=True)], 4.4)
        self.assertNotIn("6/6", texto)
        self.assertIn("5/6 nodos en verde", texto)

    def test_un_salteado_se_nombra_en_la_misma_linea(self):
        # Que no cuente no alcanza: si el número baja y nada dice por qué, se lee como un
        # fallo. La línea tiene que decir que hubo un salteo, que es lo que manda a leer el
        # bloque `── <nodo>: salteado ──` de más arriba.
        texto = resumen([Nodo(), Nodo(salteado=True)], 1.0)
        self.assertIn("1 salteado", texto)

    def test_los_salteados_se_cuentan_en_plural(self):
        texto = resumen([Nodo(), Nodo(salteado=True), Nodo(salteado=True)], 1.0)
        self.assertIn("2 salteados", texto)

    def test_un_nodo_que_falla_no_es_lo_mismo_que_uno_salteado(self):
        # Los dos bajan el numerador y por eso hay que poder distinguirlos: uno miró y dijo
        # que no, el otro no miró.
        texto = resumen([Nodo(), Nodo(codigo=1)], 1.0)
        self.assertIn("1/2 nodos en verde", texto)
        self.assertIn("1 falló", texto)
        self.assertNotIn("salteado", texto)

    def test_un_salteado_y_un_fallo_a_la_vez_se_dicen_los_dos(self):
        texto = resumen([Nodo(), Nodo(codigo=1), Nodo(salteado=True)], 2.0)
        self.assertIn("1/3 nodos en verde", texto)
        self.assertIn("1 falló", texto)
        self.assertIn("1 salteado", texto)

    def test_el_tiempo_va_en_la_linea(self):
        self.assertIn("4.4s", resumen([Nodo()], 4.4))

    def test_un_salteado_que_ademas_falla_se_cuenta_una_sola_vez(self):
        # No debería pasar —un salteo devuelve 0— pero si pasara, el numerador no puede
        # descontarlo dos veces y quedar en negativo.
        texto = resumen([Nodo(codigo=1, salteado=True), Nodo()], 1.0)
        self.assertIn("1/2 nodos en verde", texto)


if __name__ == "__main__":
    unittest.main()
