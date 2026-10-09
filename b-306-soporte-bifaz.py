from pathlib import Path
p=Path.cwd()/'src/escenas/puestos/exterior_del_almacen.gd';t=p.read_text(encoding='utf-8')
a=t.index('\t\t(\n\t\t\t_malla(',t.index('for limites: Rect2'))
b=t.index('\n\tvar fondo',a)
block=t[a:b]
block=block.replace('\t\t(\n\t\t\t_malla(', '\t\tvar pavimento := _malla(',1)
block=block.replace('\n\t\t\t. create_trimesh_collision()\n\t\t)', '\n\t\tpavimento.create_trimesh_collision()\n\t\tvar cuerpo := pavimento.get_child(0) as StaticBody3D\n\t\tvar forma := cuerpo.get_child(0) as CollisionShape3D\n\t\t# El dibujo usa ambas caras: el soporte conserva sus triángulos y recibe desde arriba.\n\t\t(forma.shape as ConcavePolygonShape3D).backface_collision = true')
t=t[:a]+block+t[b:];p.write_text(t,encoding='utf-8')
