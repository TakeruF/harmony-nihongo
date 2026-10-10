import { previewFieldValue } from '../input/PreviewFieldValue';
import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
@Entry
@Component
struct Index {
  @State text: string = '';
  @State single: string = '';
  @State searchCount: number = 0;
  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    window.getLastWindow(context).then((appWindow: window.Window) => {
      return appWindow.setWindowSystemBarProperties({ statusBarColor: '#F6F7FB', statusBarContentColor: '#202338',
        navigationBarColor: '#F6F7FB', navigationBarContentColor: '#202338' });
    }).catch(() => {});
  }
  build() {
    Column({ space: 20 }) {
      Row() {
        Text('Harmony Nihongo').fontSize(24).fontWeight(FontWeight.Bold).layoutWeight(1)
        Button() { Text('設定').fontSize(15).fontColor('#304B91') }
          .padding(0).height(36).width(60).backgroundColor('#C8CFF8')
          .onClick(() => { this.getUIContext().getRouter().pushUrl({ url: 'pages/Settings' }); })
      }.width('100%')
      Text('日本語フリック入力').fontSize(16)
      Text('設定 → システム → 入力法で Harmony Nihongo を有効にし、入力法を切り替えてください。').fontSize(16)
      TextInput({ placeholder: 'プレビュー非対応の単行入力', text: this.single })
        .id('singleInput').enablePreviewText(false).enterKeyType(EnterKeyType.Search)
        .onChange((value: string) => { this.single = value; })
        .onSubmit(() => { this.searchCount++; })
      TextArea({ placeholder: '文字・削除・改行をテスト', text: this.text })
        .id('multiInput').height(180).enterKeyType(EnterKeyType.NEW_LINE)
        .onChange((value: string, preview?: PreviewText) => {
          this.text = previewFieldValue(value, preview?.value ?? '', preview?.offset ?? 0);
        })
      Text('検索アクション: ' + this.searchCount).id('searchCount').fontSize(12)
      Text('かなを入力すると漢字候補が表示されます。確定後も次の語句を選べます。キーボードの歯車から予測・学習を設定できます。')
        .fontSize(14).fontColor('#64748B')
    }.padding(24).width('100%').height('100%').backgroundColor('#F6F7FB')
  }
}
