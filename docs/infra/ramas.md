# Ramas

Tres roles, y cada uno tiene una pregunta distinta.

| Rama | Qué es | Quién escribe ahí |
|---|---|---|
| `main` | **Lo que se entrega.** Cada entrega de la cátedra sale de acá | sólo un PR de promoción desde `staging` |
| `staging` | **Integra.** Es la rama default del repositorio | los PR de cada spec, y los commits del mapa |
| `feature/<NNN>-<kebab>` | Un spec, uno | quien lo implementa |

## Por qué dos ramas y no una

Porque las entregas tienen fecha y el trabajo no se detiene. Con una sola rama, la build de la
entrega sale de lo que haya en ese momento — incluido lo que alguien mergeó esa mañana. Con
`main` separada, lo que se entrega es una decisión: se promueve `staging` a `main` cuando el
estado sirve, y esa promoción es un PR que se mira.

## `staging` es la default, y eso la hace peligrosa

Es adonde apunta cada `gh pr create` y cada clone fresco: **el lugar más fácil de todo el repo
donde quedarse parado sin haberlo decidido.**

Por eso el hook la nombra explícitamente. Sin esa línea el veredicto sería el mismo —ninguna
rama que no matchee `feature/<NNN>-` pasa— pero el mensaje sería el equivocado: «la rama
`staging` no nombra un spec» se lee como una invitación a **renombrarla**, que es lo peor que se
puede hacer con la rama de integración. El mensaje correcto dice que el problema es **dónde
estás parado**.

## El nombre de la rama de feature no es decorativo

`feature/<NNN>-<descripcion-kebab>`, y el `NNN` es el del spec en `specs/mapa.json` — **no** el
número del issue, que es otro: los issues y los PR comparten contador en GitHub, así que el
spec `007` puede ser el issue `#23`.

De ese nombre salen dos cosas:

1. **El hook** saca el número para verificar que el spec exista. Una rama con otro nombre
   bloquea la primera edición de `src/`.
2. **`derivar_mapa.py`** saca el número para decidir si el spec aterrizó. Un PR cuya rama no
   nombra ningún spec no mueve nada.

El prefijo se acepta abierto —`fix/012-…`, `chore/012-…` cuentan igual para el derivador—
porque un spec puede aterrizar por una rama que no se llame `feature/`. Lo que el **hook** pide
es `feature/`; el derivador es más ancho a propósito, para no perder un merge sin decirlo.

## Cuándo NO hace falta un spec

Cuando el cambio no toca `src/` ni `docs/`: un asset, un typo, actualizar el addon, un
`chore/`. Ahí la rama se llama `fix/…` o `chore/…` y va directo a PR contra `staging`.

**Lo que no se puede es trabajar sobre `main` o `staging`.** El hook sólo protege dos
directorios, pero la razón vale para todo: son ramas que reciben trabajo de otros.

## Los dos workflows

| Workflow | Cuándo | Qué hace |
|---|---|---|
| `verify.yml` | cada PR, y cada push a `staging` y `main` | corre `verificar.py` |
| `mapa.yml` | cada push a `staging` | deriva `specs/mapa.json` desde los PR y los issues, y lo commitea si cambió |

**`mapa.yml` corre sobre `staging` y no sobre `main`**, y eso importa si algún día `main` se
protege con reglas: una Action que tiene que pushear a una rama con PR obligatorio no puede, y
abrir un PR desde la Action tampoco sirve —un PR creado con `GITHUB_TOKEN` no dispara
workflows, así que el check requerido nunca se satisface y el PR queda abierto para siempre—.
El mapa derivado llega a `main` con el PR de promoción, como todo lo demás.

## La carrera entre los dos, y por qué el gate del mapa no corre en un push

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
