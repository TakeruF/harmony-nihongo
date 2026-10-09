# 新環境でのDebugビルドとGboard実測比較（参照採取2026-10-09、最終検証2026-10-10）

作業先は `/Users/takeru/GitHub/harmony-nihongo`。GitHubの初期コミット `8b6d8bf` をクローンし、このMacでDebugビルドを実行した。本プロジェクトはHarmonyOSのArkTS/C++アプリで、成果物はHAP。Android/Gradleプロジェクトではない。

**Debugビルドは成功。かな・英字・数字の12キー入力を実測基準に合わせたが、GboardのすべてのUI・動作・UXが完全一致したとは扱わない。**

## 比較条件

- 参照：Android 15の比較専用エミュレータ、1080×2400、420 dpi。
- Gboard：`14.2.09.629370537-preload-arm64-v8a` / versionCode `143544270`。日本語12キー、標準の明るいテーマ、フリックと連続タップを併用。
- 日本語辞書のダウンロード完了後に、比較専用の入力欄で実際の文字列を確認した。Gboardの辞書やライブラリを本アプリへ移植していない。
- 動作側：比較専用HarmonyOS 6.0.1 / API 21エミュレータ。最終比較では1080×2400、表示倍率2.625に揃えた。
- 元から存在するエミュレータのデータを初期化していない。実機は接続許可がないため、この環境では実機検証していない。

## 変更

- パネル・通常キー・機能キー・確定キー・モードキー・文字色を、スクリーンショットの実測値に合わせた。絵文字・クリップボードの背景も統一。
- 1080 pxの参照画面で、横余白12 px、横隙間12 px、キー高さ140 px、行間15 px、候補帯144 pxとなる寸法へ調整。縦横・利用可能な高さに合わせて縮小する。
- 長押し時は中央と四方向の文字を表示し、方向選択後は選択文字と三角形の押下表示を出す。上端に透明な表示領域を確保し、入力欄の避ける位置とタッチ領域は見えるキーボードに合わせる。OSの下部ボタンとの重なりも解消。
- 表示APIが使えない古いOSやAPIエラー時は、従来のパネル設定へ戻る。
- 初期設定をフリック専用から、フリックと連続タップの併用へ変更。既に保存された利用者設定は書き換えない。
- 英字モードを日本語12キーの英字配置へ変更。日本語QWERTYは既存の長押し切替で引き続き使える。
- 英字連打は `a → b → c → A → B → C → 2`、記号連打は `@ → - → _ → / → 1` の実測順に対応。割り当てが空の方向は入力しない。
- 数字モードの12キーに、Gboardと同じ方向の記号を追加。`゜`、`・`、`〜`などは、画面の形ではなく実際に入力された文字コードを使用した。数字専用の入力欄では既存の数字入力を維持。
- 未入力時の文字変形キーを言語選択キーへ変更し、入力中は濁点・大小文字の操作に切り替える。入力言語キーからHarmonyOSの入力法一覧を開く。
- 現在のモードを「あa1」の太字と色で区別。空白キーを専用のベクターアイコンへ変更し、「変換」の文字寸法を参照へ近づけた。
- 左上のキーを入力全体の取消から、連打した文字を逆順へ戻す操作に変更。かなは `か → こ → け`、英字は `a → 2 → C → B`。フリックで直接入力した文字や、濁点へ変形した文字は変更しない。
- 絵文字を9列、9カテゴリ1,898種類へ拡充。日本語・英語のオフライン検索、最近使った36件、長押しでの肌の色選択を追加。顔の先頭36種類は参照画面の順序へ合わせた。検索語をアプリの入力欄へ送らず、入力先を切り替えたら検索を閉じる。
- 横画面のOSボタン用左右余白も公開APIから取得する。回転後の縮小値を縦画面へ持ち越さないよう、パネルの実寸から再計算する。
- 試験画面のTextAreaが、未確定文字を除いた本文だけを再描画へ戻す問題を修正。SDKのonChangeが別々に返す本文・未確定文字・位置から、実際に見える文字列を構成する。入力先へ同じ文字を再送する処理は追加していない。
- 接続直後のカーソル読み取りエラーで、入力欄をプレビュー非対応へ固定していた判定を修正。読み取りのエラーだけで非対応とは判断せず、次の入力時に読み取りを再確認する。
- Mozcのライセンス通知生成で、再ビルドだけで末尾の空行が増える問題を修正。

## 検証と証跡

`python3 tools/build.py` が成功。最終の表示調整後のDebugビルドも成功。署名設定のない通常出力は `entry/build/default/outputs/default/entry-default-unsigned.hap`。比較用エミュレータへは、SDKの開発用証明書で作成したエミュレータ限定のDebug署名を使った。実機・Release用の署名設定は変更していない。

- ホストテスト11本とネイティブ境界テスト：合格。
- Mozc実エンジンの予測・学習・再起動後の学習・文節・伸縮・逆変換：合格。
- Gboardで採取した入力：かな55方向、英字55方向、数字・記号60方向、英字と記号の連打21パターン。
- Harmonyエミュレータの独立した別アプリで、170方向と21連打を実際の入力欄の値で照合：すべて合格。基本入力・長押し・モード画面の記録を含む全202件の結果は `artifacts/gboard-validation/full-input-results.json`。
- 最終版で基本フリック・連打・長押しを再検証。候補「今日は」の確定、単行欄の検索アクションが一度だけ発火すること、言語選択ダイアログを確認。
- 入力中の「きょうは」を横・縦回転しても保持し、OSボタンとキーが重ならず、縦へ戻ると140 pxのキー高さへ戻ることを確認。
- 逆順キー、絵文字の9列・挿入・履歴、日本語検索の入力隔離、検索語を保持した一覧への戻り、肌の色のシーケンスと1個単位の削除を確認。別の入力欄へフォーカスを移すと検索が閉じ、新しい欄へ検索語が漏れず、かなを一度だけ確定できることも確認。
- 入力先の読み取り失敗だけでプレビューを無効にしない修正後、202件の独立アプリ照合で表示欠落は再発していない。書き込みの再送は追加せず、ホストでは「最初の読み取りだけ失敗・次の入力で成功」を回帰検証した。

