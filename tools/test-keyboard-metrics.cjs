const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const ts = require('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
const exportsObject = {};
vm.runInNewContext(ts.transpileModule(fs.readFileSync('entry/src/main/ets/ime/KeyboardMetrics.ets','utf8'), {compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText,{exports:exportsObject});
const {KeyboardMetrics} = exportsObject;
function near(a,b){assert(Math.abs(a-b)<1e-6, `${a} != ${b}`);}
const p = new KeyboardMetrics(940,2048);
near(p.numberWidth,174);near(p.alphaWidth,81);near(p.gap,12);near(p.numberHeight,121);near(p.panelHeight,688);
for(const [width,height] of [[418,920],[920,418],[600,960],[960,600]]) {
  const m=new KeyboardMetrics(width,height);
  near(m.margin*2+m.numberWidth*5+m.gap*4,width);
  near(m.margin*2+m.alphaWidth*10+m.gap*9,width);
  assert(m.panelHeight<=height*.55+1e-6);
  assert(m.toolbarHeight+m.numberHeight*4+m.numberGap*3+m.bottomPadding<=m.panelHeight+1e-6);
  assert(m.toolbarHeight+m.alphaHeight*4+m.alphaGap*3+m.bottomPadding<=m.panelHeight+1e-6);
}
const l=new KeyboardMetrics(920,418);assert(l.alphaHeight>35);assert(l.gap<6);
const clipped=new KeyboardMetrics(695,418,200);
near(clipped.panelHeight,200);assert(clipped.toolbarHeight+clipped.numberHeight*4+clipped.numberGap*3+clipped.bottomPadding<=200+1e-6);
console.log('Keyboard metrics portrait parity / landscape fit: PASS');
