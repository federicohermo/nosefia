from pathlib import Path

out = Path(__file__).parent
s = Path('C:/Users/fede_/orca/workspaces/nosefia/darter/.claude/scratch/batch-64-309')
text = (s / 'b-306-focal3.py').read_text(encoding='utf-8')
start = text.index("suites = [")
end = text.index("env = dict", start)
text = text[:start] + "suites = ['test/escenas/puestos/contenedor_de_basura_test.gd']\n" + text[end:]
(out / 'b-306-focal4.py').write_text(text, encoding='utf-8')
full = (s / 'b-306-full2.py').read_text(encoding='utf-8')
full = full.replace('b-306-full2', 'b-306-full3')
(s / 'b-306-full3.py').write_text(full, encoding='utf-8')
