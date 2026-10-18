from __future__ import annotations

from dataclasses import dataclass, field
from math import cos, pi, sin, sqrt
from pathlib import Path
from random import Random


Vec3 = tuple[float, float, float]
Vec2 = tuple[float, float]
TILES = {
    "plastic": (0.015, 0.515),
    "refuse": (0.015, 0.515),
    "paper": (0.515, 0.515),
    "cardboard": (0.015, 0.015),
    "can": (0.515, 0.015),
}


def sub(a: Vec3, b: Vec3) -> Vec3:
    return tuple(a[i] - b[i] for i in range(3))


def cross(a: Vec3, b: Vec3) -> Vec3:
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def dot(a: Vec3, b: Vec3) -> float:
    return sum(a[i] * b[i] for i in range(3))


def unit(a: Vec3) -> Vec3:
    length = sqrt(dot(a, a))
    return tuple(value / length for value in a)


def uv(tile: str, u: float, v: float) -> Vec2:
    origin = TILES[tile]
    return origin[0] + u * 0.47, origin[1] + v * 0.47


@dataclass
class Corner:
    vertex: int
    uv: Vec2
    normal: Vec3


@dataclass
class Mesh:
    name: str
    positions: list[Vec3] = field(default_factory=list)
    faces: list[list[Corner]] = field(default_factory=list)

    def vertex(self, point: Vec3) -> int:
        self.positions.append(point)
        return len(self.positions) - 1

    def face(self, indices: list[int], texture: list[Vec2],
             outward: Vec3, normals: list[Vec3] | None = None) -> None:
        normal = unit(cross(sub(self.positions[indices[1]], self.positions[indices[0]]),
                            sub(self.positions[indices[2]], self.positions[indices[0]])))
        if dot(normal, outward) < 0:
            indices = indices[::-1]
            texture = texture[::-1]
            normals = normals[::-1] if normals is not None else None
            normal = tuple(-value for value in normal)
        face = [Corner(index, texture[i], normals[i] if normals else normal)
                for i, index in enumerate(indices)]
        for i in range(1, len(face) - 1):
            self.faces.append([face[0], face[i], face[i + 1]])

    def write(self, path: Path) -> None:
        lines = [f"o {self.name}"]
        lines.extend("v %.6f %.6f %.6f" % point for point in self.positions)
        corners = [corner for face in self.faces for corner in face]
        lines.extend("vt %.6f %.6f" % corner.uv for corner in corners)
        lines.extend("vn %.6f %.6f %.6f" % corner.normal for corner in corners)
        for i, face in enumerate(self.faces):
            lines.append("f " + " ".join(
                f"{corner.vertex + 1}/{i * 3 + j + 1}/{i * 3 + j + 1}"
                for j, corner in enumerate(face)))
        path.write_text("\n".join(lines) + "\n", encoding="ascii")


def ring_surface(mesh: Mesh, rings: list[list[Vec3]], tile: str,
                 smooth: bool, cap_bottom: bool = True, cap_top: bool = True) -> None:
    indices = [[mesh.vertex(point) for point in ring] for ring in rings]
    segments = len(rings[0])
    ring_normals: list[list[Vec3]] = []
    for k, ring in enumerate(rings):
        previous = rings[max(0, k - 1)]
        following = rings[min(len(rings) - 1, k + 1)]
        ring_normals.append([
            unit(cross(sub(following[i], previous[i]),
                       sub(ring[(i + 1) % segments], ring[(i - 1) % segments])))
            for i in range(segments)
        ])
    for k in range(len(rings) - 1):
        for i in range(segments):
            j = (i + 1) % segments
            texture = [uv(tile, i / segments, k / (len(rings) - 1)),
                       uv(tile, i / segments, (k + 1) / (len(rings) - 1)),
                       uv(tile, (i + 1) / segments, (k + 1) / (len(rings) - 1)),
                       uv(tile, (i + 1) / segments, k / (len(rings) - 1))]
            normals = [ring_normals[k][i], ring_normals[k + 1][i],
                       ring_normals[k + 1][j], ring_normals[k][j]]
            mesh.face([indices[k][i], indices[k + 1][i], indices[k + 1][j], indices[k][j]],
                      texture, normals[0], normals if smooth else None)
    for k, enabled, direction in [(0, cap_bottom, -1), (-1, cap_top, 1)]:
        if not enabled:
            continue
        center = tuple(sum(point[a] for point in rings[k]) / segments for a in range(3))
        middle = mesh.vertex(center)
        for i in range(segments):
            j = (i + 1) % segments
            texture = [uv(tile, 0.5, 0.5),
                       uv(tile, 0.5 + 0.48 * cos(i * 2 * pi / segments),
                          0.5 + 0.48 * sin(i * 2 * pi / segments)),
                       uv(tile, 0.5 + 0.48 * cos(j * 2 * pi / segments),
                          0.5 + 0.48 * sin(j * 2 * pi / segments))]
            mesh.face([middle, indices[k][i], indices[k][j]], texture, (0, direction, 0))


