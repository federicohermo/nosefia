# Ramas

`staging` integra y `main` entrega. El resto de las ramas nombra, con su prefijo, qué toca.

| Rama | Qué es | Quién escribe ahí |
|---|---|---|
| `main` | **Lo que se entrega.** Cada entrega de la cátedra sale de acá | sólo un PR de promoción desde `staging` |
| `staging` | **Integra.** Es la rama default del repositorio | cualquiera, **también directo** |

## Los prefijos

El conjunto lo declara `gate_de_rama.py`, en dos partes: los prefijos que pueden editar `src/`
y los que no. El hook verifica sólo la primera: una rama que no toca `src/` no le pasa cerca.
El mensaje del hook manda acá para saber qué significa cada uno:

| Prefijo | Qué es |
|---|---|
| `feature/` | Código que parte de un spec: crea, modifica o borra una funcionalidad |
| `bugfix/` | Algo del producto está roto |
| `refactor/` | El mismo comportamiento del producto con otra forma |
| `improvement/` | Un cambio que no toca ningún spec y no es un bug: UI, arte, sonido, rendimiento |
| `harness/` | Scripts, gates, skills y workflows de `.github/`, aunque sea un refactor |
| `docs/` | La documentación |

**No hay `chore/`.** Se define por lo que no es, y termina siendo el cajón donde cae todo. Los
prefijos del repo dicen qué tocás.

`<tipo>/<issue>-<kebab>` cuando el cambio sale de un issue, y `<tipo>/<kebab>` cuando no. El
hook no pide el número, y el número va sin rellenar. Que una `feature/` parta de un spec lo mira el review del PR.

## Por qué dos ramas y no una

Las entregas tienen fecha y el trabajo no se detiene. Con una sola rama, la build de la entrega
sale de lo que haya en ese momento. Con `main` separada, lo que se entrega es una decisión: se
promueve `staging` a `main` con un PR que se mira.

## Todo se mergea con merge commit

`allow_squash_merge` y `allow_rebase_merge` están en `false` en la configuración del
repositorio, en Settings → General → Pull Requests. La única opción del botón es **Create a
merge commit**.

**Un squash rompe la promoción siguiente.** Deja en `main` un commit que no está en la historia
de `staging`, y la base común de las dos ramas no se mueve. La promoción siguiente vuelve a
proponer los mismos commits, y cada uno llega como conflicto. Un pedido escrito no lo frenó: por
eso la opción no está.

## A `staging` se commitea directo

En un repo de una persona, abrir una rama para mergearla en el minuto siguiente es ceremonia.
**Lo que se paga:** lo que se commitea directo no pasa por un PR. No hay dónde declarar
`AC-<COD>-### → test → resultado`, ni nada que cierre un issue.

**Un cambio que se quiere revisar o que cierra un issue va por su rama y su PR.** Lo demás puede
ir directo: un arreglo suelto, un asset, el harness, la documentación. `main` sigue bloqueada.

Un hotfix no lleva rama: es un commit directo sobre `staging`, con el mensaje empezando por
`hotfix:`.

## Los dos workflows

- `verify.yml` corre `verificar.py`. Por qué no enumera los nodos, en
  [verificación](../guides/verificacion.md).
- `desplegar.yml` corre sobre `main`, porque es lo que se entrega. Ver
  [despliegue](./despliegue.md).

Cuándo corre cada uno lo declara su bloque `on:`.
