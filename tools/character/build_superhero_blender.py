import bpy
import math
import json
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "assets" / "models" / "characters"
OUT_DIR.mkdir(parents=True, exist_ok=True)
BLEND_OUT = OUT_DIR / "multiverse_superhero_v1.blend"
GLB_OUT = OUT_DIR / "multiverse_superhero_v1.glb"
MANIFEST_OUT = OUT_DIR / "multiverse_superhero_v1.json"

# Original-IP procedural character: a large, muscular green superhero.
# This is a real Blender mesh/rig foundation, intentionally independent of gameplay code.

def mat(name, color, metallic=0.0, roughness=0.45):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Metallic"].default_value = metallic
        bsdf.inputs["Roughness"].default_value = roughness
    return m

SKIN = mat("Hero_Skin", (0.075, 0.32, 0.09), 0.0, 0.38)
SKIN_DARK = mat("Hero_Skin_Dark", (0.035, 0.16, 0.045), 0.0, 0.43)
PANTS = mat("Hero_Pants", (0.025, 0.035, 0.055), 0.05, 0.32)
BELT = mat("Hero_Belt", (0.16, 0.10, 0.025), 0.25, 0.3)
EYE = mat("Hero_Eyes", (1.0, 0.28, 0.025), 0.05, 0.18)
HAIR = mat("Hero_Hair", (0.012, 0.009, 0.006), 0.0, 0.55)


def smooth(obj):
    if obj and obj.type == 'MESH':
        for p in obj.data.polygons:
            p.use_smooth = True


