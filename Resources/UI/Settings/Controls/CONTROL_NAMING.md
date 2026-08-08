# Settings Control Asset Naming

本文件固定 Nan 确认的两张黄绿色背景预览图中的控件命名。后续实装必须先确认要替换的是哪个组件，再切对应状态图，避免把底座、内容面板和拨块混用。

## 第一张图：控件底座

源图：

- `outputs/settings-ui-image2/settings-controls-bases-transparent-solid-preview.png`
- 透明源图：`outputs/settings-ui-image2/settings-controls-bases-transparent.png`

命名约定：

| 位置 | 中文名称 | 组件 ID | Godot 目标 | 说明 |
| --- | --- | --- | --- | --- |
| 第 1 行 | 文本显示框 | `text_display_box` | `LineEdit` 或只读文本框背景 | 用于玩家名、只读信息、短文本显示；不作为普通按钮底图。 |
| 第 2 行 | 下拉框 | `dropdown_box` | `OptionButton` 关闭状态 | 只表示下拉框本体，不包含展开后的列表内容。 |
| 第 3 行左侧 | 单选框 | `radio_button` | `CheckBox`/`Button` 单选外观 | 用于单选项。若临时用于复选框，文件名也必须标注为兼容用途。 |
| 第 3 行右侧 | 布尔按钮 | `boolean_toggle_base` | 开关底座 | 只表示开关底座，不包含可移动拨块。拨块必须来自第二张图的 `boolean_toggle_thumb`。 |
| 第 4 行 | 水平滚动条 | `horizontal_scrollbar_track` | `HSlider`/`HScrollBar` 轨道 | 只表示水平轨道，不包含拨块。拨块必须来自第二张图的 `horizontal_scrollbar_thumb`。 |
| 第 5 行左侧 | 垂直滚动条 | `vertical_scrollbar_track` | `VScrollBar` 轨道 | 只表示垂直轨道，不包含拨块。拨块必须来自第二张图的 `vertical_scrollbar_thumb`。 |
| 第 5 行中间 | 下拉框的内容 | `dropdown_menu_panel` | `PopupMenu`/下拉列表面板 | 只用于展开后的列表面板，不用于下拉框关闭状态。 |
| 第 5 行右侧 | 上下翻页键 | `stepper_buttons` | 上/下翻页按钮或滚动按钮 | 包含方向按钮组；后续按方向和状态切成单独按钮资源。 |

## 第二张图：可移动拨块

源图：

- `outputs/settings-ui-image2/settings-controls-knobs-transparent-solid-preview.png`
- 透明源图：`outputs/settings-ui-image2/settings-controls-knobs-transparent.png`

命名约定：

| 位置 | 中文名称 | 组件 ID | Godot 目标 | 说明 |
| --- | --- | --- | --- | --- |
| 第 1 行 | 水平滚动条拨块 | `horizontal_scrollbar_thumb` | `HSlider`/`HScrollBar` grabber | 只能作为水平轨道上的可移动拨块。 |
| 第 2 行 | 布尔按钮拨块 | `boolean_toggle_thumb` | 开关可移动拨块 | 只能配合 `boolean_toggle_base` 使用，按 false/true 位置移动。 |
| 第 3 行 | 垂直滚动条拨块 | `vertical_scrollbar_thumb` | `VScrollBar` grabber | 只能作为垂直轨道上的可移动拨块。 |
| 第 4 行 | 暂不用拨块 | `unused_thumb_04` | 暂不用 | 暂不接入游戏，不参与设置页实装。 |

## 状态后缀

切片后的文件名采用：

```text
{component_id}_{state}.png
```

允许状态：

- `normal`
- `focus`
- `pressed`
- `disabled`
- `checked`
- `unchecked`

示例：

- `text_display_box_normal.png`
- `dropdown_box_focus.png`
- `boolean_toggle_base_pressed.png`
- `boolean_toggle_thumb_normal.png`
- `horizontal_scrollbar_track_normal.png`
- `horizontal_scrollbar_thumb_focus.png`
- `vertical_scrollbar_track_normal.png`
- `vertical_scrollbar_thumb_pressed.png`
- `dropdown_menu_panel_normal.png`
- `stepper_buttons_up_normal.png`
- `stepper_buttons_down_pressed.png`

## 实装顺序

