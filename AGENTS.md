# Instrucciones para agentes

Leer y aplicar [CLAUDE.md](./CLAUDE.md). Es la fuente del contexto, las convenciones y los
comandos del proyecto. No duplicar su contenido aquí.

Antes de editar, leer los `AGENTS.md` de los directorios afectados y las reglas de
[.claude/rules](./.claude/rules/) que correspondan. El campo `paths` de cada regla define
su alcance desde la raíz del repositorio.

- Para GDScript, aplicar [gdscript.md](./.claude/rules/gdscript.md).
- Para cualquier `.tscn`, aplicar [presentacion.md](./.claude/rules/presentacion.md).

Las referencias a carga automática en `CLAUDE.md` corresponden a Claude Code.
Los demás agentes deben leer los archivos indicados.

## Codex

`.agents/` refleja el contenido versionable de `.claude/`. `.claude/` sigue siendo la fuente.
Editar allí y propagar cada cambio a la misma ruta dentro de `.agents/`.
Excluir configuraciones personales, cachés y worktrees de la copia.
El nodo `harness` verifica que ambas carpetas conserven los mismos archivos y contenido.

Codex descubre los comandos en `.agents/skills/<nombre>/SKILL.md`, junto con sus archivos de apoyo.
Invocarlos con `$nombre`, por ejemplo `$to-spec` o `$implement-feature`.
Si no aparecen, reiniciar Codex desde este repositorio.

Antes de editar, leer también las reglas aplicables de `.agents/rules/` según su campo `paths`.
Resolver sus rutas y enlaces como en los archivos originales de `.claude/`.
Para editar `.agents/scripts/`, aplicar `.claude/rules/herramientas.md`.

`.agents/settings.json` conserva la configuración de Claude Code; Codex no la carga como hooks.
Aplicar las restricciones de rama y worktrees de `CLAUDE.md` aunque no haya hooks activos.
Consultar `mapa_del_sistema` al iniciar y ejecutar `gdformat` después de editar GDScript.
Los comandos y las rutas a `.claude/` siguen siendo válidos desde la raíz del repositorio.
