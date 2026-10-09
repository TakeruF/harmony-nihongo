import { KanaComposition } from '../input/KanaComposition';
import { ClipboardPanel } from './ClipboardPanel';
import { EmojiPanel } from './EmojiPanel';
import { CursorHoldTracker } from '../input/CursorHoldTracker';
import { KeyRepeatTracker } from '../input/KeyRepeatTracker';
import { imeController } from './ImeController';
import { keyboardHaptics } from './KeyboardHaptics';
import { display } from '@kit.ArkUI';
import { FlickTracker, FlickOutput } from '../input/FlickTracker';
import { KeyboardMetrics } from './KeyboardMetrics';
import { KeyboardPalette } from './KeyboardPalette';
import { TwelveKeyGroup, TwelveKeyLayout } from '../input/TwelveKeyLayout';
import { InputMethodListDialog } from '@kit.IMEKit';
import { CandidateChoice, CandidateRow, candidateRows } from '../input/CandidateLayout';

@Entry
@Component
struct Keyboard {
  private inputMethodsDialog: CustomDialogController = new CustomDialogController({ builder: InputMethodListDialog(), autoCancel: true });
  @State mode: string = 'kana';
  @State emojiSearching: boolean = false;
  @State emojiQuery: string = '';
  private emojiComposition: KanaComposition = new KanaComposition();
  @StorageLink('imeEditorWindowId') editorWindowId: number = -1;
  @StorageLink('imeEditorSession') @Watch('searchEditorChanged') editorSession: number = 0;
  private searchEditorChanged(): void {
    if (this.emojiSearching) {
      this.flicks.cancelAll(); this.emojiSearching = false; this.emojiQuery = ''; this.emojiComposition.clear();
      this.mode = this.emojiReturnMode;
    }
  }
  @StorageLink('imeCanReverse') canReverse: boolean = false;
  private shownReading(): string { return this.emojiSearching ? this.emojiQuery : this.reading; }
  private beginEmojiSearch(query: string): void {
    this.emojiComposition.clear(); this.emojiComposition.insert(query); this.emojiQuery = query;
    this.emojiSearching = true; this.candidatesExpanded = false; this.mode = this.japaneseMode;
  }
  private finishEmojiSearch(): void { this.flushFlicks(); this.emojiSearching = false; this.mode = 'emoji'; }
  private insertText(text: string): void {
    if (this.emojiSearching) { this.emojiComposition.insert(text); this.emojiQuery = this.emojiComposition.reading; }
    else { imeController.insert(text); }
  }
  private deleteText(): void {
    if (this.emojiSearching) { this.emojiComposition.backspace(); this.emojiQuery = this.emojiComposition.reading; }
    else { imeController.backspace(); }
  }
  private transformText(kind: string): void {
    if (this.emojiSearching) { this.emojiComposition.transform(kind); this.emojiQuery = this.emojiComposition.reading; }
    else { imeController.transformKana(kind); }
  }
  private moveText(delta: number): void {
    if (this.emojiSearching) { this.emojiComposition.move(delta); }
    else if (delta < 0) { imeController.moveLeft(); } else { imeController.moveRight(); }
  }
  private reverseText(): void {
    if (this.emojiSearching) { this.emojiComposition.reverseTap(); this.emojiQuery = this.emojiComposition.reading; }
    else { imeController.reverseKana(); }
  }
  private enterText(): void { if (this.emojiSearching) { this.finishEmojiSearch(); } else { imeController.enter(); } }
  private spaceText(): void { if (this.emojiSearching) { this.insertText(' '); } else { imeController.kanaSpace(); } }
  private convertText(): void { if (this.emojiSearching) { this.finishEmojiSearch(); } else { imeController.startSegmentConversion(); } }
  private romajiText(text: string): void {
    if (this.emojiSearching) { this.insertText(text); } else { imeController.romajiInput(text, imeController.sessionId); }
  }

  @State japaneseMode: string = 'kana';
  private emojiReturnMode: string = 'kana';
  private clipboardReturnMode: string = 'kana';
  private openClipboard(): void {
    this.emojiSearching = false; this.clipboardReturnMode = this.mode; this.candidatesExpanded = false; this.changeMode('clipboard');
  }
  private openEmoji(): void {
    if (this.emojiSearching) { this.finishEmojiSearch(); return; }
    this.emojiQuery = ''; this.emojiReturnMode = this.mode; this.candidatesExpanded = false; this.changeMode('emoji');
  }
  private modeHolds: CursorHoldTracker = new CursorHoldTracker();
  private repeatedKeys: KeyRepeatTracker = new KeyRepeatTracker();
  @StorageLink('imeVisible') @Watch('visibilityChanged') visible: boolean = false;
  @StorageLink('imeForceNumber') @Watch('editorKindChanged') forceNumber: boolean = false;
  private numberReturnMode: string = '';
  @StorageLink('imeCanReconvert') canReconvert: boolean = false;
  @StorageLink('imeCanOpenSettings') canOpenSettings: boolean = false;
  @StorageLink('imeThreeModes') threeModes: boolean = true;
  @StorageLink('imeKeitaiOnly') keitaiOnly: boolean = false;
  @State activeKey: string = '';
  @State selectedKana: string = '';
  @StorageLink('imeCandidates') @Watch('candidatesChanged') candidates: string[] = [];
  @StorageLink('imeSegmentValue') segmentValue: string = '';
  @State candidateChoices: CandidateChoice[] = [];
  @StorageLink('imeSegmentMode') segmentMode: boolean = false;
  @State candidatesExpanded: boolean = false;
  @State candidateLines: CandidateRow[] = [];
  @StorageLink('imeReading') @Watch('readingChanged') reading: string = '';
  @StorageLink('imeEnterLabel') enterLabel: string = '改行';
  private cursorHolds: CursorHoldTracker = new CursorHoldTracker();
  private flicks: FlickTracker = new FlickTracker();
  @State upper: boolean = false;
  @StorageLink('imeError') error: string = '';
  private screen = display.getDefaultDisplaySync();
  @StorageLink('imeScreenWidth') @Watch('layoutChanged') screenWidth: number = this.screen.width / this.screen.densityPixels;
  @StorageLink('imeScreenHeight') @Watch('layoutChanged') screenHeight: number = this.screen.height / this.screen.densityPixels;
  private layoutWidth: number = 0;
  private layoutHeight: number = 0;
  @StorageLink('imeKeyboardHeight') @Watch('layoutChanged') keyboardHeight: number = 0;
  @StorageLink('imePopupInset') popupInset: number = 0;
  @StorageLink('imePanelLeft') panelLeft: number = 0;
  @StorageLink('imePanelRight') panelRight: number = 0;
  @State metrics: KeyboardMetrics = new KeyboardMetrics(this.screenWidth, this.screenHeight);
  private layoutChanged(): void {
    this.flushFlicks(); this.clearHolds();
    this.metrics = new KeyboardMetrics(this.layoutWidth || this.screenWidth, this.screenHeight, this.keyboardHeight || this.screenHeight);
    this.candidatesChanged();
  }

