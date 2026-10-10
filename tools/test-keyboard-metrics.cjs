const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/ime/KeyboardMetrics.ets','utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{exports:exportsObject});
const {KeyboardMetrics} = exportsObject;
function near(a,b){assert(Math.abs(a-b)<1e-6, `${a} != ${b}`);}
const p = new KeyboardMetrics(470,1024);
const reference=470/1080;
near(p.numberWidth,(470-72*reference)/5);near(p.alphaWidth,(470-132*reference)/10);
near(p.gap,12*reference);near(p.numberHeight,140*reference);near(p.panelHeight,772*reference);
near(p.toolbarHeight,144*reference);near(p.numberGap,15*reference);
const measured=new KeyboardMetrics(1080/2.625,2400/2.625);
near(measured.numberWidth*2.625,201.6);near(measured.numberHeight*2.625,140);
near(measured.gap*2.625,12);near(measured.numberGap*2.625,15);near(measured.toolbarHeight*2.625,144);

for(const [width,height] of [[418,920],[920,418],[600,960],[960,600]]) {
  const m=new KeyboardMetrics(width,height);
  near(m.margin*2+m.numberWidth*5+m.gap*4,width);
  near(m.margin*2+m.alphaWidth*m.alphaColumns+m.gap*(m.alphaColumns-1),width);
  assert(m.panelHeight<=height*.55+1e-6);
  assert(m.toolbarHeight+m.numberHeight*4+m.numberGap*3+m.bottomPadding<=m.panelHeight+1e-6);
  assert(m.toolbarHeight+m.alphaHeight*4+m.alphaGap*3+m.bottomPadding<=m.panelHeight+1e-6);
}
const l=new KeyboardMetrics(920,418);assert(l.alphaHeight>35);assert(l.gap<6);
const clipped=new KeyboardMetrics(695,418,200);
near(clipped.panelHeight,200);assert(clipped.toolbarHeight+clipped.numberHeight*4+clipped.numberGap*3+clipped.bottomPadding<=200+1e-6);
console.log('Keyboard metrics portrait parity / landscape fit: PASS');

for (const [width,height] of [[800,1280],[1280,800],[711,1138],[1138,711],[600,960],[960,600],[1600,1000]]) {
  const m=new KeyboardMetrics(width,height);
  assert(m.tablet); near(m.panelHeight,324); near(m.numberHeight,54); near(m.toolbarHeight,56);
  near(m.margin*2+m.numberWidth*5+m.gap*4,width);
  for (const weights of [[1.2,...Array(10).fill(1),1.2],[1.5,...Array(9).fill(1),1.9],
    [1.8,...Array(9).fill(1),1.6],[1,1,1,6.4,1,1,1]]) {
    near(weights.reduce((sum,w)=>sum+m.alphaWidth*w+m.gap*(w-1),0)+m.gap*(weights.length-1),width-m.margin*2);
  }
  near(m.toolbarHeight+m.numberHeight*4+m.numberGap*3+m.bottomPadding,m.panelHeight);
}
assert(!new KeyboardMetrics(920,418).tablet, 'phone landscape must retain phone layout');
assert(!new KeyboardMetrics(500,800).tablet, 'narrow window must retain compact layout');
const smallTablet=new KeyboardMetrics(800,1280,240); near(smallTablet.panelHeight,240);
console.log('Tablet row widths / bounded height / compact fallback: PASS');
