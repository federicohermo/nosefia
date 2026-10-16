from pathlib import Path

root = Path(__file__).parent
src = (root.parent / "carril-C-431/exportar_paquete431.py").read_text(encoding="utf-8")
assert src.count("commit='6d60f82c16bbbc1f7182e656ebead8df8bf5ad87'") == 1
src = src.replace("commit='6d60f82c16bbbc1f7182e656ebead8df8bf5ad87'", "commit='893109542cafeef5a6483a8b3f041e5dc39c8f05'")
src = src.replace("431-export-02", "431-export-03").replace("EXPORT431", "EXPORT22").replace("GODOT431", "GODOT22")
(root / "exportar_paquete22.py").write_text(src,encoding="utf-8")
src = (root / "capturar_nativo22.gd").read_text(encoding="utf-8")
inicio = src.index("\nfunc _foto(")
fin = src.index("\nfunc _ejercer()",inicio)
src = src[:inicio] + '\nfunc _foto(nombre: String) -> void:\n\tprint("PCK22_ESTADO ", nombre)\n\tawait _cuadros()\n\n' + src[fin:]
src = src.replace("\troot.mode = Window.MODE_WINDOWED\n", "").replace("NATIVO22", "PAQUETE22")
(root / "paquete22.gd").write_text(src,encoding="utf-8")
print("EXPORT/PCK22 preparados sin ejecutar")