  private candidatesChanged(): void {
    const context = AppStorage.get<number>('imeCandidateContext') ?? 0;
    this.candidateChoices = this.candidates.map((value: string) => new CandidateChoice(value, context));
    this.candidateLines = candidateRows(this.candidates, (this.layoutWidth || this.screenWidth) - this.metrics.margin * 2, 17, context);
  }
  aboutToAppear(): void { this.layoutChanged(); keyboardHaptics.initialize(); this.candidatesChanged(); this.editorKindChanged(); }
  aboutToDisappear(): void { this.clearHolds(); this.flicks.cancelAll(); }
  private clearHolds(): void { this.cursorHolds.clear(); this.modeHolds.clear(); this.repeatedKeys.clear(); }
  private visibilityChanged(): void {
    if (!this.visible) { this.clearHolds(); this.flicks.cancelAll(); this.activeKey = ''; this.selectedKana = ''; }
  }
  private editorKindChanged(): void {
    let next = this.mode;
    if (this.forceNumber) {
      if (this.numberReturnMode.length === 0) {
        this.numberReturnMode = this.mode === 'clipboard' || this.mode === 'emoji' ? this.japaneseMode : this.mode;
      }
      next = 'number';
    } else if (this.numberReturnMode.length > 0) {
      if (this.mode === 'number') { next = this.numberReturnMode; }
      this.numberReturnMode = '';
    }
    if (next !== this.mode) {
      // A field change changes the layout, never commits text from the old field.
      this.flicks.cancelAll(); this.activeKey = ''; this.selectedKana = '';
      this.clearHolds(); this.candidatesExpanded = false; this.mode = next;
    }
  }
  private readingChanged(): void {
    if (this.shownReading().length === 0) { this.candidatesExpanded = false; }
  }

  private keyWidth(weight: number): number {
    const unit = (this.mode === 'romaji') ? this.metrics.alphaWidth : this.metrics.numberWidth;
    return unit * weight + this.metrics.gap * (weight - 1);
  }

  // Touch input is accepted on Down, independently of click-gesture recognition.
  // changedTouches includes only the contacts introduced by this event.
  private press(event: TouchEvent, action: () => void): void {
    if (event.type !== TouchType.Down) { return; }
    this.flushFlicks();
    event.changedTouches.forEach(() => { keyboardHaptics.tap(); action(); });
  }

  private accessibleClick(event: ClickEvent, action: () => void): void {
    // Touch/mouse already ran through onTouch. Keep keyboard/accessibility activation.
    if (event.source !== SourceType.TouchScreen && event.source !== SourceType.Mouse) { keyboardHaptics.tap(); action(); }
  }

  private verticalGap(): number {
    return (this.mode === 'romaji') ? this.metrics.alphaGap : this.metrics.numberGap;
  }

  private keyHeight(): number {
    return (this.mode === 'romaji') ? this.metrics.alphaHeight : this.metrics.numberHeight;
  }

