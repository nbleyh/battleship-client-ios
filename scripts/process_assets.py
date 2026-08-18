#!/usr/bin/env python3
"""One-off script: ports Android drawable assets into the iOS Assets.xcassets catalog.

Strips the 1px nine-patch stretch-border encoded in Android .9.png files (the
game's board cells are fixed-size, so no stretching is needed) and writes plain
PNGs into imageset folders. Also builds the AppIcon set from the source icon.
"""
import json
import os
from PIL import Image

ANDROID_RES = "/Users/nbleyh/ai-app-development/battleship-client/app/src/main/res"
ASSETS = "/Users/nbleyh/ai-app-development/battleship-client-ios/Resources/Assets.xcassets"

CONTENTS_ROOT = {"info": {"author": "xcode", "version": 1}}

def write_imageset(name, src_path, nine_patch=True):
    im = Image.open(src_path).convert("RGBA")
    if nine_patch:
        w, h = im.size
        im = im.crop((1, 1, w - 1, h - 1))
    out_dir = os.path.join(ASSETS, f"{name}.imageset")
    os.makedirs(out_dir, exist_ok=True)
    filename = f"{name}.png"
    im.save(os.path.join(out_dir, filename))
    contents = {
        "images": [
            {"filename": filename, "idiom": "universal", "scale": "1x"},
            {"idiom": "universal", "scale": "2x"},
            {"idiom": "universal", "scale": "3x"},
        ],
        "info": CONTENTS_ROOT["info"],
    }
    with open(os.path.join(out_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print(f"wrote {name} -> {im.size}")

def write_appicon(src_path):
    im = Image.open(src_path).convert("RGBA")
    # flatten alpha onto white so App Store icon has no transparency
    bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
    im = Image.alpha_composite(bg, im).convert("RGB")
    icon_1024 = im.resize((1024, 1024), Image.LANCZOS)
    out_dir = os.path.join(ASSETS, "AppIcon.appiconset")
    os.makedirs(out_dir, exist_ok=True)
    filename = "AppIcon-1024.png"
    icon_1024.save(os.path.join(out_dir, filename))
    contents = {
        "images": [
            {"filename": filename, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
        ],
        "info": CONTENTS_ROOT["info"],
    }
    with open(os.path.join(out_dir, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print(f"wrote AppIcon -> 1024x1024")

def write_root_contents():
    with open(os.path.join(ASSETS, "Contents.json"), "w") as f:
        json.dump(CONTENTS_ROOT, f, indent=2)

def main():
    os.makedirs(ASSETS, exist_ok=True)
    write_root_contents()

    d = os.path.join(ANDROID_RES, "drawable")

    nine_patch_assets = {
        "Ship": "ship.9.png",
        "ShipHit": "shiphit.9.png",
        "ShipHitStroke": "shiphit_stroke.9.png",
        "Fog": "fog.9.png",
        "ClockIcon": "clock.9.png",
        "TargetIcon": "target.9.png",
        "Waterdrop0": "waterdrop0.9.png",
        "Waterdrop1": "waterdrop1.9.png",
        "Waterdrop2": "waterdrop2.9.png",
        "Waterdrop3": "waterdrop3.9.png",
        "Waterdrop0Stroke": "waterdrop0_stroke.9.png",
        "Waterdrop1Stroke": "waterdrop1_stroke.9.png",
        "Waterdrop2Stroke": "waterdrop2_stroke.9.png",
        "Waterdrop3Stroke": "waterdrop3_stroke.9.png",
    }
    for name, fname in nine_patch_assets.items():
        write_imageset(name, os.path.join(d, fname), nine_patch=True)

    plain_assets = {
        "PeaceIcon": "peace.png",
        "Help1": "help1.png",
        "Help2": "help2.png",
    }
    for name, fname in plain_assets.items():
        write_imageset(name, os.path.join(d, fname), nine_patch=False)

    write_appicon(os.path.join(d, "battleshipicon.png"))

if __name__ == "__main__":
    main()
