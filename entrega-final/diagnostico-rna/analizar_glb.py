"""Deltas reales de los dos GLB conservados; no reconstruye salidas textuales ausentes."""
import hashlib
import json
import math
from pathlib import Path
import struct

base = Path(__file__).resolve().parent
source = base.parent/"434-recursos-c780"


class Glb:
    def __init__(self, path):
        self.raw = path.read_bytes()
        length, _ = struct.unpack_from("<II", self.raw, 12)
        self.doc = json.loads(self.raw[20:20+length])
        offset = 20+length
        length, _ = struct.unpack_from("<II", self.raw, offset)
        self.bin = self.raw[offset+8:offset+8+length]

    def accessor(self, index):
        spec = self.doc["accessors"][index]
        view = self.doc["bufferViews"][spec["bufferView"]]
        fmt, width = {5120: ("b", 1), 5121: ("B", 1), 5122: ("h", 2), 5123: ("H", 2),
                      5125: ("I", 4), 5126: ("f", 4)}[spec["componentType"]]
        n = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[spec["type"]]
        step = view.get("byteStride", width*n)
        start = view.get("byteOffset", 0)+spec.get("byteOffset", 0)
        return [struct.unpack_from("<"+fmt*n, self.bin, start+i*step) for i in range(spec["count"])]

    def images(self):
        out = {}
        for i, image in enumerate(self.doc.get("images", [])):
            view = self.doc["bufferViews"][image["bufferView"]]
            off = view.get("byteOffset", 0)
            out[image.get("name", str(i))] = hashlib.sha256(self.bin[off:off+view["byteLength"]]).hexdigest()
        return out


paths = [source/"434-exportacion-primera.glb", source/"434-exportacion-repetida.glb"]
a, b = map(Glb, paths)
nodes = []
assert [n.get("name") for n in a.doc["nodes"]] == [n.get("name") for n in b.doc["nodes"]]
for i, (one, two) in enumerate(zip(a.doc["nodes"], b.doc["nodes"])):
    if one != two:
        fields = {}
        for key in one.keys()|two.keys():
            x, y = one.get(key), two.get(key)
            if x == y:
                continue
            item = {"primera": x, "repetida": y}
            if isinstance(x, list) and isinstance(y, list) and len(x) == len(y) and all(
                    isinstance(v, (int, float)) for v in x+y):
                item["delta_max"] = max(abs(u-v) for u, v in zip(x, y))
            fields[key] = item
        nodes.append({"index": i, "name": one.get("name"), "fields": fields})

meshes = []
for i, (one, two) in enumerate(zip(a.doc["meshes"], b.doc["meshes"])):
    assert one.get("name") == two.get("name")
    assert len(one["primitives"]) == len(two["primitives"])
    changes = []
    for j, (p, q) in enumerate(zip(one["primitives"], two["primitives"])):
        assert p.keys() == q.keys()
        assert p["attributes"].keys() == q["attributes"].keys()
        assert p.get("material") == q.get("material")
        for key in ["indices", *p["attributes"]]:
            ix = p[key] if key == "indices" else p["attributes"][key]
            iy = q[key] if key == "indices" else q["attributes"][key]
            x, y = a.accessor(ix), b.accessor(iy)
            assert len(x) == len(y)
            if x != y:
                changes.append({"primitive": j, "attribute": key,
                                "items": len(x), "changed_items": sum(u != v for u, v in zip(x, y)),
                                "delta_max": max(abs(c-d) for u, v in zip(x, y) for c, d in zip(u, v))})
    if changes:
        meshes.append({"index": i, "name": one.get("name"), "changes": changes})

out = {"inputs": {str(p): {"bytes": p.stat().st_size, "sha256": hashlib.sha256(p.read_bytes()).hexdigest()} for p in paths},
       "nodes": len(a.doc["nodes"]), "meshes": len(a.doc["meshes"]), "nodes_changed": nodes,
       "mesh_attributes_changed": meshes, "materials_identical": a.doc.get("materials") == b.doc.get("materials"),
       "images_identical": a.images() == b.images(), "image_count": len(a.images()),
       "limite": "Comparación directa de GLB conservados. No recupera ni reconstruye los tres textos de primera pasada que no se copiaron."}
(base/"deltas-glb.json").write_bytes(json.dumps(out, indent=2, ensure_ascii=False).encode("utf-8"))
print(json.dumps({k:v for k,v in out.items() if k not in ("inputs", "limite")}, indent=2))