  private acceptFlicks(outputs: FlickOutput[]): void {
    outputs.forEach((output: FlickOutput) => {
      if (this.emojiSearching) {
        const taps = this.mode === 'alpha' ? TwelveKeyLayout.alphabetTapValues(output.tapValues) : output.tapValues;
        if (taps.length > 0 && !(AppStorage.get<boolean>('imeFlickOnly') ?? false)) { this.emojiComposition.tap(taps, output.pressedAt); }
        else { this.emojiComposition.insert(output.value); }
        this.emojiQuery = this.emojiComposition.reading; return;
      }
      if (this.mode === 'number') { this.insertText(output.value); }
      else {
        const taps = this.mode === 'alpha' ? TwelveKeyLayout.alphabetTapValues(output.tapValues) : output.tapValues;
        imeController.kanaInput(output.value, output.session, taps, output.pressedAt);
      }
    });
  }
  private flushFlicks(): void { this.acceptFlicks(this.flicks.flush()); this.activeKey = ''; this.selectedKana = ''; }
  private changeMode(mode: string): void {
    this.flushFlicks(); this.clearHolds(); if (!this.emojiSearching) { imeController.commitKana(); } this.mode = mode;
  }
  private modeTouch(event: TouchEvent): void {
    event.changedTouches.forEach((touch: TouchObject) => {
      if (event.type === TouchType.Down) {
        keyboardHaptics.tap(); this.flushFlicks();
        const nextMode = this.mode === 'kana' || this.mode === 'romaji' ? 'alpha' :
          (this.mode === 'alpha' && this.threeModes ? 'number' : this.japaneseMode);
        this.modeHolds.begin(touch.id, () => { this.changeMode(nextMode); }, () => {
          this.japaneseMode = this.japaneseMode === 'kana' ? 'romaji' : 'kana';
          this.changeMode(this.japaneseMode);
        });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.modeHolds.end(touch.id, event.type === TouchType.Cancel);
      }
    });
  }
  private letter(key: string): void {
    if (this.mode === 'romaji') { this.romajiText(key); }
    else { this.insertText(this.upper ? key.toUpperCase() : key); }
  }
  @Builder
  modeKey(weight: number = 1) {
    Button() {
      Text() {
        Span('あ').fontWeight(this.mode === 'kana' || this.mode === 'romaji' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.mode === 'kana' || this.mode === 'romaji' ? KeyboardPalette.ink : KeyboardPalette.inactiveInk)
        Span('a').fontWeight(this.mode === 'alpha' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.mode === 'alpha' ? KeyboardPalette.ink : KeyboardPalette.inactiveInk)
        Span('1').fontWeight(this.mode === 'number' || this.mode === 'symbol' ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.mode === 'number' || this.mode === 'symbol' ? KeyboardPalette.ink : KeyboardPalette.inactiveInk)
      }.fontSize(20)
    }
      .type(ButtonType.Normal).borderRadius(this.keyHeight() / 2).padding(0).backgroundColor(KeyboardPalette.modeKey)
      .height(this.keyHeight()).width(this.keyWidth(weight))
      .responseRegion({ x: -this.metrics.gap / 2, y: -this.verticalGap() / 2,
        width: this.keyWidth(weight) + this.metrics.gap, height: this.keyHeight() + this.verticalGap() })
      .id('key-入力モード').accessibilityText('入力モード。長押しで日本語12キー・QWERTY切替')
      .onTouch((event: TouchEvent) => { this.modeTouch(event); })
      .onClick((event: ClickEvent) => { this.accessibleClick(event, () => {
        this.changeMode(this.mode === 'kana' || this.mode === 'romaji' ? 'alpha' :
          (this.mode === 'alpha' && this.threeModes ? 'number' : this.japaneseMode));
      }); })
  }
  private flick(event: TouchEvent, values: string[]): void {
    this.flicks.flickEnabled = !this.keitaiOnly;
    event.changedTouches.forEach((touch: TouchObject) => {
      if (event.type === TouchType.Down) {
        keyboardHaptics.tap();
        this.flicks.begin(touch.id, values, touch.screenX, touch.screenY, imeController.sessionId);
        this.activeKey = values[0]; this.selectedKana = values[0];
      } else if (event.type === TouchType.Move) {
        this.selectedKana = this.flicks.move(touch.id, touch.screenX, touch.screenY);
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.acceptFlicks(this.flicks.end(touch.id, touch.screenX, touch.screenY, event.type === TouchType.Cancel));
        this.activeKey = ''; this.selectedKana = '';
      }
    });
  }
  private kanaRows: string[][][] = [
    [['あ','い','う','え','お'], ['か','き','く','け','こ'], ['さ','し','す','せ','そ']],
    [['た','ち','つ','て','と'], ['な','に','ぬ','ね','の'], ['は','ひ','ふ','へ','ほ']],
    [['ま','み','む','め','も'], ['や','（','ゆ','）','よ'], ['ら','り','る','れ','ろ']]
  ];
  private top: string[] = ['q','w','e','r','t','y','u','i','o','p'];
  private middle: string[] = ['a','s','d','f','g','h','j','k','l'];
  private bottom: string[] = ['z','x','c','v','b','n','m'];
  private digits: string[][] = [['1','2','3'], ['4','5','6'], ['7','8','9']];
  private symbols: string[][] = [['!','@','#'], ['$','%','&'], ['(',')','?']];

  @Builder
  keyboardKey(label: string, action: () => void, weight: number = 1,
    accent: boolean = false, pill: boolean = false, large: boolean = false, actionKey: boolean = false) {
    Button() {
      Text(label).fontSize(large ? 24 : (this.mode === 'romaji' && label.length > 1 ? 14 : 20)).fontColor(KeyboardPalette.ink)
        .textAlign(TextAlign.Center).width('100%').maxLines(1)
    }.type(ButtonType.Normal).borderRadius(pill ? this.keyHeight() / 2 : 8).padding(0)
      .backgroundColor(actionKey ? KeyboardPalette.actionKey : (accent ? KeyboardPalette.functionKey : KeyboardPalette.key))
      .height(this.keyHeight()).width(this.keyWidth(weight))
      .id('key-' + label)
      .responseRegion({ x: -this.metrics.gap / 2, y: -this.verticalGap() / 2,
        width: this.keyWidth(weight) + this.metrics.gap, height: this.keyHeight() + this.verticalGap() })
      .onTouch((event: TouchEvent) => { this.press(event, action); })
      .onClick((event: ClickEvent) => { this.accessibleClick(event, action); })
  }

