// Friend data is read and rendered exclusively in the Open Data Context.
const surface=wx.getSharedCanvas();
const ctx=surface.getContext('2d');
let visible=false;
let rows=[];
function paint(message) {
  if(!visible) return;
  const width=message.width, height=message.height;
  surface.width=width; surface.height=height;
  const scale=width/540;
  ctx.save(); ctx.scale(scale,scale);
  const h=height/scale;
  ctx.fillStyle='#edf6ed'; ctx.fillRect(0,0,540,h);
  ctx.fillStyle='#173d49'; ctx.font='bold 24px sans-serif';
  ctx.fillText('← 返回',28,60); ctx.fillText('好友天际榜',28,130);
  ctx.font='15px sans-serif'; ctx.fillStyle='#65858a';
  ctx.fillText('按完成用时排序 · 越快越靠前',28,165);
  if(!rows.length) ctx.fillText('暂无好友纪录，完成一场竞速后再来看看',28,245);
  rows.slice(0,Math.floor((h-210)/70)).forEach((row,index)=>{
    const y=201+index*70;
    ctx.fillStyle=index===0?'#e7fb78':'#ffffff'; ctx.fillRect(26,y,488,58);
    ctx.fillStyle='#173d49'; ctx.font='bold 20px sans-serif';ctx.fillText(String(index+1).padStart(2,'0'),42,y+37);
    ctx.font='18px sans-serif'; ctx.fillText((row.nickname||'微信跑者').slice(0,8),100,y+36);
    ctx.fillText((row.time/1000).toFixed(2)+' 秒',383,y+36);
  });
  ctx.restore();
}
wx.onMessage(message=>{
  if(message.type==='hide') {visible=false;return;}
  if(message.type!=='show') return;
  visible=true; rows=[]; paint(message);
  wx.getFriendCloudStorage({keyList:['skyline_time_ms'], success(result){
    rows=(result.data||[]).map(user=>{
      const value=(user.KVDataList||[]).find(item=>item.key==='skyline_time_ms');
      return {nickname:user.nickname,time:value?Number(value.value):0};
    }).filter(user=>Number.isFinite(user.time)&&user.time>0).sort((a,b)=>a.time-b.time);
    paint(message);
  },fail(){
    if(!visible)return;paint(message);
    ctx.fillStyle='#65858a';ctx.font='16px sans-serif';ctx.fillText('请使用已登录微信及正式 AppID 测试',28,290);
  }});
});
