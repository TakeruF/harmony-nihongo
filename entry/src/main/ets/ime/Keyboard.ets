import { ClipboardPanel } from './ClipboardPanel';
import { EmojiPanel } from './EmojiPanel';
import { CursorHoldTracker } from '../input/CursorHoldTracker';
import { KeyRepeatTracker } from '../input/KeyRepeatTracker';
import { imeController } from './ImeController';
import { keyboardHaptics } from './KeyboardHaptics';
import { display } from '@kit.ArkUI';
import { FlickTracker, FlickOutput } from '../input/FlickTracker';
import { KeyboardMetrics } from './KeyboardMetrics';
import { CandidateChoice, CandidateRow, candidateRows } from '../input/CandidateLayout';

@Entry
@Component
struct Keyboard {
  @State mode: string = 'kana';
  @State japaneseMode: string = 'kana';
  private emojiReturnMode: string = 'kana';
  private clipboardReturnMode: string = 'kana';
  private openClipboard(): void {
    this.clipboardReturnMode = this.mode; this.candidatesExpanded = false; this.changeMode('clipboard');
  }
  private openEmoji(): void {
    this.emojiReturnMode = this.mode; this.candidatesExpanded = false; this.changeMode('emoji');
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
  @State metrics: KeyboardMetrics = new KeyboardMetrics(this.screenWidth, this.screenHeight);
  private layoutChanged(): void {
    this.flushFlicks(); this.clearHolds();
    this.metrics = new KeyboardMetrics(this.layoutWidth || this.screenWidth, this.screenHeight, this.layoutHeight || this.screenHeight);
    this.candidatesChanged();
  }

  private candidatesChanged(): void {
    const context = AppStorage.get<number>('imeCandidateContext') ?? 0;
    this.candidateChoices = this.candidates.map((value: string) => new CandidateChoice(value, context));
    this.candidateLines = candidateRows(this.candidates, (this.layoutWidth || this.screenWidth) - this.metrics.margin * 2, 17, context);
  }
  aboutToAppear(): void { keyboardHaptics.initialize(); this.candidatesChanged(); this.editorKindChanged(); }
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
    if (this.reading.length === 0) { this.candidatesExpanded = false; }
  }

  private keyWidth(weight: number): number {
    const unit = (this.mode === 'alpha' || this.mode === 'romaji') ? this.metrics.alphaWidth : this.metrics.numberWidth;
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
    return (this.mode === 'alpha' || this.mode === 'romaji') ? this.metrics.alphaGap : this.metrics.numberGap;
  }

  private keyHeight(): number {
    return (this.mode === 'alpha' || this.mode === 'romaji') ? this.metrics.alphaHeight : this.metrics.numberHeight;
  }

  private acceptFlicks(outputs: FlickOutput[]): void {
    outputs.forEach((output: FlickOutput) => { imeController.kanaInput(output.value, output.session, output.tapValues, output.pressedAt); });
  }
  private flushFlicks(): void { this.acceptFlicks(this.flicks.flush()); this.activeKey = ''; this.selectedKana = ''; }
  private changeMode(mode: string): void {
    this.flushFlicks(); this.clearHolds(); imeController.commitKana(); this.mode = mode;
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
    if (this.mode === 'romaji') { imeController.romajiInput(key, imeController.sessionId); }
    else { imeController.insert(this.upper ? key.toUpperCase() : key); }
  }
  @Builder
  modeKey(weight: number = 1) {
    Button() { Text('あa1').fontSize(20).fontColor('#304B91') }
      .type(ButtonType.Normal).borderRadius(24).padding(0).backgroundColor('#CECAFA')
      .height(this.keyHeight()).width(this.keyWidth(weight))
      .responseRegion({ x: -this.metrics.gap / 2, y: -this.verticalGap() / 2,
        width: this.keyWidth(weight) + this.metrics.gap, height: this.keyHeight() + this.verticalGap() })
      .accessibilityText('入力モード。長押しで日本語12キー・QWERTY切替')
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
    accent: boolean = false, pill: boolean = false, large: boolean = false) {
    Button() {
      Text(label).fontSize(large ? 24 : (label.length > 1 ? 14 : 20)).fontColor(accent ? '#304B91' : '#202338')
        .textAlign(TextAlign.Center).width('100%').maxLines(1)
    }.type(ButtonType.Normal).borderRadius(pill ? 24 : 6).padding(0)
      .backgroundColor(accent ? '#CECAFA' : '#FFFFFF')
      .height(this.keyHeight()).width(this.keyWidth(weight))
      .id('key-' + label)
      .responseRegion({ x: -this.metrics.gap / 2, y: -this.verticalGap() / 2,
        width: this.keyWidth(weight) + this.metrics.gap, height: this.keyHeight() + this.verticalGap() })
      .onTouch((event: TouchEvent) => { this.press(event, action); })
      .onClick((event: ClickEvent) => { this.accessibleClick(event, action); })
  }