  @Builder
  iconKey(icon: Resource, accessibleLabel: string, action: () => void, weight: number = 1, pill: boolean = false, repeat: boolean = false, actionKey: boolean = false) {
    Button() {
      Image(icon).width(25).height(25).opacity(accessibleLabel === '逆順' && !(this.emojiSearching ? this.emojiComposition.canReverse : this.canReverse) ? 0.4 : 1)
    }.type(ButtonType.Normal).borderRadius(pill ? this.keyHeight() / 2 : 8).padding(0)
      .backgroundColor(actionKey ? KeyboardPalette.actionKey : KeyboardPalette.functionKey).height(this.keyHeight()).width(this.keyWidth(weight))
      .id('key-' + accessibleLabel)
      .responseRegion({ x: -this.metrics.gap / 2, y: -this.verticalGap() / 2,
        width: this.keyWidth(weight) + this.metrics.gap, height: this.keyHeight() + this.verticalGap() })
      .accessibilityText(accessibleLabel)
      .onTouch((event: TouchEvent) => {
        if (repeat) { this.repeatTouch(event, action); } else { this.press(event, action); }
      })
      .onClick((event: ClickEvent) => { this.accessibleClick(event, action); })
  }

  private repeatTouch(event: TouchEvent, action: () => void): void {
    event.changedTouches.forEach((touch: TouchObject) => {
      if (event.type === TouchType.Down) {
        keyboardHaptics.tap(); this.flushFlicks();
        const session = imeController.sessionId;
        this.repeatedKeys.begin(touch.id, () => {
          if (session === imeController.sessionId) { action(); } else { this.repeatedKeys.end(touch.id); }
        });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) { this.repeatedKeys.end(touch.id); }
    });
  }

  private cursorTouch(event: TouchEvent, delta: number): void {
    event.changedTouches.forEach((touch: TouchObject) => {
      if (event.type === TouchType.Down) {
        keyboardHaptics.tap(); this.flushFlicks();
        const move = (): void => { if (delta < 0) { this.moveText(-1); } else { this.moveText(1); } };
        if (!this.segmentMode) {
          const session = imeController.sessionId;
          this.repeatedKeys.begin(touch.id, () => {
            if (session === imeController.sessionId && !this.segmentMode) { move(); } else { this.repeatedKeys.end(touch.id); }
          });
          return;
        }
        const session = imeController.sessionId;
        const context = AppStorage.get<number>('imeCandidateContext') ?? -1;
        this.cursorHolds.begin(touch.id, () => { imeController.moveSegment(delta, session, context); }, () => { imeController.resizeSegment(delta, session, context); });
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.cursorHolds.end(touch.id, event.type === TouchType.Cancel);
        this.repeatedKeys.end(touch.id);
      }
    });
  }
  @Builder
  cursorKey(delta: number) {
    Button() { Image(delta < 0 ? $r('app.media.ic_left') : $r('app.media.ic_right')).width(25).height(25) }
      .type(ButtonType.Normal).borderRadius(8).padding(0).backgroundColor(KeyboardPalette.functionKey)
      .height(this.keyHeight()).width(this.keyWidth(1))
      .responseRegion({ x: -this.metrics.gap / 2, y: -this.verticalGap() / 2,
        width: this.keyWidth(1) + this.metrics.gap, height: this.keyHeight() + this.verticalGap() })
      .id(delta < 0 ? 'key-カーソル左' : 'key-カーソル右').accessibilityText(this.segmentMode ? (delta < 0 ? '前の文節。長押しで文節を縮める' : '次の文節。長押しで文節を伸ばす') : (delta < 0 ? 'カーソル左' : 'カーソル右'))
      .onTouch((event: TouchEvent) => { this.cursorTouch(event, delta); })
      .onClick((event: ClickEvent) => { this.accessibleClick(event, () => { if (delta < 0) { this.moveText(-1); } else { this.moveText(1); } }); })
  }

  private flickDirectionPoints(values: string[]): number[][] {
    const width = this.metrics.numberWidth;
    const height = this.metrics.numberHeight;
    const center: number[] = [width / 2, height / 2];
    const direction = values.indexOf(this.selectedKana);
    if (direction === 1) { return [[0, 0], center, [0, height]]; }
    if (direction === 2) { return [[0, 0], center, [width, 0]]; }
    if (direction === 3) { return [[width, 0], center, [width, height]]; }
    return [[0, height], center, [width, height]];
  }

  private popupValue(value: string): string {
    return this.mode === 'alpha' ? value.toUpperCase() : value;
  }

  @Builder
  flickPopup(values: string[]) {
    Stack() {
      if (this.selectedKana === values[0]) {
        Column() {
          Text(this.popupValue(values[2])).fontSize(13).fontColor(KeyboardPalette.ink).textAlign(TextAlign.Center).width('100%').height('24%')
          Row() {
            Text(this.popupValue(values[1])).fontSize(13).fontColor(KeyboardPalette.ink).textAlign(TextAlign.Center).width('24%')
            Text(this.popupValue(values[0])).fontSize(26).fontColor(KeyboardPalette.ink).textAlign(TextAlign.Center).layoutWeight(1)
            Text(this.popupValue(values[3])).fontSize(13).fontColor(KeyboardPalette.ink).textAlign(TextAlign.Center).width('24%')
          }.width('100%').height('52%')
          Text(this.popupValue(values[4])).fontSize(13).fontColor(KeyboardPalette.ink).textAlign(TextAlign.Center).width('100%').height('24%')
        }.width('100%').height('100%')
      } else {
        Text(this.popupValue(this.selectedKana)).fontSize(30).fontColor(KeyboardPalette.ink).textAlign(TextAlign.Center)
      }
    }.width(this.metrics.numberHeight * 1.1).height(this.metrics.numberHeight * 1.1)
      .backgroundColor(KeyboardPalette.key).borderRadius(this.metrics.numberHeight)
      .shadow({ radius: 5, color: '#24000000', offsetY: 2 })
      .translate({ y: -this.metrics.numberHeight * 1.16 }).hitTestBehavior(HitTestMode.None)
      .accessibilityLevel('no')
  }