后续逐个实装时按以下顺序推进，每个组件单独验证：

1. `text_display_box`
2. `dropdown_box`
3. `radio_button`
4. `boolean_toggle_base` + `boolean_toggle_thumb`
5. `horizontal_scrollbar_track` + `horizontal_scrollbar_thumb`
6. `vertical_scrollbar_track` + `vertical_scrollbar_thumb`
7. `dropdown_menu_panel`
8. `stepper_buttons`

每完成一个组件，先在设置页确认比例、九宫格边距、文字位置和状态切换，再继续下一个组件。

## 下拉框固定尺寸规则（2026-07-26）

- `dropdown_box_*`：最终尺寸固定为 `340 x 60`，运行时不得横向非等比拉伸。
- `dropdown_menu_panel_2_items.png`：源素材 `340 x 78`，运行时仅延长中段到 `340 x 96`，完整容纳 2 项。
- `dropdown_menu_panel_5_items.png`：源素材 `340 x 165`，运行时仅延长中段到 `340 x 194`，完整容纳 5 项。
- `dropdown_menu_panel_15_items.png`：源素材 `340 x 455`，运行时仅延长中段到 `340 x 500`，完整容纳 15 项。
- `dropdown_menu_panel_region.png`：`340 x 533`，用于国家/区域长列表。
- 所有关闭态和展开态素材的分隔线保持在约 `80%` 宽度处，左侧显示运行时文字，右侧显示箭头或滚动区。
- 国家/区域列表的 `dropdown_scroll_thumb_*` 是独立可移动图层，不得烘焙进面板，也不得非等比缩放。
- `dropdown_scroll_thumb_*` 的水平中心必须对准国家面板右舱内的黄铜轨道中心；布局时需补偿 `PopupMenu` 内容区左内边距，不能只按透明滚动条命中区居中。
- 下拉列表项 hover 高亮由运行时透明贴图绘制，只在左侧约 `80%` 文字区显示蓝色细边框；右侧约 `20%` 箭头 / 滚动舱必须保持透明，不能出现横跨全宽的蓝色光圈。
- 2/5/15 项短弹层在运行时移除源素材右舱中的旧烘焙滚动条，只保留无控件的黑钛纹理右舱；国家/区域长列表继续保留轨道与独立拨块。
- 短弹层分隔带统一使用关闭态 `dropdown_box_normal.png` 的 `x = 268-272px` 金属线，使关闭态和展开态严格共线；选中圆圈由运行时按 `SETTINGS_TEXT` 颜色生成，不使用 Godot 默认白色 radio 图标。

## 布尔按钮固定组合规则（2026-07-26）

- `toggle_base_*` 对应命名约定中的 `boolean_toggle_base`，使用完整胶囊底座贴图，不做九宫格切片。
- `toggle_knob_*` 对应 `boolean_toggle_thumb`，使用完整圆形装饰拨块并保持原始长宽比；`toggle_knob_*_icon.png` 是旧缩略资源，不再用于静音布尔按钮。
- false/true 状态只移动独立拨块的水平位置，并切换对应 normal/focus 资源；不得拉伸或裁切拨块。

## 文本显示框接入规则（2026-07-26）

- 当前 Godot 文件名 `line_edit_{normal,focus,pressed,disabled}.png` 对应命名约定中的 `text_display_box`。
- 设置页顶部 `BasicSettingsTab`、`ControllerSettingsTab`、`ProfileSettingsTab` 和玩家信息页 `PlayerNameField` 使用这组文本显示框贴图，运行时控件尺寸按 `220 x 60` 等比显示。
- 这组资源只用于页签、只读玩家名等文本显示框，不作为普通设置按钮底图；设置页普通动作按钮按需求复用退出游戏弹窗按钮贴图。
- 文本显示框目前不做九宫格切片，避免边角和金属结构被二次切割。

## 垂直滚动条轨道拉伸规则（2026-07-26）

- `vertical_scrollbar_track_*` 作为轨道底图时使用 `NinePatchRect`，上下端帽按 `78px` 源图边距保护。
- 运行时只拉伸中段；上/下箭头和端部矩形边缘不得整张纵向缩放或拉伸变形。
- `vertical_scrollbar_thumb_*` 仍是独立可移动拨块，保持原始长宽比并随滚动值移动。
