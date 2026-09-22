"""La línea final de `verificar.py`: la que se lee y la que se cita.

Vive acá y no en el ejecutable porque **decide qué dice la corrida**, y eso es exactamente lo
que `.claude/rules/herramientas.md` manda sacar del cableado: mientras vivió adentro de
`verificar.py`, la única forma de ejercerla era lanzar el script entero — o sea, hacía falta
tener Godot instalado para poder probar qué imprime cuando no lo está, que es justo el caso
que se rompió.

## El bug que justifica el módulo

Hasta el 2026-09-02 la línea era `len(resultados) - len(fallaron)`. Un nodo **salteado**
devuelve código 0, así que no estaba entre los que fallaron y **sumaba al numerador**: una
corrida con `tests` salteado por falta de `GODOT_BIN` imprimía `6/6 nodos en verde`.

La evidencia de que el nodo no había corrido estaba en pantalla —la columna de estado decía
`salteado` y el bloque `── tests: salteado ──` explicaba por qué—, tres líneas más arriba de
la frase que decía que todo estaba en verde. Es la familia de bug que este harness entero
existe para cerrar, en el único lugar donde nadie la había buscado: el resumen.

Y pesa más que un número mal: `N/N nodos en verde` es la frase que los criterios de
aceptación de los specs citan como prueba de que la verificación pasó.
"""


def resumen(resultados, segundos: float) -> str:
    """El texto de la última línea: cuántos pasaron de verdad, y qué le pasó al resto.

    `resultados` es cualquier secuencia de objetos con `.codigo` y `.salteado` — no se pide el
    `Resultado` de `verificar.py` para no atar este módulo al ejecutable que lo usa.

    Un nodo entra al numerador **sólo** si corrió y salió bien. Los otros dos casos se nombran
    por separado en la misma línea, porque bajar el número sin decir por qué se lee como un
    fallo: uno miró y dijo que no, el otro no miró.
    """
    total = len(resultados)
    fallaron = sum(1 for r in resultados if r.codigo != 0 and not r.salteado)
    salteados = sum(1 for r in resultados if r.salteado)
    verdes = total - fallaron - salteados

    linea = f"{verdes}/{total} nodos en verde"
    if fallaron:
        linea += f", {fallaron} {'falló' if fallaron == 1 else 'fallaron'}"
    if salteados:
        linea += f", {salteados} {'salteado' if salteados == 1 else 'salteados'}"
    return f"{linea}, en {segundos:.1f}s."
