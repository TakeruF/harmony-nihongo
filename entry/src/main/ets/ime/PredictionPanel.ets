import { imeController } from './ImeController';
import { KeyboardMetrics } from './KeyboardMetrics';
import { KeyboardPalette } from './KeyboardPalette';
import { PanelBackButton } from './PanelBackButton';

@Component
export struct PredictionPanel {
  metrics: KeyboardMetrics = new KeyboardMetrics(360, 800);
  onReturn: () => void = () => {};
  @StorageLink('imeNextWord') nextWord: boolean = true;
  @StorageLink('imePersonalized') learning: boolean = true;
  @StorageLink('imePrivate') privateMode: boolean = false;
  @StorageLink('imeLearnedCount') count: number = 0;
  @StorageLink('imeCanOpenSettings') canOpenSettings: boolean = false;
  @State confirmReset: boolean = false;
  @State resetting: boolean = false;
  @State message: string = '';

  @Builder
  option(title: string, detail: string, checked: boolean, key: string) {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text(title).fontSize(15).fontColor(KeyboardPalette.ink).width('100%')
        Text(detail).fontSize(11).fontColor(KeyboardPalette.inactiveInk).width('100%')
      }.layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: checked }).selectedColor(KeyboardPalette.panelAccent)
        .id('prediction-' + key).accessibilityText(title).enabled(!this.resetting)
        .onChange((value: boolean) => { imeController.setPredictionOption(key, value); })
    }.width('100%').padding({ top: 10, bottom: 10, left: 10, right: 10 })
  }
  build() {
    Column() {
      Row({ space: 10 }) {
        PanelBackButton({ metrics: this.metrics, identifier: 'prediction-back', label: 'キーボードへ戻る', onBack: this.onReturn })
        Text('予測・学習').fontSize(18).fontColor(KeyboardPalette.ink).layoutWeight(1)
      }.height(this.metrics.toolbarHeight).width('100%')
      Scroll() {
        Column({ space: 3 }) {
          this.option('次の語句を予測', '確定した言葉に続く候補を表示します。', this.nextWord, 'nextWord')
          this.option('個人に合わせて学習', 'よく使う言葉とその続きを端末内で覚えます。', this.learning, 'learning')
          this.option('シークレットモード', '学習と個人候補、確定後の予測を一時停止します。', this.privateMode, 'private')
          Text('候補を長押しすると、その候補を削除できます。').fontSize(11).fontColor(KeyboardPalette.inactiveInk).width('100%').padding(10)
          if (this.confirmReset) {
            Text('覚えた言葉と削除した候補をリセットしますか？').fontSize(13).fontColor(KeyboardPalette.ink).padding(8)
            Row({ space: 10 }) {
              Button('キャンセル').id('prediction-reset-cancel').onClick(() => { this.confirmReset = false; })
              Button('削除する').id('prediction-reset-confirm').enabled(!this.resetting).onClick(() => {
                this.resetting = true;
                imeController.clearLearnedData().then((saved: boolean) => {
                  this.message = saved ? '学習データを削除しました' : '削除できませんでした';
                  this.resetting = false; this.confirmReset = false;
                });
              })
            }.padding(6)
          } else {
            Button('学習データを削除 (' + this.count.toString() + ')').id('prediction-reset').fontSize(13)
              .backgroundColor(KeyboardPalette.functionKey).fontColor(KeyboardPalette.ink)
              .onClick(() => { this.confirmReset = true; this.message = ''; })
          }
          if (this.message.length > 0) { Text(this.message).id('prediction-status').fontSize(12).fontColor(KeyboardPalette.ink).padding(6) }
          if (this.canOpenSettings) {
            Button('その他の設定').fontSize(12).backgroundColor(Color.Transparent).fontColor(KeyboardPalette.selectedInk)
              .onClick(() => { imeController.openAppSettings(); })
          }
        }.width('100%').padding({ bottom: 12 })
      }.width('100%').layoutWeight(1).scrollBar(BarState.Off)
    }.width('100%').height('100%')
  }
}
