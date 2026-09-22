# Ramas

Cada rama tiene una pregunta distinta, y el prefijo la contesta.

| Rama | Qué es | Quién escribe ahí |
|---|---|---|
| `main` | **Lo que se entrega.** Cada entrega de la cátedra sale de acá | sólo un PR de promoción desde `staging` |
| `staging` | **Integra.** Es la rama default del repositorio | cualquiera, **también directo** |
| `feature/<issue>-<kebab>` | Un issue, uno | quien lo implementa |
| `bugfix/<kebab>` | Algo del producto está roto. Puede salir de un issue o no | quien lo arregla |
| `hotfix/<kebab>` | Urgente, contra lo que ya se entregó | quien lo arregla |
| `harness/<kebab>` | El harness de `.claude/`: scripts, gates, skills | quien lo toque |
| `docs/<kebab>` | La documentación | quien la escriba |
| `ci/<kebab>` | Los workflows de `.github/` | quien los toque |

## Los prefijos son un conjunto cerrado, y sólo la mitad se puede verificar

Los tres primeros —`feature/`, `bugfix/`, `hotfix/`— son los de la [convención de
Atlassian](https://support.atlassian.com/bitbucket-cloud/kb/how-to-prevent-creating-branches-with-the-prefixes-that-are-not-defined-in-the-branching-model-using-git-hooks-in-bitbucket-cloud/),
y son **los únicos que pueden editar `src/`**. Eso lo verifica `gate_de_rama.py` en cada
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

O sea: **el trabajo de un issue sigue necesitando su `feature/<issue>-…`**. Lo que se liberó es
todo lo demás: un arreglo suelto, un asset, el harness, la documentación.

`main` sigue bloqueada. Es lo que se entrega, y llega por el PR de promoción.

## El nombre de la rama de feature no es decorativo

`feature/<issue>-<descripcion-kebab>`, y el número es **el del issue de GitHub** — el issue es el
único plan, y lo numera GitHub al abrirlo.

De ese nombre sale una cosa, y alcanza: **el hook** pide el número, y **sólo a las ramas
`feature/`**. A `bugfix/` y `hotfix/` exigírselo las obligaría a inventar uno. Una `feature/` sin
número bloquea la primera edición de `src/`.

**Los dígitos son los que haya.** GitHub numera desde 1 y no rellena, así que rellenar a tres
separaría la rama del issue que nombra. `feature/38-…` y `feature/1234-…` valen los dos.

**El hook no consulta GitHub.** Mira el nombre y nada más: un número que no existe no frena la
primera edición. Poner una llamada de red adentro de cada escritura haría un gate lento, y un
gate lento se apaga. Lo que cobra que el trabajo esté completo es el PR, con el nodo `specs` de
`verificar.py` corriendo encima.

## Los dos workflows

| Workflow | Cuándo | Qué hace |
|---|---|---|
| `verify.yml` | cada PR, y cada push a `staging` y `main` | corre `verificar.py` |
| `desplegar.yml` | cada push a `main`, y a mano | exporta a Web, publica en Vercel y verifica que se juegue. Ver [despliegue](./despliegue.md) |

`desplegar.yml` corre sobre `main` porque es lo que se entrega. `verify.yml` corre en todos
lados: es el mismo `verificar.py` que se corre a mano, y por eso la CI **no enumera los nodos**.
