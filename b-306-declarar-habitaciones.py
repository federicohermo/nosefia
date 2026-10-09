from pathlib import Path
import json
root=Path.cwd(); s=Path(__file__).parent
parts=json.loads((s/'b-306-particion-305.json').read_text(encoding='utf-8'))['parts']
p=root/'src/escenas/puestos/estructura_del_almacen.tscn'; t=p.read_text(encoding='utf-8')
t=t.replace('[ext_resource type="PackedScene"', '[ext_resource type="Script" path="res://src/escenas/puestos/habitaciones_del_almacen.gd" id="habitaciones"]\n\n[ext_resource type="PackedScene"',1)
t+='\n[node name="HabitacionesDelAlmacen" type="Node3D" parent="."]\nscript = ExtResource("habitaciones")\n'
for name, boxes in parts.items():
 vals=[]
 for a in boxes:
  vals.append('AABB('+', '.join(f'{v:.9f}'.rstrip('0').rstrip('.') for v in a[:3]+[a[i+3]-a[i] for i in range(3)])+')')
 t+=name+' = Array[AABB](['+', '.join(vals)+'])\n'
p.write_text(t,encoding='utf-8')
p=root/'src/escenas/almacen.tscn';t=p.read_text(encoding='utf-8').replace('"_programa_de_tickets")]', '"_programa_de_tickets", "_habitaciones")]').replace('_programa_de_tickets = NodePath("Interfaz/ProgramaDeTickets")','_programa_de_tickets = NodePath("Interfaz/ProgramaDeTickets")\n_habitaciones = NodePath("Estructura/HabitacionesDelAlmacen")');p.write_text(t,encoding='utf-8')
