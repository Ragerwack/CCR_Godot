#!/usr/bin/env python3
"""从方案 A 原图生成可在 Godot 中动态填充 5 张子卡的多颜色圣物资源。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = PROJECT_ROOT / "Resources/Relics/scheme_a"
DEFAULT_CARD_PATHS = [
    PROJECT_ROOT / f"Resources/Cards/card_{number:03d}.jpg" for number in range(1, 6)
]

WHITE_SLOT_POLYGONS_PX = [
    [(284, 380), (285, 494), (310, 519), (372, 519), (395, 497), (421, 519), (482, 519), (506, 493), (507, 380), (479, 354), (308, 354)],
    [(284, 581), (285, 695), (310, 720), (372, 720), (394, 699), (419, 720), (480, 720), (506, 694), (507, 581), (483, 556), (416, 556), (396, 572), (381, 561), (377, 561), (374, 556), (308, 556)],
    [(284, 782), (285, 897), (310, 922), (372, 922), (396, 901), (420, 923), (481, 923), (506, 897), (506, 784), (480, 759), (418, 759), (396, 775), (375, 759), (307, 759)],
    [(285, 985), (285, 1096), (310, 1120), (372, 1120), (394, 1100), (417, 1120), (479, 1120), (506, 1096), (506, 986), (481, 961), (415, 961), (396, 977), (387, 968), (378, 967), (374, 961), (307, 961)],
    [(307, 1160), (286, 1183), (285, 1313), (314, 1348), (384, 1348), (391, 1338), (395, 1336), (405, 1347), (480, 1347), (506, 1316), (507, 1187), (481, 1160), (417, 1160), (396, 1177), (393, 1177), (386, 1167), (378, 1168), (371, 1160)],
]

RELIC_SPECS = {
    "white": {
        "source": "relic_scheme_a_source.png",
        "prefix": "relic_scheme_a",
        # Nan 通过网页标记工具绘制的精确边界；坐标取填充区内缘。
        "slot_polygons_px": WHITE_SLOT_POLYGONS_PX,
        "label_layout": {
            "series": {"x_ratio": 0.23, "y_ratio": 0.724, "width_ratio": 0.54, "height_ratio": 0.045},
            "name": {"x_ratio": 0.20, "y_ratio": 0.768, "width_ratio": 0.60, "height_ratio": 0.065},
            "count": {"x_ratio": 0.25, "y_ratio": 0.835, "width_ratio": 0.50, "height_ratio": 0.05},
        },
    },
    "green": {
        "source": "relic_scheme_a_green_source.png",
        "prefix": "relic_scheme_a_green",
        # 原图不是单列布局：1/3/5 偏左，2/4 偏右 31 px。
        # 每组最后两个值是八边形横向、纵向切角尺寸。
        "slots_px": [
            (281, 356, 231, 137, 19, 18),
            (312, 542, 231, 135, 19, 18),
            (281, 726, 231, 137, 19, 18),
            (312, 913, 231, 137, 19, 18),
            (281, 1097, 231, 141, 19, 18),
        ],
        "label_layout": {
            "series": {"x_ratio": 0.25, "y_ratio": 0.724, "width_ratio": 0.50, "height_ratio": 0.04},
            "name": {"x_ratio": 0.21, "y_ratio": 0.766, "width_ratio": 0.58, "height_ratio": 0.055},
            "count": {"x_ratio": 0.25, "y_ratio": 0.822, "width_ratio": 0.50, "height_ratio": 0.045},
        },
    },
    "blue": {
        "source": "relic_scheme_a_blue_source.png",
        "prefix": "relic_scheme_a_blue",
        "slots_px": [(329, 236, 286, 148, 16, 16), (330, 427, 285, 148, 16, 16), (330, 617, 285, 148, 16, 16), (330, 806, 285, 151, 16, 16), (329, 996, 286, 152, 16, 16)],
        "label_layout": {
            "series": {"x_ratio": 0.33, "y_ratio": 0.735, "width_ratio": 0.34, "height_ratio": 0.035},
            "name": {"x_ratio": 0.28, "y_ratio": 0.775, "width_ratio": 0.44, "height_ratio": 0.05},
            "count": {"x_ratio": 0.32, "y_ratio": 0.828, "width_ratio": 0.36, "height_ratio": 0.04},
        },
    },
    "purple": {
        "source": "relic_scheme_a_purple_source.png",
        "prefix": "relic_scheme_a_purple",
        "slots_px": [(347, 267, 248, 135, 15, 15), (347, 440, 248, 132, 15, 15), (347, 614, 248, 132, 15, 15), (347, 787, 248, 135, 15, 15), (347, 960, 248, 137, 15, 15)],
        "label_layout": {
            "series": {"x_ratio": 0.35, "y_ratio": 0.711, "width_ratio": 0.30, "height_ratio": 0.035},
            "name": {"x_ratio": 0.30, "y_ratio": 0.751, "width_ratio": 0.40, "height_ratio": 0.05},
            "count": {"x_ratio": 0.34, "y_ratio": 0.807, "width_ratio": 0.32, "height_ratio": 0.04},
        },
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--rarity", choices=["all", *RELIC_SPECS.keys()], default="all")
    parser.add_argument("--cards", type=Path, nargs=5, default=DEFAULT_CARD_PATHS)
    return parser.parse_args()


def slots_from_pixels(rects: list[tuple[int, int, int, int, int, int]], width: int, height: int) -> list[dict]:
    return [
        {
            "id": index,
            "x_ratio": x / width,
            "y_ratio": y / height,
            "width_ratio": slot_width / width,
            "height_ratio": slot_height / height,
            "center_x_ratio": (x + slot_width / 2) / width,
            "center_y_ratio": (y + slot_height / 2) / height,
            "mask_shape": "octagon",
            "bevel_x_ratio_to_width": bevel_x / slot_width,
            "bevel_y_ratio_to_height": bevel_y / slot_height,
        }
        for index, (x, y, slot_width, slot_height, bevel_x, bevel_y) in enumerate(rects, 1)
    ]


def slots_from_polygons(polygons: list[list[tuple[int, int]]], width: int, height: int, prefix: str) -> list[dict]:
    slots: list[dict] = []
    for index, points in enumerate(polygons, 1):
        xs = [point[0] for point in points]
        ys = [point[1] for point in points]
        x = min(xs)
        y = min(ys)
        slot_width = max(xs) - x + 1
        slot_height = max(ys) - y + 1
        slots.append({
            "id": index,
            "x_ratio": x / width,
            "y_ratio": y / height,
            "width_ratio": slot_width / width,
            "height_ratio": slot_height / height,
            "center_x_ratio": (x + slot_width / 2) / width,
            "center_y_ratio": (y + slot_height / 2) / height,
            "mask_shape": "polygon",
            "mask_polygon": [{"x_ratio": px / width, "y_ratio": py / height} for px, py in points],
            "mask": f"res://Resources/Relics/scheme_a/{prefix}_slot_{index}_mask.png",
        })
    return slots


def normalize_slots(slots: list[dict], width: int, height: int) -> list[dict]:
    normalized: list[dict] = []
    for raw_slot in slots:
        slot = dict(raw_slot)
        slot_width = float(slot["width_ratio"])
        slot_height = float(slot["height_ratio"])
        slot["center_x_ratio"] = float(slot["x_ratio"]) + slot_width / 2
        slot["center_y_ratio"] = float(slot["y_ratio"]) + slot_height / 2
        if slot.get("mask_shape") == "polygon":
            normalized.append(slot)
            continue
        slot["mask_shape"] = "octagon"
        # 兼容旧布局中的圆角数值；新资源统一按八边形切角解释。
        legacy_bevel = float(slot.pop("corner_radius_ratio_to_height", 0.1))
        slot.setdefault("bevel_x_ratio_to_width", legacy_bevel * slot_height * height / max(slot_width * width, 1.0))
        slot.setdefault("bevel_y_ratio_to_height", legacy_bevel)
        normalized.append(slot)
    return normalized


def load_or_create_layout(path: Path, source: Path, rarity: str, prefix: str, spec: dict, width: int, height: int) -> dict:
    if "slot_polygons_px" in spec:
        source_slots = slots_from_polygons(spec["slot_polygons_px"], width, height, prefix)
    elif "slots" in spec:
        source_slots = spec["slots"]
    else:
        source_slots = slots_from_pixels(spec["slots_px"], width, height)
    if path.exists():
        layout = json.loads(path.read_text(encoding="utf-8"))
    else:
        layout = {
            "rarity": rarity,
            "source": f"res://Resources/Relics/scheme_a/{source.name}",
            "frame": f"res://Resources/Relics/scheme_a/{prefix}_frame.png",
            "canvas": {"width": width, "height": height},
            "pivot": {"x_ratio": 0.5, "y_ratio": 0.5},
            "slots": source_slots,
            "label_layout": spec["label_layout"],
            "rendering": {
                "slot_z_index": 0,
                "frame_z_index": 10,
                "slot_antialias_px": 3,
            },
        }
    # 规格中的槽位坐标是可重复生成资源的权威值，避免旧 JSON 保留错误布局。
    layout["slots"] = normalize_slots(source_slots, width, height)
    layout["canvas"] = {"width": width, "height": height}
    layout["source_file"] = source.name
    layout["rarity"] = rarity
    layout["source"] = f"res://Resources/Relics/scheme_a/{source.name}"
    layout["frame"] = f"res://Resources/Relics/scheme_a/{prefix}_frame.png"
    layout["label_layout"] = spec["label_layout"]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return layout


def slot_geometry(slot: dict, width: int, height: int) -> tuple[int, int, int, int, int, int]:
    x = round(width * float(slot["x_ratio"]))
    y = round(height * float(slot["y_ratio"]))
    w = round(width * float(slot["width_ratio"]))
    h = round(height * float(slot["height_ratio"]))
    bevel_x = round(w * float(slot.get("bevel_x_ratio_to_width", 0.0)))
    bevel_y = round(h * float(slot.get("bevel_y_ratio_to_height", 0.0)))
    return x, y, w, h, bevel_x, bevel_y


def octagon_points(x: int, y: int, width: int, height: int, bevel_x: int, bevel_y: int) -> list[tuple[int, int]]:
    return [
        (x + bevel_x, y),
        (x + width - bevel_x, y),
        (x + width, y + bevel_y),
        (x + width, y + height - bevel_y),
        (x + width - bevel_x, y + height),
        (x + bevel_x, y + height),
        (x, y + height - bevel_y),
        (x, y + bevel_y),
    ]


def slot_points(slot: dict, width: int, height: int) -> list[tuple[int, int]]:
    if slot.get("mask_shape") == "polygon":
        return [
            (round(width * float(point["x_ratio"])), round(height * float(point["y_ratio"])))
            for point in slot["mask_polygon"]
        ]
    x, y, slot_width, slot_height, bevel_x, bevel_y = slot_geometry(slot, width, height)
    return octagon_points(x, y, slot_width, slot_height, bevel_x, bevel_y)


def local_slot_mask(slot: dict, width: int, height: int, scale: int = 4) -> Image.Image:
    x, y, slot_width, slot_height, _, _ = slot_geometry(slot, width, height)
    mask = Image.new("L", (slot_width * scale, slot_height * scale), 0)
    points = slot_points(slot, width, height)
    local_points = [((px - x) * scale, (py - y) * scale) for px, py in points]
    ImageDraw.Draw(mask).polygon(local_points, fill=255)
    return mask.resize((slot_width, slot_height), Image.Resampling.LANCZOS)


def combined_slot_mask(layout: dict, width: int, height: int, scale: int = 4) -> Image.Image:
    mask = Image.new("L", (width * scale, height * scale), 0)
    draw = ImageDraw.Draw(mask)
    for slot in layout["slots"]:
        points = slot_points(slot, width, height)
        draw.polygon([(px * scale, py * scale) for px, py in points], fill=255)
    return mask.resize((width, height), Image.Resampling.LANCZOS)


def extract_foreground_alpha(source_rgb: np.ndarray) -> np.ndarray:
    """从边缘连通的亮色中性棋盘中分离主体，并保留其最大连通区域。"""
    minimum = source_rgb.min(axis=2)
    maximum = source_rgb.max(axis=2)
    # 素材使用两档近白棋盘格模拟透明底；不同出图的暗格最低约为 235。
    # 放宽亮度和中性色差后，仍只移除与画布边缘连通的区域，避免误删主体白色面板。
    background_candidate = ((minimum >= 235) & ((maximum - minimum) <= 8)).astype(np.uint8)
    count, labels, _, _ = cv2.connectedComponentsWithStats(background_candidate, 8)
    if count <= 1:
        raise RuntimeError("未能从棋盘背景中识别圣物主体")

    border_labels = np.unique(
        np.concatenate((labels[0, :], labels[-1, :], labels[:, 0], labels[:, -1]))
    )
    foreground = (~np.isin(labels, border_labels)).astype(np.uint8)
    component_count, component_labels, stats, _ = cv2.connectedComponentsWithStats(foreground, 8)
    if component_count <= 1:
        raise RuntimeError("未能形成有效的圣物前景区域")
    largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    alpha = (component_labels == largest).astype(np.uint8) * 255
    return cv2.GaussianBlur(alpha, (0, 0), 0.8)


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - target_w) // 2
    top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def generate_assets(rarity: str, spec: dict, output: Path, card_paths: list[Path]) -> None:
    source_path = output / spec["source"]
    prefix = spec["prefix"]
    layout_path = output / f"{prefix}_layout.json"
    if not source_path.exists():
        raise FileNotFoundError(f"找不到 {rarity} 方案 A 原图: {source_path}")
    output.mkdir(parents=True, exist_ok=True)

    source = Image.open(source_path).convert("RGB")
    width, height = source.size
    layout = load_or_create_layout(layout_path, source_path, rarity, prefix, spec, width, height)
    source_rgb = np.asarray(source)
    foreground_alpha = extract_foreground_alpha(source_rgb)
    slots_mask = combined_slot_mask(layout, width, height)
    slots_alpha = np.asarray(slots_mask)

    frame_alpha = np.minimum(foreground_alpha, 255 - slots_alpha)
    frame = Image.fromarray(np.dstack((source_rgb, frame_alpha)), "RGBA")
    frame.save(output / f"{prefix}_frame.png")

    mask_rgba = Image.merge("RGBA", (slots_mask, slots_mask, slots_mask, Image.new("L", (width, height), 255)))
    mask_rgba.save(output / f"{prefix}_slot_mask.png")

    calibration = source.convert("RGBA")
    draw = ImageDraw.Draw(calibration)
    font = ImageFont.load_default(size=20)
    for slot in layout["slots"]:
        x, y, w, h, bevel_x, bevel_y = slot_geometry(slot, width, height)
        points = slot_points(slot, width, height)
        draw.line(points + [points[0]], fill=(255, 32, 32, 255), width=4, joint="curve")
        center_x = x + w / 2
        center_y = y + h / 2
        draw.ellipse((center_x - 3, center_y - 3, center_x + 3, center_y + 3), fill=(255, 32, 32, 255))
        draw.text((x + 8, y + 6), str(slot["id"]), font=font, fill=(255, 32, 32, 255), stroke_width=2, stroke_fill=(255, 255, 255, 255))
    calibration.save(output / f"{prefix}_calibration_overlay.png")

    for slot in layout["slots"]:
        x, y, w, h, bevel_x, bevel_y = slot_geometry(slot, width, height)
        crop = source.crop((x, y, x + w, y + h)).convert("RGBA")
        mask = local_slot_mask(slot, width, height)
        crop.putalpha(mask)
        extracted_prefix = "" if rarity == "white" else f"{prefix}_"
        crop.save(output / f"{extracted_prefix}extracted_slot_{slot['id']}.png")
        if slot.get("mask_shape") == "polygon":
            mask.save(output / f"{prefix}_slot_{slot['id']}_mask.png")

    preview = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for slot, card_path in zip(layout["slots"], card_paths):
        if not card_path.exists():
            raise FileNotFoundError(f"找不到预览子卡插图: {card_path}")
        x, y, w, h, bevel_x, bevel_y = slot_geometry(slot, width, height)
        card = cover_resize(Image.open(card_path).convert("RGBA"), (w, h))
        card.putalpha(local_slot_mask(slot, width, height))
        preview.alpha_composite(card, (x, y))
    preview.alpha_composite(frame)
    preview.save(output / f"{prefix}_preview.png")

    print(f"[{rarity}] Source size: {width} x {height}")
    for slot in layout["slots"]:
        x, y, w, h, bevel_x, bevel_y = slot_geometry(slot, width, height)
        print(
            f"Slot {slot['id']}: x={x}, y={y}, w={w}, h={h}, "
            f"center=({x + w / 2:.1f}, {y + h / 2:.1f}), bevel=({bevel_x}, {bevel_y})"
        )
    print("Generated calibration overlay.")
    print("Generated extracted slots.")
    print("Generated transparent frame.")
    print("Generated slot mask.")
    print("Generated preview.")


def main() -> None:
    args = parse_args()
    rarities = RELIC_SPECS.keys() if args.rarity == "all" else [args.rarity]
    for rarity in rarities:
        generate_assets(rarity, RELIC_SPECS[rarity], args.output.resolve(), [path.resolve() for path in args.cards])


if __name__ == "__main__":
    main()
