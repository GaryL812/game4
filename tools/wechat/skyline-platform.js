/* Native WeChat bridge. Loaded after weapp-adapter, before Godot. */
const config = require('./skyline-config');
const scope = typeof GameGlobal !== 'undefined' ? GameGlobal : globalThis;
let callback = null;
let ad = null;
let adBusy = false;
let friendsVisible = false;
let friendRenderer = null;
let adTimer = null;
const quad = new Float32Array([-1,-1,1,-1,-1,1,1,1]);
const emit = (event, value) => { if (callback) callback(event, value); };
function finishAd(completed) {
  if (!adBusy) return;
  adBusy = false;
  if (adTimer) clearTimeout(adTimer);
  adTimer = null;
  emit('ad', completed);
}
function initAd() {
  if (ad || !config.rewardAdUnitId || !wx.createRewardedVideoAd) return;
  ad = wx.createRewardedVideoAd({ adUnitId: config.rewardAdUnitId });
  ad.onClose(result => finishAd(!!result && result.isEnded === true));
  ad.onError(() => finishAd(false));
}
function compile(gl, kind, source) {
  const shader = gl.createShader(kind);
  gl.shaderSource(shader, source); gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader));
  return shader;
}
function drawFriends() {
  if (!friendsVisible) return;
  try {
    const surface = wx.getOpenDataContext().canvas;
    const gl = canvas.getContext(scope.__godotMinigameWXGLXEnabled ? 'wxwebgl2' : 'webgl2');
    if (!gl || !surface || !surface.width) return;
    if (!friendRenderer) {
      const program = gl.createProgram();
      const vertex = compile(gl, gl.VERTEX_SHADER, 'attribute vec2 p; varying vec2 uv; void main(){gl_Position=vec4(p,0.,1.);uv=vec2(p.x*.5+.5,.5-p.y*.5);}');
      const fragment = compile(gl, gl.FRAGMENT_SHADER, 'precision mediump float; varying vec2 uv; uniform sampler2D image; void main(){gl_FragColor=texture2D(image,uv);}');
      gl.attachShader(program, vertex); gl.attachShader(program, fragment); gl.linkProgram(program);
      if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program));
      gl.deleteShader(vertex); gl.deleteShader(fragment);
      friendRenderer = { program, vao: gl.createVertexArray(), buffer: gl.createBuffer(), texture: gl.createTexture(), location: gl.getAttribLocation(program, 'p'), sampler: gl.getUniformLocation(program, 'image') };
    }
    const saved = {
      program: gl.getParameter(gl.CURRENT_PROGRAM), vao: gl.getParameter(gl.VERTEX_ARRAY_BINDING),
      buffer: gl.getParameter(gl.ARRAY_BUFFER_BINDING), active: gl.getParameter(gl.ACTIVE_TEXTURE),
      viewport: gl.getParameter(gl.VIEWPORT), framebuffer: gl.getParameter(gl.FRAMEBUFFER_BINDING),
      flip: gl.getParameter(gl.UNPACK_FLIP_Y_WEBGL), mask: gl.getParameter(gl.COLOR_WRITEMASK),
      flags: [gl.BLEND,gl.DEPTH_TEST,gl.CULL_FACE,gl.SCISSOR_TEST,gl.STENCIL_TEST].map(flag=>[flag,gl.isEnabled(flag)])
    };
    gl.activeTexture(gl.TEXTURE0);
    saved.texture = gl.getParameter(gl.TEXTURE_BINDING_2D);
    try {
      gl.bindFramebuffer(gl.FRAMEBUFFER, null);
      saved.flags.forEach(([flag]) => gl.disable(flag));
      gl.colorMask(true,true,true,true);
      gl.viewport(0,0,canvas.width,canvas.height);
      gl.useProgram(friendRenderer.program);
      gl.bindVertexArray(friendRenderer.vao);
      gl.bindBuffer(gl.ARRAY_BUFFER,friendRenderer.buffer);
      if(!friendRenderer.bufferReady) { gl.bufferData(gl.ARRAY_BUFFER,quad,gl.STATIC_DRAW); friendRenderer.bufferReady=true; }
      gl.vertexAttribPointer(friendRenderer.location,2,gl.FLOAT,false,0,0);
      gl.enableVertexAttribArray(friendRenderer.location);
      gl.bindTexture(gl.TEXTURE_2D,friendRenderer.texture);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,false);
      if(!friendRenderer.lastUpload || Date.now()-friendRenderer.lastUpload>200) {
        gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,gl.RGBA,gl.UNSIGNED_BYTE,surface);
        friendRenderer.lastUpload=Date.now();
      }
      gl.uniform1i(friendRenderer.sampler,0);
      gl.drawArrays(gl.TRIANGLE_STRIP,0,4);
    } finally {
      gl.bindTexture(gl.TEXTURE_2D,saved.texture); gl.activeTexture(saved.active);
      gl.bindVertexArray(saved.vao); gl.bindBuffer(gl.ARRAY_BUFFER,saved.buffer);
      gl.useProgram(saved.program); gl.bindFramebuffer(gl.FRAMEBUFFER,saved.framebuffer);
      gl.viewport(...saved.viewport); gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL,saved.flip);
      gl.colorMask(...saved.mask);
      saved.flags.forEach(([flag,enabled])=>enabled?gl.enable(flag):gl.disable(flag));
    }
  } catch (error) {
    friendsVisible=false;
    wx.showToast({ title:'好友排行暂不可用',icon:'none' });
    console.error('[Skyline friends]',error);
  }
}
const originalRAF = scope.requestAnimationFrame || (typeof window !== 'undefined' && window.requestAnimationFrame);
if (originalRAF) {
  const wrapped = fn => originalRAF(time => { fn(time); drawFriends(); });
  scope.requestAnimationFrame=wrapped;
  if (typeof window !== 'undefined') window.requestAnimationFrame=wrapped;
  globalThis.requestAnimationFrame=wrapped;
}
const bridge = {
  setCallback(fn) { callback=fn; },
  getStorage(key) { try { return wx.getStorageSync(key) || ''; } catch (_) { return ''; } },
  setStorage(key,value) { try { wx.setStorageSync(key,value); } catch (e) { wx.showToast({title:'存档失败，请检查空间',icon:'none'}); console.error(e); } },
  isLowEnd() {
    try { const info=wx.getDeviceInfo?wx.getDeviceInfo():wx.getSystemInfoSync(); return (info.benchmarkLevel > 0 && info.benchmarkLevel < 15) || (info.memorySize > 0 && info.memorySize <= 2048); }
    catch (_) { return false; }
  },
  hasRewardAd() { return !!config.rewardAdUnitId && !!wx.createRewardedVideoAd; },
  showRewardAd() {
    if(adBusy) return;
    initAd(); adBusy=true;
    if(!ad) { finishAd(false); return; }
    // An unavailable/failed ad never grants a reward. Close is the authority.
    adTimer=setTimeout(()=>finishAd(false),180000);
    ad.show().catch(()=>ad.load().then(()=>ad.show())).catch(()=>finishAd(false));
  },
  share(title) { if(wx.shareAppMessage) wx.shareAppMessage({title,query:'source=result'}); },
  submitScore(milliseconds) {
    const best=Number(this.getStorage('skyline_best_ms')) || Infinity;
    if(milliseconds>=best) return;
    this.setStorage('skyline_best_ms',String(milliseconds));
    if(wx.setUserCloudStorage) wx.setUserCloudStorage({KVDataList:[{key:'skyline_time_ms',value:String(milliseconds)}], fail:e=>console.warn('[Cloud score]',e)});
  },
  showFriends() {
    if(!wx.getOpenDataContext) { wx.showToast({title:'当前环境不支持好友排行',icon:'none'}); return; }
    friendsVisible=true;
    if(friendRenderer) friendRenderer.lastUpload=0;
    const shared=wx.getOpenDataContext().canvas; shared.width=canvas.width; shared.height=canvas.height;
    wx.getOpenDataContext().postMessage({type:'show',width:canvas.width,height:canvas.height});
  },
  hideFriends() { friendsVisible=false; if(wx.getOpenDataContext) wx.getOpenDataContext().postMessage({type:'hide'}); }
};
scope.SkylinePlatform=bridge;
globalThis.SkylinePlatform=bridge;
if(typeof window!=='undefined') window.SkylinePlatform=bridge;
if(wx.onHide) wx.onHide(()=>emit('hide',false));
if(wx.onTouchEnd) wx.onTouchEnd(event=>{
  const touch=event.changedTouches && event.changedTouches[0];
  if(friendsVisible && touch && touch.clientY<100) bridge.hideFriends();
});
if(wx.showShareMenu) wx.showShareMenu({menus:['shareAppMessage']});
if(wx.onShareAppMessage) wx.onShareAppMessage(()=>({title:config.title}));
module.exports=bridge;
