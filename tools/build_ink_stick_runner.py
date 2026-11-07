"""Build the Godot hero from the supplied Blender file without changing the source."""
import json
import math
from pathlib import Path

import bpy
from mathutils import Quaternion, Vector


MODEL_NAME = "runner_ink_stick"
TRIANGLE_BUDGET = 500
UP = Vector((0, 0, 1))
ACROSS = Vector((1, 0, 0))
BONE_AXIS = Vector((0, 1, 0))
LOOPS = {"Climb", "Celebrate", "SideSlide"}
FRAMES = {"Jump": 19, "Land": 10, "Flip": 20, "Hit": 19,
          "Celebrate": 31, "Climb": 25, "SideSlide": 22}


def optimize_mesh(mesh):
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    triangulate = mesh.modifiers.new("Triangulate for the mobile budget", "TRIANGULATE")
    bpy.ops.object.modifier_move_to_index(modifier=triangulate.name, index=0)
    bpy.ops.object.modifier_apply(modifier=triangulate.name)
    decimate = mesh.modifiers.new("Mobile triangle budget", "DECIMATE")
    decimate.ratio = TRIANGLE_BUDGET / len(mesh.data.polygons)
    bpy.ops.object.modifier_move_to_index(modifier=decimate.name, index=0)
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    triangles = len(mesh.data.polygons)
    assert 0 < triangles <= TRIANGLE_BUDGET

    # A vertex mask lets the wardrobe color the two ink ribbons without tinting
    # the original dry-brush atlas or the black ponytail.
    colors = mesh.data.color_attributes
    mask = colors.new(name="Ribbon tint mask", type="FLOAT_COLOR", domain="POINT")
    colors.active_color = mask
    ribbons = {g.index for g in mesh.vertex_groups if g.name.startswith("Ribbon_")}
    for vertex in mesh.data.vertices:
        total = sum(g.weight for g in vertex.groups)
        assert total > 0, f"Unweighted vertex {vertex.index}"
        weight = sum(g.weight for g in vertex.groups if g.group in ribbons) / total
        mask.data[vertex.index].color = (weight, weight, weight, 1)
    return triangles


