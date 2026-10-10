import { KeyboardPalette } from './KeyboardPalette';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { clipboardHistory, ClipboardItem } from '../input/ClipboardHistory';
import { imeController } from './ImeController';
import { KeyboardMetrics } from './KeyboardMetrics';
import { keyboardHaptics } from './KeyboardHaptics';
import { clipboardStore } from './ClipboardStore';
import { PanelBackButton } from './PanelBackButton';

@Component
export struct ClipboardPanel {
  @Prop metrics: KeyboardMetrics;
  @Prop returnLabel: string = 'あいう';
  onReturn: () => void = () => {};
  onAdd: () => void = () => {};
  @StorageLink('imeClipboardAllowed') @Watch('modeChanged') allowed: boolean = false;
  @State entries: ClipboardItem[] = [];
  @State message: string = '';
  @State loading: boolean = false;
  @State historyEnabled: boolean = true;
  @State editing: boolean = false;
  @State selected: number[] = [];
  private active: boolean = false;
  private request: number = 0;
  aboutToAppear(): void { this.active = true; this.entries = clipboardHistory.snapshot(); this.historyEnabled = clipboardHistory.enabled; }
  aboutToDisappear(): void { this.active = false; this.request++; }
  private modeChanged(): void {
    this.request++; this.loading = false; this.entries = clipboardHistory.snapshot(); this.message = ''; this.editing = false; this.selected = [];
  }
  private readAndPaste(result: PasteButtonOnClickResult): void {
    if (!this.allowed || !this.historyEnabled || this.loading) { return; }
    if (result !== PasteButtonOnClickResult.SUCCESS) {
      this.message = '貼り付けボタンをもう一度押してください。'; return;
    }
    const session = imeController.sessionId;
    const request = ++this.request;
    this.loading = true; this.message = '';
    // Start getData directly in the secure control's success callback.
    let operation: Promise<pasteboard.PasteData>;
    try { operation = pasteboard.getSystemPasteboard().getData(); } catch (_err) {
      this.loading = false; this.message = '読み取れませんでした。もう一度お試しください。'; return;
    }
    operation.then((data: pasteboard.PasteData) => {
      if (!this.active || request !== this.request || session !== imeController.sessionId || !imeController.canUseClipboard) { return; }
      const text = data.getPrimaryText();
      const item = clipboardHistory.remember(text);
      if (!item) {
        this.message = text.length > 16384 ? 'テキストが長すぎます。短く分けてコピーしてください。' :
          (text.length > 0 ? '固定したクリップが上限に達しています。固定を解除してお試しください。' : 'コピーされたテキストがありません。');
        return;
      }
      this.entries = clipboardHistory.snapshot();
      imeController.insertClipboard(item.text, session);
    }).catch((_err: BusinessError) => {
      if (this.active && request === this.request) { this.message = '読み取れませんでした。貼り付けボタンでもう一度お試しください。'; }
    }).finally(() => { if (this.active && request === this.request) { this.loading = false; } });
  }
  private paste(item: ClipboardItem): void {
    this.entries = clipboardHistory.snapshot();
    if (!this.entries.some((value: ClipboardItem) => value.id === item.id)) { return; }
    keyboardHaptics.tap(); imeController.insertClipboard(item.text, imeController.sessionId);
  }
  private persist(): void {
    if (this.allowed && !clipboardStore.save()) { this.message = 'クリップボードの設定を保存できませんでした。'; }
  }
  private setEnabled(enabled: boolean): void {
    if (!this.allowed) { return; }
    keyboardHaptics.tap(); this.historyEnabled = enabled; clipboardHistory.setEnabled(enabled);
    this.entries = clipboardHistory.snapshot(); this.editing = false; this.selected = []; this.persist();
  }
  private select(item: ClipboardItem): void {
    this.selected = this.selected.includes(item.id) ? this.selected.filter((id: number) => id !== item.id) : [...this.selected, item.id];
  }
  private deleteSelected(): void {
    if (!this.allowed) { return; }
    this.selected.forEach((id: number) => { clipboardHistory.remove(id); });
    this.entries = clipboardHistory.snapshot(); this.selected = []; this.persist();
  }
  private pinSelected(): void {
    if (!this.allowed) { return; }
    const unpin = this.entries.filter((item: ClipboardItem) => this.selected.includes(item.id)).every((item: ClipboardItem) => item.pinned);
    clipboardHistory.pin(this.selected, !unpin); this.entries = clipboardHistory.snapshot(); this.selected = []; this.persist();
  }
  private items(pinned: boolean): ClipboardItem[] { return this.entries.filter((item: ClipboardItem) => item.pinned === pinned); }
  private actionEnabled(identifier: string): boolean {
    if (!this.allowed) { return false; }
    if (identifier === 'clipboard-edit') { return this.historyEnabled; }
    return identifier === 'clipboard-add' ? this.selected.length === 0 : this.selected.length > 0;
  }
  @Builder
  headerAction(icon: Resource, identifier: string, label: string, action: () => void) {
    Button() {
      Image(icon).width(this.metrics.toolbarHeight * (identifier === 'clipboard-edit' ? 0.44 : 0.36))
        .height(this.metrics.toolbarHeight * (identifier === 'clipboard-edit' ? 0.44 : 0.36))
    }
      .width(this.metrics.toolbarHeight * 0.7).height(this.metrics.toolbarHeight * 0.7).padding(0)
      .backgroundColor(KeyboardPalette.panelCard).borderRadius(this.metrics.toolbarHeight).enabled(this.actionEnabled(identifier))
      .opacity(this.actionEnabled(identifier) ? 1 : 0.35).id(identifier).accessibilityText(label)
      .onClick(() => { keyboardHaptics.tap(); action(); })
  }
  @Builder
  card(item: ClipboardItem) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Text(item.text).fontSize(14).fontColor(KeyboardPalette.panelInk).maxLines(6).textOverflow({ overflow: TextOverflow.Ellipsis })
        .id('clipboard-item-' + item.id.toString())
        .width('100%').padding({ left: 12, right: this.editing || item.pinned ? 32 : 12, top: 12, bottom: 12 })
        .constraintSize({ minHeight: 64 }).textAlign(TextAlign.Start)
      if (this.editing) {
        Text(this.selected.includes(item.id) ? '✓' : '').fontSize(13).fontColor(KeyboardPalette.panelInk)
          .width(20).height(20).textAlign(TextAlign.Center).borderRadius(10)
          .border({ width: 1.7, color: this.selected.includes(item.id) ? KeyboardPalette.panelAccent : KeyboardPalette.inactiveInk })
          .backgroundColor(this.selected.includes(item.id) ? KeyboardPalette.panelAccent : Color.Transparent).margin(10)
      } else if (item.pinned) { Image($r('app.media.ic_pin')).width(14).height(14).margin(10) }
    }.width('100%').backgroundColor(this.selected.includes(item.id) ? KeyboardPalette.panelSelected : KeyboardPalette.panelCard)
      .borderRadius(8).id('clipboard-card-' + item.id.toString()).accessibilityText(item.text + (item.pinned ? '、固定済み' : ''))
      .onClick(() => { if (this.editing) { this.select(item); } else { this.paste(item); } })
      .gesture(LongPressGesture().onAction(() => { this.editing = true; this.selected = [item.id]; }))
  }
  @Builder
  section(pinned: boolean, showPaste: boolean = false) {
    Column() {
      Row() {
        Text(pinned ? '固定済み' : (this.entries.length === 0 ? 'ヒント' : '最近'))
          .fontSize(12).fontColor(KeyboardPalette.inactiveInk).layoutWeight(1)
        if (showPaste && !this.editing && this.entries.length > 0) {
          PasteButton({ icon: PasteIconStyle.LINES, buttonType: ButtonType.Circle }).iconSize(16)
            .iconColor(KeyboardPalette.panelInk).backgroundColor(KeyboardPalette.panelCard).width(28).height(28)
            .id('clipboard-paste')
            .onClick((_event: ClickEvent, result: PasteButtonOnClickResult) => { this.readAndPaste(result); })
        }
      }.width('100%').height(this.entries.length === 0 ? 24 : 28).padding({ left: 5, right: 5 })
      Row({ space: 10 }) {
        Column({ space: 8 }) {
          ForEach(this.entries.filter((item: ClipboardItem) => item.pinned === pinned).filter((_item: ClipboardItem, index: number) => index % 2 === 0),
            (item: ClipboardItem) => { this.card(item); }, (item: ClipboardItem) => item.id.toString())
        }.layoutWeight(1)
        Column({ space: 8 }) {
          ForEach(this.entries.filter((item: ClipboardItem) => item.pinned === pinned).filter((_item: ClipboardItem, index: number) => index % 2 === 1),
            (item: ClipboardItem) => { this.card(item); }, (item: ClipboardItem) => item.id.toString())
        }.layoutWeight(1)
      }.width('100%').alignItems(VerticalAlign.Top)
    }.width('100%')
  }
  @Builder
  hint(icon: Resource, text: string, securePaste: boolean = false) {
    Column({ space: 12 }) {
      if (securePaste && !this.editing) {
        PasteButton({ icon: PasteIconStyle.LINES, buttonType: ButtonType.Circle }).iconSize(16)
          .iconColor(KeyboardPalette.panelInk).backgroundColor(KeyboardPalette.panelAccent).width(24).height(24)
          .id('clipboard-paste').onClick((_event: ClickEvent, result: PasteButtonOnClickResult) => { this.readAndPaste(result); })
      } else {
        Row() { Image(icon).width(16).height(16) }.width(24).height(24).justifyContent(FlexAlign.Center)
          .backgroundColor(KeyboardPalette.panelAccent).borderRadius(12)
      }
      Text(text).fontSize(14).fontColor(KeyboardPalette.panelInk).width('100%').textAlign(TextAlign.Start)
    }.width('100%').padding(12).alignItems(HorizontalAlign.Start).backgroundColor(KeyboardPalette.panelCard).borderRadius(8)
  }
  build() {
    Column() {
      Row({ space: this.metrics.toolbarHeight * 0.25 }) {
        PanelBackButton({ metrics: this.metrics, identifier: 'clipboard-return', editing: this.editing,
          label: this.editing ? '選択をキャンセル' : this.returnLabel + 'のキーボードに戻る', onBack: () => {
            keyboardHaptics.tap(); if (this.editing) { this.editing = false; this.selected = []; } else { this.onReturn(); }
          } })
        Text(this.editing ? (this.selected.length > 0 ? this.selected.length.toString() + '件を選択中' : 'アイテムを選択') : 'クリップボード')
          .fontSize(18).fontWeight(FontWeight.Medium).fontColor(KeyboardPalette.panelInk).layoutWeight(1).maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis }).id('clipboard-title')
        Row({ space: this.metrics.toolbarHeight * 0.335 }) {
        if (this.editing) {
          this.headerAction($r('app.media.ic_delete'), 'clipboard-clear', '選択したクリップを削除', () => { this.deleteSelected(); })
          this.headerAction($r('app.media.ic_pin'), 'clipboard-pin', '選択したクリップの固定を切り替える', () => { this.pinSelected(); })
          this.headerAction($r('app.media.ic_add'), 'clipboard-add', '新しいクリップ', () => { this.onAdd(); })
        } else {
          Button() { Image($r('app.media.ic_clipboard_toggle')).width(24).height(24).rotate({ angle: this.historyEnabled ? 0 : 180 }) }
            .width(this.metrics.toolbarHeight * 0.7).height(this.metrics.toolbarHeight * 0.7).padding(0)
            .backgroundColor(KeyboardPalette.panelCard).borderRadius(this.metrics.toolbarHeight).enabled(this.allowed)
            .id('clipboard-toggle').accessibilityText(this.historyEnabled ? 'クリップボードを無効にする' : 'クリップボードを有効にする')
            .onClick(() => { this.setEnabled(!this.historyEnabled); })
          this.headerAction($r('app.media.ic_edit'), 'clipboard-edit', 'クリップを編集', () => { this.editing = true; this.selected = []; })
        }
        }
      }.height(this.metrics.toolbarHeight * 0.93).width('100%').padding({ left: 2, right: 2 }).id('clipboard-header')
      if (this.editing) { Divider().color(KeyboardPalette.divider).strokeWidth(0.7) }
      if (!this.allowed) {
        Text('クリップボードは完全アクセスモードで使えます。').fontSize(15).fontColor('#64748B')
          .layoutWeight(1).width('100%').padding(16).id('clipboard-basic-message')
      } else if (!this.historyEnabled) {
        Column({ space: 20 }) {
          Text('クリップボードへようこそ').fontSize(20).fontWeight(FontWeight.Medium).fontColor(KeyboardPalette.panelInk)
          Text('コピーしたテキストを保存して、いつでも貼り付けられます。').fontSize(14).fontColor(KeyboardPalette.panelInk).textAlign(TextAlign.Center)
          Button('クリップボードを有効にする').fontSize(14).fontColor(KeyboardPalette.panelInk)
            .backgroundColor(KeyboardPalette.panelCard).id('clipboard-enable').onClick(() => { this.setEnabled(true); })
        }.width('100%').layoutWeight(1).justifyContent(FlexAlign.Center).padding(20)
      } else {
        Scroll() {
          Column() {
            this.section(false, true)
            if (this.items(true).length > 0) { this.section(true); }
            if (this.entries.length > 0) {
              Text('ヒント').fontSize(12).fontColor(KeyboardPalette.inactiveInk).height(24).width('100%')
                .textAlign(TextAlign.Start).padding({ left: 5 }).margin({ top: 12 })
            }
              Row({ space: 10 }) {
                Column({ space: 8 }) {
                  this.hint($r('app.media.ic_clipboard_toggle'), 'クリップボードへようこそ。コピーしたテキストはここに保存されます。')
                  this.hint($r('app.media.ic_edit'), '編集アイコンで、クリップを固定、追加、削除できます。')
                }.layoutWeight(1)
                Column({ space: 8 }) {
                  if (this.entries.length === 0) {
                    this.hint($r('app.media.ic_clipboard'), '貼り付けアイコンでコピーしたテキストを保存・入力できます。クリップをタップすると貼り付けられます。', true)
                  } else {
                    this.hint($r('app.media.ic_clipboard'), 'クリップをタップすると、テキストボックスに貼り付けられます。')
                  }
                  this.hint($r('app.media.ic_pin'), 'クリップを長押しすると固定できます。固定しないクリップは1時間後に削除されます。')
                }.layoutWeight(1)
              }.width('100%').alignItems(VerticalAlign.Top)
          }.width('100%').padding({ left: 2, right: 2, bottom: 8 })
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off).align(Alignment.TopStart).id('clipboard-list')
      }
      if (this.message.length > 0) { Text(this.message).fontSize(13).fontColor('#64748B').maxLines(2).width('100%') }
    }.width('100%').height('100%').backgroundColor(KeyboardPalette.clipboardPanel)
  }
}
