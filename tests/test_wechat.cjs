const assert=require('node:assert/strict');
const fs=require('node:fs');
const vm=require('node:vm');
const path=require('node:path');
const source=fs.readFileSync(path.join(__dirname,'../tools/wechat/skyline-platform.js'),'utf8');
let checks=0;
function check(value,label){assert.ok(value,label);checks++;console.log('PASS:',label);}
function create(adId=''){
  const storage=new Map(), events=[], listeners={};
  let close,error,share,cloud,shows=0;
  const ad={onClose(fn){close=fn;},onError(fn){error=fn;},show(){shows++;return Promise.resolve();},load(){return Promise.resolve();}};
  const wx={getStorageSync:k=>storage.get(k),setStorageSync:(k,v)=>storage.set(k,v),getDeviceInfo:()=>({benchmarkLevel:10}),createRewardedVideoAd:()=>ad,
    onHide:fn=>listeners.hide=fn,onTouchEnd:fn=>listeners.touch=fn,showShareMenu(){},onShareAppMessage(){},
    shareAppMessage:value=>share=value,setUserCloudStorage:value=>cloud=value,showToast(){}};
  const box={wx,module:{exports:{}},GameGlobal:{},console,require:()=>({rewardAdUnitId:adId,title:'Skyline'}),setTimeout:()=>1,clearTimeout(){}};
  vm.createContext(box);vm.runInContext(source,box);
  const bridge=box.module.exports;bridge.setCallback((...args)=>events.push(args));
  return {bridge,events,listeners,storage,close:result=>close(result),error:()=>error(),shows:()=>shows,share:()=>share,cloud:()=>cloud};
}
async function run(){
  const none=create();
  check(!none.bridge.hasRewardAd(),'no ad ID disables reward ads');
  none.bridge.showRewardAd();
  check(none.events.length===1 && none.events[0][1]===false,'unconfigured ad reports failure');
  none.bridge.setStorage('save','{"coins":34}');
  check(none.bridge.getStorage('save')==='{"coins":34}','wx storage round trip');
  check(none.bridge.isLowEnd(),'low-end hardware is detected');
  none.listeners.hide();check(none.events.at(-1)[0]==='hide','background event reaches Godot');
  none.bridge.share('第1名');check(none.share().title==='第1名','share opens native panel');
  none.bridge.submitScore(72000);none.bridge.submitScore(81000);
  check(none.cloud().KVDataList[0].value==='72000','only improved time is submitted');
  none.bridge.submitScore(69000);check(none.cloud().KVDataList[0].value==='69000','new best replaces cloud score');
  const complete=create('adunit-test');
  complete.bridge.showRewardAd();complete.bridge.showRewardAd();
  check(complete.shows()===1,'duplicate ad requests do not open two videos');
  complete.close({isEnded:false});
  check(complete.events[0][1]===false,'early close is not rewarded');
  complete.bridge.showRewardAd();complete.close({isEnded:true});complete.close({isEnded:true});
  check(complete.events.filter(e=>e[1]===true).length===1,'completed ad grants once despite duplicate close');
  complete.bridge.showRewardAd();complete.close(undefined);
  check(complete.events.at(-1)[1]===false,'unknown completion state is not rewarded');
  complete.bridge.showRewardAd();complete.error();
  check(complete.events.at(-1)[1]===false,'native ad error is not rewarded');
  console.log(`WECHAT_TESTS ${checks}/${checks} passed`);
}
run().catch(error=>{console.error(error);process.exitCode=1;});
