from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCENE = ROOT / "scenes" / "player" / "high_detail_character.tscn"
ASSET = "res://assets/models/characters/multiverse_superhero_v1.glb"

if not SCENE.exists():
    raise SystemExit(f"Missing scene: {SCENE}")

text = SCENE.read_text(encoding="utf-8")

# Replace the scaffold placeholder with the generated Blender GLB.
text = text.replace('load_steps=2', 'load_steps=2')
text = text.replace('[gd_scene load_steps=2 format=3]', '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="PackedScene" path="' + ASSET + '" id="1_character"]')

marker = '[node name="AssetPlaceholder" type="Node3D" parent="."]'
if marker in text:
    before, after = text.split(marker, 1)
    replacement = '[node name="CharacterAsset" parent="." instance=ExtResource("1_character")]\n\n[node name="AssetPlaceholder" type="Node3D" parent="."]'
    text = before + replacement + after
else:
    raise SystemExit("Expected AssetPlaceholder node was not found; refusing to modify the scene.")

SCENE.write_text(text, encoding="utf-8")
print("Character asset installer: connected")
print(f"Scene: {SCENE}")
print(f"Asset: {ASSET}")
