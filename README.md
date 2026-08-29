# No se fía

Un empleado nuevo hace su primer turno nocturno en un almacén. Atiende por la ventanilla,
cumple las tareas que le dejó el jefe y, con el correr de los días, empieza a notar que algo no
cierra. Cada minuto que dedica a averiguar qué pasa es un minuto que no dedica a su trabajo.

Proyecto de la cátedra de Videojuegos (FADU) — **equipo Manada**. Godot 4.4, GDScript.

## Empezar

```bash
pip install "gdtoolkit==4.*"                     # el linter de GDScript
# y declarar GODOT_BIN con la ruta al ejecutable de Godot
python .claude/scripts/verificar.py              # correr todo
```

El paso a paso —incluidas las dos trampas de Windows que cuestan una tarde cada una— está en
[docs/guides/quickstart.md](./docs/guides/quickstart.md).

Abrí `project.godot` con Godot 4.4 para trabajar en el juego. gdUnit4 viene con el repo: no hay
nada que instalar.

## Cómo se trabaja acá

- **Un cambio empieza por un spec**, y el spec es un issue de GitHub. No se edita `src/` ni
  `docs/` sin uno: lo bloquea un hook, no la buena voluntad.
- **El test va primero.** Todo script de `src/dominio/` y `src/sistemas/` tiene su espejo en
  `test/`, y un gate lo verifica.
- **`staging` integra, `main` es lo que se entrega.** Cada spec entra por su rama
  `feature/<NNN>-<kebab>` y su PR.
- **`python .claude/scripts/verificar.py` antes de cada PR.** Es lo mismo que corre la CI.

El detalle está en [CLAUDE.md](./CLAUDE.md) —que es también la guía para los agentes— y en
[docs/](./docs/README.md).

## Dónde está cada cosa

| Qué | Dónde |
|---|---|
| Diseño: pitch, core loop, sistemas, alcance | el **GDD** en Notion (documento vivo) |
| Tareas, sprints y backlog | **Notion** |
| Referencias estéticas | **Figma** · **Miro** |
| Referencias de audio | **Drive** |
| Trabajo planificado y deuda técnica | [GitHub Issues](https://github.com/federicohermo/nosefia/issues) |
| Documentación técnica | [docs/](./docs/README.md) |

## El equipo

Camila Dos Santos · Federico Hermo · Martín Páez Gerez · Tiago Picolo · Mía Sanz Pedemonte
