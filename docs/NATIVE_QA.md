# 原生版 1.0.0 验收记录

2026-10-14，Windows x86_64。原生游戏工程、发行导出与独立启动已通过。用户手动执行旧版主体清理后重新复核，工程导入、130 项规则检查与发行文件哈希均通过；剩余旧素材导入缓存仍待删除。

## 完成范围与证据

| 验收项 | 结果与证据 |
| --- | --- |
| 原生完整流程 | Godot 导入无解析错误；三位角色各两个种子的六次自然模拟均击败四位首领并结算。见 [playtest.json](../godot/test-output/playtest.json)。 |
| 内容覆盖 | 130 项规则检查通过，覆盖二十种符术、六条进化、十二件旧物、誓愿、契约、成长及保存。见 [world-tests.json](../godot/test-output/world-tests.json)。 |
| 画面、动作与音频 | 选定的十四份印画位图、独立施术图集、脚底对齐、原生纸签与朱印；六段原创章节与首领音轨。GUI 动作时钟验证施术、死亡及四首领蓄力、攻击、怒相。见 [animation-flow.json](../godot/test-output/animation-flow.json)、[素材记录](../godot/assets/ART_RECORD.md)。 |
| 构筑与互动 | 三道誓愿、融霜／燃瘴／引雷、四槽旧物替换、祭灯、首领阶段与风险路线有实现与规则证据；自然模拟包含成长和选择。 |
| 操作与界面 | 29 项真实 GUI 输入检查通过：键鼠、设备 0／1 的标准手柄事件、暂停、教程、行囊、选卡、设置持久化、全屏切换、保存恢复和结算。见 [ui-flow.json](../godot/test-output/ui-flow.json)。 |
| 存档可靠性 | 局内 RNG 精确恢复、嵌套损坏记录拒绝且不改当前状态、有效备份回退、异常写入回滚、旧营地合并和奖励去重通过规则测试。 |
| 模式与性能 | 七次模式模拟包括三项契约、高夜阶、两次同日同途和长夜；同途战斗结果相同，长夜进入第六关。密集压力测试通过。见 [mode-playtest.json](../godot/test-output/mode-playtest.json)、[performance.json](../godot/test-output/performance.json)。 |
| 视觉复核 | 26 个原生画面捕获通过，结合实际截图逐屏检查：菜单、角色、锁定／每日设置、营地、手记、四场景、教程、誓愿、选卡、旧物替换、暂停、设置、行囊、结算及技能形状。修复滑轨／滚动条不可见、字体截字、图片最小尺寸、教程文本和奖励总额。见 [visual-audit.json](../godot/test-output/visual-audit.json)。 |
| 可发行产物 | 1.0.0.0 EXE 与 PCK 单独复制到仓库外临时目录，PATH 仅包含 Windows 系统目录，菜单和战场独立启动均退出 0、stderr 为空；文件及压缩包逐项 SHA256 一致。见 [release-smoke.json](../godot/test-output/release-smoke.json)。 |

总验证记录：[verification.json](../godot/test-output/verification.json)，2026-10-13 18:41:49 UTC（北京时间 10-14 02:41）。字体制作源迁移后重新生成子集，最终发行包再次独立启动。新音效制作工具脱离旧版生成十一份音效，逐文件 SHA256 与运行素材一致。

## 性能实测

机器：AMD Ryzen 7 8845H、NVIDIA GeForce RTX 4060 Laptop GPU、Windows 11 家庭版中文版。引擎报告 `4.7.2.stable.official.ed1daf0bf`，OpenGL Compatibility，1600×900，关闭垂直同步。

持续三十秒、2287 帧；平均 170 个活动敌人与约 400 个投射物，另维持十四个预警与一百五十个掉落，四种五阶符术、三种进化、六种满阶行装。动画、战斗、着色器、音频和 HUD 均启用，每十二秒实际自动存档。

| 指标 | 实测 |
| --- | --- |
| 平均 FPS | 76.18 |
| 平均帧耗时 | 13.13 ms |
| p95 帧耗时 | 15.09 ms |
| p99 帧耗时 | 16.85 ms |
| 平均模拟／表现耗时 | 3.25 / 3.90 ms |
| 自动存档失败 | 0 |

这是原生调试渲染器的人工密集负载，不是所有硬件的性能保证。门槛为 p95 ≤ 16.67 ms；少量 p99 帧超过该值。自动游玩不替代真人体验，手柄验证使用注入事件，尚未验证实物控制器或其他显卡与操作系统。旧版清理前的 44 项 Python 回归检查通过，记录保存在 `godot/test-output/python-regression.log`，属于迁移基线。

## 发行包

- 目录：`dist/NightRoad-v1.0.0/`，包含 EXE、PCK、玩家说明、素材记录、五份许可证与文件清单。
- 压缩包：`dist/符塔夜行-夜渡-Windows-v1.0.0.zip`，72,559,058 字节。
- ZIP SHA256：`a35a10c30171247ad8b7f929582e6baa1751025b25fbca5c6b2ef21000fa8374`。
- [主菜单实机截图](../godot/test-output/release-menu.png)／[战场实机截图](../godot/test-output/release-arena.png)。

退出复测修复了音频驱动尚未释放播放资源的日志：先禁止再次播放、停止并清空音频引用，再按驱动延迟等待后退出。最终两次独立启动日志为空。

## 旧版删除状态

此前自动删除被审批拒绝，用户随后手动执行了脚本。复核旧版主体清单为零：Python 源码、运行素材、测试、构建目录和旧发行包均已删除。原生工程清理后重新导入与 130 项规则检查通过，发行文件逐项 SHA256 与 manifest 一致。

进一步检查发现原脚本遗漏 44 个旧素材的 Godot 导入缓存，已补入 [remove_legacy.ps1](../tools/remove_legacy.ps1)。之后根目录又出现 `assets/data/skills.json`，当前预览共 45 个清理目标（根目录 assets 与 44 个缓存文件），不将其记为完全清理。本环境对缓存的非递归删除也返回 `blocked by policy`，所以仍未删除。再次使用 `-Apply` 手动执行脚本可清理；个人存档保持保留，残留不参与原生运行或发行包。

可复现命令见 [原生项目说明](../godot/README.md)。
