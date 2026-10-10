"""Los tests de las herramientas del harness.

Corren con `unittest`, que viene con Python: el harness no tiene una sola dependencia de
runtime, y eso es deliberado. Lo único que se instala en esta máquina es `gdtoolkit`, que es
el linter del juego y no de estas herramientas.

Se corren solos con `python .claude/scripts/verificar.py --solo harness`, y como parte de
`verificar.py`, que es lo que hay que correr antes de un PR.
"""
