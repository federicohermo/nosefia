# Plan — Spec NNN

<!-- Techo: 250 palabras, y ni los encabezados ni estos comentarios cuentan — así que rotular
     no cuesta y leer las instrucciones tampoco. Lo que sí cuenta es lo que escribas afuera.
     Los tres `##` de abajo los exige `test_convencion_de_specs.py`; podés agregar otros. -->

## Orden obligado

<!-- Qué NO se puede paralelizar, y por qué. En prosa, no como lista de tareas: la lista de lo
     que sí se puede hacer junto exige conocer los archivos antes de abrirlos, y está medido
     que esa predicción falla —43 % de rutas nunca tocadas, 39 % de imprevistos—.
     Empezá por las escenas: un merge de tres vías sobre una escena da una escena corrupta,
     no un conflicto. -->

## Qué NO se toca

<!-- Las dos mitades se separan por lo que se puede verificar y lo que no. Es la sección 4
     (blast radius) y la 3 (invariantes) del task-brief, y la fila "Constraints" de la Tabla I
     de Agentic Agile-V, que las pone aparte de los criterios de aceptación. -->

### Rutas

<!-- Los archivos y directorios que este spec NO escribe, uno por viñeta y entre backticks. Es
     una lista NEGATIVA y cerrada: no predice qué vas a tocar, prohíbe lo que no. Por eso no
     hereda la medición que mató a la lista de tareas.

     Y se cruza contra la rama: `test_rutas_del_plan.py` da rojo si tocás uno de éstos, con el
     PR todavía abierto. Tres formas — un directorio con la barra al final, una ruta completa
     que matchea exacto, y un nombre pelado que matchea en cualquier carpeta.

     Sólo lo que de verdad es intocable. Un archivo citado como *fuente* de algo no va acá: el
     plan del 012 nombra una regla del repo como la lista de la que salen sus patrones, y
     declararla prohibida daría rojo sobre un PR correcto.

     Las rutas de acá adentro se citan SIN backticks a propósito: entre backticks las
     levantaría el propio parser y la plantilla quedaría prohibiéndolas. -->

Ninguna.

<!-- Reemplazá el `Ninguna.` por tus viñetas. Si el spec de verdad no restringe ningún
     archivo, dejalo: 11 de los 24 specs abiertos están en ese caso, y omitir el rubro se lee
     igual que olvidarlo. -->

### Invariantes

<!-- Lo que sigue siendo cierto después del cambio, y que ningún gate puede decidir: «ningún
     autoload», «ninguna regla del juego en escenas/», «ninguna unidad de stock se mueve fuera
     de Estante.colocar()». Es prosa a propósito — la mira la revisión, y está declarado como
     prosa igual que el resto de las reglas no verificables del repo. -->

## Criterio de terminado

<!-- `verificar.py` en verde sin nodos salteados, y qué más. Si hay algo que sólo se ve
     corriendo el juego, decilo acá: no es un criterio de aceptación, porque un criterio lo
     tiene que poder cerrar un agente. -->
