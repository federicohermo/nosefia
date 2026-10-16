"""Lo puro del gate de spec: decidir si una ruta cae adentro de una carpeta protegida.

**Existe para que tenga tests**, por el mismo motivo que `specs.py`: mientras esto vive
adentro del script del hook, la única forma de ejercerlo es correr el script entero como
subproceso, y el modo de falla que más importa no se puede fabricar así.

## Por qué el módulo de rutas se inyecta

El caso peligroso es **dos discos de Windows**, que es la configuración de la máquina donde
se desarrolla este juego: el repo está en `D:` y el temporal del sistema en `C:`.

En Python, `relpath` entre dos discos **lanza `ValueError`** en vez de devolver algo
plausible, así que el error no puede pasar desapercibido — pero sólo si alguien lo atrapa y
decide qué significa. Significa **«no está adentro»**: si no hay ningún camino relativo de
la carpeta protegida al archivo, el archivo no está bajo esa carpeta. Sin esa decisión
escrita, el gate se cae con un stack en vez de contestar, y un gate que se cae en cada
edición del scratchpad se desactiva el mismo día.

En POSIX el caso no existe: con una sola raíz, `relpath` nunca falla. Reproducirlo de verdad
pide dos discos, que dependen de la máquina y no existen en el `ubuntu-latest` donde corre
la CI. Recibiendo el módulo por parámetro, el caso se prueba con `ntpath` y da lo mismo en
las tres plataformas.
"""

from types import ModuleType


def esta_protegida(modulo_ruta: ModuleType, raiz: str, protegidas: list[str], ruta: str) -> bool:
    """Si `ruta` cae dentro de alguna de las `protegidas`, las dos relativas a `raiz`.

    Compara por RUTA RESUELTA y no por el string: `relpath` normaliza los `..`, las barras
    invertidas de Windows y las rutas relativas, así que `src/../src/dominio/turno.gd` cae
    donde tiene que caer. Comparar el string dejaría pasar cualquiera de esas tres formas.

    `modulo_ruta` es `os.path`, `ntpath` o `posixpath`. Ver el encabezado.
    """
    absoluta = modulo_ruta.normpath(modulo_ruta.join(raiz, ruta))
    for carpeta in protegidas:
        base = modulo_ruta.normpath(modulo_ruta.join(raiz, carpeta))
        try:
            relativa = modulo_ruta.relpath(absoluta, base)
        except ValueError:
            # Discos distintos: no hay camino relativo posible, o sea que NO está adentro.
            # Ver «Por qué el módulo de rutas se inyecta».
            continue
        # `.` es la ruta que ES la carpeta protegida, y cuenta como ADENTRO: con `Bash` en
        # el matcher del hook, el payload puede ser `rm -rf src`, o sea el borrado que más
        # importa por la única puerta que quedaría abierta.
        #
        # Y el «sale de acá» se compara contra `..` exacto o `../…`, no contra el prefijo
        # `..`: una carpeta hermana que se llame `..notas` empieza con `..` y no sale de
        # ningún lado. El prefijo pelado la dejaría pasar creyendo que está afuera.
        sube = relativa == ".." or relativa.startswith(f"..{modulo_ruta.sep}")
        if not sube:
            return True
    return False
