# クリップボード

Pura70 / HarmonyOS7向け0.11.0（versionCode100010）に、テキストのクリップボードパネルを追加。

## 操作と保存

未入力時のツールバーのクリップボードアイコンから開く。標準の貼り付けボタンを押すと、現在コピーされているテキストを入力欄に貼り付ける。ボタンの表示言語は端末の言語に従う。読み込んだ項目をタップして再利用でき、×で個別削除、「履歴を消す」で一括削除できる。

- 最大10件。重複は先頭へ移動し、1時間で利用期限が切れる。IMEプロセスの終了で消える一時履歴。
- ファイル・ネットワークに保存せず、自動監視・バックグラウンド読み取り・システムクリップボードの書き換えは行わない。履歴の削除はアプリ内の一時履歴だけを消す。
- テキストのみ。空白、改行、Unicode結合列はそのまま渡す。1件16,384 UTF-16単位まで。大きすぎるテキストは切り捨てずに案内する。画像・ファイルの貼り付け、ピン留め・永続保存は未対応。
- 完全アクセスモードで利用する。基礎モードでは読み取りボタンを出さず、利用できないことを表示し、保持している履歴も消す。
- 下部から元の12キー・日本語QWERTY・英字などへ戻る。画面回転にも対応する。

## API・境界

`PasteButtonOnClickResult.SUCCESS`から`pasteboard.getSystemPasteboard().getData()`を呼ぶ。常時読み取り用の`ohos.permission.READ_PASTEBOARD`を追加していない。追加のユーザー権限要求画面もない。

[OpenHarmony公式の貼り付けコントロールガイド](https://github.com/openharmony/docs/blob/master/zh-cn/application-dev/security/AccessToken/pastebutton.md)と、実際のSDK26の`paste_button.d.ts`、`security_component.d.ts`、`@ohos.pasteboard.d.ts`を確認。[Huawei公式ガイド](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/pastebutton)はWeb取得で本文が得られなかったため、SDK宣言とHarmonyOS7実機で検証した。

読み取りの完了時に編集先の世代・パネルの存続・セキュリティモードを確認する。貼り付けも既存の編集キューを使い、未確定文字があれば先に確定する。確定後も世代と利用可否を再確認し、古い編集先や閉じたキーボードに貼り付けない。内容をログに出さない。

## 検証

`node tools/test-clipboard-history.cjs`: Unicode・空白の保持、空データ・サイズ上限、重複と順序、件数上限、期限、削除を検証。

`node tools/test-conversion-controller.cjs`: かなの一度だけの確定、完全なテキストの挿入、古い編集先・非表示パネル・利用不可への切り替えを検証。既存のかな・ローマ字・変換・文節・再変換の回帰チェックも実行。

`python3 tools/test-clipboard-device.py`: システムのコピー操作と標準の貼り付けボタンで実際の入力を検証。アプリ所有の単行・複数行の欄、履歴の再利用・削除、検索を誤送信しないこと、元のレイアウト、横画面・回転を確認する。Huaweiブラウザーからコピーした公開URLをこのIME経由でアプリの欄に貼り付ける試験も実施。

履歴の期限や基礎モードへの切り替えのガードはホスト側の検証。実機試験は完全アクセスモード。画像・全アプリ・基礎モードの実機確認を意味しない。

## 最終HAP

`artifacts/phase10/HarmonyNihongo-0.11.0-debug.hap`

SHA-256: `ee8fd1f4469f2a84059ee3a0024ae9677cec5aa7430ee7638c3a0c030ad388cb`

署名・ダイジェストを`hap-sign-tool verify-app`で検証し、接続端末に更新インストール。画像と結果は`artifacts/phase10/`に保存する。アプリ設定の共有・永続化は引き続きdata-group-idの準備後に対応するが、この一時クリップボード履歴には共有領域を使用しない。

最終HAPでアプリ所有の入力欄の実機16項目がすべてPASS。別アプリ（Huaweiブラウザー）から公開URLをコピーし、このIMEの標準貼り付けボタンから入力する試験もPASSで、実機17項目を確認した。`clipboard-portrait.png`、`clipboard-history.png`、`clipboard-landscape.png`を保存し、縦横のパネルを目視確認した。1時間の期限を実際に待つ試験は行わず、境界時刻を渡すホストテストで検証した。
