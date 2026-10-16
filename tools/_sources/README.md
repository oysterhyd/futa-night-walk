# 字体制作源

此目录保存开发时使用的完整 OFL 字体：`LXGWWenKai-Medium-source.ttf`、`MaShanZheng-source.ttf`。两份源文件已从旧版测试暂存目录复制，并核对 SHA256 一致。源文件不进入 Git 或发行包。

运行 `python tools/bundle_godot_fonts.py` 会更新原生工程字体子集。普通游戏运行和发行导出只使用 `godot/assets/fonts/` 中的现成字体。

上游来源与许可见 `godot/assets/ART_RECORD.md`；源文件缺失时，请按该记录下载相应字体后放在此目录。
