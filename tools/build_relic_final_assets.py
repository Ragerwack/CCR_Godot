#!/usr/bin/env python3
"""离线生成七色 Relic 透明外框、运行时布局和美术检查图。"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SOURCE_ROOT = PROJECT_ROOT / "ArtSource/Relics"
RUNTIME_OUTPUT = PROJECT_ROOT / "Resources/Relics/final"
ARCHIVE_OUTPUT = SOURCE_ROOT / "cut-frames"
PREVIEW_OUTPUT = SOURCE_ROOT / "previews"
CARD_PATHS = [PROJECT_ROOT / f"Resources/Cards/card_{number:03d}.jpg" for number in range(1, 6)]

RARITIES = ("white", "green", "blue", "purple", "orange", "black", "red")

LABEL_LAYOUTS = {
    "white": {
        "series": {"x_ratio": 0.23, "y_ratio": 0.724, "width_ratio": 0.54, "height_ratio": 0.045},
        "name": {"x_ratio": 0.20, "y_ratio": 0.768, "width_ratio": 0.60, "height_ratio": 0.065},
        "count": {"x_ratio": 0.25, "y_ratio": 0.835, "width_ratio": 0.50, "height_ratio": 0.05},
    },
    "green": {
        "series": {"x_ratio": 0.25, "y_ratio": 0.724, "width_ratio": 0.50, "height_ratio": 0.04},
        "name": {"x_ratio": 0.21, "y_ratio": 0.766, "width_ratio": 0.58, "height_ratio": 0.055},
        "count": {"x_ratio": 0.25, "y_ratio": 0.822, "width_ratio": 0.50, "height_ratio": 0.045},
    },
    "blue": {
        "series": {"x_ratio": 0.30, "y_ratio": 0.755, "width_ratio": 0.40, "height_ratio": 0.035},
        "name": {"x_ratio": 0.25, "y_ratio": 0.795, "width_ratio": 0.50, "height_ratio": 0.05},
        "count": {"x_ratio": 0.30, "y_ratio": 0.848, "width_ratio": 0.40, "height_ratio": 0.04},
    },
    "purple": {
        "series": {"x_ratio": 0.35, "y_ratio": 0.711, "width_ratio": 0.30, "height_ratio": 0.035},
        "name": {"x_ratio": 0.30, "y_ratio": 0.751, "width_ratio": 0.40, "height_ratio": 0.05},
        "count": {"x_ratio": 0.34, "y_ratio": 0.807, "width_ratio": 0.32, "height_ratio": 0.04},
    },
}

for _rarity in ("orange", "black", "red"):
    LABEL_LAYOUTS[_rarity] = {
        "series": {"x_ratio": 0.34, "y_ratio": 0.755, "width_ratio": 0.32, "height_ratio": 0.035},
        "name": {"x_ratio": 0.28, "y_ratio": 0.795, "width_ratio": 0.44, "height_ratio": 0.05},
        "count": {"x_ratio": 0.34, "y_ratio": 0.85, "width_ratio": 0.32, "height_ratio": 0.04},
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rarity", choices=("all", *RARITIES), default="all")
    return parser.parse_args()


def shape_points(shape: dict, width: int, height: int) -> list[tuple[int, int]]:
    if shape["type"] in ("hline", "vline"):
        return [
            (round(shape[key]["x"] * width), round(shape[key]["y"] * height))
            for key in ("start", "end")
        ]
    if shape["type"] == "polyline":
        return [(round(point["x"] * width), round(point["y"] * height)) for point in shape["points"]]
    return []


def shape_bounds(shape: dict, width: int, height: int) -> tuple[float, float, float, float]:
    if shape["type"] in ("hline", "vline", "polyline"):
        points = shape_points(shape, width, height)
        xs = [point[0] for point in points]
        ys = [point[1] for point in points]
        return min(xs), min(ys), max(xs), max(ys)
    center_x = float(shape["center"]["x"]) * width
    center_y = float(shape["center"]["y"]) * height
    if shape["type"] == "circle":
        radius_x = float(shape["radius_ratio"]) * width
        radius_y = radius_x
    else:
        radius_x = float(shape["radius_x_ratio"]) * width
        radius_y = float(shape["radius_y_ratio"]) * height
    return center_x - radius_x, center_y - radius_y, center_x + radius_x, center_y + radius_y


def rasterize_boundaries(scheme: dict) -> np.ndarray:
    width = int(scheme["source"]["width"])
    height = int(scheme["source"]["height"])
    boundary = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(boundary)
    endpoints: list[tuple[int, int]] = []

    for shape in scheme["shapes"]:
        line_width = max(3, round(float(shape.get("stroke_width_ratio", 0.004)) * width))
        if shape["type"] in ("hline", "vline", "polyline"):
            points = shape_points(shape, width, height)
            draw.line(points, fill=255, width=line_width, joint="curve")
            if shape.get("closed"):
                draw.line([points[-1], points[0]], fill=255, width=line_width)
            else:
                endpoints.extend((points[0], points[-1]))
        elif shape["type"] in ("circle", "ellipse"):
            draw.ellipse(shape_bounds(shape, width, height), outline=255, width=line_width)

    # 分段线在网页中可能相差少量像素，只桥接同一槽位内距离很近的端点。
    used: set[int] = set()
    for index, point in enumerate(endpoints):
        if index in used:
            continue
        candidates: list[tuple[float, int, tuple[int, int]]] = []
        for other_index, other in enumerate(endpoints):
            if other_index == index or other_index in used:
                continue
            distance = math.hypot(point[0] - other[0], point[1] - other[1])
            if distance <= 40:
                candidates.append((distance, other_index, other))
        if candidates:
            _, other_index, other = min(candidates)
            draw.line([point, other], fill=255, width=4)
            used.update((index, other_index))

    return cv2.morphologyEx(np.asarray(boundary), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))


def extract_slot_masks(scheme: dict, boundaries: np.ndarray) -> list[np.ndarray]:
    width = int(scheme["source"]["width"])
    height = int(scheme["source"]["height"])
    candidate_bounds: list[tuple[float, float, float, float]] = []
    for shape in scheme["shapes"]:
        left, top, right, bottom = shape_bounds(shape, width, height)
        if (right - left) * (bottom - top) > 0.004 * width * height:
            candidate_bounds.append((left, top, right, bottom))

    # 白色第 5 槽由左右两段长折线组成；合并纵向重叠且横向间隙很小的主图形。
    merged: list[tuple[float, float, float, float]] = []
    for bounds in candidate_bounds:
        left, top, right, bottom = bounds
        match = -1
        for index, existing in enumerate(merged):
            ex_left, ex_top, ex_right, ex_bottom = existing
            vertical_overlap = min(bottom, ex_bottom) - max(top, ex_top)
            horizontal_gap = max(left - ex_right, ex_left - right, 0.0)
            if vertical_overlap > 0.0 and horizontal_gap <= 40.0:
                match = index
                break
        if match >= 0:
            ex_left, ex_top, ex_right, ex_bottom = merged[match]
            merged[match] = (min(left, ex_left), min(top, ex_top), max(right, ex_right), max(bottom, ex_bottom))
        else:
            merged.append(bounds)

    seeds = [(round((left + right) / 2), round((top + bottom) / 2)) for left, top, right, bottom in merged]
    if len(seeds) != 5:
        raise RuntimeError(f"{scheme['rarity']} 主槽位数量为 {len(seeds)}，预期为 5")

    masks: list[np.ndarray] = []
    for index, seed in enumerate(seeds, 1):
        flood = (boundaries > 0).astype(np.uint8) * 255
        flood_mask = np.zeros((height + 2, width + 2), np.uint8)
        cv2.floodFill(flood, flood_mask, seed, 128)
        inside = flood == 128
        if inside[0].any() or inside[-1].any() or inside[:, 0].any() or inside[:, -1].any():
            raise RuntimeError(f"{scheme['rarity']} 槽位 {index} 边界未闭合")
        masks.append(inside)
    return masks


def extract_foreground_alpha(source_rgb: np.ndarray) -> np.ndarray:
    minimum = source_rgb.min(axis=2)
    maximum = source_rgb.max(axis=2)
    background = ((minimum >= 235) & ((maximum - minimum) <= 8)).astype(np.uint8)
    _, labels, _, _ = cv2.connectedComponentsWithStats(background, 8)
    border_labels = np.unique(np.concatenate((labels[0], labels[-1], labels[:, 0], labels[:, -1])))
    foreground = (~np.isin(labels, border_labels)).astype(np.uint8)
    count, component_labels, stats, _ = cv2.connectedComponentsWithStats(foreground, 8)
    if count <= 1:
        raise RuntimeError("未识别到 Relic 前景")
    largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    return cv2.GaussianBlur((component_labels == largest).astype(np.uint8) * 255, (0, 0), 0.8)


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_width, target_height = size
    scale = max(target_width / image.width, target_height / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - target_width) // 2
    top = (resized.height - target_height) // 2
    return resized.crop((left, top, left + target_width, top + target_height))


def mask_bounds(mask: np.ndarray) -> tuple[int, int, int, int]:
    ys, xs = np.where(mask)
    return int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1


def generate(rarity: str) -> None:
    source_path = SOURCE_ROOT / "sources" / f"relic_{rarity}.png"
    scheme_path = SOURCE_ROOT / "cut-schemes" / f"relic_{rarity}.json"
    scheme = json.loads(scheme_path.read_text(encoding="utf-8"))
    width = int(scheme["source"]["width"])
    height = int(scheme["source"]["height"])
    source = Image.open(source_path).convert("RGB")
    if source.size != (width, height):
        raise RuntimeError(f"{rarity} 原图尺寸与切割方案不一致")

    boundaries = rasterize_boundaries(scheme)
    masks = extract_slot_masks(scheme, boundaries)
    union = np.any(masks, axis=0)
    source_rgb = np.asarray(source)
    frame_alpha = np.minimum(extract_foreground_alpha(source_rgb), np.where(union, 0, 255).astype(np.uint8))
    frame = Image.fromarray(np.dstack((source_rgb, frame_alpha)), "RGBA")

    RUNTIME_OUTPUT.mkdir(parents=True, exist_ok=True)
    ARCHIVE_OUTPUT.mkdir(parents=True, exist_ok=True)
    PREVIEW_OUTPUT.mkdir(parents=True, exist_ok=True)
    frame_name = f"relic_{rarity}_frame.png"
    frame.save(RUNTIME_OUTPUT / frame_name, optimize=True)
    frame.save(ARCHIVE_OUTPUT / frame_name, optimize=True)

    slots: list[dict] = []
    preview = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for index, (mask, card_path) in enumerate(zip(masks, CARD_PATHS), 1):
        left, top, right, bottom = mask_bounds(mask)
        slot_width = right - left
        slot_height = bottom - top
        slots.append({
            "id": index,
            "x_ratio": left / width,
            "y_ratio": top / height,
            "width_ratio": slot_width / width,
            "height_ratio": slot_height / height,
        })
        # 检查图可以裁出精确形状；正式客户端不会加载该遮罩，也不会裁子卡。
        art = cover_resize(Image.open(card_path).convert("RGBA"), (slot_width, slot_height))
        art.putalpha(Image.fromarray((mask[top:bottom, left:right] * 255).astype(np.uint8)))
        preview.alpha_composite(art, (left, top))
    preview.alpha_composite(frame)
    preview.save(PREVIEW_OUTPUT / f"relic_{rarity}_preview.png", optimize=True)

    layout = {
        "rarity": rarity,
        "render_mode": "precut_frame_overlay",
        "canvas": {"width": width, "height": height},
        "frame": f"res://Resources/Relics/final/{frame_name}",
        "slots": slots,
        "label_layout": LABEL_LAYOUTS[rarity],
        "rendering": {"slot_z_index": 0, "frame_z_index": 10},
    }
    (RUNTIME_OUTPUT / f"relic_{rarity}_layout.json").write_text(
        json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"[{rarity}] {width}x{height} -> 5 slots, precut frame saved")


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_manifest() -> None:
    items = []
    for rarity in RARITIES:
        source = SOURCE_ROOT / "sources" / f"relic_{rarity}.png"
        scheme = SOURCE_ROOT / "cut-schemes" / f"relic_{rarity}.json"
        frame = ARCHIVE_OUTPUT / f"relic_{rarity}_frame.png"
        layout = json.loads((RUNTIME_OUTPUT / f"relic_{rarity}_layout.json").read_text(encoding="utf-8"))
        items.append({
            "rarity": rarity,
            "canvas": layout["canvas"],
            "source": {"file": str(source.relative_to(SOURCE_ROOT)), "sha256": file_sha256(source)},
            "cut_scheme": {"file": str(scheme.relative_to(SOURCE_ROOT)), "sha256": file_sha256(scheme)},
            "cut_frame": {"file": str(frame.relative_to(SOURCE_ROOT)), "sha256": file_sha256(frame)},
        })
    (SOURCE_ROOT / "manifest.json").write_text(
        json.dumps({"format": "ccr-relic-art-source", "version": 1, "items": items}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    args = parse_args()
    targets = RARITIES if args.rarity == "all" else (args.rarity,)
    for rarity in targets:
        generate(rarity)
    if args.rarity == "all":
        write_manifest()


if __name__ == "__main__":
    main()
