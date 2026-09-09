from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCENE = ROOT / "scenes" / "player" / "player.tscn"

SCRIPT_PATH = 'res://scripts/player/high_detail_character_bridge.gd'
ASSET_PATH = 'res://scenes/player/high_detail_character.tscn'
SCRIPT_ID = 'high_detail_bridge_script'
ASSET_ID = 'high_detail_character_scene'
NODE_NAME = 'HighDetailCharacterBridge'


def main() -> None:
    if not SCENE.exists():
        raise SystemExit(f"Missing player scene: {SCENE}")

    text = SCENE.read_text(encoding='utf-8')
    if f'name="{NODE_NAME}" type="Node3D" parent="."' in text:
        print('High-detail character bridge: already installed')
        return

    if 'res://scripts/player/high_detail_character_bridge.gd' not in text:
        marker = '[sub_resource '
        index = text.find(marker)
        if index < 0:
            raise SystemExit('Could not find the first sub_resource block in player.tscn')
        ext = (
            f'[ext_resource path="{SCRIPT_PATH}" type="Script" id="{SCRIPT_ID}"]\n'
            f'[ext_resource path="{ASSET_PATH}" type="PackedScene" id="{ASSET_ID}"]\n\n'
        )
        text = text[:index] + ext + text[index:]

    node = (
        f'\n[node name="{NODE_NAME}" type="Node3D" parent="."]\n'
        f'script = ExtResource("{SCRIPT_ID}")\n'
        f'character_scene = ExtResource("{ASSET_ID}")\n'
        f'character_scale = 1.0\n'
        f'hide_fallback_body = false\n'
    )
    if not text.endswith('\n'):
        text += '\n'
    text += node
    SCENE.write_text(text, encoding='utf-8')
    print('High-detail character bridge: installed')
    print(f'Updated: {SCENE}')


if __name__ == '__main__':
    main()