def folded_sheet(mesh: Mesh, outline: list[Vec3], tile: str,
                 thickness: float, texture: list[Vec2] | None = None) -> None:
    top = [mesh.vertex(point) for point in outline]
    bottom = [mesh.vertex((x, y - thickness, z)) for x, y, z in outline]
    if texture is None:
        xs = [point[0] for point in outline]
        zs = [point[2] for point in outline]
        texture = [uv(tile, (x - min(xs)) / (max(xs) - min(xs)),
                      (z - min(zs)) / (max(zs) - min(zs))) for x, _, z in outline]
    mesh.face(top, texture, (0, 1, 0))
    mesh.face(bottom, texture, (0, -1, 0))
    center = tuple(sum(point[a] for point in outline) / len(outline) for a in range(3))
    for i in range(len(outline)):
        j = (i + 1) % len(outline)
        outward = (outline[i][0] - center[0], 0, outline[i][2] - center[2])
        mesh.face([top[i], bottom[i], bottom[j], top[j]],
                  [texture[i], texture[i], texture[j], texture[j]], outward)


def make_bag() -> Mesh:
    mesh = Mesh("trash_bag")
    random = Random(402)
    segments = 12
    profiles = [(-0.143, 0.066, 0.060, -0.006, 0.002),
                (-0.118, 0.099, 0.087, -0.004, 0.003),
                (-0.065, 0.108, 0.097, 0.001, -0.002),
                (0.024, 0.079, 0.071, -0.004, 0.001),
                (0.080, 0.047, 0.044, 0.006, 0.001),
                (0.118, 0.014, 0.014, 0.012, -0.004)]
    lobe = [random.uniform(0.91, 1.04) for _ in range(segments)]
    rings = []
    for k, (height, width, depth, dx, dz) in enumerate(profiles):
        ring = []
        for i in range(segments):
            angle = pi / 2 + i * 2 * pi / segments
            fold = lobe[i] * (1 + 0.025 * sin(i * 2.8 + k))
            ring.append((dx + width * fold * cos(angle),
                         height + 0.002 * sin(i * 2.3 + k),
                         dz + depth * fold * sin(angle)))
        rings.append(ring)
    ring_surface(mesh, rings, "plastic", True)
    knot = [[(0.012 + rx * cos(i * pi / 3), y, -0.004 + rz * sin(i * pi / 3))
             for i in range(6)]
            for y, rx, rz in [(0.116, 0.014, 0.012), (0.132, 0.023, 0.017),
                              (0.145, 0.012, 0.010)]]
    ring_surface(mesh, knot, "plastic", False)
    folded_sheet(mesh, [(0.008, 0.139, -0.009), (0.034, 0.144, -0.008),
                        (0.062, 0.177, 0.004), (0.048, 0.182, 0.019),
                        (0.023, 0.158, 0.012)], "plastic", 0.003)
    folded_sheet(mesh, [(0.017, 0.142, -0.007), (-0.003, 0.141, 0.008),
                        (-0.037, 0.168, 0.003), (-0.046, 0.164, -0.014),
                        (-0.008, 0.153, -0.018)], "plastic", 0.003)
    return mesh


def crumpled_paper(mesh: Mesh, center: Vec3, scale: Vec3, seed: int) -> None:
    random = Random(seed)
    segments = 7
    rings = []
    for k, (height, radius) in enumerate([(-0.6, 0.56), (0.0, 1.0), (0.55, 0.62)]):
        ring = []
        for i in range(segments):
            angle = i * 2 * pi / segments + k * 0.22
            crease = random.uniform(0.76, 1.13)
            ring.append((center[0] + cos(angle) * radius * crease * scale[0],
                         center[1] + (height + random.uniform(-0.18, 0.18)) * scale[1],
                         center[2] + sin(angle) * radius * crease * scale[2]))
        rings.append(ring)
    ring_surface(mesh, rings, "paper", False)


