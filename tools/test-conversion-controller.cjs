// Actual ArkTS controller compiled on host; native timing/editor APIs are controlled.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const ts = require('/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js');
const storage = new Map();
const noop = () => {};
const api = {SecurityMode:{FULL:1,BASIC:0},PATTERN_TEXT:0,PATTERN_NULL:-1,getKeyboardDelegate:()=>({on:noop,off:noop}),getInputMethodAbility:()=>({on:noop,off:noop,getSecurityMode:()=>0})};
Object.assign(api,{ENTER_KEY_TYPE_GO:1,ENTER_KEY_TYPE_SEARCH:2,ENTER_KEY_TYPE_SEND:3,
  ENTER_KEY_TYPE_NEXT:4,ENTER_KEY_TYPE_DONE:5,ENTER_KEY_TYPE_PREVIOUS:6,ENTER_KEY_TYPE_NEWLINE:7,
  PATTERN_NUMBER:1,PATTERN_PHONE:3,PATTERN_DATETIME:4});
const cache = new Map();
let fakeTimerId=0;const fakeTimers=new Map();
function load(file) {
  file = path.resolve(file); if(cache.has(file)) return cache.get(file);
  const exports = {}; cache.set(file,exports);
  const source = ts.transpileModule(fs.readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2020}}).outputText;
  const requireMock = name => {
    if(name==='@kit.IMEKit') return {inputMethodEngine:api};
    if(name==='@kit.PerformanceAnalysisKit') return {hilog:{info:noop,error:noop}};
    if(name==='@kit.ArkUI') return {};
    if(name==='@kit.CoreFileKit') return {fileIo:{}};
    if(name==='libnihongo.so') return {add:(a,b)=>a+b,echo:text=>text};
    if(name==='./KeyboardSettings') return {keyboardSettings:{enabled:()=>true,refresh:noop}};
    if(name.startsWith('@kit.')) return {};
    return load(path.join(path.dirname(file),name+'.ets'));
  };
  vm.runInNewContext(source,{exports,require:requireMock,setTimeout:(fn,ms)=>{fakeTimers.set(++fakeTimerId,{fn,ms});return fakeTimerId;},clearTimeout:id=>fakeTimers.delete(id),AppStorage:{setOrCreate:(k,v)=>storage.set(k,v)},Date,Promise,Error});
  return exports;
}
const {SegmentComposition}=load('entry/src/main/ets/input/SegmentComposition.ets');
const segmentRows=[['わたしは','私は','わたしは'],['はしを','橋を','箸を'],['わたる','渡る','わたる']];
const segmented=new SegmentComposition('わたしははしをわたる',segmentRows);
assert.equal(segmented.text,'私は橋を渡る');segmented.move(1);assert(segmented.select('箸を'));
assert.equal(segmented.text,'私は箸を渡る');segmented.move(100);assert.equal(segmented.focus,2);segmented.move(-100);assert.equal(segmented.focus,0);
assert.equal(segmented.select('古い候補'),false);
assert.throws(()=>new SegmentComposition('違う読み',segmentRows));assert.throws(()=>new SegmentComposition('あ',[['あ']]));
const shrinkRows=[['わたし','私'],['は','は'],['はしを','橋を','箸を'],['わたる','渡る','わたる']];
segmented.move(1);segmented.select('箸を');const shrunk=segmented.resized(shrinkRows);
assert.equal(shrunk.text,'私は箸を渡る');assert.deepEqual(Array.from(shrunk.lengths),[3,1,3,3]);
assert.deepEqual(Array.from(segmented.lengths),[4,3,3]);
assert.deepEqual(Array.from(new SegmentComposition('あ😀',[['あ😀','あ😀']]).lengths),[2]);
const {candidateRows}=load('entry/src/main/ets/input/CandidateLayout.ets');
const sample=['今日は','きょうは','教は','教派','強は','長い文章の変換候補を表示します'];
const rows=candidateRows(sample,360);
assert.equal(rows[0].values.length,4);
assert.deepEqual(Array.from(rows.flatMap(r=>Array.from(r.values))),sample);
assert(rows.every(r=>r.values.length>0 && r.spans.reduce((a,b)=>a+b,0)<=4));
assert.equal(rows.at(-1).spans[0],4);
const c=load('entry/src/main/ets/ime/ImeController.ets').imeController;
let preview='',committed='',finishes=0,inserts=0;
let supported=true,insertSuccess=true,inputPattern=-1,attributeFailure=false;
let editorAction=7;
let learned=[];
const learn=async(reading,value)=>{learned.push([reading,value]);return true;};
const client={
  getEditorAttribute:async()=>{if(attributeFailure)throw{code:12800003};return {inputPattern,enterKeyType:editorAction};},
  getTextIndexAtCursor:async()=>0,
  setPreviewText:async text=>{if(!supported)throw{code:12800011};preview=text;},
  finishTextPreview:async()=>{committed+=preview;preview='';finishes++;},
  insertText:async text=>{inserts++;if(insertSuccess)committed+=text;return insertSuccess;},
};
function attach(){c.active=true;c.onStart({hide:async()=>{}},client);preview='';committed='';finishes=0;inserts=0;}
async function type(text){for(const ch of text)c.kanaInput(ch,c.sessionId);await c.queue;}
(async()=>{
  attach();c.onEditorAttribute({enterKeyType:7});assert.equal(storage.get('imeEnterLabel'),'改行');
  c.onEditorAttribute({enterKeyType:2});assert.equal(storage.get('imeEnterLabel'),'検索');
  c.onEditorAttribute({enterKeyType:3});assert.equal(storage.get('imeEnterLabel'),'送信');
  for(let i=0;i<5;i++)await Promise.resolve();assert.equal(storage.get('imeEnterLabel'),'送信');
  c.onStop();c.onEditorAttribute({enterKeyType:5});assert.equal(storage.get('imeEnterLabel'),'送信');
  console.log('Editor action: field changes, newline/search/send, stale hidden client: PASS');
  attach();c.onEditorAttribute({enterKeyType:7,inputPattern:3});assert.equal(storage.get('imeForceNumber'),true);assert.equal(c.learningAllowed,false);
  c.onEditorAttribute({enterKeyType:7,inputPattern:0});assert.equal(storage.get('imeForceNumber'),false);assert.equal(c.learningAllowed,true);
  attach();c.onEditorAttribute({enterKeyType:7,isTextPreviewSupported:false});await type('きょうは');
  assert.equal(preview,'');assert.equal(c.kana.composition.reading,'きょうは');c.enter();await c.queue;
  assert.equal(committed,'きょうは');assert.equal(inserts,1);
  const cursorRead=client.getTextIndexAtCursor;let releaseCursor;
  attach();client.getTextIndexAtCursor=()=>new Promise(resolve=>{releaseCursor=resolve;});
  for(const character of 'きょうは')c.kanaInput(character,c.sessionId);
  for(let i=0;i<20&&!releaseCursor;i++)await Promise.resolve();assert(releaseCursor);
  const timeout=[...fakeTimers].find(([,value])=>value.ms===400);assert(timeout);
  fakeTimers.delete(timeout[0]);timeout[1].fn();await c.queue;
  assert.equal(preview,'きょうは');assert.equal(c.kana.composition.reading,'きょうは');c.enter();await c.queue;
  assert.equal(committed,'きょうは');releaseCursor(0);for(let i=0;i<5;i++)await Promise.resolve();
  assert.equal(committed,'きょうは');assert.equal(preview,'');
  attach();releaseCursor=undefined;c.kanaInput('あ',c.sessionId);
  for(let i=0;i<20&&!releaseCursor;i++)await Promise.resolve();assert(releaseCursor);
  const oldQueue=c.queue;attach();client.getTextIndexAtCursor=cursorRead;
  c.insert('new editor');await c.queue;assert.equal(committed,'new editor');
  releaseCursor(0);await oldQueue;assert.equal(preview,'');assert.equal(committed,'new editor');
  console.log('Preview compatibility: advertised unsupported, stalled cursor fallback, full queued reading, commit once, late reply/editor replacement: PASS');
  const insertAsync=client.insertText;const deleteAsync=client.deleteForward;
  client.insertText=text=>{inserts++;committed+=text;return new Promise(()=>{});};
  client.deleteForward=()=>{committed=committed.slice(0,-1);return new Promise(()=>{});};
  releaseCursor=undefined;client.getTextIndexAtCursor=()=>new Promise(resolve=>{releaseCursor=resolve;});
  attach();c.insert('あ');c.insert('い');
  for(let i=0;i<20&&!releaseCursor;i++)await Promise.resolve();assert(releaseCursor);
  const bootstrapTimeout=[...fakeTimers].find(([,value])=>value.ms===400);assert(bootstrapTimeout);
  fakeTimers.delete(bootstrapTimeout[0]);bootstrapTimeout[1].fn();await c.queue;
  assert.equal(committed,'あい');assert.equal(inserts,2);releaseCursor(0);
  c.backspace();await c.queue;assert.equal(committed,'あ');
  client.insertText=()=>Promise.resolve(false);c.insert('refused');await c.queue;
  assert(storage.get('imeError').length>0,'Immediate bridge refusal must remain visible');
  let releaseRefusal;client.insertText=()=>new Promise(resolve=>{releaseRefusal=resolve;});
  c.insert('stale');await c.queue;assert(releaseRefusal);
  client.getTextIndexAtCursor=cursorRead;attach();const freshEditorError=storage.get('imeError');releaseRefusal(false);
  for(let i=0;i<5;i++)await Promise.resolve();assert.equal(storage.get('imeError'),freshEditorError);
  client.insertText=insertAsync;client.deleteForward=deleteAsync;
  console.log('Compatibility dispatch: missing write/delete callbacks do not block, ordered writes, no retries: PASS');
  const previewAsync=client.setPreviewText,finishAsync=client.finishTextPreview;
  client.setPreviewText=text=>{preview=text;return new Promise(()=>{});};
  client.finishTextPreview=()=>{committed+=preview;preview='';finishes++;return new Promise(()=>{});};
  attach();await c.queue;c.kana.dispatchOnlyEditor=true;
  await type('あか');assert.equal(preview,'あか');assert.equal(committed,'');
  c.enter();await c.queue;assert.equal(committed,'あか');assert.equal(finishes,1);assert.equal(inserts,0);
  await type('さ');assert.equal(preview,'さ');c.backspace();await c.queue;assert.equal(preview,'');
  await type('あ');c.cancelKana();await c.queue;assert.equal(preview,'');assert.equal(c.kana.composition.reading,'');
  await type('か');preview='';c.onTextChange('');assert.equal(c.kana.composition.reading,'');
  assert(c.kana.dispatchOnlyEditor);await type('さ');assert.equal(preview,'さ');
  preview='';c.onSelection(1,1,0,0);assert.equal(c.kana.composition.reading,'');
  await type('た');assert.equal(preview,'た');c.onStop();assert.equal(c.kana.composition.reading,'');
  client.setPreviewText=previewAsync;client.finishTextPreview=finishAsync;
  console.log('Bridge composition: visible reading, unacknowledged preview/finish, commit once, delete/cancel, app clears and new reading: PASS');

  attach();const emojis=['😀','❤️','👍🏽','🇯🇵','👨‍👩‍👧‍👦'];
  for(let i=0;i<100;i++)c.insert(emojis[i%emojis.length]);await c.queue;
  assert.equal(committed,emojis.join('').repeat(20));assert.equal(inserts,100);
  attach();await type('あ');c.insert('😀');await c.queue;assert.equal(committed,'あ😀');assert.equal(finishes,1);
  attach();supported=false;await type('か');c.insert('👍🏽');await c.queue;assert.equal(committed,'か👍🏽');supported=true;
  attach();c.insert('😀');c.onStop();await c.queue;assert.equal(committed,'');
  console.log('Emoji: complete sequences, 100 queued inserts, composition/fallback commit once, stale editor: PASS');
  attach();c.clipboardAllowed=true;c.insertClipboard(' 日本語\n👨‍👩‍👧‍👦 ',c.sessionId);await c.queue;assert.equal(committed,' 日本語\n👨‍👩‍👧‍👦 ');
  attach();c.clipboardAllowed=false;c.insertClipboard('blocked',c.sessionId);await c.queue;assert.equal(committed,'');
  attach();c.clipboardAllowed=true;c.insertClipboard('old',c.sessionId-1);await c.queue;assert.equal(committed,'');
  attach();c.clipboardAllowed=true;await type('あ');c.insertClipboard('コピー',c.sessionId);await c.queue;assert.equal(committed,'あコピー');assert.equal(finishes,1);
  attach();c.clipboardAllowed=true;c.insertClipboard('hidden',c.sessionId);c.visible=false;await c.queue;assert.equal(committed,'');
  attach();c.clipboardAllowed=true;c.insertClipboard('queued',c.sessionId);c.clipboardAllowed=false;await c.queue;assert.equal(committed,'');
  const {clipboardHistory}=load('entry/src/main/ets/input/ClipboardHistory.ets');
  attach();c.updateMode(1);clipboardHistory.remember('discard');c.updateMode(0);assert.equal(clipboardHistory.snapshot().length,0);assert.equal(c.canUseClipboard,false);
  attach();c.clipboardAllowed=true;await type('あ');const normalFinish=client.finishTextPreview;let releaseClipboardFinish;
  client.finishTextPreview=()=>new Promise(resolve=>{releaseClipboardFinish=()=>{committed+=preview;preview='';finishes++;resolve();};});
  c.insertClipboard('must-not-paste',c.sessionId);for(let i=0;i<10&&!releaseClipboardFinish;i++)await Promise.resolve();assert(releaseClipboardFinish);
  c.onStop();releaseClipboardFinish();await c.queue;assert(!committed.includes('must-not-paste'));client.finishTextPreview=normalFinish;
  console.log('Clipboard controller: complete text, kana commit once, stale session, hidden panel, revoked access: PASS');
  async function roman(text) { for (const ch of text) c.romajiInput(ch,c.sessionId); await c.queue; }
  attach(); await roman('ky'); assert.equal(preview,'ky'); c.backspace(); await c.queue;
  assert.equal(preview,'k'); await roman('a'); assert.equal(preview,'か');
  attach(); await roman('kyouha'); assert.equal(preview,'きょうは');
  c.engine={convert:async()=>['今日は'],learn};await c.updateCandidates();
  c.selectCandidate('今日は','きょうは',c.sessionId);await c.queue;assert.equal(committed,'今日は');
  attach();await roman('kan');assert.equal(preview,'かn');c.enter();await c.queue;assert.equal(committed,'かん');
  attach();await roman('kann');c.enter();await c.queue;assert.equal(committed,'かん');
  attach();await roman('k');let queries=0;c.engine={convert:async()=>{queries++;return [];}};
  await c.updateCandidates();assert.equal(queries,0);
  c.kanaInput('あ',c.sessionId);await c.queue;assert.equal(preview,'kあ');
  attach();await roman('kyo');c.backspace();await c.queue;assert.equal(preview,'き');
  attach();await roman('n');c.moveLeft();await c.queue;await roman('a');assert.equal(preview,'あん');
  attach();await roman('gakkou'.repeat(20));assert.equal(preview,'がっこう'.repeat(20));
  const romanSession=c.sessionId;c.onStop();attach();c.romajiInput('a',romanSession);await c.queue;assert.equal(preview,'');
  await roman('k');c.cancelKana();await c.queue;await roman('a');assert.equal(preview,'あ');
  attach();await roman('n');c.selectCandidate('n','n',c.sessionId);await c.queue;assert.equal(committed,'ん');
  attach();supported=false;await roman('kan');c.commitKana();await c.queue;assert.equal(committed,'かん');assert.equal(inserts,1);supported=true;
  attach();let segmentReading='';c.engine={segments:async reading=>{segmentReading=reading;return [[reading,'缶',reading]];}};
  await roman('kan');c.startSegmentConversion();await c.queue;await c.queue;
  assert.equal(segmentReading,'かん');assert.equal(preview,'缶');
  console.log('Romaji controller: fast queue, candidates, pending n, cursor/delete, flick switch, fallback, segment conversion: PASS');
  learned=[];
  attach(); await type('あいうえお'.repeat(16)); assert.equal(preview,'あいうえお'.repeat(16));
  let resolve; c.engine={convert:()=>new Promise(r=>resolve=r)};
  const old=c.updateCandidates(); await type('か');resolve(['古い候補']);await old;
  assert(!storage.get('imeCandidates').includes('古い候補'));
  attach();await type('きょうは');c.engine={convert:async()=>['今日は','教は'],learn};await c.updateCandidates();
  c.selectCandidate('今日は','きょうは',c.sessionId);await c.queue;
  assert.equal(committed,'今日は');assert.equal(finishes,1);assert.equal(inserts,0);
  assert.deepEqual(learned,[['きょうは','今日は']]);
  learned=[];
  await type('あ');assert.equal(preview,'あ');
  attach();await type('きょうは');await c.updateCandidates();
  c.kanaInput('あ',c.sessionId);c.selectCandidate('今日は','きょうは',c.sessionId);await c.queue;
  assert.equal(committed,'');assert.equal(preview,'きょうはあ');
  attach();supported=false;await type('きょうは');await c.updateCandidates();
  insertSuccess=false;c.selectCandidate('今日は','きょうは',c.sessionId);await c.queue;
  assert.equal(c.kana.composition.reading,'きょうは');assert.equal(committed,'');assert.equal(learned.length,0);
  insertSuccess=true;c.selectCandidate('今日は','きょうは',c.sessionId);await c.queue;
  assert.equal(committed,'今日は');assert.equal(finishes,0);assert.equal(inserts,2);
  attach();await type('きょうは');c.engine={convert:()=>new Promise(r=>resolve=r)};
  const stopped=c.updateCandidates();c.onStop();resolve(['今日は']);await stopped;
  assert.equal(storage.get('imeCandidates').length,0);
  attach();await type('きょうは');c.learningAllowed=false;c.engine={convert:async(_reading,privateMode)=>{assert.equal(privateMode,true);return ['今日は'];},learn};
  await c.updateCandidates();const previous=learned.length;
  c.selectCandidate('今日は','きょうは',c.sessionId);await c.queue;
  assert.equal(learned.length,previous);
  attach();await type('きょうは');c.commitKana();await c.queue;assert.equal(learned.length,previous);
  attach();supported=true;await type('きょうは');
  let saveDone;c.engine={convert:async()=>['今日は'],learn:()=>new Promise(r=>saveDone=r)};await c.updateCandidates();
  c.selectCandidate('今日は','きょうは',c.sessionId);await c.queue;await type('あ');assert.equal(preview,'あ');saveDone(true);
  const reading='わたしははしをわたる';let learnedSegments=[];
  async function beginSegments(){c.startSegmentConversion();await c.queue;await Promise.resolve();await c.queue;}
  function segmentEngine(){c.engine={convert:async()=>[],segments:async()=>segmentRows,learnSegments:async(r,v)=>{learnedSegments.push([r,Array.from(v)]);return true;}};}
  attach();await type(reading);segmentEngine();await beginSegments();assert.equal(preview,'私は橋を渡る');
  assert.equal(committed,'');assert.equal(storage.get('imeSegmentMode'),true);
  c.selectCandidate('わたしは',reading,c.sessionId,c.revision);await c.queue;
  c.moveRight();await c.queue;const oldContext=c.revision;c.moveRight();await c.queue;
  c.selectCandidate('箸を',reading,c.sessionId,oldContext);await c.queue;assert.equal(preview,'わたしは橋を渡る');
  c.moveLeft();await c.queue;c.selectCandidate('箸を',reading,c.sessionId,c.revision);await c.queue;
  assert.equal(preview,'わたしは箸を渡る');c.enter();await c.queue;assert.equal(committed,'わたしは箸を渡る');assert.equal(finishes,1);
  assert.deepEqual(learnedSegments,[[reading,['わたしは','箸を','渡る']]]);
  await type('あ');assert.equal(preview,'あ');
  attach();await type(reading);segmentEngine();await beginSegments();c.cancelKana();await c.queue;assert.equal(preview,reading);assert.equal(committed,'');
  await beginSegments();c.backspace();await c.queue;assert.equal(preview,reading);c.backspace();await c.queue;assert.equal(preview,reading.slice(0,-1));
  attach();await type(reading);segmentEngine();await beginSegments();await type('あ'.repeat(80));assert.equal(committed,'私は橋を渡る');assert.equal(preview,'あ'.repeat(80));
  attach();supported=false;await type(reading);segmentEngine();await beginSegments();c.moveRight();await c.queue;
  c.selectCandidate('箸を',reading,c.sessionId,c.revision);await c.queue;assert.equal(committed,'');
  insertSuccess=false;c.enter();await c.queue;assert.equal(c.kana.conversion.text,'私は箸を渡る');
  insertSuccess=true;c.enter();await c.queue;assert.equal(committed,'私は箸を渡る');assert.equal(inserts,2);
  attach();supported=true;await type(reading);let splitDone;c.engine={segments:()=>new Promise(r=>splitDone=r)};
  c.startSegmentConversion();await c.queue;await type('あ');splitDone(segmentRows);await Promise.resolve();await c.queue;assert.equal(c.kana.conversion,undefined);assert.equal(preview,reading+'あ');
  attach();await type(reading);c.engine={segments:()=>new Promise(r=>splitDone=r)};c.startSegmentConversion();await c.queue;c.onStop();splitDone(segmentRows);await Promise.resolve();await c.queue;assert.equal(c.kana.conversion,undefined);
  attach();await type(reading);segmentEngine();await beginSegments();c.moveRight();await c.queue;
  c.selectCandidate('箸を',reading,c.sessionId,c.revision);await c.queue;
  c.moveLeft();await c.queue;let resizeArgs;
  c.engine.resizeSegments=async(...args)=>{resizeArgs=args;return shrinkRows;};
  c.resizeSegment(-1,c.sessionId,c.revision);await c.queue;await Promise.resolve();await c.queue;
  assert.equal(preview,'私は箸を渡る');assert.deepEqual(Array.from(resizeArgs[1]),[4,3,3]);assert.equal(resizeArgs[2],0);assert.equal(resizeArgs[3],-1);
  assert.equal(c.kana.conversion.focus,0);assert.equal(c.kana.composition.reading,reading);
  const snapshot=c.kana.conversion;c.engine.resizeSegments=()=>new Promise(r=>splitDone=r);
  c.resizeSegment(1,c.sessionId,c.revision);await c.queue;c.moveRight();await c.queue;splitDone(segmentRows);await Promise.resolve();await c.queue;
  assert.equal(c.kana.conversion,snapshot);
  c.resizeSegment(-1,c.sessionId,c.revision);await c.queue;assert.equal(c.kana.conversion,snapshot); // One-character segment cannot shrink.
  c.moveRight();await c.queue;c.resizeSegment(1,c.sessionId,c.revision);await c.queue;c.cancelKana();await c.queue;splitDone(segmentRows);await Promise.resolve();await c.queue;assert.equal(c.kana.conversion,undefined);assert.equal(preview,reading);
  console.log('Boundary: Unicode lengths, unchanged selections, shrink, stale focus/cancel, smallest boundary: PASS');
  for(const pattern of [7,8,9,11,13,99]){inputPattern=pattern;attach();await type('きょうは');assert.equal(c.learningAllowed,false);}
  inputPattern=0;attach();await type('きょうは');assert.equal(c.learningAllowed,true);
  attributeFailure=true;attach();await type('きょうは');assert.equal(c.learningAllowed,false);attributeFailure=false;inputPattern=-1;

  let document='', selection={start:1,end:2}, previewRange=null, reconFinishes=0, reconInserts=0, reconLearn=0, reconSupported=true, reconInsertOK=true, readFailure=false;
  const reconClient={
    getEditorAttribute:async()=>({inputPattern:-1}),getTextIndexAtCursor:async()=>selection.end,
    selectByRangeSync:r=>{selection={...r};c.onSelection(0,0,r.start,r.end);},
    getForwardSync:n=>{if(readFailure)throw{code:12800003};return document.slice(Math.max(0,selection.end-n),selection.end);},
    setPreviewText:async(text,range)=>{
      if(!reconSupported)throw{code:12800011};
      const start=range.start<0?(previewRange?.start ?? selection.start):range.start;
      const end=range.end<0?(previewRange?.end ?? selection.end):range.end;
      document=document.slice(0,start)+text+document.slice(end);previewRange={start,end:start+text.length};
      selection={start:start+text.length,end:start+text.length};c.onSelection(0,0,selection.start,selection.end);
    },
    finishTextPreview:async()=>{previewRange=null;reconFinishes++;},
    insertText:async(text)=>{reconInserts++;if(!reconInsertOK)return false;document=document.slice(0,selection.start)+text+document.slice(selection.end);selection={start:selection.start+text.length,end:selection.start+text.length};c.onSelection(0,0,selection.start,selection.end);return true;},
  };
  async function reconAttach(){document='前橋後';selection={start:1,end:2};previewRange=null;reconFinishes=0;reconInserts=0;readFailure=false;reconInsertOK=true;
    c.active=true;c.onStart({hide:async()=>{}},reconClient);await Promise.resolve();
    c.engine={reverse:async()=> 'はし',segments:async()=>[['はし','橋','箸','はし']],learnSegments:async()=>{reconLearn++;return true;}};
    c.onSelection(0,0,1,2);
  }
  async function reconSettle(){for(let i=0;i<8;i++){await Promise.resolve();await c.queue;}}
  await reconAttach();assert.equal(storage.get('imeCanReconvert'),true);c.reconvertSelection();await reconSettle();
  assert.equal(c.kana.reconversion.original,'橋');assert.equal(c.kana.anchor,1);
  c.selectCandidate('箸','はし',c.sessionId,c.revision);await c.queue;assert.equal(document,'前箸後');c.enter();await c.queue;assert.equal(document,'前箸後');assert.equal(reconFinishes,1);assert.equal(reconLearn,1);
  await reconAttach();c.reconvertSelection();await reconSettle();c.selectCandidate('箸','はし',c.sessionId,c.revision);await c.queue;c.cancelKana();await c.queue;assert.equal(document,'前橋後');assert.equal(reconLearn,1);
  await reconAttach();reconSupported=false;c.reconvertSelection();await reconSettle();c.selectCandidate('箸','はし',c.sessionId,c.revision);await c.queue;assert.equal(document,'前橋後');
  reconInsertOK=false;c.enter();await c.queue;assert.equal(document,'前橋後');assert(c.kana.reconversion);reconInsertOK=true;c.enter();await c.queue;assert.equal(document,'前箸後');assert.equal(reconInserts,2);
  await reconAttach();c.reconvertSelection();await reconSettle();c.backspace();await c.queue;assert.equal(document,'前橋後');assert.equal(reconInserts,0);
  await reconAttach();reconSupported=true;c.engine.reverse=()=>new Promise(r=>splitDone=r);c.reconvertSelection();await c.queue;reconClient.selectByRangeSync({start:3,end:3});splitDone('はし');await reconSettle();assert.equal(document,'前橋後');assert.equal(c.kana.reconversion,undefined);
  await reconAttach();c.engine.reverse=()=>new Promise(r=>splitDone=r);c.reconvertSelection();await c.queue;document='前犬後';splitDone('はし');await reconSettle();assert.equal(document,'前犬後');assert.equal(c.kana.reconversion,undefined);
  await reconAttach();readFailure=true;c.reconvertSelection();await reconSettle();assert.equal(document,'前橋後');assert.deepEqual(selection,{start:1,end:2});
  await reconAttach();c.engine.reverse=()=>new Promise(r=>splitDone=r);c.reconvertSelection();await c.queue;c.onStop();splitDone('はし');await reconSettle();assert.equal(document,'前橋後');assert.equal(c.kana.reconversion,undefined);
  await reconAttach();const selectSync=reconClient.selectByRangeSync;
  reconClient.selectByRangeSync=r=>{selection={...r};};c.engine.reverse=()=>new Promise(r=>splitDone=r);
  c.reconvertSelection();await c.queue;c.onSelection(1,2,2,2);splitDone('はし');await reconSettle();
  assert.equal(document,'前橋後');assert.equal(c.kana.reconversion,undefined);reconClient.selectByRangeSync=selectSync;
  console.log('Reconversion: selected range only, cancel restores original, fallback/failed insert, changed selection/text/client, failed read: PASS');
  console.log('Segments: multiple choices, focused context, one commit, cancel/delete, next kana, fallback/failure, stale response/editor: PASS');
  console.log('80 queued kana, stale conversion/click, preview/fallback commit, failed commit retention, editor generation: PASS');
})().catch(e=>{console.error(e);process.exitCode=1;});