  @Builder
  iconKey(icon: Resource, accessibleLabel: string, action: () => void, weight: number = 1, pill: boolean = false, repeat: boolean = false) {
    Button() {
      Image(icon).width(25).height(25).opacity(accessibleLabel === '取消' && this.reading.length === 0 ? 0.4 : 1)
    }.type(ButtonType.Normal).borderRadius(pill ? 24 : 6).padding(0)
      .backgroundColor('#CECAFA').height(this.keyHeight()).width(this.keyWidth(weight))
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
        const move = (): void => { if (delta < 0) { imeController.moveLeft(); } else { imeController.moveRight(); } };
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
      .type(ButtonType.Normal).borderRadius(6).padding(0).backgroundColor('#CECAFA')
      .height(this.keyHeight()).width(this.keyWidth(1))
      .responseRegion({ x: -this.metrics.gap / 2, y: -this.verticalGap() / 2,
        width: this.keyWidth(1) + this.metrics.gap, height: this.keyHeight() + this.verticalGap() })
      .accessibilityText(this.segmentMode ? (delta < 0 ? '前の文節。長押しで文節を縮める' : '次の文節。長押しで文節を伸ばす') : (delta < 0 ? 'カーソル左' : 'カーソル右'))
      .onTouch((event: TouchEvent) => { this.cursorTouch(event, delta); })
      .onClick((event: ClickEvent) => { this.accessibleClick(event, () => { if (delta < 0) { imeController.moveLeft(); } else { imeController.moveRight(); } }); })
  }

  @Builder
  kanaKey(values: string[]) {
    Stack({ alignContent: Alignment.Center }) {
    Button() {
      if (values[0] === '、') {
        Column({ space: 0 }) {
          Text('？').fontSize(13).fontColor('#202338')
          Text('。 、 ！').fontSize(13).fontColor('#202338')
          Text('…').fontSize(11).fontColor('#202338')
        }
      } else { Text(values[0]).fontSize(24).fontColor('#202338').width('100%').textAlign(TextAlign.Center) }
    }
      .type(ButtonType.Normal).borderRadius(6).padding(0)
      .backgroundColor(this.activeKey === values[0] ? '#CECAFA' : '#FFFFFF')
      .height(this.metrics.numberHeight).width(this.metrics.numberWidth)
      .responseRegion({ x: -this.metrics.gap / 2, y: -this.metrics.numberGap / 2,
        width: this.metrics.numberWidth + this.metrics.gap, height: this.metrics.numberHeight + this.metrics.numberGap })
      .onTouch((event: TouchEvent) => { this.flick(event, values); })
      .onClick((event: ClickEvent) => { this.accessibleClick(event, () => {
        imeController.kanaInput(values[0], imeController.sessionId);
      }); })
    if (this.activeKey === values[0] && this.selectedKana.length > 0) {
      Text(this.selectedKana).fontSize(30).fontColor('#202338').textAlign(TextAlign.Center)
        .width(this.metrics.numberHeight * 1.16).height(this.metrics.numberHeight * 1.16)
        .backgroundColor('#FFFFFF').borderRadius(this.metrics.numberHeight)
        .shadow({ radius: 5, color: '#24000000', offsetY: 2 })
        .translate({ y: -this.metrics.numberHeight * 1.05 }).hitTestBehavior(HitTestMode.None)
        .accessibilityLevel('no')
    }
    }.width(this.metrics.numberWidth).height(this.metrics.numberHeight)
      .zIndex(this.activeKey === values[0] ? 10 : 0)
  }

  @Builder
  enterKey(weight: number = 1) {
    if (this.reading.length > 0) {
      this.iconKey($r('app.media.ic_enter'), '確定', () => { imeController.enter(); }, weight, true)
    } else if (this.enterLabel === '改行') {
      this.iconKey($r('app.media.ic_enter'), '改行', () => { imeController.enter(); }, weight, true)
    } else if (this.enterLabel === '検索') {
      this.iconKey($r('app.media.ic_search'), '検索', () => { imeController.enter(); }, weight, true)
    } else {
      this.keyboardKey(this.enterLabel, () => { imeController.enter(); }, weight, true, true)
    }
  }

