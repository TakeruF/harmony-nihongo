import { KeyboardPalette } from './KeyboardPalette';
import { pasteboard, BusinessError } from '@kit.BasicServicesKit';
import { clipboardHistory, ClipboardItem } from '../input/ClipboardHistory';
import { imeController } from './ImeController';
import { KeyboardMetrics } from './KeyboardMetrics';
import { keyboardHaptics } from './KeyboardHaptics';

@Component
export struct ClipboardPanel {
  @Prop metrics: KeyboardMetrics;
  @Prop returnLabel: string = 'あいう';
  onReturn: () => void = () => {};
  @StorageLink('imeClipboardAllowed') @Watch('modeChanged') allowed: boolean = false;
  @State entries: ClipboardItem[] = [];
  @State message: string = '';
  @State loading: boolean = false;
  private active: boolean = false;
  private request: number = 0;
  aboutToAppear(): void { this.active = true; this.entries = clipboardHistory.snapshot(); }
  aboutToDisappear(): void { this.active = false; this.request++; }
  private modeChanged(): void {
    this.request++; this.loading = false; this.entries = clipboardHistory.snapshot(); this.message = '';
  }
  private readAndPaste(result: PasteButtonOnClickResult): void {
    if (!this.allowed || this.loading) { return; }
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
        this.message = text.length > 16384 ? 'テキストが長すぎます。短く分けてコピーしてください。' : 'コピーされたテキストがありません。';
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
  build() {
    Column() {
      Row() {
        Text('クリップボード').fontSize(18).fontColor(KeyboardPalette.ink).layoutWeight(1)
        Button('履歴を消す').fontSize(13).fontColor(KeyboardPalette.ink).backgroundColor(Color.Transparent)
          .id('clipboard-clear').enabled(this.entries.length > 0)
          .onClick(() => { clipboardHistory.clear(); this.entries = []; })
      }.height(this.metrics.toolbarHeight).width('100%')
      if (!this.allowed) {
        Text('クリップボードは完全アクセスモードで使えます。').fontSize(15).fontColor('#64748B')
          .layoutWeight(1).width('100%').padding(16).id('clipboard-basic-message')
      } else {
        List({ space: 8 }) {
          if (this.entries.length === 0) {
            ListItem() {
              Text('下の貼り付けボタンで、コピーしたテキストを入力できます。').fontSize(15).fontColor('#64748B').padding(16)
            }
          }
          ForEach(this.entries, (item: ClipboardItem) => {
            ListItem() {
              Row() {
                Text(item.text).fontSize(16).fontColor(KeyboardPalette.ink).maxLines(3).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1).padding(14).id('clipboard-item-' + item.id.toString()).onClick(() => { this.paste(item); })
                Button('×').fontSize(22).fontColor('#64748B').width(36).height(40).padding(0).backgroundColor(Color.Transparent)
                  .id('clipboard-remove-' + item.id.toString()).accessibilityText('この履歴を削除')
                  .onClick(() => { clipboardHistory.remove(item.id); this.entries = clipboardHistory.snapshot(); })
              }.width('100%').backgroundColor(KeyboardPalette.key).borderRadius(10)
            }
          }, (item: ClipboardItem) => item.id.toString())
        }.layoutWeight(1).width('100%').scrollBar(BarState.Off).id('clipboard-list')
      }
      if (this.message.length > 0) { Text(this.message).fontSize(13).fontColor('#64748B').maxLines(2).width('100%') }
      Text('履歴は最大10件、1時間の一時保存です。').fontSize(11).fontColor('#64748B').width('100%').margin({ top: 4, bottom: 4 })
      Row({ space: this.metrics.gap }) {
        Button(this.returnLabel).fontSize(17).fontColor(KeyboardPalette.ink).layoutWeight(1)
          .height(this.metrics.alphaHeight).backgroundColor(KeyboardPalette.functionKey).borderRadius(24).id('clipboard-return')
          .onClick(() => { keyboardHaptics.tap(); this.onReturn(); })
        if (this.allowed) {
          Column() {
            PasteButton().fontSize(17).fontColor(KeyboardPalette.ink).iconColor(KeyboardPalette.ink).backgroundColor(KeyboardPalette.functionKey)
              .height(Math.max(40, this.metrics.alphaHeight)).width('100%')
              .id('clipboard-paste').onClick((_event: ClickEvent, result: PasteButtonOnClickResult) => { this.readAndPaste(result); })
          }.layoutWeight(1)
        }
      }.width('100%')
    }.width('100%').height('100%')
  }
}
