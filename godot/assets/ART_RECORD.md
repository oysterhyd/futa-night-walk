# 夜渡 · 原生版素材记录

原生版的主方向由用户明确选定：民俗木版画＋剪纸。使用墨蓝、纸白、朱红，以宽轮廓、平涂与刻痕保持战斗中的辨认度。

## 四章动作版新增素材

以下位图使用内置 `image_gen.imagegen` 生成或编辑，工程路径均为 `godot/assets/images/`：

| 文件 | 用途 | 选定生成源文件 |
| --- | --- | --- |
| `campaign-props-print-v2.png` | 渡口、古寺和妖塔共十二种独立道具 | `exec-445da1ad-f2c3-4464-ada4-e9680e0f29af.png` |
| `river-floor-print.png` | 白狐渡栈桥木板地面 | `exec-476b0229-2919-4820-830b-54675c56b5dd.png` |
| `temple-floor-print.png` | 沉钟寺石板地面 | `exec-303afb7e-f79d-4f4d-9310-13cb40934302.png` |
| `tower-floor-print.png` | 无明塔旧木地面 | `exec-e8682f93-4467-44f5-901f-5b1ad1e7f6fa.png` |

完整提示词、编辑参考、透明选项与选用状态保存在 [campaign_art_record.json](data/campaign_art_record.json)，发行包另附 `CAMPAIGN_ART_PROMPTS.json`。第一版 `campaign-props-print.png` 保留作生成来源，运行使用 v2；v2 重新分隔道具，并将系缆桩改为一个连通物件，避免图集切片带入邻近轮廓。透明像素由生图工具生成，测量工具只输出区域坐标。

刀弧、重砸、符弹起手、冰棱、缚地阵、丹丸抛物线、敌弹轮廓与命中碎屑由 `combat_illustration.gd`、`combat_batch.gd` 和着色器绘制。它们依照实际攻击方向、技能位置和时序变化。

3.0 补充章节特效：白狐渡的水纹预警与卷浪、沉钟寺的悬钟落点与碎地冲击、无明塔的纸符阵与飞散符纸；狐姬尾迹、守将钟纹和塔主环绕符印随真实招式触发。爆焰丸落地与连爆各自触发爆燃效果，技能视觉范围取自当前改造。上述效果为项目内原创 Godot 绘制，无新增第三方特效依赖；原有位图与音频来源不变。

新增剑风、槌击、毒针、雷轮、霜砂、弓弦、爆燃、碎冰与钟声九种原创合成提示音，由 `tools/compose_native_cues.py` 制作，无外部采样。命中、敌方起手和关键受伤提示有独立声部与限流。

## 第一章新增素材 · 2026-10-15

第一章使用内置 `image_gen.imagegen` 新生成三份位图，已复制进工程：

| 文件 | 用途 | 生成源文件 |
| --- | --- | --- |
| `market-props-print.png` | 十二种灯市道具：摊位、菜筐、院墙、门、茶桌、工坊、祭灯、宝箱、路障与灯柱 | `exec-9b4efdf7-b5fe-4eb4-83d6-f70690182dcb.png` |
| `market-floor-print.png` | 低对比纸白石板地面 | `exec-7cec56a2-e383-4657-8907-b19752968821.png` |
| `chapter-icons-print.png` | 六件装备与六种主动技能的独立印画图标 | `exec-db043d0b-2413-4847-95e7-c7a0d8a96055.png` |

完整提示词、透明背景选项与源文件名保存在 `assets/data/chapter_art_record.json`，发行包另附 `ART_PROMPTS.json`。道具与图标保留生成图的透明像素。`tools/measure_native_atlases.py` 测量实际轮廓并输出图集区域，避免邻近道具串入画面，不修改图片像素。

场景由地面、碰撞、道具、门与镜头共同组成。斩击、施术、出生预告、状态反应与屏外危险标记由原生绘制和现有批量着色器呈现。角色与怪物沿用已有印画身份和动作图集。

## 当前使用的位图

以下素材使用内置 `image_gen.imagegen` 生成或编辑，生成后复制进工程。保留生成的透明 alpha，不使用离线背景去除。角色图集由 Godot `AtlasTexture` 切片，部分动画以测量后的区域与脚底对齐显示；`tools/measure_native_atlases.py` 只分析像素并写入区域坐标，不修改图片。

