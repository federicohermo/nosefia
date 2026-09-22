# Ramas

Cada rama tiene una pregunta distinta, y el prefijo la contesta.

| Rama | Qué es | Quién escribe ahí |
|---|---|---|
| `main` | **Lo que se entrega.** Cada entrega de la cátedra sale de acá | sólo un PR de promoción desde `staging` |
| `staging` | **Integra.** Es la rama default del repositorio | cualquiera, **también directo** |
| `feature/<kebab>` | Código que parte de un spec: crea, modifica o borra una funcionalidad | quien lo implementa |
| `bugfix/<kebab>` | Algo del producto está roto | quien lo arregla |
| `refactor/<kebab>` | El mismo comportamiento con otra forma | quien lo toque |
| `improvement/<kebab>` | Un cambio o un agregado que no toca ningún spec y no es un bug: UI, arte, sonido, rendimiento | quien lo toque |
| `harness/<kebab>` | El harness: scripts, gates, skills y los workflows de `.github/` | quien lo toque |
| `docs/<kebab>` | La documentación | quien la escriba |

## Los prefijos son un conjunto cerrado, y sólo una parte se puede verificar

Los cuatro primeros pueden editar `src/`. `feature/` y `bugfix/` son los de la [convención de
Atlassian](https://support.atlassian.com/bitbucket-cloud/kb/how-to-prevent-creating-branches-with-the-prefixes-that-are-not-defined-in-the-branching-model-using-git-hooks-in-bitbucket-cloud/),
y `refactor/` e `improvement/` cubren lo que no es spec ni bug. Que la rama tenga uno de los
cuatro lo verifica `gate_de_rama.py` en cada escritura.

**No hay `hotfix/`.** Un hotfix no es una rama: es un commit directo sobre `staging`, con el
mensaje empezando por `hotfix:`.

Los otros dos **no los verifica nadie, y no se podría**: el hook sólo protege `src/`, así que
una rama `docs/` que edita documentación no le pasa ni cerca. Están declarados igual porque el
mensaje del bloqueo tiene que poder ofrecerlos — «renombrá la rama» sin decir a qué no es una
salida.

**No hay `ci/`.** Los workflows de `.github/` son harness igual que los scripts y los gates, y
dos prefijos para lo mismo no se recuerdan. **Un refactor del harness sigue siendo `harness/`:**
lo que el prefijo contesta es qué toca, no de qué clase es el cambio. `refactor/` es para el
producto, que es lo que el hook necesita saber.

**Tampoco hay `chore/`**, que es el que la convención pone para «lo demás». Se define por lo que
no es, así que termina siendo el cajón donde cae todo; estos seis dicen qué tocás.

## Por qué dos ramas y no una

Porque las entregas tienen fecha y el trabajo no se detiene. Con una sola rama, la build de la
entrega sale de lo que haya en ese momento — incluido lo que alguien mergeó esa mañana. Con
`main` separada, lo que se entrega es una decisión: se promueve `staging` a `main` cuando el
estado sirve, y esa promoción es un PR que se mira.

## Todo se mergea con merge commit, y el botón del squash ya no existe

`allow_squash_merge` y `allow_rebase_merge` están en `false` en la configuración del repositorio
—Settings → General → Pull Requests—, así que la única opción del botón es **Create a merge
commit**.

**No es preferencia de estilo: un squash rompe la promoción siguiente.** `staging` → `main` no es
un PR común. Un squash deja en `main` un commit que no está en la historia de `staging`, así que
**la base común de las dos ramas no se mueve**: la promoción siguiente vuelve a proponer los
mismos commits contra un árbol que ya los tiene, y cada uno llega como conflicto. Medido: el
squash de #75 le costó a #110 **115 archivos en conflicto**.

Se pidió por escrito en el cuerpo de tres PR de promoción seguidos y se aplastó igual. Un pedido
en prosa que hay que acordarse de leer no es una regla — **por eso ahora la opción no está**.

## A `staging` se commitea directo

Desde el **2026-09-14**. El hook la bloqueaba, y en un repo de una persona abrir una rama para
mergearla en el minuto siguiente es ceremonia: el costo se paga en cada cambio y el beneficio
—que otro no pise trabajo ajeno— no existe acá.

**Lo que se paga, y es real:** lo que se commitea acá no pasa por ningún PR, así que no hay
dónde declarar `AC-<COD>-### → test → resultado` ni nada que cierre un issue.

O sea: **un cambio que se quiere revisar o que cierra un issue va por su rama y su PR**. Lo
que se liberó es todo lo demás: un arreglo suelto, un asset, el harness, la documentación.

`main` sigue bloqueada. Es lo que se entrega, y llega por el PR de promoción.

## El número del issue va si hay issue

`<tipo>/<issue>-<kebab>` cuando el cambio sale de un issue; `<tipo>/<kebab>` cuando no. El
número es el que GitHub le dio, sin rellenar.

**El hook no lo pide.** Hasta el 2026-09-22 lo exigía a `feature/`, y eso obligaba a abrir un
issue antes de escribir la primera línea. Un issue no es un spec: una `feature/` puede partir de
un spec escrito sin issue. Que una `feature/` parta de un spec lo mira el review del PR.

## Los dos workflows

| Workflow | Cuándo | Qué hace |
|---|---|---|
| `verify.yml` | cada PR, y cada push a `staging` y `main` | corre `verificar.py` |
| `desplegar.yml` | cada push a `main`, y a mano | exporta a Web, publica en Vercel y verifica que se juegue. Ver [despliegue](./despliegue.md) |

`desplegar.yml` corre sobre `main` porque es lo que se entrega. `verify.yml` corre en todos
lados: es el mismo `verificar.py` que se corre a mano, y por eso la CI **no enumera los nodos**.