  @Builder
  emojiKey() {
    Button() {
      Row({ space: 1 }) {
        Image($r('app.media.ic_emoji')).width(22).height(22)
        Text('記').fontSize(19).fontColor('#304B91')
      }
    }.type(ButtonType.Normal).borderRadius(6).padding(0).backgroundColor('#CECAFA')
      .height(this.metrics.numberHeight).width(this.metrics.numberWidth)
      .responseRegion({ x: -this.metrics.gap / 2, y: -this.metrics.numberGap / 2,
        width: this.metrics.numberWidth + this.metrics.gap, height: this.metrics.numberHeight + this.metrics.numberGap })
      .accessibilityText('絵文字・記号')
      .onTouch((event: TouchEvent) => { this.press(event, () => { this.openEmoji(); }); })
      .onClick((event: ClickEvent) => { this.accessibleClick(event, () => { this.openEmoji(); }); })
  }

  @Builder
  modifierKey() {
    Button() {
      Column({ space: 2 }) {
        Text('゛ ゜').fontSize(19).fontColor('#202338')
        Text('大 ⇔ 小').fontSize(8).fontColor('#202338')
      }
    }.type(ButtonType.Normal).borderRadius(6).padding(0).backgroundColor('#FFFFFF')
      .height(this.metrics.numberHeight).width(this.metrics.numberWidth)
      .responseRegion({ x: -this.metrics.gap / 2, y: -this.metrics.numberGap / 2,
        width: this.metrics.numberWidth + this.metrics.gap, height: this.metrics.numberHeight + this.metrics.numberGap })
      .accessibilityText('濁点・半濁点・小文字')
      .onTouch((event: TouchEvent) => { this.press(event, () => { imeController.transformKana('variant'); }); })
      .onClick((event: ClickEvent) => { this.accessibleClick(event, () => { imeController.transformKana('variant'); }); })
  }

