const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const read=name=>JSON.parse(fs.readFileSync(path.join(root,name),'utf8').replace(/^\uFEFF/,''));
const fmt=n=>Number(n).toFixed(1);
const models=read('art/asset_manifest.json');
const label={characters:'角色',accessories:'配饰',track:'场景模块',interactive:'交互',props:'城市装饰',background:'远景',effects:'特效'};
const inventory=['# 美术资产清单','','所有 GLB 由 Blender 5.2.3 脚本生成，完整源文件位于 `art/`。','','| 分类 | 资源 | 三角面 | GLB字节 |','|---|---|---:|---:|',...models.map(m=>`| ${label[m.category]} | ${m.name} | ${m.triangles} | ${m.bytes} |`),'',`共 ${models.length} 个模型，${models.reduce((n,m)=>n+m.triangles,0)} 个唯一三角面。运行时复用模型，因此此数值不是单帧统计。`,'','每款角色含 Run / Jump / Land / Flip / Hit / Celebrate / Climb / SideSlide 八套骨骼动画。UI 使用 Godot 原生矢量绘制，字体和原始授权另见 `assets/fonts/`。'];
fs.writeFileSync(path.join(root,'docs/资产清单.md'),inventory.join('\n'));
const data=['portrait','landscape'].map(o=>({o,p:read('build/performance_'+o+'.json'),pack:read('build/package-'+o+'.json')}));
for(const {o,p,pack} of data){
  if(!p.measured_frames)throw Error('Missing per-frame data: '+o);
  if(p.frame_peak_draw_calls>80||p.frame_peak_primitives>5000||pack.main_bytes>4194304)throw Error('Budget exceeded: '+o+' '+JSON.stringify(p));
}
const report=['# 性能与功能测试报告','','测试日期：2026-11-06（UTC+8）。','','## 测量环境与结果','',`Godot 4.7.2 / Compatibility / OpenGL 3.3，Windows，${data[0].p.hardware}。水墨默认质量、60帧上限、音乐关闭，运行完整首关；不使用加速时间。两种方向同时运行，结果用于本机回归，不等同于低端安卓认证。`,'','每帧读取 Godot 渲染监视器并记录最大值，FPS 每秒读取一次。首两秒资源/着色器预热不计入下表；不把加载阶段的停顿计作稳定游戏帧率。图元监视器同时包含UI与3D绘制，作为保守预算统计。','','| 方向 / 逻辑视口 | 测量帧数 | FPS范围 | FPS均值 | 每帧Draw Call峰值 | 每帧图元峰值 | 通关用时 |','|---|---:|---:|---:|---:|---:|---:|'];
for(const {o,p} of data){const a=p.samples.map(x=>x.fps);report.push(`| ${o} / ${p.viewport.width}×${p.viewport.height} | ${p.measured_frames} | ${Math.min(...a)}—${Math.max(...a)} | ${fmt(a.reduce((x,y)=>x+y,0)/a.length)} | ${p.frame_peak_draw_calls} | ${p.frame_peak_primitives} | ${fmt(p.race_seconds)}秒 |`);}
report.push('','原始数据：`build/performance_portrait.json`、`build/performance_landscape.json`。重现：以对应窗口尺寸运行 `-- --benchmark`。基准测试使用同样的AI路线策略控制玩家，结束后恢复测试前存档。','','## 功能检查','','- Godot 玩法回归：59/59。128²纸纹、平台视觉/物理高度一致、20粒子池上限、低端粒子关闭、冲线卷轴动画、三路高低分叉、浪客骨骼与材质、最多两名可见NPC、远处对手分散、随机追逐起跑、正面攀爬翻上平台、侧面滑铲、自动跳跃、无弹窗就近恢复、跳板只触发一次、触摸点按、首关通关、金币奖励、皮肤购买、JSON存档往返、每日奖励防重、广告失败和重复回调、切后台暂停。','- 微信桥接模拟：13/13。wx存储、低端识别、分享参数、最佳成绩上报、广告中断/失败/未知状态不奖励、重复请求和回调保护。','- 打包及资产检查：19/19。两种方向、游客身份、分包声明、资源包魔数、桥接加载、开放数据域及模型面数预算。','- 视觉检查：主页、衣橱、水墨主页、青石/栈道/屋檐/石桥、古建山雾、攀爬、卷轴与印章结算；检查字体、触控区域与卡片是否溢出。','','自动化为逻辑及静态检查，不能证明真实 wx 平台 API 或微信渲染兼容。','','## 包体','','下表是目录文件的实际字节数，包含分发授权文件。引擎 WASM 保持上游 Brotli 压缩，不用 ZIP 的二次压缩数值替代主包统计。','','| 方向 | 主包 | engine分包 | 总计 | 主包门槛 |','|---|---:|---:|---:|---:|');
for(const {o,pack} of data)report.push(`| ${o} | ${pack.main_bytes} B | ${pack.engine_subpackage_bytes} B | ${pack.total_bytes} B | 4,194,304 B |`);
report.push('','## 尚未验证','','| 项目 | 当前状态 |','|---|---|','| 微信开发者工具编译/运行 | 本机未检测到开发者工具，未验证 |','| 低端安卓稳定≥30 FPS | 没有连接手机，未验证 |','| iOS与高性能模式 | 未验证 |','| 激励视频真实投放 | 未提供广告位ID，未验证 |','| 正式好友榜/云存储 | 未提供正式AppID和微信账号环境，未验证 |','| 微信内存峰值、冷启动和首次下载耗时 | 未验证 |','| 微信审核/商业发布 | 尚未进行 |','','主包小于4MiB并不代表引擎解压内存小。WASM 原始大小约66MiB，需在目标手机记录内存峰值、5分钟持续帧率、首次/再次启动和切后台行为。','','没有基于桌面显卡的结果宣称手机性能已达标。当前输出为游客测试工程，不是已上线产品。');
fs.writeFileSync(path.join(root,'docs/性能测试报告.md'),report.join('\n'));
console.log('REPORTS_OK');
