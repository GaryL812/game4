"""Export approved Blender sources; run Blender --background --python tools/create_assets.py.
Pass -- --output <directory> to validate exports without replacing shipped assets.
"""
from pathlib import Path
import argparse
import json
import sys
import bpy

ROOT = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, default=ROOT / "assets/models")
args = parser.parse_args(sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
manifest = json.loads((ROOT / "art/asset_manifest.json").read_text("utf-8"))
for entry in manifest:
    source = ROOT / "art" / (entry["name"] + ".blend")
    bpy.ops.wm.open_mainfile(filepath=str(source))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    triangles = 0
    for obj in meshes:
        evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        evaluated.to_mesh_clear()
    if triangles != entry["triangles"]:
        raise RuntimeError(f"{source.name}: expected {entry['triangles']} triangles, found {triangles}")
    target = args.output / entry["category"] / (entry["name"] + ".glb")
    target.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(target), export_format="GLB", export_yup=True)
    entry["bytes"] = target.stat().st_size
    print(f"EXPORTED {entry['name']} {triangles} triangles")
if args.output.resolve() == (ROOT / "assets/models").resolve():
    (ROOT / "art/asset_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
