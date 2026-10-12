#!/bin/bash
# Draw calls y tiempo de cuadro: la base contra sí misma, después base y propuesta alternadas.
S=/tmp/claude-0/-home-user-nosefia/4501b05d-e818-5c7c-9f61-c4ad75e7a081/scratchpad/f368
M=$S/medidas
mkdir -p $M
BASE=/tmp/f368-base
PROP=/home/user/nosefia/.claude/worktrees/agent-a8b30418e4737f0d8
medir() {
	cd "$1" || exit 2
	xvfb-run -a -s "-screen 0 1280x720x24" /usr/local/bin/godot --path . --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 1280x720 --script $S/fixture_368.gd -- medir $M/$2.json $2 > $S/med-$2.log 2>&1
	echo "$2: $?"
}
medir $BASE ruido-a
medir $BASE ruido-b
medir $BASE base-1
medir $PROP prop-1
medir $PROP prop-2
medir $BASE base-2
medir $BASE base-3
medir $PROP prop-3