  @Builder
  kanaKey(values: string[], label: string = '', hint: string = '') {
    Stack({ alignContent: Alignment.Center }) {
      Button() {
        Stack() {
          if (this.activeKey === values[0] && this.selectedKana.length > 0 && this.selectedKana !== values[0]) {
            Polygon().points(this.flickDirectionPoints(values)).fill(KeyboardPalette.actionKey).strokeWidth(0)
              .width('100%').height('100%').hitTestBehavior(HitTestMode.None).accessibilityLevel('no')
          }
          if (label.length > 0) {
            Column({ space: 0 }) {
              Text(label).fontSize(this.mode === 'number' ? 24 : 18).fontColor(KeyboardPalette.ink).textAlign(TextAlign.Center).width('100%')
              if (hint.length > 0) { Text(hint).fontSize(10).fontColor(KeyboardPalette.ink).opacity(0.65) }
            }.width('100%')
          } else if (values[0] === '、') {
            Column({ space: 0 }) {
              Text('？').fontSize(13).fontColor(KeyboardPalette.ink)
              Text('。 、 ！').fontSize(13).fontColor(KeyboardPalette.ink)
              Text('…').fontSize(11).fontColor(KeyboardPalette.ink)
            }
          } else {
            Text(values[0]).fontSize(24).fontColor(KeyboardPalette.ink).width('100%').textAlign(TextAlign.Center)
          }
        }.width('100%').height('100%')
      }.type(ButtonType.Normal).borderRadius(8).padding(0).clip(true)
        .backgroundColor(this.activeKey === values[0] ? KeyboardPalette.pressedKey : KeyboardPalette.key)
        .height(this.metrics.numberHeight).width(this.metrics.numberWidth)
        .id('key-' + values[0]).accessibilityText(values[0])
        .responseRegion({ x: -this.metrics.gap / 2, y: -this.metrics.numberGap / 2,
          width: this.metrics.numberWidth + this.metrics.gap, height: this.metrics.numberHeight + this.metrics.numberGap })
        .onTouch((event: TouchEvent) => { this.flick(event, values); })
        .onClick((event: ClickEvent) => { this.accessibleClick(event, () => {
          this.acceptFlicks([new FlickOutput(values[0], imeController.sessionId)]);
        }); })
      if (this.activeKey === values[0] && this.selectedKana.length > 0) { this.flickPopup(values); }
    }.width(this.metrics.numberWidth).height(this.metrics.numberHeight)
      .zIndex(this.activeKey === values[0] ? 10 : 0)
  }

  @Builder
  enterKey(weight: number = 1) {
    if (this.emojiSearching) {
      this.iconKey($r('app.media.ic_search'), '絵文字検索', () => { this.enterText(); }, weight, true, false, true)
    } else if (this.shownReading().length > 0) {
      this.iconKey($r('app.media.ic_enter'), '確定', () => { this.enterText(); }, weight, true, false, true)
    } else if (this.enterLabel === '改行') {
      this.iconKey($r('app.media.ic_enter'), '改行', () => { this.enterText(); }, weight, true, false, true)
    } else if (this.enterLabel === '検索') {
      this.iconKey($r('app.media.ic_search'), '検索', () => { this.enterText(); }, weight, true, false, true)
    } else {
      this.keyboardKey(this.enterLabel, () => { this.enterText(); }, weight, true, true, false, true)
    }
  }

  @Builder
  emojiKey() {
    Button() {
      Row({ space: 1 }) {
        Image($r('app.media.ic_emoji')).width(22).height(22)
        Text('記').fontSize(19).fontColor(KeyboardPalette.ink)
      }
    }.type(ButtonType.Normal).borderRadius(8).padding(0).backgroundColor(KeyboardPalette.functionKey)
      .height(this.metrics.numberHeight).width(this.metrics.numberWidth)
      .responseRegion({ x: -this.metrics.gap / 2, y: -this.metrics.numberGap / 2,
        width: this.metrics.numberWidth + this.metrics.gap, height: this.metrics.numberHeight + this.metrics.numberGap })
      .id('key-絵文字記号').accessibilityText('絵文字・記号')
      .onTouch((event: TouchEvent) => { this.press(event, () => { this.openEmoji(); }); })
      .onClick((event: ClickEvent) => { this.accessibleClick(event, () => { this.openEmoji(); }); })
  }

  @Builder
  modifierKey() {
    Button() {
      Column({ space: 2 }) {
        Text('゛ ゜').fontSize(19).fontColor(KeyboardPalette.ink)
        Text('大 ⇔ 小').fontSize(8).fontColor(KeyboardPalette.ink)
      }
    }.type(ButtonType.Normal).borderRadius(8).padding(0).backgroundColor(KeyboardPalette.key)
      .height(this.metrics.numberHeight).width(this.metrics.numberWidth)
      .responseRegion({ x: -this.metrics.gap / 2, y: -this.metrics.numberGap / 2,
        width: this.metrics.numberWidth + this.metrics.gap, height: this.metrics.numberHeight + this.metrics.numberGap })
      .id('key-文字変形').accessibilityText('濁点・半濁点・小文字')
      .onTouch((event: TouchEvent) => { this.press(event, () => { this.transformText('variant'); }); })
      .onClick((event: ClickEvent) => { this.accessibleClick(event, () => { this.transformText('variant'); }); })
  }

