#!/bin/bash
# Capturas de la base y de las variantes, desde las tres vistas.
S=/tmp/claude-0/-home-user-nosefia/4501b05d-e818-5c7c-9f61-c4ad75e7a081/scratchpad/f368
C=$S/capturas/368
rm -rf $C
mkdir -p $C
correr() {
	xvfb-run -a -s "-screen 0 1280x720x24" /usr/local/bin/godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 --script $S/fixture_368.gd -- "$@" > $S/cap-$3.log 2>&1
	echo "$3: $?"
}
cd /tmp/f368-base || exit 2
correr capturar $C base
cd /home/user/nosefia/.claude/worktrees/agent-a8b30418e4737f0d8 || exit 2
correr capturar $C propuesta,identidad:1.0:1.0,suave:0.7:0.85,media:0.45:0.7,fuerte:0.2:0.55
