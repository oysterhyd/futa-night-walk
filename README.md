# 燃灯夜行 · 夜渡

源码版本 3.1.0「夜渡」：新界面、故事、燃灯与四象构筑，见 [3.1 改动记录](docs/NIGHT_CROSSING_3_1.md)和 [3.1 Windows 验收记录](docs/NIGHT_CROSSING_3_1_QA.md)。四章动作版 3.0.0 重构与特效改进见 [重构记录](docs/CAMPAIGN_REWORK.md)，验证范围见 [四章验收记录](docs/CAMPAIGN_QA.md)。

长夜漫漫，百鬼横行。持辟邪古灯破夜诛邪，穿巷渡江，直登古塔之巅。

Godot 原生 Windows 版，包含灯市旧巷、白狐渡、沉钟寺、无明塔四章连续冒险。美术采用民俗木版画与剪纸，毛笔标题、文楷正文、路签按钮、册页面板与朱印组成统一界面。运行不需要安装 Python 或 Godot，也不需要联网。

## 直接游玩

从 [GitHub Releases 下载 3.1.0 四章 Windows 发行包](https://github.com/oysterhyd/futa-night-walk/releases/tag/v3.1.0)，解压后打开 `NightRoad.exe`。这是 Windows x86_64 免安装版，`NightRoad.exe` 与 `NightRoad.pck` 必须放在同一目录。发行包包含完整游戏、游玩说明与许可文件。

包含三位夜行者、四章共五十六个房间、六件装备、六种主动技能、十六种符印、十六件遗物与十种奇遇。装备与技能各占一个槽位，可升阶并选择形态改造。构筑跨章保留，击败无明塔主后完成冒险。后三章有涨潮、落钟、封印爆发、专属奇遇和不同首领招式。提供标准闯关与每日挑战，保留营地、难度和契约。

WASD / 方向键移动，鼠标瞄准，左键攻击（支持点按与长按），右键 / Q 发动唯一技能，空格闪避，F 燃灯，E 交互与过门，祭灯时长按 E，B 查看行囊，Tab 查看地图，Esc 暂停，F11 全屏。手柄使用左摇杆移动、右摇杆瞄准、RT 攻击、RB 技能、LT 闪避、R3 燃灯、Y 交互、LB 地图。

- [四章游玩说明](docs/CAMPAIGN_GUIDE.md)
- [四章验收证据、性能与测试范围](docs/CAMPAIGN_QA.md)
- [美术、字体和音乐素材记录](godot/assets/ART_RECORD.md)

## 开发与发行

用 Godot 4.7.2 打开 `godot/project.godot`。从仓库根目录用 PowerShell 7 执行：

```powershell
pwsh -NoProfile -File tools/verify_native.ps1
pwsh -NoProfile -File tools/build_native_release.ps1 -Version 3.1.0
pwsh -NoProfile -File tools/verify_native_release.ps1 -Version 3.1.0
```

原生模拟与存档在 `godot/systems/`、`godot/core/`；角色、场景和批量特效在 `godot/presentation/`；刻版控件和手记在 `godot/ui/`；规则与真实 GUI 验证在 `godot/tests/`。报告写入 `godot/test-output/`。

Python 仅用于制作音频、测量图集和重做字体子集，开发依赖见 `requirements-dev.txt`。音效与章节音乐工具分别为 `tools/compose_native_cues.py`、`tools/compose_native_audio.py`，字体源保存在 `tools/_sources/`。

## 存档与许可

当前仓库源码为 Godot 原生版。构建产物通过 GitHub Releases 分发，导入缓存、测试输出和个人存档不提交到仓库。

设置页可导入已有旧版营地 `profile.json`。代码许可见 [LICENSE](LICENSE)，Godot 与字体许可随发行包提供。
