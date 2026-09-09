# Ramas

Cada rama tiene una pregunta distinta, y el prefijo la contesta.

| Rama | Qué es | Quién escribe ahí |
|---|---|---|
| `main` | **Lo que se entrega.** Cada entrega de la cátedra sale de acá | sólo un PR de promoción desde `staging` |
| `staging` | **Integra.** Es la rama default del repositorio | los PR de cada spec, y los commits del mapa |
| `feature/<NNN>-<kebab>` | Un spec, uno | quien lo implementa |
| `bugfix/<kebab>` | Algo del producto está roto. Puede salir de un spec o no | quien lo arregla |
| `hotfix/<kebab>` | Urgente, contra lo que ya se entregó | quien lo arregla |
| `harness/<kebab>` | El harness de `.claude/`: scripts, gates, skills | quien lo toque |
| `docs/<kebab>` | La documentación | quien la escriba |
| `ci/<kebab>` | Los workflows de `.github/` | quien los toque |

## Los prefijos son un conjunto cerrado, y sólo la mitad se puede verificar

Los tres primeros —`feature/`, `bugfix/`, `hotfix/`— son los de la [convención de
Atlassian](https://support.atlassian.com/bitbucket-cloud/kb/how-to-prevent-creating-branches-with-the-prefixes-that-are-not-defined-in-the-branching-model-using-git-hooks-in-bitbucket-cloud/),
y son **los únicos que pueden editar `src/`**. Eso lo verifica `gate_de_spec.py` en cada
escritura.

Los otros tres **no los verifica nadie, y no se podría**: el hook sólo protege `src/`, así que
una rama `docs/` que edita documentación no le pasa ni cerca. Están declarados igual porque el
mensaje del bloqueo tiene que poder ofrecerlos — «renombrá la rama» sin decir a qué no es una
salida.

**No hay `chore/`**, que es el que la convención pone para «lo demás». Se define por lo que no
es, así que termina siendo el cajón donde cae todo; estos tres dicen qué tocás.

## Por qué dos ramas y no una

Porque las entregas tienen fecha y el trabajo no se detiene. Con una sola rama, la build de la
entrega sale de lo que haya en ese momento — incluido lo que alguien mergeó esa mañana. Con
`main` separada, lo que se entrega es una decisión: se promueve `staging` a `main` cuando el
estado sirve, y esa promoción es un PR que se mira.

## `staging` es la default, y eso la hace peligrosa

Es adonde apunta cada `gh pr create` y cada clone fresco: **el lugar más fácil de todo el repo
donde quedarse parado sin haberlo decidido.**

Por eso el hook la nombra explícitamente. Sin esa línea el veredicto sería el mismo —`staging`
no empieza con ninguno de los tres prefijos del producto— pero el mensaje sería el equivocado:
«esa rama no puede editar el producto» se lee como una invitación a **renombrarla**, que es lo
peor que se puede hacer con la rama de integración. El mensaje correcto dice que el problema es
**dónde estás parado**.

## El nombre de la rama de feature no es decorativo

`feature/<NNN>-<descripcion-kebab>`, y el `NNN` es el del spec en `specs/mapa.json` — **no** el
número del issue, que es otro: los issues y los PR comparten contador en GitHub, así que el
spec `007` puede ser el issue `#23`.

De ese nombre salen dos cosas:

1. **El hook** pide el `NNN` en tres dígitos, y **sólo a las ramas `feature/`**: a `bugfix/` y
   `hotfix/` exigírselo las obligaría a inventar un número. Una `feature/` sin número bloquea la
   primera edición de `src/`.
2. **`derivar_mapa.py`** saca el número para decidir si el spec aterrizó. Un PR cuya rama no
   nombra ningún spec no mueve nada.

**Lo que el hook ya NO hace es cruzar el `NNN` contra `specs/mapa.json`.** Lo hizo hasta el
2026-09-08, y el efecto era que para escribir la primera línea de código había que haber abierto
el issue de GitHub y commiteado el mapa a `staging`.

**El cruce no se perdió: se mudó** a `test_criterios_de_la_rama.py`, que corre en el nodo
`harness` de `verificar.py` y en la CI, con el PR todavía abierto. Ahí llega igual de a tiempo y
no frena la primera edición: el spec se puede publicar **después** de empezar a escribir, pero no
después de mergear. **El derivador no lo cobra** y no está para eso — un PR cuya rama nombra un
`NNN` que el mapa no tiene no le agrega ninguna fila, a propósito: inventarla sería peor que la
falta.

Para el derivador el prefijo es abierto —`bugfix/012-…` cuenta igual— porque un spec puede
aterrizar por una rama que no se llame `feature/`. Es más ancho a propósito, para no perder un
merge sin decirlo.

## Cuándo NO hace falta un spec

Cuando el cambio no toca `src/`: un asset, un typo, la documentación, actualizar el addon, una
herramienta del harness. Ahí la rama se llama `harness/…`, `docs/…` o `ci/…` según qué toque, y
va directo a PR contra `staging`.

**Lo que no se puede es trabajar sobre `main` o `staging`.** El hook sólo protege un
directorio, pero la razón vale para todo: son ramas que reciben trabajo de otros.

## Los tres workflows

| Workflow | Cuándo | Qué hace |
|---|---|---|
| `verify.yml` | cada PR, y cada push a `staging` y `main` | corre `verificar.py` |
| `mapa.yml` | cada push a `staging` | deriva `specs/mapa.json` desde los PR y los issues, y lo commitea si cambió |
| `desplegar.yml` | cada push a `main`, y a mano | exporta a Web, publica en Vercel y verifica que se juegue. Ver [despliegue](./despliegue.md) |

**`mapa.yml` corre sobre `staging` y no sobre `main`**, y eso importa si algún día `main` se
protege con reglas: una Action que tiene que pushear a una rama con PR obligatorio no puede, y
abrir un PR desde la Action tampoco sirve —un PR creado con `GITHUB_TOKEN` no dispara
workflows, así que el check requerido nunca se satisface y el PR queda abierto para siempre—.
El mapa derivado llega a `main` con el PR de promoción, como todo lo demás.

## La carrera entre `verify.yml` y `mapa.yml`, y por qué el gate del mapa no corre en un push

Cuando el PR de un spec aterriza, ese push a `staging` dispara **los dos workflows a la vez**.
En ese commit el mapa todavía dice `Propuesto` —no puede decir otra cosa: el gate prohíbe
cambiarlo adentro del PR— y el PR ya figura `MERGED`, o sea exactamente la condición que el
gate declara mentira. `mapa.yml` la corrige en segundos, pero `verify` no lo espera: arranca
con el mismo commit y lee el mapa de **antes**.

Por eso el gate del mapa **sólo cruza contra GitHub en un PR**: fuera de un PR el mapa no es la
afirmación de nadie, es una derivada, y quien la calcula es el otro workflow. En un PR sí tiene
que estar consistente, y ahí el gate caza todo lo demás.

Sin esto, cada merge de spec dejaría la rama de integración en rojo con un rojo que ya está
arreglado y que nadie va a volver a correr — la forma más rápida conocida de que alguien apague
el gate.