def uv(name, loc, scale, material, seg=32, rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    smooth(o)
    return o


def cyl(name, loc, radius, depth, material, rot=(0,0,0), verts=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.name = name
    o.data.materials.append(material)
    smooth(o)
    bevel = o.modifiers.new("Soft_Edges", 'BEVEL')
    bevel.width = min(radius * 0.16, 0.12)
    bevel.segments = 3
    return o


def bone(arm, name, head, tail, parent=None):
    b = arm.data.edit_bones.new(name)
    b.head = head
    b.tail = tail
    if parent:
        b.parent = arm.data.edit_bones.get(parent)
    return b


def make_rig():
    bpy.ops.object.armature_add(enter_editmode=True, location=(0,0,0))
    arm = bpy.context.object
    arm.name = "Hero_Rig"
    arm.data.name = "Hero_Humanoid_Rig"
    for b in list(arm.data.edit_bones):
        arm.data.edit_bones.remove(b)
    bone(arm, "root", (0,0,0), (0,0,0.45))
    bone(arm, "pelvis", (0,0,0.65), (0,0,1.05), "root")
    bone(arm, "spine", (0,0,1.0), (0,0,1.65), "pelvis")
    bone(arm, "chest", (0,0,1.55), (0,0,2.15), "spine")
    bone(arm, "neck", (0,0,2.1), (0,0,2.38), "chest")
    bone(arm, "head", (0,0,2.35), (0,0,2.95), "neck")
    for s in (-1, 1):
        side = "L" if s < 0 else "R"
        x = s
        bone(arm, f"clavicle_{side}", (0.18*s,0,1.98), (0.48*s,0,1.98), "chest")
        bone(arm, f"upper_arm_{side}", (0.45*s,0,1.96), (1.05*s,0,1.72), f"clavicle_{side}")
        bone(arm, f"forearm_{side}", (1.05*s,0,1.72), (1.45*s,0,1.48), f"upper_arm_{side}")
        bone(arm, f"hand_{side}", (1.45*s,0,1.48), (1.68*s,0,1.42), f"forearm_{side}")
        for i in range(1,5):
            base = 1.53 + i*0.035
            bone(arm, f"finger_{side}_{i}_01", (base*s,0.01*(i-2),1.42), ((base+0.11)*s,0.01*(i-2),1.40), f"hand_{side}")
        bone(arm, f"thigh_{side}", (0.28*s,0,0.68), (0.38*s,0,0.05), "pelvis")
        bone(arm, f"shin_{side}", (0.38*s,0,0.05), (0.39*s,0,-0.65), f"thigh_{side}")
        bone(arm, f"foot_{side}", (0.39*s,0,-0.65), (0.39*s,-0.30,-0.72), f"shin_{side}")
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.show_in_front = True
    return arm


def parent_bone(obj, arm, name):
    obj.parent = arm
    obj.parent_type = 'BONE'
    obj.parent_bone = name


def make_character():
    parts = []
    # Feet and legs
    for s in (-1, 1):
        side = "L" if s < 0 else "R"
        parts += [
            uv(f"Calf_{side}", (0.39*s,0, -0.28), (0.28,0.24,0.46), SKIN),
            uv(f"Thigh_{side}", (0.28*s,0, 0.38), (0.38,0.30,0.58), SKIN),
            uv(f"Foot_{side}", (0.39*s,-0.16,-0.70), (0.28,0.48,0.18), SKIN),
        ]
    # Pelvis / torso / chest muscle masses
    parts += [
        uv("Pelvis", (0,0,0.72), (0.78,0.43,0.42), SKIN_DARK),
        uv("Abdomen", (0,0,1.23), (0.72,0.39,0.66), SKIN),
        uv("Chest", (0,0,1.72), (1.10,0.47,0.56), SKIN),
        uv("Chest_Center", (0,-0.10,1.77), (0.57,0.28,0.43), SKIN),
        uv("Neck", (0,0,2.20), (0.30,0.29,0.34), SKIN),
        uv("Head", (0,0,2.55), (0.46,0.40,0.55), SKIN),
        uv("Jaw", (0,-0.04,2.38), (0.40,0.36,0.25), SKIN_DARK),
    ]
    # Ab and shoulder definition
    for z, sx in [(1.05,0.42),(1.28,0.46),(1.50,0.50)]:
        parts += [uv(f"Ab_L_{z}", (-sx*0.55,-0.36,z), (0.28,0.10,0.16), SKIN_DARK),
                  uv(f"Ab_R_{z}", (sx*0.55,-0.36,z), (0.28,0.10,0.16), SKIN_DARK)]
    for s in (-1,1):
        side = "L" if s < 0 else "R"
        parts += [
            uv(f"Shoulder_{side}", (0.94*s,0,1.91), (0.42,0.43,0.40), SKIN),
            uv(f"Bicep_{side}", (1.18*s,0,1.70), (0.34,0.34,0.48), SKIN),
            uv(f"Forearm_{side}", (1.48*s,0,1.47), (0.28,0.29,0.45), SKIN),
            uv(f"Hand_{side}", (1.70*s,0,1.40), (0.28,0.24,0.25), SKIN),
        ]
        for i in range(4):
            parts.append(uv(f"Finger_{side}_{i+1}", (1.78*s, -0.10 + i*0.07, 1.30), (0.07,0.06,0.18), SKIN))
    # Face features and hair ridge
    parts += [
        uv("Eye_L", (-0.18,-0.37,2.62), (0.105,0.055,0.075), EYE, 24, 12),
        uv("Eye_R", (0.18,-0.37,2.62), (0.105,0.055,0.075), EYE, 24, 12),
        uv("Brow_L", (-0.18,-0.38,2.72), (0.18,0.05,0.055), SKIN_DARK, 24, 12),
        uv("Brow_R", (0.18,-0.38,2.72), (0.18,0.05,0.055), SKIN_DARK, 24, 12),
        uv("Nose", (0,-0.42,2.50), (0.12,0.15,0.20), SKIN_DARK, 24, 12),
        uv("Hair", (0,0.0,2.91), (0.43,0.38,0.22), HAIR),
        uv("Belt", (0,0,0.78), (0.80,0.46,0.12), BELT),
    ]
    for p in parts:
        if p.name.startswith("Eye") or p.name.startswith("Brow") or p.name in {"Nose","Hair","Belt"}:
            continue
    arm = make_rig()
    for obj in parts:
        # Attach major pieces to nearest logical bones; detail pieces follow torso/head.
        n = obj.name
        if n.startswith("Thigh_"): b = "thigh_" + n[-1]
        elif n.startswith("Calf_"): b = "shin_" + n[-1]
        elif n.startswith("Foot_"): b = "foot_" + n[-1]
        elif n.startswith("Shoulder_"): b = "upper_arm_" + n[-1]
        elif n.startswith("Bicep_"): b = "upper_arm_" + n[-1]
        elif n.startswith("Forearm_"): b = "forearm_" + n[-1]
        elif n.startswith("Hand_") or n.startswith("Finger_"): b = "hand_" + n[-1]
        elif n in {"Head","Jaw","Eye_L","Eye_R","Brow_L","Brow_R","Nose","Hair"}: b = "head"
        elif n == "Neck": b = "neck"
        elif n in {"Pelvis","Belt"}: b = "pelvis"
        else: b = "chest"
        parent_bone(obj, arm, b)
    return arm, parts


def add_animations(arm):
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    for name in ["Idle","Walk","Sprint","Jump","Fly"]:
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        arm.animation_data_create()
        arm.animation_data.action = action
        bpy.context.scene.frame_start = 1
        bpy.context.scene.frame_end = 30
        pb = arm.pose.bones
        # Neutral baseline
        for b in pb:
            b.rotation_mode = 'XYZ'
            b.rotation_euler = (0,0,0)
            b.keyframe_insert("rotation_euler", frame=1)
            b.keyframe_insert("rotation_euler", frame=30)
        if name == "Idle":
            pb["chest"].rotation_euler.x = math.radians(-2)
            pb["chest"].keyframe_insert("rotation_euler", frame=15)
        elif name in ("Walk","Sprint"):
            amp = 0.35 if name == "Walk" else 0.65
            for f, phase in [(1,0),(8,1),(16,0),(23,-1),(30,0)]:
                a = math.sin(phase * math.pi/2) * amp
                for side in ("L","R"):
                    sign = -1 if side == "L" else 1
                    pb[f"upper_arm_{side}"].rotation_euler.x = -a*sign
                    pb[f"thigh_{side}"].rotation_euler.x = a*sign
                    pb[f"forearm_{side}"].rotation_euler.x = abs(a)*0.2
                    pb[f"shin_{side}"].rotation_euler.x = -abs(a)*0.15
                    for bn in (f"upper_arm_{side}",f"thigh_{side}",f"forearm_{side}",f"shin_{side}"):
                        pb[bn].keyframe_insert("rotation_euler", frame=f)
        elif name == "Jump":
            for f, x in [(1,0),(10,-0.5),(20,-0.2),(30,0)]:
                pb["spine"].rotation_euler.x = x
                pb["chest"].rotation_euler.x = x*0.5
                pb["spine"].keyframe_insert("rotation_euler", frame=f)
                pb["chest"].keyframe_insert("rotation_euler", frame=f)
        elif name == "Fly":
            for f, x in [(1,0.15),(15,0.0),(30,0.15)]:
                pb["spine"].rotation_euler.x = x
                pb["chest"].rotation_euler.x = x*0.5
                pb["upper_arm_L"].rotation_euler.x = math.radians(-55)
                pb["upper_arm_R"].rotation_euler.x = math.radians(-55)
                pb["spine"].keyframe_insert("rotation_euler", frame=f)
                pb["chest"].keyframe_insert("rotation_euler", frame=f)
                pb["upper_arm_L"].keyframe_insert("rotation_euler", frame=f)
                pb["upper_arm_R"].keyframe_insert("rotation_euler", frame=f)
    arm.animation_data.action = bpy.data.actions.get("Idle")


def main():
    bpy.ops.object.mode_set(mode='OBJECT') if bpy.context.object and bpy.context.object.mode != 'OBJECT' else None
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        pass
    arm, parts = make_character()
    add_animations(arm)
    # Put rig at front of character hierarchy for export.
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUT))
    bpy.ops.object.select_all(action='SELECT')
    try:
        bpy.ops.export_scene.gltf(filepath=str(GLB_OUT), export_format='GLB', export_apply=True, export_animations=True)
    except TypeError:
        bpy.ops.export_scene.gltf(filepath=str(GLB_OUT), export_format='GLB', export_animations=True)
    manifest = {
        "asset": "multiverse_superhero_v1",
        "original_ip": True,
        "blender_version_target": "5.2+",
        "height_units": 3.0,
        "rig": "Hero_Humanoid_Rig",
        "animations": ["Idle","Walk","Sprint","Jump","Fly"],
        "godot_import": "GLB",
        "blend": str(BLEND_OUT).replace('\\','/'),
        "glb": str(GLB_OUT).replace('\\','/'),
    }
    MANIFEST_OUT.write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print("=== MULTIVERSE SUPERHERO BUILD COMPLETE ===")
    print(f"BLEND: {BLEND_OUT}")
    print(f"GLB:   {GLB_OUT}")
    print(f"MANIFEST: {MANIFEST_OUT}")

if __name__ == "__main__":
    main()