def key_pose(rig, action, frame, t):
    for bone in rig.pose.bones:
        bone.rotation_mode = "QUATERNION"
        bone.matrix_basis.identity()
    rest = {p.name: p.bone.matrix_local.to_quaternion() for p in rig.pose.bones}

    def orientation(p):
        base = rest[p.name]
        if p.parent:
            base = orientation(p.parent) @ rest[p.parent.name].inverted() @ base
        return base @ p.rotation_quaternion

    def aim(name, vector):
        p = rig.pose.bones[name]
        p.rotation_quaternion = BONE_AXIS.rotation_difference(
            orientation(p).inverted() @ Vector(vector).normalized())

    def rotate(name, axis, angle):
        q = rest[name]
        rig.pose.bones[name].rotation_quaternion = q.inverted() @ Quaternion(axis, angle) @ q

    def offset_root(vector):
        rig.pose.bones["Root"].location = rest["Root"].inverted() @ Vector(vector)

    wave = math.sin(t * math.tau)
    pulse = math.sin(t * math.pi)
    # Body pitch and compression are local animation only. Gameplay owns the
    # actual jump, forward speed, wall position and collision height.
    lean, lower = {
        "Jump": (.22 - .29 * t, -.035 * pulse),
        "Land": (.14 + .35 * pulse, -.15 * pulse),
        "Flip": (.35 + .45 * pulse, 0),
        "Hit": (-.42 * pulse, -.10 * pulse),
        "Celebrate": (.035 * wave, .06 * pulse * pulse),
        "Climb": (.10 + .03 * wave, 0),
        "SideSlide": (.24 + .025 * wave, -.29),
    }[action]
    rotate("Spine", ACROSS, lean)
    rotate("Head", ACROSS, -.65 * lean)
    offset_root((0, 0, lower))

    for side, sign in ((".L", -1), (".R", 1)):
        swing = wave * sign
        # Each pair is (upper segment, lower segment) in Blender world axes.
        arms, legs = {
            "Jump": (((.33 * sign, -.68, .33 - .68 * t), (.14 * sign, -.68, .53 - .78 * t)),
                     ((.14 * sign, -.22 - .44 * (sign > 0) * pulse, -1),
                      (.05 * sign, .20 + .49 * (sign < 0) * pulse, -1))),
            "Land": (((.39 * sign, -.45, -.73), (.36 * sign, -.72, -.38)),
                     ((.17 * sign, -.18 - .40 * pulse, -1), (.04 * sign, .16 + .45 * pulse, -1))),
            "Flip": (((.15 * sign, -.63, -.51), (-.18 * sign, -.32, -.94)),
                     ((.20 * sign, -.43 - .80 * pulse, -1 + 1.35 * pulse),
                      ((.08 * sign, .48 + .40 * pulse, -1 - .14 * pulse)))),
            "Hit": (((.61 * sign, .35 * pulse, -.65), (.55 * sign, -.34, .23 + .46 * pulse)),
                    ((.19 * sign, -.49 * sign * pulse, -1), (.11 * sign, .29, -1))),
            "Celebrate": (((.52 * sign, -.16, .71 + .20 * swing), (.22 * sign, -.23, .91)),
                          ((.13 * sign, -.20 * swing, -1), (.03 * sign, .16 * pulse, -1))),
            "Climb": (((.30 * sign, -.43, .15 + .72 * swing), (.07 * sign, -.21, .83 + .2 * swing)),
                      ((.18 * sign, -.51 - .36 * swing, -.88 + .17 * swing),
                       (.04 * sign, .41 + .28 * swing, -1))),
            "SideSlide": (((.50 * sign, -.44 if sign < 0 else .12, -.43),
                           (.19 * sign, -.54, .52 + .08 * swing)),
                          ((.12 * sign, -.80 if sign < 0 else .63, -.76),
                           (.10 * sign, .28 if sign < 0 else .69, -1))),
        }[action]
        for prefix, direction in zip(("UpperArm", "Forearm", "Thigh", "Shin"), arms + legs):
            aim(prefix + side, direction)
        aim("Foot" + side, (.08 * sign, -1, -.22 if action != "Climb" else -.52))

    for name, amount in (("Tail_Base", .13), ("Tail_Tip", .19),
                         ("Ribbon_Main", .21), ("Ribbon_Thread", .27)):
        rotate(name, ACROSS, amount * (wave - .45 * pulse))
    if action == "Flip":
        angle = -t * math.tau
        pivot = Vector((0, 0, .91))
        rotation = Quaternion(ACROSS, angle)
        rotate("Root", ACROSS, angle)
        offset_root(pivot - rotation @ pivot)

    for bone in rig.pose.bones:
        # Keep adjacent quaternions in the same hemisphere for interpolated flips.
        value = bone.rotation_quaternion.copy()
        previous = key_pose.previous.get(bone.name)
        if previous is not None and previous.dot(value) < 0:
            value.negate()
            bone.rotation_quaternion = value
        key_pose.previous[bone.name] = value
        bone.keyframe_insert(data_path="rotation_quaternion", frame=frame, group=bone.name)
    rig.pose.bones["Root"].keyframe_insert(data_path="location", frame=frame, group="Root")


def export_runner(root):
    root = Path(root)
    bpy.ops.wm.open_mainfile(filepath=str(root / "art/ink_stick_runner/ink_stick_runner.blend"))
    scene = bpy.context.scene
    rig = next(o for o in scene.objects if o.type == "ARMATURE")
    mesh = next(o for o in scene.objects if o.type == "MESH")
    assert mesh.parent == rig and rig.animation_data.action.name == "Run"
    animations = rig.animation_data
    actions = [animations.action]
    triangles = optimize_mesh(mesh)
    for name, frames in FRAMES.items():
        action = bpy.data.actions.new(name)
        animations.action = action
        key_pose.previous = {}
        for frame in range(1, frames + 1):
            key_pose(rig, name, frame, (frame - 1) / (frames - 1))
        if name in LOOPS:
            action.use_cyclic = True
        actions.append(action)
    animations.action = None
    for action in actions:
        track = animations.nla_tracks.new()
        track.name = action.name
        track.strips.new(action.name, 1, action)
    scene.frame_set(1)
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    rig.select_set(True)
    path = root / "assets/models/characters" / (MODEL_NAME + ".glb")
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
        export_animation_mode="NLA_TRACKS", export_skins=True, export_cameras=False,
        export_lights=False, export_vertex_color="ACTIVE", export_rest_position_armature=True,
    )
    return {"name": MODEL_NAME, "category": "characters", "triangles": triangles,
            "bytes": path.stat().st_size}


if __name__ == "__main__":
    project = Path(__file__).resolve().parents[1]
    entry = export_runner(project)
    manifest_path = project / "art/asset_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest = [model for model in manifest if model["name"] != MODEL_NAME]
    index = max(i for i, model in enumerate(manifest) if model["category"] == "characters")
    manifest.insert(index + 1, entry)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print("INK_STICK_EXPORT", entry)