def dented_can(mesh: Mesh) -> None:
    segments = 10
    center = (0.145, -0.026, -0.110)
    direction = unit((0.85, 0.08, -0.52))
    across = unit((0.52, 0.0, 0.85))
    up = unit(cross(across, direction))
    profiles = [(-0.073, 0.030), (-0.067, 0.034), (-0.054, 0.035),
                (0.051, 0.034), (0.065, 0.032), (0.070, 0.029)]
    rings = []
    for k, (distance, radius) in enumerate(profiles):
        ring = []
        for i in range(segments):
            angle = i * 2 * pi / segments
            dent = 0.69 if k in (2, 3) and i in (2, 3) else 1.0
            ring.append(tuple(center[a] + direction[a] * distance
                              + across[a] * radius * cos(angle) * dent
                              + up[a] * radius * sin(angle) for a in range(3)))
        rings.append(ring)
    indices = [[mesh.vertex(point) for point in ring] for ring in rings]
    for k in range(len(rings) - 1):
        tile = "paper" if k in (0, 4) else "can"
        for i in range(segments):
            j = (i + 1) % segments
            outward = sub(rings[k][i], tuple(center[a] + direction[a] * profiles[k][0]
                                             for a in range(3)))
            mesh.face([indices[k][i], indices[k + 1][i], indices[k + 1][j], indices[k][j]],
                      [uv(tile, i / segments, k / 5), uv(tile, i / segments, (k + 1) / 5),
                       uv(tile, (i + 1) / segments, (k + 1) / 5),
                       uv(tile, (i + 1) / segments, k / 5)], outward)
    for k, sign in [(0, -1), (-1, 1)]:
        normal = tuple(sign * value for value in direction)
        texture = [uv("paper", 0.5 + 0.44 * cos(i * 2 * pi / segments),
                      0.5 + 0.44 * sin(i * 2 * pi / segments)) for i in range(segments)]
        mesh.face(indices[k], texture, normal)


def make_overflow() -> Mesh:
    mesh = Mesh("trash_overflow")
    outline = [(0, -1), (0.88, -1), (1, -0.82), (1, 0), (1, 0.82), (0.88, 1),
               (0, 1), (-0.88, 1), (-1, 0.82), (-1, 0), (-1, -0.82), (-0.88, -1)]
    segments = len(outline)
    rings = []
    profiles = [(-0.248, 0.110, 0.095), (-0.179, 0.246, 0.214),
                (-0.093, 0.299, 0.261), (-0.078, 0.305, 0.267)]
    for k, (height, width, depth) in enumerate(profiles):
        ring = []
        for i, (x, z) in enumerate(outline):
            crease = 1 + 0.004 * sin(i * 2.1 + k)
            rim = 0.004 * sin(i * 2.7) if k >= 2 else 0
            ring.append((width * crease * x, height + rim, depth * crease * z))
        rings.append(ring)
    ring_surface(mesh, rings, "refuse", False, True, False)
    inner = [(x * 0.54, y + 0.028, z * 0.54) for x, y, z in rings[-1]]
    rim_indices = [mesh.vertex(point) for point in rings[-1]]
    inner_indices = [mesh.vertex(point) for point in inner]
    middle = mesh.vertex((0.0, -0.025, 0.0))
    for i in range(segments):
        j = (i + 1) % segments
        texture = [uv("refuse", 0.5 + x * 1.5, 0.5 + z * 1.7)
                   for x, _, z in [rings[-1][i], inner[i], inner[j], rings[-1][j]]]
        mesh.face([rim_indices[i], inner_indices[i], inner_indices[j], rim_indices[j]],
                  texture, (0, 1, 0))
        mesh.face([middle, inner_indices[i], inner_indices[j]],
                  [uv("refuse", 0.5, 0.5), texture[1], texture[2]], (0, 1, 0))
    papers = [((-0.205, -0.051, 0.115), (0.066, 0.060, 0.054), 81),
              ((-0.150, -0.054, -0.165), (0.071, 0.062, 0.048), 82),
              ((0.190, -0.058, 0.155), (0.055, 0.048, 0.062), 83)]
    for center, scale, seed in papers:
        crumpled_paper(mesh, center, scale, seed)
    folded_sheet(mesh, [(-0.118, -0.019, -0.052), (0.010, 0.005, -0.064),
                        (0.063, -0.008, 0.039), (-0.091, -0.029, 0.047)],
                 "cardboard", 0.005)
    folded_sheet(mesh, [(-0.118, -0.019, -0.052), (-0.091, -0.029, 0.047),
                        (-0.159, 0.004, 0.027), (-0.176, 0.012, -0.042)],
                 "cardboard", 0.004)
    folded_sheet(mesh, [(0.010, 0.005, -0.064), (-0.118, -0.019, -0.052),
                        (-0.097, 0.023, -0.116), (0.018, 0.033, -0.111)],
                 "cardboard", 0.004)
    dented_can(mesh)
    return mesh


if __name__ == "__main__":
    destination = Path(__file__).resolve().parent
    make_bag().write(destination / "bag.obj")
    make_overflow().write(destination / "overflow.obj")