  @Builder
  keyboardToolbar() {
    if (this.reading.length > 0) {
      Row({ space: 4 }) {
        Scroll() {
          Row() {
            ForEach(this.candidateChoices, (choice: CandidateChoice, index: number) => {
              Text(choice.value)
                .id(choice.value === this.reading ? 'composition' : 'candidate-' + index.toString())
                .fontSize(17).fontColor(this.segmentMode && choice.value === this.segmentValue ? '#304B91' : '#202338')
                .fontWeight(this.segmentMode && choice.value === this.segmentValue ? FontWeight.Medium : FontWeight.Normal).maxLines(1)
                .padding({ left: 12, right: 12 }).height(this.metrics.toolbarHeight)
                .onClick(() => {
                  keyboardHaptics.tap();
                  this.flushFlicks();
                  imeController.selectCandidate(choice.value, this.reading, imeController.sessionId, choice.context);
                  this.candidatesExpanded = false;
                })
              if (index < this.candidates.length - 1) {
                Divider().vertical(true).height(20).color('#C8CAE1')
              }
            }, (choice: CandidateChoice) => choice.context.toString() + choice.value)
          }
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).align(Alignment.Start).layoutWeight(1)
        Button() {
          Image($r('app.media.ic_hide')).width(20).height(20).fillColor('#304B91').rotate({ angle: this.candidatesExpanded ? 180 : 0 })
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
            if (this.canReconvert) {
              this.keyboardKey('再変換', () => { imeController.reconvertSelection(); }, 1, true)
            } else { this.iconKey($r('app.media.ic_undo'), '取消', () => { imeController.cancelKana(); }) }
          } else if (index === 1) {
            this.cursorKey(-1)
          } else {
            this.emojiKey()
          }
          ForEach(row, (values: string[]) => { this.kanaKey(values); }, (values: string[]) => values[0])
          if (index === 0) {
            this.iconKey($r('app.media.ic_backspace'), '削除', () => { imeController.backspace(); }, 1, false, true)
          } else if (index === 1) {
            this.cursorKey(1)
          } else {
            this.keyboardKey(this.reading.length > 0 ? '変換' : '␣', () => {
              if (this.reading.length > 0) { this.flushFlicks(); imeController.startSegmentConversion(); } else { imeController.kanaSpace(); }
            }, 1, true)
          }
        }.width('100%')
      }, (row: string[][], index: number) => index.toString())
      Row({ space: this.metrics.gap }) {
        this.modeKey()
        this.modifierKey()
        this.kanaKey(['わ','を','ん','ー','〜'])
        this.kanaKey(['、','。','？','！','…'])
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
        this.iconKey($r('app.media.ic_backspace'), '削除', () => { imeController.backspace(); }, 1.5, false, true)
      }.width('100%')
      Row({ space: this.metrics.gap }) {
        this.modeKey(1.5)
        this.keyboardKey('?123', () => { this.changeMode('number'); }, 1, true)
        this.keyboardKey('/', () => { if (this.mode === 'romaji') { imeController.romajiInput('/', imeController.sessionId); } else { imeController.insert('/'); } })
        this.keyboardKey(this.mode === 'romaji' ? '日本語' : 'English', () => {
          if (this.mode === 'romaji') {
            if (this.reading.length > 0) { imeController.startSegmentConversion(); } else { imeController.kanaSpace(); }
          } else { imeController.insert(' '); }
        }, 2)
        this.keyboardKey('.', () => { if (this.mode === 'romaji') { imeController.romajiInput('.', imeController.sessionId); } else { imeController.insert('.'); } })
        this.cursorKey(-1)
        this.cursorKey(1)
        this.enterKey(1.5)
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
            this.iconKey($r('app.media.ic_left'), 'カーソル左', () => { imeController.moveLeft(); })
          } else {
            this.keyboardKey(this.mode === 'symbol' ? '123' : '#+=',
              () => { this.changeMode(this.mode === 'symbol' ? 'number' : 'symbol'); }, 1, true)
          }
          ForEach(row, (key: string) => {
            this.keyboardKey(key, () => { imeController.insert(key); }, 1, false, false, true)
          }, (key: string) => key)
          if (index === 0) {
            this.iconKey($r('app.media.ic_backspace'), '削除', () => { imeController.backspace(); }, 1, false, true)
          } else if (index === 1) {
            this.iconKey($r('app.media.ic_right'), 'カーソル右', () => { imeController.moveRight(); })
          } else {
            this.keyboardKey('␣', () => { imeController.insert(' '); }, 1, true)
          }
        }.width('100%')
      }, (row: string[], index: number) => this.mode + index.toString())
      Row({ space: this.metrics.gap }) {
        this.modeKey()
        this.keyboardKey(this.mode === 'symbol' ? '[' : '.',
          () => { imeController.insert(this.mode === 'symbol' ? '[' : '.'); }, 1, false, false, true)
        this.keyboardKey(this.mode === 'symbol' ? ']' : '0',
          () => { imeController.insert(this.mode === 'symbol' ? ']' : '0'); }, 1, false, false, true)
        this.keyboardKey(this.mode === 'symbol' ? '"' : ',',
          () => { imeController.insert(this.mode === 'symbol' ? '"' : ','); }, 1, false, false, true)
        this.enterKey()
      }.width('100%')
    }.width('100%')
  }

  build() {
    Column() {
      if (this.mode === 'clipboard') {
        ClipboardPanel({ metrics: this.metrics, returnLabel: this.clipboardReturnMode === 'alpha' ? 'ABC' : (this.clipboardReturnMode === 'number' ? '123' : 'あいう'),
          onReturn: () => { this.changeMode(this.clipboardReturnMode); } }).layoutWeight(1)
      } else if (this.mode === 'emoji') {
        EmojiPanel({ metrics: this.metrics, returnLabel: this.emojiReturnMode === 'alpha' ? 'ABC' : (this.emojiReturnMode === 'number' ? '123' : 'あいう'),
          onReturn: () => { this.changeMode(this.emojiReturnMode); }, onSymbols: () => { this.changeMode('symbol'); } }).layoutWeight(1)
      } else {
      this.keyboardToolbar()
      if (this.candidatesExpanded && this.reading.length > 0) {
        Scroll() {
          Column() {
            ForEach(this.candidateLines, (row: CandidateRow) => {
              Row() {
                ForEach(row.values, (value: string, index: number) => {
                  Row() {
                    Text(value).fontSize(17).fontColor(this.segmentMode && value === this.segmentValue ? '#304B91' : '#202338').maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis }).textAlign(TextAlign.Center)
                      .layoutWeight(1).padding({ left: 8, right: 8 })
                    if (index < row.values.length - 1) {
                      Divider().vertical(true).height(this.metrics.toolbarHeight * 0.46).color('#C8CAE1')
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
      } else if (this.mode === 'kana') { this.kanaKeys(); } else if (this.mode === 'alpha') { this.alphaKeys(); } else if (this.mode === 'romaji') { this.alphaKeys(); } else { this.numberKeys(); }
      }
      if (this.error.length > 0) { Text(this.error).fontSize(11).fontColor('#B42318').height(16) }
    }.padding({ left: this.metrics.margin, right: this.metrics.margin, bottom: this.metrics.bottomPadding })
      .width('100%').height('100%').backgroundColor('#E8E3FC')
      .onAreaChange((_oldArea: Area, area: Area) => {
        const width = Number(area.width); const height = Number(area.height);
        if (width > 0 && height > 0 && (width !== this.layoutWidth || height !== this.layoutHeight)) {
          this.layoutWidth = width; this.layoutHeight = height; this.layoutChanged();
        }
      })
  }
}
