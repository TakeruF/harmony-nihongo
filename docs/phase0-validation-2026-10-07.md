# 段階0の実装と実機検証

2026-10-07、Pura 70（ADY-AL10）/ HarmonyOS `7.0.0.109(SP6C00E105R5P2)`、API 26、arm64-v8aで検証。SDKは`26.0.0.23 Beta1`、DevEco Studioは`26.0.0.461`。パッケージは`com.takeruf.harmonynihongo`、バージョン0.1.0。

## 結果

| 層 | 確認した内容 | 結果 |
| --- | --- | --- |
| クリーンビルド | 公開対象のソースのみを別ディレクトリへコピーし、ローカル署名情報なしでビルド | unsigned HAPのビルド成功 |
| ソース・ビルド | InputMethodExtensionAbility、SOFT_KEYBOARD、Node-API共有ライブラリ | ArkTS/CMakeビルド成功 |
| Nativeホストテスト | 計算、かな・絵文字・空文字・埋め込みNUL、型と長さの境界 | 実際のC++モジュールをNodeで読み込み、成功 |
| 署名 | 最終HAPを公式hap-sign-toolで検証 | codesign、SHA-256 digest、verify-app成功 |
| 実機IME | 有効化、選択、画面表示 | BASIC_MODEで成功 |
| IME内Native | add(20,22)、echo(きょうは) | inputMethodプロセスのログでNATIVE_PROBE PASS mode=0 |
| 自作テスト画面 | 英数字、削除、空白、改行、検索 | 複数行の`ab \nq`、検索回数1をUIツリーで確認 |
| モード操作 | 数字、記号、Shift、カーソル左 | `a \nq10!BA`をUIツリーで確認 |
| 他アプリ | Huawei設定アプリの検索欄 | `ab1`、削除後`ab`をSearchFieldで確認。テスト文字は消去 |
| 最終寸法調整後 | 表示、英字、空白、改行、数字画面切替 | 最終UIツリーは`a \nq`、英字・数字の実機スクリーンショット確認 |

最終HAPと画面はローカルの`artifacts/phase0/`に保存。最終署名検証は`signature-verification.txt`、入力結果は`final-layout.json`。以前の試作画面`keyboard.png`とモード操作結果`modes-layout.json`は寸法調整前の記録。

## Gboard画像から合わせた寸法

ユーザー提供画像の幅940pxを基準に比率を計測。OSのvpへ変換して端末幅に合わせる。定義を`KeyboardMetrics.ets`にまとめ、パネル高さも同じ定義から算出する。

| 部分 | 基準画像上の寸法 |
| --- | --- |
| 左右余白 | 各11px |
| 横のキー間隔 | 12px |
| 英字キー | 81×110px |
| 英字の縦間隔 | 26px |
| 数字キー | 174×121px |
| 数字の縦間隔 | 16px |
| 英字の操作キー | 通常幅の1.5倍＋間隔の補正 |
| スペース | 英字2キー分＋間隔 |

英字の2段目も1段目と同じキー幅。背景`#E6E7FC`、文字キー白、操作キー`#C8CFF8`。通常キーの角丸6vp、端のモード・Enterキーはピル形。OSが表示する下部の入力方法バーはHarmonyOS側の表示。

現段階は縦画面のPura 70での検証。横画面・タブレット・ダークテーマと、日本語フリック画面は次段階で確認する。

## 実装時に判明した差

Enterは固定値1では複数行の改行が成立しなかった。`InputClient.getEditorAttribute()`の`enterKeyType`を取得して`sendKeyFunction()`へ渡すと、TextAreaの改行とTextInputの検索がそれぞれ成立した。

自動署名の初回取得で規約確認エラーが出たが、DevEco内のRetryで取得成功。追加の規約同意操作は行っていない。デバッグ署名の設定はローカルファイルのみ。

## 操作の再現

```sh
hdc install entry/build/default/outputs/default/entry-default-signed.hap
hdc shell ime -e com.takeruf.harmonynihongo -b
hdc shell ime -s com.takeruf.harmonynihongo
hdc shell aa start -a EntryAbility -b com.takeruf.harmonynihongo
```

検証後は元のIME `io.github.nxn2021max.jpflickkeyboard`へ戻し、現在の選択を`ime -g`で確認した。自作IMEはインストール・基礎モードの有効化を維持。

## 残っている実装

Mozc本体・辞書のOHOSビルドとIME内読み込みは未検証。今回のC++検証はNode-APIの最小モジュールであり、Mozc移植成功の証拠にはならない。フリック認識、かな未確定状態、候補取得・確定を順に接続する。