  @Builder
  keyboardToolbar() {
    if (this.emojiSearching) {
      Row({ space: 8 }) {
        Button() { Image($r('app.media.ic_left')).width(24).height(24) }
          .width(36).height(36).padding(0).backgroundColor(Color.Transparent).id('emoji-search-back')
          .accessibilityText('絵文字の一覧へ戻る').onClick(() => { this.finishEmojiSearch(); })
        Text(this.emojiQuery || '絵文字を検索').fontSize(18).fontColor(KeyboardPalette.ink).layoutWeight(1).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).id('emoji-search-query')
        Button('×').width(32).height(32).padding(0).backgroundColor(Color.Transparent).fontColor(KeyboardPalette.ink)
          .id('emoji-search-clear').accessibilityText('検索語を消す').onClick(() => { this.emojiComposition.clear(); this.emojiQuery = ''; })
      }.width('100%').height(this.metrics.toolbarHeight)
    } else if (this.shownReading().length > 0) {
      Row({ space: 4 }) {
        Scroll() {
          Row() {
            ForEach(this.candidateChoices, (choice: CandidateChoice, index: number) => {
              Text(choice.value)
                .id(choice.value === this.reading ? 'composition' : 'candidate-' + index.toString())
                .fontSize(17).fontColor(this.segmentMode && choice.value === this.segmentValue ? KeyboardPalette.selectedInk : KeyboardPalette.ink)
                .fontWeight(this.segmentMode && choice.value === this.segmentValue ? FontWeight.Medium : FontWeight.Normal).maxLines(1)
                .padding({ left: 12, right: 12 }).height(this.metrics.toolbarHeight)
                .onClick(() => {
                  keyboardHaptics.tap();
                  this.flushFlicks();
                  imeController.selectCandidate(choice.value, this.reading, imeController.sessionId, choice.context);
                  this.candidatesExpanded = false;
                })
              if (index < this.candidates.length - 1) {
                Divider().vertical(true).height(20).color(KeyboardPalette.divider)
              }
            }, (choice: CandidateChoice) => choice.context.toString() + choice.value)
          }
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).align(Alignment.Start).layoutWeight(1)
        Button() {
          Image($r('app.media.ic_hide')).width(20).height(20).fillColor(KeyboardPalette.ink).rotate({ angle: this.candidatesExpanded ? 180 : 0 })
        }.padding(0).width(40).height(this.metrics.toolbarHeight).backgroundColor(Color.Transparent)
          .onClick(() => { keyboardHaptics.tap(); this.flushFlicks(); this.candidatesExpanded = !this.candidatesExpanded; })
          .accessibilityText(this.candidatesExpanded ? '変換候補を閉じる' : '変換候補を展開')
      }.width('100%').height(this.metrics.toolbarHeight)
    } else {
      Row({ space: 4 }) {
        Button() { Image($r('app.media.ic_emoji')).width(24).height(24) }
          .height(32).width(32).padding(0)
          .backgroundColor(Color.Transparent).accessibilityText('絵文字').id('open-emoji')
          .onClick(() => { keyboardHaptics.tap(); this.openEmoji(); })
        Button() { Image($r('app.media.ic_clipboard')).width(22).height(22) }
          .padding(0).height(32).width(32).backgroundColor(Color.Transparent).accessibilityText('クリップボード').id('open-clipboard')
          .onClick(() => { keyboardHaptics.tap(); this.openClipboard(); })
        Blank()
        if (this.canOpenSettings) {
          Button() { Image($r('app.media.ic_settings')).width(20).height(20) }
            .padding(0).height(32).width(28).backgroundColor(Color.Transparent).accessibilityText('アプリの設定')
            .onClick(() => { keyboardHaptics.tap(); imeController.openAppSettings(); })
        }
        Button() { Image($r('app.media.ic_hide')).width(22).height(22) }
          .backgroundColor(Color.Transparent).width(32).height(32).accessibilityText('キーボードを閉じる')
          .onClick(() => { keyboardHaptics.tap(); this.flushFlicks(); imeController.commitKana(); imeController.hide(); })
      }.width('100%').height(this.metrics.toolbarHeight)
    }
  }

  @Builder
  kanaKeys() {
    Column({ space: this.metrics.numberGap }) {
      ForEach(this.kanaRows, (row: string[][], index: number) => {
        Row({ space: this.metrics.gap }) {
          if (index === 0) {
            if (this.canReconvert && !this.emojiSearching) {
              this.keyboardKey('再変換', () => { imeController.reconvertSelection(); }, 1, true)
            } else { this.iconKey($r('app.media.ic_undo'), '逆順', () => { this.reverseText(); }) }
          } else if (index === 1) {
            this.cursorKey(-1)
          } else {
            this.emojiKey()
          }
          ForEach(row, (values: string[]) => { this.kanaKey(values); }, (values: string[]) => values[0])
          if (index === 0) {
            this.iconKey($r('app.media.ic_backspace'), '削除', () => { this.deleteText(); }, 1, false, true)
          } else if (index === 1) {
            this.cursorKey(1)
          } else {
            if (this.shownReading().length > 0) {
              this.keyboardKey('変換', () => { this.flushFlicks(); this.convertText(); }, 1, true)
            } else { this.iconKey($r('app.media.ic_space'), '空白', () => { this.spaceText(); }) }
          }
        }.width('100%')
      }, (row: string[][], index: number) => index.toString())
      Row({ space: this.metrics.gap }) {
        this.modeKey()
        if (this.shownReading().length > 0) { this.modifierKey() } else { this.languageKey() }
        this.kanaKey(['わ','を','ん','ー','〜'])
        this.kanaKey(['、','。','？','！','…'])
        this.enterKey()
      }.width('100%')
    }.width('100%')
  }

  @Builder
  languageKey() {
    Button() { Image($r('app.media.ic_globe')).width(24).height(24) }
      .type(ButtonType.Normal).borderRadius(8).padding(0).backgroundColor(KeyboardPalette.key)
      .height(this.metrics.numberHeight).width(this.metrics.numberWidth)
      .id('key-入力言語').accessibilityText('入力言語を選択')
      .onClick(() => { keyboardHaptics.tap(); this.flushFlicks(); imeController.commitKana(); this.inputMethodsDialog.open(); })
  }

  @Builder
  alphabet12Keys() {
    Column({ space: this.metrics.numberGap }) {
      ForEach(TwelveKeyLayout.alphabet, (row: TwelveKeyGroup[], index: number) => {
        Row({ space: this.metrics.gap }) {
          if (index === 0) { this.iconKey($r('app.media.ic_undo'), '逆順', () => { this.reverseText(); }) }
          else if (index === 1) { this.cursorKey(-1) }
          else { this.emojiKey() }
          ForEach(row, (group: TwelveKeyGroup) => { this.kanaKey(group.values, group.label, group.hint); }, (group: TwelveKeyGroup) => group.label)
          if (index === 0) { this.iconKey($r('app.media.ic_backspace'), '削除', () => { this.deleteText(); }, 1, false, true) }
          else if (index === 1) { this.cursorKey(1) }
          else { this.iconKey($r('app.media.ic_space'), '空白', () => { this.insertText(' '); }) }
        }.width('100%')
      }, (row: TwelveKeyGroup[], index: number) => index.toString())
      Row({ space: this.metrics.gap }) {
        this.modeKey()
        if (this.shownReading().length > 0) {
          this.keyboardKey('a ⇔ A', () => { this.transformText('case'); })
        } else { this.languageKey() }
        this.kanaKey(TwelveKeyLayout.quotes.values, TwelveKeyLayout.quotes.label, TwelveKeyLayout.quotes.hint)
        this.kanaKey(TwelveKeyLayout.alphabetPunctuation.values, TwelveKeyLayout.alphabetPunctuation.label)
        this.enterKey()
      }.width('100%')
    }.width('100%')
  }

  @Builder
  alphaKeys() {
    Column({ space: this.metrics.alphaGap }) {
      Row({ space: this.metrics.gap }) {
        ForEach(this.top, (key: string) => {
          this.keyboardKey(this.upper ? key.toUpperCase() : key,
            () => { this.letter(key); })
        }, (key: string) => key)
      }.width('100%')
      Row({ space: this.metrics.gap }) {
        Blank().width((this.metrics.alphaWidth - this.metrics.gap) / 2)
        ForEach(this.middle, (key: string) => {
          this.keyboardKey(this.upper ? key.toUpperCase() : key,
            () => { this.letter(key); })
        }, (key: string) => key)
        Blank().width((this.metrics.alphaWidth - this.metrics.gap) / 2)
      }.width('100%')
      Row({ space: this.metrics.gap }) {
        this.iconKey($r('app.media.ic_shift'), '大文字・小文字切替', () => { this.upper = !this.upper; }, 1.5)
        ForEach(this.bottom, (key: string) => {
          this.keyboardKey(this.upper ? key.toUpperCase() : key,
            () => { this.letter(key); })
        }, (key: string) => key)
        this.iconKey($r('app.media.ic_backspace'), '削除', () => { this.deleteText(); }, 1.5, false, true)
      }.width('100%')
      Row({ space: this.metrics.gap }) {
        this.modeKey(1.5)
        this.keyboardKey('?123', () => { this.changeMode('number'); }, 1, true)
        this.keyboardKey('/', () => { if (this.mode === 'romaji') { this.romajiText('/'); } else { this.insertText('/'); } })
        this.keyboardKey(this.mode === 'romaji' ? '日本語' : 'English', () => {
          if (this.mode === 'romaji') {
            if (this.shownReading().length > 0) { this.convertText(); } else { this.spaceText(); }
          } else { this.insertText(' '); }
        }, 2)
        this.keyboardKey('.', () => { if (this.mode === 'romaji') { this.romajiText('.'); } else { this.insertText('.'); } })
        this.cursorKey(-1)
        this.cursorKey(1)
        this.enterKey(1.5)
      }.width('100%')
    }.width('100%')
  }

  @Builder
  number12Keys() {
    Column({ space: this.metrics.numberGap }) {
      ForEach(TwelveKeyLayout.numbers, (row: TwelveKeyGroup[], index: number) => {
        Row({ space: this.metrics.gap }) {
          if (index === 0) { this.iconKey($r('app.media.ic_undo'), '逆順', () => { this.reverseText(); }) }
          else if (index === 1) { this.cursorKey(-1) }
          else { this.keyboardKey('!?#', () => { this.changeMode('symbol'); }, 1, true) }
          ForEach(row, (group: TwelveKeyGroup) => { this.kanaKey(group.values, group.label, group.hint); }, (group: TwelveKeyGroup) => group.label)
          if (index === 0) { this.iconKey($r('app.media.ic_backspace'), '削除', () => { this.deleteText(); }, 1, false, true) }
          else if (index === 1) { this.cursorKey(1) }
          else { this.iconKey($r('app.media.ic_space'), '空白', () => { this.insertText(' '); }) }
        }.width('100%')
      }, (row: TwelveKeyGroup[], index: number) => index.toString())
      Row({ space: this.metrics.gap }) {
        this.modeKey()
        this.kanaKey(TwelveKeyLayout.brackets.values, TwelveKeyLayout.brackets.label)
        this.kanaKey(TwelveKeyLayout.zero.values, TwelveKeyLayout.zero.label, TwelveKeyLayout.zero.hint)
        this.kanaKey(TwelveKeyLayout.numberPunctuation.values, TwelveKeyLayout.numberPunctuation.label)
        this.enterKey()
      }.width('100%')
    }.width('100%')
  }

  @Builder
  numberKeys() {
    Column({ space: this.metrics.numberGap }) {
      ForEach(this.mode === 'symbol' ? this.symbols : this.digits, (row: string[], index: number) => {
        Row({ space: this.metrics.gap }) {
          if (index === 0) {
            this.iconKey($r('app.media.ic_hide'), 'キーボードを閉じる', () => { imeController.hide(); })
          } else if (index === 1) {
            this.iconKey($r('app.media.ic_left'), 'カーソル左', () => { this.moveText(-1); })
          } else {
            this.keyboardKey(this.mode === 'symbol' ? '123' : '#+=',
              () => { this.changeMode(this.mode === 'symbol' ? 'number' : 'symbol'); }, 1, true)
          }
          ForEach(row, (key: string) => {
            this.keyboardKey(key, () => { this.insertText(key); }, 1, false, false, true)
          }, (key: string) => key)
          if (index === 0) {
            this.iconKey($r('app.media.ic_backspace'), '削除', () => { this.deleteText(); }, 1, false, true)
          } else if (index === 1) {
            this.iconKey($r('app.media.ic_right'), 'カーソル右', () => { this.moveText(1); })
          } else {
            this.iconKey($r('app.media.ic_space'), '空白', () => { this.insertText(' '); })
          }
        }.width('100%')
      }, (row: string[], index: number) => this.mode + index.toString())
      Row({ space: this.metrics.gap }) {
        this.modeKey()
        this.keyboardKey(this.mode === 'symbol' ? '[' : '.',
          () => { this.insertText(this.mode === 'symbol' ? '[' : '.'); }, 1, false, false, true)
        this.keyboardKey(this.mode === 'symbol' ? ']' : '0',
          () => { this.insertText(this.mode === 'symbol' ? ']' : '0'); }, 1, false, false, true)
        this.keyboardKey(this.mode === 'symbol' ? '"' : ',',
          () => { this.insertText(this.mode === 'symbol' ? '"' : ','); }, 1, false, false, true)
        this.enterKey()
      }.width('100%')
    }.width('100%')
  }

  build() {
    Column() {
      Blank().height(this.popupInset).hitTestBehavior(HitTestMode.None)
      Column() {
        if (this.mode === 'clipboard') {
          ClipboardPanel({ metrics: this.metrics, returnLabel: this.clipboardReturnMode === 'alpha' ? 'ABC' : (this.clipboardReturnMode === 'number' ? '123' : 'あいう'),
            onReturn: () => { this.changeMode(this.clipboardReturnMode); } }).layoutWeight(1)
        } else if (this.mode === 'emoji') {
          EmojiPanel({ metrics: this.metrics, query: this.emojiQuery, returnLabel: this.emojiReturnMode === 'alpha' ? 'ABC' : (this.emojiReturnMode === 'number' ? '123' : 'あいう'),
            onSearch: (query: string) => { this.beginEmojiSearch(query); },
            onReturn: () => { this.emojiQuery = ''; this.changeMode(this.emojiReturnMode); }, onSymbols: () => { this.changeMode('symbol'); } }).layoutWeight(1)
        } else {
        this.keyboardToolbar()
        if (this.candidatesExpanded && this.shownReading().length > 0) {
          Scroll() {
            Column() {
              ForEach(this.candidateLines, (row: CandidateRow) => {
                Row() {
                  ForEach(row.values, (value: string, index: number) => {
                    Row() {
                      Text(value).fontSize(17).fontColor(this.segmentMode && value === this.segmentValue ? KeyboardPalette.selectedInk : KeyboardPalette.ink).maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
                        .layoutWeight(1).padding({ left: 8, right: 8 })
                      if (index < row.values.length - 1) {
                        Divider().vertical(true).height(this.metrics.toolbarHeight * 0.46).color(KeyboardPalette.divider)
                      }
                    }.width((row.spans[index] * 25).toString() + '%').height(this.metrics.toolbarHeight * 0.84)
                      .onClick(() => {
                        keyboardHaptics.tap();
                        this.flushFlicks();
                        imeController.selectCandidate(value, this.reading, imeController.sessionId, row.context);
                        this.candidatesExpanded = false;
                      })
                  }, (value: string) => value)
                }.width('100%')
              }, (row: CandidateRow) => row.context.toString() + row.values.join('\u0001'))
            }.width('100%')
          }.align(Alignment.TopStart).scrollBar(BarState.Off).layoutWeight(1).width('100%')
        } else if (this.mode === 'kana') { this.kanaKeys(); } else if (this.mode === 'alpha') { this.alphabet12Keys(); } else if (this.mode === 'romaji') { this.alphaKeys(); } else if (this.mode === 'number' && !this.forceNumber) { this.number12Keys(); } else { this.numberKeys(); }
        }
        if (this.error.length > 0) { Text(this.error).fontSize(11).fontColor('#B42318').height(16) }
      }.padding({ left: this.metrics.margin, right: this.metrics.margin, bottom: this.metrics.bottomPadding })
        .width('100%').height(this.metrics.panelHeight).backgroundColor(KeyboardPalette.panel)
        .onAreaChange((_oldArea: Area, area: Area) => {
          const width = Number(area.width); const height = Number(area.height);
          if (width > 0 && height > 0 && (width !== this.layoutWidth || height !== this.layoutHeight)) {
            this.layoutWidth = width; this.layoutHeight = height; this.layoutChanged();
          }
        })
    }.width('100%').height('100%').padding({ left: this.panelLeft, right: this.panelRight }).backgroundColor(Color.Transparent)
      .id('ime-editor-window-' + this.editorWindowId.toString())
  }
}
