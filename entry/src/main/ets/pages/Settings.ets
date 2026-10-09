import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { keyboardSettings } from '../ime/KeyboardSettings';

@Entry
@Component
struct Settings {
  @StorageLink('settingsLinked') linked: boolean = false;
  @StorageLink('settingsError') error: string = '';
  @StorageLink('imeHalfSpace') halfSpace: boolean = false;
  @StorageLink('imeHaptics') haptics: boolean = true;
  @StorageLink('imeThreeModes') threeModes: boolean = true;
  @StorageLink('imeFlickOnly') flickOnly: boolean = false;
  @StorageLink('imeKeitaiOnly') keitaiOnly: boolean = false;
  private kanaPreview: string[][] = [['↶','あ','か','さ','⌫'], ['◀','た','な','は','▶'],
    ['記','ま','や','ら','空'], ['あa1','゛゜小','わ','、','↵']];
  private qwertyPreview: string[][] = [['q','w','e','r','t','y','u','i','o','p'],
    ['a','s','d','f','g','h','j','k','l'], ['⇧','z','x','c','v','b','n','m','⌫'], ['あa1','123','日本語','◀','▶']];

  aboutToAppear(): void {
    keyboardSettings.refresh();
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    window.getLastWindow(context).then((appWindow: window.Window) => {
      return appWindow.setWindowSystemBarProperties({ statusBarColor: '#0C153B', statusBarContentColor: '#EDF0FF',
        navigationBarColor: '#0C153B', navigationBarContentColor: '#EDF0FF' });
    }).catch(() => {});
  }

  @Builder
  miniature(rows: string[][]) {
    Column({ space: 2 }) {
      ForEach(rows, (row: string[], index: number) => {
        Row({ space: 2 }) {
          ForEach(row, (label: string, keyIndex: number) => {
            Text(label).maxLines(1).fontSize(row.length > 5 || label.length > 2 ? 7 : 9).fontColor('#EDF0FF')
              .height(18).layoutWeight(label === '日本語' ? 2 : 1).textAlign(TextAlign.Center).backgroundColor('#354E9D').borderRadius(3)
          }, (label: string, keyIndex: number) => keyIndex.toString())
        }.width('100%')
      }, (row: string[], index: number) => index.toString())
    }.padding(5).width('100%').backgroundColor('#101C46').borderRadius(8)
  }

  @Builder
  settingRow(title: string, detail: string, checked: boolean, change: (value: boolean) => void) {
    Row({ space: 14 }) {
      Column({ space: 5 }) {
        Text(title).fontSize(17).fontColor('#EDF0FF').width('100%')
        Text(detail).fontSize(13).fontColor('#AEBCE4').width('100%')
      }.layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: checked }).selectedColor('#89A9FF').enabled(this.linked)
        .onChange(change)
    }.width('100%').padding(18).backgroundColor('#202D62').borderRadius(20)
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 16 }) {
        Button('‹').fontSize(28).width(42).height(42).backgroundColor('#202D62').fontColor('#AEBCE4')
          .accessibilityText('設定を閉じる').onClick(() => {
            this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
          })
        Text('日本語').fontSize(25).fontColor('#EDF0FF')
        Blank()
      }.width('100%').padding({ left: 16, right: 16, top: 12, bottom: 6 })
      Scroll() {
        Column({ space: 14 }) {
          Row({ space: 12 }) {
            Column({ space: 12 }) {
              this.miniature(this.kanaPreview)
              Text('✓  12キー').fontSize(16).height(38).width('100%').textAlign(TextAlign.Center)
                .backgroundColor('#89A9FF').fontColor('#152D65').borderRadius(24)
            }.layoutWeight(1)
            Column({ space: 12 }) {
              this.miniature(this.qwertyPreview)
              Text('○  QWERTY').fontSize(16).height(38).width('100%').textAlign(TextAlign.Center)
                .fontColor('#AEBCE4').border({ width: 1, color: '#6D7FAF', radius: 24 })
            }.layoutWeight(1)
          }.padding(18).width('100%').backgroundColor('#202D62').borderRadius(24)
          Text('キーボードの「あa1」を長押しすると、12キーと日本語QWERTYを切り替えられます。').fontSize(12).fontColor('#AEBCE4').width('100%')
          if (!this.linked) {
            Column({ space: 5 }) {
              Text('設定共有を準備中').fontSize(15).fontColor('#EDF0FF').width('100%')
              Text('現在は標準設定で入力できます。設定項目は共有の準備後に変更できます。')
                .fontSize(13).fontColor('#AEBCE4').width('100%')
            }.padding(16).width('100%').backgroundColor('#202D62').borderRadius(20)
          }
          Text('言語設定').fontSize(14).fontColor('#95ACEC').width('100%').margin({ top: 12, left: 6 })
          this.settingRow('半角スペースを使う', 'かな入力でも半角スペースを使います。オフのときは全角になります。',
            this.halfSpace, (value: boolean) => { keyboardSettings.set('imeHalfSpace', value); })
          Text('ソフトキーボード設定').fontSize(14).fontColor('#95ACEC').width('100%').margin({ top: 12, left: 6 })
          this.settingRow('キー操作で振動', 'キーや候補の操作で短く振動します。入力法の完全アクセスモードで利用できます。',
            this.haptics, (value: boolean) => { keyboardSettings.set('imeHaptics', value); })
          this.settingRow('3つの入力モード', 'かな・英字に加えて、数字をモード切替に含めます。',
            this.threeModes, (value: boolean) => { keyboardSettings.set('imeThreeModes', value); })
          Text('横画面対応 · 選択中の入力方式を維持').fontSize(13).fontColor('#AEBCE4').width('100%').padding(12)
          Text('12キーの設定').fontSize(14).fontColor('#95ACEC').width('100%').margin({ top: 12, left: 6 })
          Text('英字はQWERTYを使用 · 英字12キーは今後対応').fontSize(13).fontColor('#AEBCE4').width('100%').padding(12)
          this.settingRow('フリックのみ', '同じキーを続けてタップしても、先頭のかなを入力します。',
            this.flickOnly, (value: boolean) => { keyboardSettings.set('imeFlickOnly', value); })
          this.settingRow('ケータイ入力のみ', 'フリックを使わず、同じキーの連続タップでかなを切り替えます。',
            this.keitaiOnly, (value: boolean) => { keyboardSettings.set('imeKeitaiOnly', value); })
          Text('両方オフでフリックと連続タップを併用できます。').fontSize(12).fontColor('#AEBCE4').width('100%')
          if (this.error.length > 0) { Text(this.error).fontSize(13).fontColor('#FFB4AB') }
        }.padding({ left: 16, right: 16, bottom: 24 }).width('100%')
      }.width('100%').layoutWeight(1)
    }.width('100%').height('100%').backgroundColor('#0C153B').expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
