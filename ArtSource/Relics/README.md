# Relic 正式美术源文件

这里永久保存白、绿、蓝、紫、橙、黑、红七种 Relic 的原图和 Nan 导出的切割边界方案。

- `sources/`：七张原始 Relic PNG。
- `cut-schemes/`：网页标记工具导出的 JSON。
- `cut-frames/`：构建脚本生成的七张最终透明开窗外框。
- `previews/`：构建阶段的真实子卡合成检查图。

本目录带有 `.gdignore`，Godot 不导入源文件，也不会在运行时读取或裁切这些图片。客户端只加载 `Resources/Relics/final/` 中预生成的外框和布局。

重新构建：

```bash
python3 tools/build_relic_final_assets.py
```

