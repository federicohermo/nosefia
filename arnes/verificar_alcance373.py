from pathlib import Path
import subprocess,json,re
r=Path.cwd();s=Path(__file__).parent
p=subprocess.run(['rg','-n',r'AppChats|app_chats|App\.CHATS|chats_actualizados|pedir_marcar_leida|lectura_pedida|"nota_escrita"','src','test','specs','docs','.claude'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
assert p.returncode==1,p.stdout.decode('utf-8',errors='replace')
subprocess.run(['git','diff','--quiet','35009014d90c61bd0d719d7744e134bab99a7519','--','src/escenas/almacen.tscn','src/escenas/puestos/servicios_del_almacen.tscn','src/ui/hud.tscn','src/escenas/jugador.tscn','src/ui/pila_de_notificaciones.tscn','src/ui/interrupciones/pantalla_de_cierre.tscn','src/ui/interrupciones/menu_de_pausa.tscn','src/ui/diegetica/app_caja.tscn'],check=True)
f={'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'base_fija':subprocess.check_output(['git','rev-parse','refs/nosefia/base-373'],text=True).strip(),'base_apilada':'35009014d90c61bd0d719d7744e134bab99a7519','sin_retirados':True,'escenas_protegidas_sin_cambios':True}
(s/'373-alcance-final.json').write_text(json.dumps(f,indent=2),encoding='utf-8');print(json.dumps(f,indent=2))
