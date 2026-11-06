const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');let checks=0;
function check(value,message){assert.ok(value,message);console.log('PASS:',message);checks++;}
function walk(dir){return fs.readdirSync(dir,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(dir,e.name)):[path.join(dir,e.name)]);}
for(const orientation of ['portrait','landscape']){
  const dir=path.join(root,'build','wechat-'+orientation);
  const config=JSON.parse(fs.readFileSync(path.join(dir,'game.json'),'utf8').replace(/^\uFEFF/,''));
  check(config.deviceOrientation===orientation,orientation+' orientation');
  check(config.subpackages.some(p=>p.name==='engine'&&p.root==='engine/'),'engine declared as subpackage');
  const project=JSON.parse(fs.readFileSync(path.join(dir,'project.config.json'),'utf8').replace(/^\uFEFF/,''));
  check(project.appid==='touristappid' && project.isGameTourist,'tourist identity replaces template AppID');
  let main=0;for(const file of walk(dir)){const rel=path.relative(dir,file).split(path.sep).join('/');if(!rel.startsWith('engine/'))main+=fs.statSync(file).size;}
  check(main<=4*1024*1024,orientation+' main package within 4 MiB: '+main);
  check(fs.readFileSync(path.join(dir,'engine','empty-tips.bin')).subarray(0,4).toString()==='GDPC','actual Godot resource pack header');
  check(fs.readFileSync(path.join(dir,'game.js'),'utf8').includes("import './skyline-platform'"),'native bridge loaded before engine');
  check(config.openDataContext==='open-data'&&fs.existsSync(path.join(dir,'open-data','index.js')),'open data context packaged');
  check(!fs.readFileSync(path.join(dir,'skyline-config.js'),'utf8').includes('adunit-test'),'no test advertisement identity shipped');
}
const manifest=JSON.parse(fs.readFileSync(path.join(root,'art','asset_manifest.json'),'utf8'));
check(manifest.length===45,'all 45 Blender models have a manifest entry');
check(manifest.filter(x=>x.category==='characters').every(x=>x.triangles<=500),'character triangle budget');
check(manifest.filter(x=>x.category==='track').every(x=>x.triangles<=300),'track module triangle budget');
console.log(`PACKAGE_TESTS ${checks}/${checks} passed`);