| 文件（`godot/assets/images/`） | 用途 | 选定的生成源文件 |
| --- | --- | --- |
| `title-print.png` | 渡口标题画面 | `exec-a28d9864-8900-4575-b4e4-1b32bb3eab15.png` |
| `arena-print.png` | 灯市旧巷 | `exec-b39824c1-be25-42a3-95b6-6bddc017a1c1.png` |
| `arena-fox-print.png` | 白狐渡 | `exec-78b1c139-d413-4027-a4da-d0bafbd2672a.png` |
| `arena-temple-print.png` | 古钟寺 | `exec-be0035d4-72df-4d9f-99b0-e9c3d4ba75d4.png` |
| `arena-tower-print.png` | 无明塔 | `exec-f549a272-6d14-4f6b-841a-6a76742db058.png` |
| `keeper-print.png` | 守灯人待机、行走、闪避、消散 | `exec-729c7624-b464-4fee-a578-809c892dc58b.png` |
| `swordswoman-print.png` | 听雨同上 | `exec-20ee05bc-43bb-4367-a5fe-ce374c9c9bbe.png` |
| `alchemist-print.png` | 葛翁同上 | `exec-da02b286-b535-49e0-8479-e6440715210c.png` |
| `keeper-cast-print.png` | 守灯人六帧施术 | `exec-6aa03cbc-70b2-4df5-b704-c89ae8a7da1e.png` |
| `swordswoman-cast-print.png` | 听雨六帧剑术 | `exec-944e471b-8c05-4ffc-9771-fea6c9e7739e.png` |
| `alchemist-cast-print.png` | 葛翁六帧葫芦施术 | `exec-0c354703-02d3-4961-99c0-f8ba38173bd8.png` |
| `enemy-print-v2.png` | 五种怪物，各六帧行走、蓄力与攻击 | `exec-9df5082a-92bc-47ca-a0f4-1ab5d7a1903e.png` |
| `boss-print.png` | 四位首领，各六帧待机、蓄力、攻击与恢复 | `exec-eb0d6fb3-76d9-4575-92ec-b2a6723bd42e.png` |
| `environment-props-print.png` | 石灯、狐祠、残碑、铜钟、红灯、芦苇、香炉与旧书 | `exec-282190fb-d0ff-4761-bc30-c1cad31cf8c4.png` |

选定源文件保存在本次会话的 Codex 生成目录中。项目运行只依赖表中的工程内文件。旧版素材与较早的图集已由用户执行清理脚本删除；剩余旧开发导入缓存不参与当前运行或正式发布包，清理状态见根目录 README。

## 提示词集合

共享风格提示：`Chinese folk woodblock print and cut-paper game sprites. Three solid inks: dark indigo #183544, warm ivory #e8dfc5, vermilion #ad3527. Broad flat silhouettes, bold carved edges, sparse deliberate hatch incisions. No painterly gradients, glows, halos, smoky backdrops, shadows or floor. Completely transparent PNG alpha0 outside each separate figure.`

场景提示：俯视 16:9，中央约八成留低对比纸白地面，边缘使用墨蓝建筑、草木与少量朱红符纸；分别以灯市庭院、狐渡水域、古寺铜钟、封妖塔木地板为主题；不绘制角色、敌人、UI 或文字。标题画面左侧留纸面，右侧安排月轮、夜塔与提灯的路。

人物动作提示：以原有角色为身份参考，保持帽形、发型、衣装与配色；待机、行走、闪避、消散为六列五行。施术单独制作三列两行的六帧图集，人物、手脚和武器完整，保留透明边距，避免把长魔法尾迹烘焙进动作图。

敌人提示：纸灵、灯妖、雾狐、石卫、弓手各占一行，六列分别为四帧行走、蓄力、攻击；每个角色保留独立透明边距。首领六列四行，动作对应真实蓄力与攻击计时。环境道具四列两行，各物件独立透明背景。

实际生产以接入后的截图、动作时钟与图集区域检查为准，不以提示词所要求的尺寸或留白作为验证结果。

## 原生绘制

`godot/ui/` 内的纸签按钮、书页、穿绳、朱印、勾选标记、滑条与灯形图标使用 SVG 或 Godot 绘图代码。标题独立排字并加入刻痕。字体、菜单形状和战斗图形共享印刷语汇。

符纸、灵珠、冰晶、魂灯、丹丸、箭矢、雷印与回声环由批量绘制着色器生成。护身符为菱形纸符，影分身使用角色纹样。没有外部 UI 或图标库。

## 字体

- 霞鹜文楷 Medium 1.522：正文与数值，来源 https://github.com/lxgw/LxgwWenKai 。采用 OFL 1.1；保留版权与许可证。
- 马善政毛笔字体：标题、印章与控件，来源 https://github.com/googlefonts/mashanzheng 。采用 OFL 1.1。
- `tools/bundle_godot_fonts.py` 根据工程实际文字制作字形子集，并将修改字体分别改名为 `NightRoad Notes` 与 `NightRoad Inscription`。许可文件位于 `assets/fonts/`。

## 音频

章节、渡口与首领配乐由 `tools/compose_native_audio.py` 以原创音符与节奏编排，使用弦音、笛音、钟音、木击与鼓音的程序合成，无外部采样。六段循环为立体声，保留循环尾音并修平接缝。纸签点击与拾取提示为短音。

其余命中、闪避、镇魂、受伤与结局提示使用项目原创合成音，制作工具为 `tools/compose_native_cues.py`。普通声部与关键声部独立分配，避免密集拾取淹没受伤或首领提示。合成音的响度与循环数据见 `assets/audio/score_record.json`。

## 第三方组件

Godot 4.7.2 标准版与 Windows 导出模板来自官方发行。Godot MIT 许可证与其第三方组件声明位于 `godot/legal/`，并随发行包复制。项目自己的代码与内容不在这些第三方许可证中重新授予公共授权。
