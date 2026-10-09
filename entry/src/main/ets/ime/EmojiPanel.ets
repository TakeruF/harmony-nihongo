import { util } from '@kit.ArkTS';
import { KeyboardPalette } from './KeyboardPalette';
import { emojiCategories, EmojiCategory, EmojiEntry, EmojiCatalogData, SearchableEmojiCategory, emojiHistory, searchEmoji } from '../input/EmojiCatalog';
import { KeyboardMetrics } from './KeyboardMetrics';
import { imeController } from './ImeController';
import { keyboardHaptics } from './KeyboardHaptics';

@Component
export struct EmojiPanel {
  @Prop metrics: KeyboardMetrics;
  @Prop query: string = '';
  @State category: number = 0;
  @State catalog: SearchableEmojiCategory[] = [];
  @State recent: EmojiEntry[] = [];
  @State variants: string[] = [];
  @State selectedEntry: EmojiEntry = new EmojiEntry();
  private active: boolean = false;
  private categoryIcons: Resource[] = [$r('app.media.ic_emoji'), $r('app.media.ic_person'), $r('app.media.ic_nature'),
    $r('app.media.ic_food'), $r('app.media.ic_travel'), $r('app.media.ic_activity'), $r('app.media.ic_object'),
    $r('app.media.ic_symbol'), $r('app.media.ic_flag')];
  private scroller: Scroller = new Scroller();
  @Prop returnLabel: string = 'あいう';
  onReturn: () => void = () => {};
  onSymbols: () => void = () => {};
  onSearch: (query: string) => void = () => {};
  aboutToAppear(): void {
    this.active = true; this.recent = emojiHistory.snapshot();
    this.catalog = emojiCategories.map((category: EmojiCategory) => {
      const result = new SearchableEmojiCategory(); result.label = category.label; result.icon = category.icon;
      result.entries = category.values.map((value: string) => { const entry = new EmojiEntry(); entry.value = value; entry.name = value; return entry; });
      return result;
    });
    const context = this.getUIContext().getHostContext();
    if (context) {
      context.resourceManager.getRawFileContent('emoji-15.1-ja.json').then((bytes: Uint8Array) => {
        if (!this.active) { return; }
        const data = JSON.parse(util.TextDecoder.create('utf-8').decodeToString(bytes)) as EmojiCatalogData;
        this.catalog = data.categories;
      }).catch(() => {});
    }
  }
  aboutToDisappear(): void { this.active = false; }
  private entries(): EmojiEntry[] {
    if (this.query.trim().length > 0) { return searchEmoji(this.catalog, this.query); }
    return this.category < 0 ? this.recent : (this.catalog[this.category]?.entries ?? []);
  }
  private choose(entry: EmojiEntry, value: string = entry.value): void {
    keyboardHaptics.tap(); imeController.insert(value);
    const recent = new EmojiEntry(); recent.value = value; recent.name = entry.name; recent.keywords = entry.keywords;
    emojiHistory.remember(recent); this.recent = emojiHistory.snapshot(); this.variants = [];
  }
  private chooseCategory(index: number): void { keyboardHaptics.tap(); this.category = index; this.variants = []; this.scroller.scrollEdge(Edge.Top); }
  build() {
    Column() {
      Row({ space: 6 }) {
        Button() { Image($r('app.media.ic_back')).width(24).height(24) }
          .width(36).height(36).padding(0).backgroundColor(KeyboardPalette.key).borderRadius(18)
          .accessibilityText('キーボードに戻る').id('emoji-back').onClick(() => { this.onReturn(); })
        Text('絵文字').fontSize(18).fontColor(KeyboardPalette.ink)
        Button() {
          Row({ space: 4 }) {
            Image($r('app.media.ic_search')).width(19).height(19)
            Text(this.query || '検索').fontSize(15).fontColor(KeyboardPalette.inactiveInk).maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }.padding({ left: 10, right: 10 })
        }.height(34).width(112).padding(0).backgroundColor(KeyboardPalette.key).borderRadius(18)
          .id('emoji-search').accessibilityText('絵文字を検索').onClick(() => { this.onSearch(this.query); })
        Scroll() {
          Row({ space: 3 }) {
            Button() { Image($r('app.media.ic_recent')).width(22).height(22) }.width(32).height(32).padding(0)
              .backgroundColor(this.category < 0 ? KeyboardPalette.functionKey : Color.Transparent).borderRadius(16)
              .id('emoji-recent').accessibilityText('最近使った絵文字').onClick(() => { this.chooseCategory(-1); })
            ForEach(this.catalog, (item: SearchableEmojiCategory, index: number) => {
              Button() { Image(this.categoryIcons[index]).width(22).height(22) }.width(32).height(32).padding(0).borderRadius(16)
                .backgroundColor(index === this.category ? KeyboardPalette.functionKey : Color.Transparent)
                .accessibilityText(item.label).id('emoji-category-' + index.toString()).onClick(() => { this.chooseCategory(index); })
            }, (item: SearchableEmojiCategory) => item.label)
          }
        }.layoutWeight(1).scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
      }.height(this.metrics.toolbarHeight).width('100%')
      Column() {
        Text(this.query ? '検索結果' : (this.category < 0 ? '最近使った絵文字' : (this.catalog[this.category]?.label ?? '絵文字')))
          .fontSize(12).fontColor(KeyboardPalette.inactiveInk).height(24).width('100%').padding({ left: 6 }).textAlign(TextAlign.Start)
        if (this.variants.length > 0) {
          Row() {
            Grid() {
              ForEach(this.variants, (value: string) => {
                GridItem() {
                  Text(value).fontSize(27).height(44).width('100%').textAlign(TextAlign.Center).id('emoji-variant-' + value)
                }.height(44).onClick(() => { this.choose(this.selectedEntry, value); })
              }, (value: string) => value)
            }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr').layoutWeight(1)
              .height(Math.min(132, Math.ceil(this.variants.length / 6) * 44)).scrollBar(BarState.Off)
            Button('×').width(28).height(40).padding(0).backgroundColor(Color.Transparent).fontColor(KeyboardPalette.ink)
              .accessibilityText('肌の色の選択を閉じる').onClick(() => { this.variants = []; })
          }.width('100%').backgroundColor(KeyboardPalette.functionKey)
        }
        if (this.entries().length === 0) {
          Text(this.query ? '見つかりませんでした' : 'まだ使った絵文字はありません').fontSize(14).fontColor(KeyboardPalette.inactiveInk)
            .layoutWeight(1).width('100%').textAlign(TextAlign.Center).id('emoji-empty')
        } else {
          Grid(this.scroller) {
            ForEach(this.entries(), (entry: EmojiEntry) => {
              GridItem() {
                Text(entry.value).fontSize(27).width('100%').height('100%').textAlign(TextAlign.Center)
                  .id('emoji-' + entry.value).accessibilityText(entry.name)
              }.height(Math.max(32, this.metrics.numberHeight * 0.82)).onClick(() => { this.choose(entry); })
                .gesture(LongPressGesture().onAction(() => {
                  if (entry.variants.length > 0) { this.selectedEntry = entry; this.variants = [entry.value, ...entry.variants]; }
                }))
            }, (entry: EmojiEntry) => entry.value)
          }.columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr').rowsGap(0).columnsGap(0)
            .layoutWeight(1).width('100%').scrollBar(BarState.Off).id('emoji-grid')
        }
      }.width('100%').layoutWeight(1).backgroundColor(KeyboardPalette.key)
      Row() {
        Button(this.returnLabel).fontSize(17).fontColor(KeyboardPalette.ink).width(54).height(44).padding(0)
          .backgroundColor(Color.Transparent).id('emoji-return').onClick(() => { keyboardHaptics.tap(); this.onReturn(); })
        Button('#+=').fontSize(17).fontColor(KeyboardPalette.ink).width(44).height(44).padding(0)
          .backgroundColor(Color.Transparent).id('emoji-symbols').onClick(() => { keyboardHaptics.tap(); this.onSymbols(); })
        Button() { Image($r('app.media.ic_emoji')).width(26).height(26) }
          .width(36).height(36).padding(0).backgroundColor(KeyboardPalette.actionKey).borderRadius(18).accessibilityText('絵文字')
        Blank()
        Button() { Image($r('app.media.ic_backspace')).width(26).height(26) }
          .width(44).height(44).padding(0).backgroundColor(Color.Transparent).id('emoji-delete').accessibilityText('削除')
          .onClick(() => { keyboardHaptics.tap(); imeController.backspace(); })
      }.width('100%').height(this.metrics.toolbarHeight)
    }.width('100%').height('100%')
  }
}
