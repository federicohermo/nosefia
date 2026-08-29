"""Lo que las herramientas del harness comparten.

Todo lo que vive acá es **puro o inyectable**, y no por gusto: es lo que hace que tenga
tests. Los scripts de `.claude/scripts/` son el cableado —stdin, disco, red, `sys.exit`— y
no se pueden cubrir sin correrlos; lo que decide vive de este lado.
"""
