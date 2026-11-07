# 云端飞奔 · SKYLINE RUSH

Godot 4.7.2 水墨跑酷竞速游戏，当前为完整单关版本。支持竖屏与横屏、三路高低平台、6 名 AI、自动跳跃／侧跳／攀爬、掉落就近复活、金币与皮肤、每日挑战、本机纪录。

双击 **运行游戏.cmd**，或使用 Godot 导入 `project.godot` 并运行主场景。鼠标／触屏左右拖动或点按控制横移，键盘 A/D 或方向键也可操作。每收集 15 枚金币自动进入 5 秒疾跑，接近障碍或 NPC 时挥刀。穿过山门立即结算，角色继续向前减速后停下。

## 正式版目录

| 目录 | 用途 |
|---|---|
| scripts、scenes | 游戏逻辑、Shader 和场景 |
| assets | 当前使用的模型、图集、UI、音频和字体，以及待清理旧稿 |
| art | 当前 12 个定稿 Blender 源文件和面数清单（旧稿待清理） |
| jiarui | 当前角色、背景及平台原画；不参与导入和游戏打包 |
| tools | 当前美术重建、微信导出及交付压缩工具 |
| tests | 玩法、特效、卷轴、终点及打包回归检查 |
| .tools/template47 | 本机离线微信引擎模板；不进入游戏资源包 |
| build/wechat-portrait、build/wechat-landscape | 最新微信开发者工具测试工程 |

当前资源详见 `docs/资产清单.md`。历史方案与性能报告保留了阶段标记，最新清理及验证结果见 `docs/清理记录.md`。游戏导出采用当前资源白名单，旧模型和重复素材不再进入新游戏包。工作目录的批量删除被本机自动审批策略拦截，原文件仍保留；候选清单见 `tools/obsolete_files.json`。Git 历史保留。

## 重建与检查

以下命令在项目根目录执行，Godot／Blender 路径按本机安装位置调整。

```powershell
$godot = 'E:\godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --editor --path . --import
& $godot --headless --path . tests/test_game.tscn
& $godot --headless --path . tests/test_sword.tscn
& $godot --path . tests/test_trail.tscn
& $godot --headless --path . tests/test_progress_scroll.tscn
& $godot --headless --path . tests/test_finish.tscn
node tests/test_wechat.cjs
./tools/build_wechat.ps1
./tools/build_wechat.ps1 -Orientation landscape
node tests/test_package.cjs
```

编辑 Blender 源文件后，用 `E:/blender/blender.exe --background --python tools/create_assets.py` 导出。也可追加 `-- --output build/model-check` 验证到临时目录。人物图集用 `tools/build_paper_runner_atlas.ps1` 重建，背景图集用 `tools/build_ink_scenery_atlas.py` 重建（需要 Pillow）。新增正式素材时同步更新 Godot 导出预设的“选中的资源”，特别是通过字符串动态加载的素材。字体和音频已随工程提供；需要重建时运行 `tools/setup_art.ps1`。离线模板缺失时运行 `tools/fetch_wechat_template.ps1`。需要交付 ZIP 时运行 `tools/package_delivery.ps1`，日常不保存多份重复压缩包。

## 微信状态

当前为微信**小游戏**工程，使用社区 Godot 微信模板和 Compatibility / WebGL2。主包与引擎分包大小由 `build/package-portrait.json`、`package-landscape.json` 记录。

尚未提供正式 AppID 或广告位，使用游客配置。微信开发者工具、原生广告／好友榜和低端手机帧率仍需正式账号及真机验证。配置步骤见 `docs/微信打包说明.md`。本次清理的自动化结果不能代替真机性能测试。
