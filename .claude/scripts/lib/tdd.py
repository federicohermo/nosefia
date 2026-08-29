"""La disciplina de tests, verificada en vez de pedida.

## Por qué este archivo existe, y qué reemplaza

El harness del que sale éste tiene un gate de **cobertura al 100 %** en las cuatro métricas,
sin una sola excepción. Ese gate es el que sostiene el TDD: una función sin test no llega a
mergearse porque el número baja y la CI se pone roja.

**En GDScript ese número no existe.** Godot no instrumenta scripts y ninguna de las dos
herramientas de test del ecosistema mide cobertura de ramas. Así que hay dos salidas
honestas: pedir TDD por escrito y confiar, o buscar las señales que sí son medibles. Ésta es
la segunda, y hay que decir con todas las letras **qué se pierde**: esto no sabe si un test
ejerce una rama. Sabe si el archivo existe, si el test afirma algo y si va a correr. Es un
piso, no el techo que da un 100 % de cobertura.

Las cuatro reglas, y el modo de falla que cierra cada una:

1. **Todo script de `dominio/` y `sistemas/` tiene su test espejo.** Es la que reemplaza al
   umbral: sin ella, el código nuevo entra sin nada que lo ejerza y nadie se entera hasta que
   rompe. El espejo —`src/dominio/turno.gd` → `test/dominio/turno_test.gd`— es lo que permite
   contestarlo sin que nadie mantenga una lista.
2. **Ningún test sin una sola aserción.** Un test que corre y no afirma nada es verde
   permanente: cuesta lo mismo que uno de verdad y no puede fallar nunca.
3. **Ningún test salteado ni `assert_not_yet_implemented`.** Es la misma familia: verde sin
   ejercer. Saltear un test es una decisión que se toma borrándolo o arreglándolo, no
   dejándolo apagado adentro del archivo donde se lee como cobertura.
4. **Ningún `func test_…` en un archivo que no sea un `*_test.gd`.** Un test con el nombre
   equivocado **no corre y no se queja**, que es exactamente «fallar en verde»: la suite pasa
   y el archivo con los tests está ahí, a la vista, dando la impresión contraria.

Todo lo de acá es puro: recibe rutas y textos, devuelve hallazgos. Quien camina el disco es
`gate_de_tests.py`.
"""

import re

#: Una función de test de gdUnit4. El prefijo `test_` es la convención del framework.
_FUNCION_DE_TEST = re.compile(r"^func\s+(test_\w*)\s*\(", re.MULTILINE)

#: Cualquier función a nivel de archivo, para saber dónde termina la anterior.
_CUALQUIER_FUNCION = re.compile(r"^func\s+\w+\s*\(", re.MULTILINE)

#: Una aserción de gdUnit4: `assert_that`, `assert_int`, `assert_array`, …
#:
#: `assert_not_yet_implemented` queda EXCLUIDA a propósito y por la regla 3: es la forma que
#: tiene el framework de decir «este test todavía no afirma nada», así que contarla como
#: aserción sería aceptar como cubierto justo lo que declara no estarlo.
_ASERCION = re.compile(r"\bassert_(?!not_yet_implemented)\w+\s*\(")

#: Las formas de apagar un test sin borrarlo.
_APAGADO = re.compile(r"\bassert_not_yet_implemented\b|\bskip\s*\(\s*true\s*\)|@\s*ignore\b")

SUFIJO_DE_TEST = "_test.gd"


def ruta_de_test(ruta_script: str, capas: tuple[str, ...], dir_tests: str) -> str | None:
    """Dónde vive el test de un script, o `None` si ese script no lo necesita.

    `src/dominio/turno/reloj.gd` → `test/dominio/turno/reloj_test.gd`.
    """
    normalizada = ruta_script.replace("\\", "/")
    for capa in capas:
        if not normalizada.startswith(f"{capa}/"):
            continue
        # `src/dominio/x.gd` → `dominio/x.gd`: se le saca la raíz de la capa (`src/`) y se le
        # deja el resto, que es lo que el espejo replica.
        raiz = capa.split("/", 1)[0]
        resto = normalizada[len(raiz) + 1 :]
        return f"{dir_tests}/{resto[:-3]}{SUFIJO_DE_TEST}"
    return None


def funciones_de_test(texto: str) -> list[tuple[str, str]]:
    """Las funciones `test_…` de un archivo, con su cuerpo: `(nombre, cuerpo)`.

    El cuerpo va desde la firma hasta la función siguiente **a nivel de archivo**, que es lo
    que permite mirar cada test por separado: sin el corte, un archivo con un test que afirma
    y otro que no daría verde entero por el primero.
    """
    inicios = [(m.group(1), m.start()) for m in _FUNCION_DE_TEST.finditer(texto)]
    todas = [m.start() for m in _CUALQUIER_FUNCION.finditer(texto)]
    resultado = []
    for nombre, inicio in inicios:
        siguientes = [p for p in todas if p > inicio]
        fin = siguientes[0] if siguientes else len(texto)
        resultado.append((nombre, texto[inicio:fin]))
    return resultado


def violaciones(
    scripts: dict[str, str],
    tests: dict[str, str],
    capas: tuple[str, ...],
    dir_tests: str,
) -> list[tuple[str, str]]:
    """Los hallazgos, como `(archivo, qué está mal)`.

    `scripts` son los `.gd` de `src/` y `tests` los de `test/`, los dos como `ruta` → texto.
    """
    hallazgos: list[tuple[str, str]] = []

    # Regla 1 — el espejo.
    for ruta in sorted(scripts):
        destino = ruta_de_test(ruta, capas, dir_tests)
        if destino is None or destino in tests:
            continue
        hallazgos.append(
            (ruta, f"no tiene test: falta `{destino}`. Es una capa que se ejerce sin escena.")
        )

    for ruta in sorted(tests):
        texto = tests[ruta]
        normalizada = ruta.replace("\\", "/")
        funciones = funciones_de_test(texto)

        # Regla 4 — el nombre, que decide si el archivo corre.
        if funciones and not normalizada.endswith(SUFIJO_DE_TEST):
            hallazgos.append(
                (
                    ruta,
                    f"tiene {len(funciones)} `func test_…` y no se llama `*{SUFIJO_DE_TEST}`: "
                    "el archivo no se descubre como suite y esos tests no corren.",
                )
            )
            continue

        if not normalizada.endswith(SUFIJO_DE_TEST):
            continue

        # Un `*_test.gd` sin una sola función de test es la misma mentira que un test sin
        # aserción, un nivel más arriba: el archivo existe, el espejo de la regla 1 lo da por
        # cumplido, y no ejerce nada.
        if not funciones:
            hallazgos.append((ruta, "es un `*_test.gd` sin una sola `func test_…`."))
            continue

        for nombre, cuerpo in funciones:
            # Reglas 2 y 3, en ese orden: si el test está apagado, decirlo antes es más útil
            # que decir que no afirma nada — que es la consecuencia, no la causa.
            apagado = _APAGADO.search(cuerpo)
            if apagado:
                hallazgos.append(
                    (
                        ruta,
                        f"`{nombre}` está apagado (`{apagado.group(0)}`): un test que no puede "
                        "fallar es verde permanente. Arreglalo o borralo.",
                    )
                )
            elif not _ASERCION.search(cuerpo):
                hallazgos.append(
                    (ruta, f"`{nombre}` no tiene una sola aserción: no puede fallar nunca.")
                )

    return hallazgos