全件照合のログは `artifacts/gboard-validation/independent-device-tests.log`、最終ビルドは `debug-build.log`、その他のログは `artifacts/gboard-validation/`、参照画像は `artifacts/gboard-reference-2026-10-09/`、Harmony側の画像は `artifacts/gboard-reference-device/`、`artifacts/gboard-extra-device/`、`artifacts/gboard-emoji-device/` に保存。画像・ビルド成果物・端末ログはGit対象外。入力文字列の参照データは `tools/fixtures/gboard-14.2-*.json` に含める。

## 保存した最終成果物

- 通常のDebug HAP（未署名）：`artifacts/gboard-validation/HarmonyNihongo-gboard-debug-unsigned.hap`
- この比較用エミュレータにだけインストールできる署名版：`artifacts/gboard-validation/HarmonyNihongo-gboard-emulator-only.hap`
- 検証件数・成果物ハッシュ：`artifacts/gboard-validation/verification-summary.json`
- [Gboardのかな・候補画面](../artifacts/gboard-reference-2026-10-09/kyouha-candidates.png)
- [最終版のかな・候補画面](../artifacts/gboard-extra-device/kana-candidates.png)
- [最終版の絵文字検索画面](../artifacts/gboard-emoji-device/emoji-search-results.png)

画像の上側は比較用の入力アプリ。比較対象は下側のキーボード領域。ビルド成果物・画像・ログはこのMacに保存し、Gitの対象には含めていない。

## 再実行

メインアプリのビルドにはREADMEのDevEco環境を使う。

```sh
python3 tools/build.py
node tools/test-kana.cjs
node tools/test-keyboard-metrics.cjs
node tools/test-conversion-controller.cjs
node tools/test-emoji-catalog.cjs
python3 tools/test-gboard-reference-device.py --target <hdcの接続先> --full
python3 tools/test-gboard-extra-device.py --target <hdcの接続先>
python3 tools/test-gboard-emoji-device.py --target <hdcの接続先>
```

端末テストは選択した端末の本アプリの試験入力欄を操作する。署名済みアプリをインストールし、Harmony Nihongoを選択してから実行する。試験中に本アプリを再起動するため、残しておきたい試験入力は先に控える。

Harmony側にも独立した入力欄を用意した。IMEを毎回停止することなく、別アプリへの実入力を照合できる。

```sh
python3 tools/build-harmony-comparison.py
# 生成した独立入力アプリを、選択したエミュレータ用に署名・インストールしてから:
python3 tools/test-gboard-reference-device.py --target <hdcの接続先> \
  --editor-bundle com.takeruf.imecompareharmony --full
```

Android参照用の独立した入力欄のソースとビルド手順も追加した。これは本アプリのAndroid移植ではない。

```sh
python3 tools/build-android-comparison.py \
  --sdk /Users/takeru/Library/Android/sdk \
  --java-home /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
```

## 絵文字データ

[Unicode Emoji 15.1](https://www.unicode.org/Public/emoji/15.1/emoji-test.txt) の完全修飾シーケンスと、[CLDR 44の日本語注釈](https://github.com/unicode-org/cldr/tree/release-44/common/annotations)・派生注釈を使用。肌の色を基本一覧から分離し、1,898種類の基本項目と長押しの選択肢に整理した。Unicodeの順序を基本に、顔の先頭36種類のみGboardの実測順へ変更。全件の順序がGboardと同一とは扱わない。

`tools/build-emoji-catalog.py` で固定版と記録済みハッシュを検証して再生成できる。データ・ライセンスはリポジトリに含めるため、通常のビルドで取得は不要。Unicode License v3を `licenses/UNICODE-LICENSE.txt` とアプリのライセンス通知に含める。絵文字画像やGboardの内部資産はコピーしていない。

## 完全一致まで残る差

| 項目 | 現在の状態 |
| --- | --- |
| 候補・学習 | OSS Mozcの候補を使う。Gboard全体の順位・個人化・データと同一とは検証していない。 |
| ツールバー | Gboardのツール一覧、GIF、ステッカー、音声、手書きなどと構成・機能が異なる。機能のないボタンを装飾だけで追加していない。 |
| 記号・絵文字・クリップボード画面 | 絵文字の9列・日本語検索・一時履歴・肌の色を実装。Gboardの全件順序、検索順位、履歴永続化、記号画面、クリップボードのピン留め・配置は一致していない。 |
| 長押し・取消・編集 | 連打の逆順操作は実測へ合わせた。日本語QWERTY切替は既存の長押しを維持。Gboardの全メニュー・編集履歴・時間設定と同一ではない。 |
| 設定保存 | Huaweiの承認済みdata-group-idが未取得。利用者にも未取得と確認済み。設定画面からIMEへ反映する検証は承認待ち。 |
| OSが描く領域 | HarmonyOSの入力法切替・下部ボタンとAndroidのナビゲーションは異なる。 |
| フォント・全端末 | OSの書体・描画差や、全サイズ・端末での一致は未検証。HarmonyOS 7実機の再検証も残る。 |

設定共有の接続と申請手順は [settings-sharing.md](settings-sharing.md)。この比較の入力パターン合格を、全機能の完全一致という意味へ拡張しない。
