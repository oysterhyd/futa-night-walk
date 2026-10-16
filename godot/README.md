# 燃灯夜行 · 夜渡

Godot 4.7.2 原生工程，当前发行版本为 3.0.0，内容为四章连续冒险。玩家说明见 `../docs/CAMPAIGN_GUIDE.md`，验收证据见 `../docs/CAMPAIGN_QA.md`。`CHAPTER_ONE_GUIDE.md`、`CHAPTER_ONE_QA.md` 与 NATIVE 系列文档保留为旧版记录。

打开 `project.godot` 运行和编辑。游戏使用 GDScript、Godot 原生绘制、动作图集与音频，运行时不依赖 Python。

从仓库根目录用 PowerShell 7 执行：

```powershell
pwsh -NoProfile -File tools/verify_native.ps1
pwsh -NoProfile -File tools/build_native_release.ps1 -Version 3.0.0
pwsh -NoProfile -File tools/verify_native_release.ps1 -Version 3.0.0
```

图集与字体制作工具只用于开发。设置可以导入已有旧版营地文件；原生运行与构建不依赖旧 Python 版。Windows 免安装发行包见 [GitHub Releases](https://github.com/oysterhyd/futa-night-walk/releases/tag/v3.0.0)。
