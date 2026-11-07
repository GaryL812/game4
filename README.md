# 云端飞奔 · SKYLINE RUSH

Blender 原创资产 + Godot 4.7.2 的 3D 水墨跑酷竞速游戏，首关已实现。默认竖屏，支持横屏布局。包含 6 名 AI、34 段高低路线、64 处高低平台、自动跳跃、墨痕／云纹跳板、正面攀爬、侧面滑铲、金币、结算、8 款配色皮肤、每日挑战及本机纪录。

## 本轮修改（0.4.0 · 水墨山海）

- 三路高低跑酷结构、自动攀爬、侧滑、就近复活及稀疏NPC追逐保持可玩。
- 青石板、木栈道、屋檐、石桥四种平台；竹篓、屏风、铜铃三类障碍；墨痕与云纹两类跳板。
- 远景更换为淡墨群山、云雾、亭台、古塔和竹影，移除比赛画面中的城市楼体与现代道具。
- 全场使用128×128重复纸纹和程序化墨色Shader；角色带墨线边缘与干笔飞白，保留浪客造型。
- 跳跃墨点、加速烟墨拖尾、碰撞淡墨扩散，共用20个粒子实例；低端模式关闭动态粒子并减少雾层。
- 界面采用宋体、纸面卡片与朱砂色，冲线触发卷轴展开及通关印章。
- 桌面与小游戏均限制最高60帧，保持低面数与可复现的渲染预算检查；手机真机性能尚未验证。

截图：`build/ink_home.png`、`build/ink_race.png`。完整材质与资源说明见 `docs/水墨风格实现.md`。

## 运行

双击 **运行游戏.cmd**。也可用本机 Godot 4.7.2 导入 `project.godot`，按 F6/F5 运行主场景。

- 手机：左右拖动，或点按左右半屏。
- 电脑：鼠标拖动/点按，A/D 或左右方向键。
- 每收集 15 枚金币自动进入 5 秒、1.3 倍速度的疾跑，画面两侧出现风线，镜头视野拉开，脚下留下墨痕。接近前方同路线、同高度的障碍或 NPC 时自动挥刀，平时保持跑姿。NPC 被斩中后消失 2 秒，再从最近的安全位置恢复比赛。持续期间拾取金币照常获得收益，结束后重新收集 15 枚充能。命中沿用墨爆、短暂震屏和疾行效果，疾行最迟随充能结束。平台高度和三路之间的高度差为最初版本的约四成。
- 跳跃自动完成；墨痕踏板触发加速和翻滚。
- 脚底使用 `assets/ink_fx/trail.png`：普通跑步留下淡墨飞白，斩击和加速时平滑加宽加浓；起跳留下短暂地面笔迹，腾空跟随细淡墨丝，落地接回地面墨痕。两个笔迹实例共用一次绘制，并裁切到屋顶边界。
- Esc 暂停；掉落后自动回到刚离开的屋顶稍往前的位置继续跑，无弹窗、无广告、无检查点。

## 交付目录

| 文件/目录 | 内容 |
|---|---|
| `project.godot`、`scenes/`、`scripts/` | 完整 Godot 工程 |
| `art/` | 45 类 Blender 模型源文件、资源面数清单 |
| `assets/models/` | 按角色、配饰、赛道、交互、装饰、远景、特效分类的 GLB |
| `assets/fonts/`、`assets/audio/` | 中英文字体及授权、原创 MP3 音效/音乐 |
| `tools/create_assets.py` | Blender 全量美术生成脚本 |
| `tools/build_wechat.ps1` | 可重复执行的微信打包脚本 |
| `build/wechat-portrait/`、`build/wechat-landscape/` | 微信开发者工具游客测试工程 |
| `docs/项目实现框架.md` | 资产、模块、适配、优化和扩展方案 |
| `docs/微信打包说明.md` | AppID/广告位配置、导入步骤与发布前验证 |
| `docs/性能测试报告.md` | 自动化结果、桌面渲染数据、未验证项 |
| `tests/` | 玩法回归、微信桥接与打包检查 |

## 微信版本状态

输出目标为 **微信小游戏**。普通微信小程序的页面运行环境与小游戏不同，不能将本工程当成普通小程序上传。

目前未提供正式 AppID / 广告位 ID，因此使用 `touristappid`。工程已打包，但尚未经过微信开发者工具编译和手机真机验证，**不是已审核或可直接发布的商业版本**。激励视频只在原生关闭回调确认完整观看后发奖；未配置时不模拟奖励。分享提供原生接口；好友榜通过开放数据域读取并绘制，需正式账号环境联调。

采用 [godothub 社区微信模板](https://github.com/godothub/godot-minigame/releases/tag/4.7)，并以独立的 `SkylinePlatform` 桥接微信能力。Godot 4 使用 Compatibility / WebGL2；没有 GLES2 路径。引擎放在 `engine` 分包，主包仅保留加载器、桥接与开放数据域。

## 重建和检查

```powershell
# 3D 美术，保留 .blend 与 GLB
& 'E:\blender\blender.exe' --background --python tools/create_assets.py
# 如需重建字体/音频（已随源码提供，可跳过）
./tools/setup_art.ps1
# 导入
& 'E:\godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --editor --path . --import
# 核心玩法回归
& 'E:\godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . tests/test_game.tscn
# 斩击玩法回归；去掉 --headless 并追加 -- --visual 可截图并检查三个特效的 Draw Call 增量
& 'E:\godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . tests/test_sword.tscn
# 跑步／加速／跳跃／落地墨痕回归；追加 -- --visual 可生成四种状态的预览图
& 'E:\godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe' --headless --path . tests/test_trail.tscn
# 微信桥接单元检查
node tests/test_wechat.cjs
node tests/test_package.cjs
# 打包（首次重建先运行 tools/fetch_wechat_template.ps1）
./tools/build_wechat.ps1
./tools/build_wechat.ps1 -Orientation landscape
```

Blender/Godot 的绝对路径可通过脚本参数修改；上述路径对应当前电脑。`.tools` 仅是下载和构建缓存，不是游戏源码依赖，也不进入游戏包。

玩法与竞速结构参考屋顶跑酷类型，玩家角色按照用户提供参考图重新建模；NPC、关卡、UI及音频为本项目生成资产，没有提取原作的模型或关卡文件。
