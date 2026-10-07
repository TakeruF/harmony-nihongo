import { emojiCategories, EmojiCategory } from '../input/EmojiCatalog';
import { KeyboardMetrics } from './KeyboardMetrics';
import { imeController } from './ImeController';
import { keyboardHaptics } from './KeyboardHaptics';

@Component
export struct EmojiPanel {
  @Prop metrics: KeyboardMetrics;
  @State category: number = 0;
  private scroller: Scroller = new Scroller();
  @Prop returnLabel: string = 'あいう';
  onReturn: () => void = () => {};
  onSymbols: () => void = () => {};
  private choose(value: string): void { keyboardHaptics.tap(); imeController.insert(value); }
  build() {
    Column() {
      Row() {
        ForEach(emojiCategories, (item: EmojiCategory, index: number) => {
          Button() { Text(item.icon).fontSize(22).fontColor('#304B91') }
            .type(ButtonType.Normal).padding(0).borderRadius(16).layoutWeight(1).height(32)
            .backgroundColor(index === this.category ? '#CECAFA' : Color.Transparent)
            .accessibilityText(item.label).id('emoji-category-' + index.toString())
            .onClick(() => { keyboardHaptics.tap(); this.category = index; this.scroller.scrollEdge(Edge.Top); })
        }, (item: EmojiCategory) => item.label)
      }.height(this.metrics.toolbarHeight).width('100%')
      Grid(this.scroller) {
        ForEach(emojiCategories[this.category].values, (value: string) => {
          GridItem() {
            Text(value).fontSize(26).width('100%').height('100%').textAlign(TextAlign.Center)
              .id('emoji-' + value).accessibilityText(value)
          }.height(Math.max(40, Math.min(this.metrics.alphaHeight,
            (this.metrics.panelHeight - this.metrics.bottomPadding - this.metrics.toolbarHeight - this.metrics.alphaHeight - this.metrics.numberGap - 12) / 4))).onClick(() => { this.choose(value); })
        }, (value: string) => value)
      }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr').rowsGap(4).columnsGap(2)
        .layoutWeight(1).width('100%').scrollBar(BarState.Off).id('emoji-grid')
      Row({ space: this.metrics.gap }) {
        Button(this.returnLabel).fontSize(17).fontColor('#304B91').layoutWeight(1)
          .height(this.metrics.alphaHeight).backgroundColor('#CECAFA').borderRadius(24).id('emoji-return')
          .onClick(() => { keyboardHaptics.tap(); this.onReturn(); })
        Button('#+=').fontSize(17).fontColor('#304B91').layoutWeight(1)
          .height(this.metrics.alphaHeight).backgroundColor('#CECAFA').borderRadius(6).id('emoji-symbols')
          .onClick(() => { keyboardHaptics.tap(); this.onSymbols(); })
        Button() { Image($r('app.media.ic_backspace')).width(25).height(25) }
          .layoutWeight(1).height(this.metrics.alphaHeight).backgroundColor('#CECAFA').borderRadius(6)
          .id('emoji-delete').accessibilityText('削除').onClick(() => { keyboardHaptics.tap(); imeController.backspace(); })
        Button() { Image($r('app.media.ic_enter')).width(25).height(25) }
          .layoutWeight(1).height(this.metrics.alphaHeight).backgroundColor('#CECAFA').borderRadius(24)
          .id('emoji-enter').accessibilityText('Enter').onClick(() => { keyboardHaptics.tap(); imeController.enter(); })
      }.width('100%').margin({ top: this.metrics.numberGap })
    }.width('100%').height('100%')
  }
}
