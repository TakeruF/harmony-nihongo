# Mozc変換の実装と検証

2026-10-07。Pura 70（ADY-AL10）/ HarmonyOS `7.0.0.109(SP6C00E105R5P2)`、API 26、IME **BASIC_MODE**。アプリ0.3.0 / versionCode 100002。

## 実装

Google Mozc固定コミット `60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98` を使用する。辞書候補を手書きした実装ではない。

- ホスト上のBazel 9でOSS辞書 `mozc.data` を生成。DevEco NativeのOHOS Clang 15、musl、libc++でARM64ライブラリをクロスコンパイル。Android NDK/JNIは使わない。
- Clang 15向けに、集成体の括弧初期化を波括弧へ変更し、ラムダが捕捉する構造化束縛を通常の変数へ変更。変換アルゴリズムは変更しない。再現手順は `tools/build-mozc.py` に集約。
- 同梱辞書をIME自身のfilesDirへ原子的に展開。アプリ設定の共有領域とは別で、data-group-id承認は変換機能の前提ではない。
- `DataManager::CreateFromFile` → `Engine::CreateEngine` → `Engine::GetConverter` → `StartConversion`。読みを `ConversionRequestBuilder.SetKey` に直接渡す。
- 文節ごとの候補を、他文節の最上位候補と結合して全文候補を作る。最大40候補。部分文節だけを全文として確定しない。全文候補を保存し、入力先と読みの世代を照合して選択する。SessionCommandの候補IDを表示インデックスで代用しない。
- Native処理はNode-API async workで実行。40msの待機でまとめ、同時変換は1件。入力・プレビューの直列キューは変換完了を待たない。入力変更/入力先変更/IME停止後に届いた候補は破棄。
- 候補帯は既存の高さの横1列。最上位漢字候補、未確定かな、他候補を横スクロール。下矢印/空白キーでキー領域を候補一覧へ切替。背景色は既存のキーボードと共通。参照画像に合わせて縦の区切り線と4列を基本とする行配置を使い、長い候補は複数列を使う。候補をタップすると全文確定。
- プレビュー対応の入力先は `setPreviewText(選択文字列)` + `finishTextPreview()`。非対応なら `insertText(選択文字列)` を1度送る。失敗した場合は未確定かなを保持する。
- Mozc、OSS辞書、Abseil、protobuf、utf8_range、zlib、Japanese Usage Dictionaryの必要な通知を `resources/rawfile/third-party-notices.txt` に同梱。

## 検証

ビルド成功だけで実機対応とは判断せず、IMEの基礎モードで辞書の展開・読み込み、C++エンジン起動と候補の確定を確認する。

- ホスト: 既存のかな/フリック/設定ロジックとNativeプローブが成功。
- 入力制御: 本番Controllerを実行し、80文字のキュー、遅い変換結果の破棄、古い候補タップの拒否、プレビュー/非対応欄での確定、確定失敗時の読みの保持、入力先世代の破棄が成功。`tools/test-conversion-controller.cjs`。
- 実機: `tools/test-mozc-device.py` は実際のフリック操作から候補タップまで検証。結果を `artifacts/phase2/conversion-results.json`、画面を `candidates.png` / `expanded.png` に保存。
- HAPにはOHOS AArch64の `libnihongo.so`、`libnihongo_engine.so` と辞書が同梱。Nativeの依存先はライブラリ名で、開発端末の絶対パスではない。

署名済みHAP: `artifacts/phase2/HarmonyNihongo-0.3.0-debug.hap`。公式hap-sign-toolのSHA-256検証とverify-appに成功し、実機へインストール済み。

HAP SHA-256: `9f90ee2c545d58c73cbaa953acda4a456f5f4b11a5a3620c3ac4ebf3c2742777`。

実機の候補確定は「きょうは→今日は」「がっこう→学校」「にほんご→日本語」が成功。非対応入力欄での一度だけの確定、候補確定と検索の分離、候補一覧の確定、別入力欄への古い候補の混入防止も成功。結果は17項目。

80回の連続タッチ注入で全かなが保持され、一度だけ確定できた。HDC/uinputの押下・離脱間隔10ms、プロセス起動等を含む全体12.68秒（約6.3回/秒）。80文字を10msごとに渡すホストのキューテストとは別の証拠。

最後に候補一覧を参照画像の行・区切り線・背景共通化へ調整した後、候補帯/一覧を画面確認し、一覧から「今日は」を確定できた。続くかな入力の最終再確認は端末の手動操作と重なり、結果を確定しない。直前の17項目では続け入力・候補帯での確定は成功している。`final-ui-results.json`。

## 今回の範囲と残る確認

通常のかな→漢字の全文変換。選択後の学習、入力途中の予測、文節の手動調整、再変換は未実装。現在はMozcのConverter直接接続で、今後のSessionHandler統合とは区別する。

この記録の入力先はアプリ所有のTextAreaとプレビューを無効にしたTextInput。他アプリ/Web入力欄、横画面・タブレット、パスワード属性、辞書破損時の実機復旧、メモリ/変換時間の包括的測定は未検証。ホストの80文字キューは、実際に指で毎秒100回タップした証拠ではない。

設定共有の承認は引き続き未取得。標準設定で変換できるが、アプリの設定変更をIMEへ反映する機能はまだ有効化していない。

## 候補帯の表示修正

上部の「あ / ABC / 123 / #+=」切替を削除。かな候補は読みそのものを表示し、カーソル記号 `│` を付けない。モード切替はキー領域の既存キーから操作する。候補帯の高さとキー位置は維持。再ビルド・実機インストール成功。修正版HAPは `artifacts/ui-cleanup/HarmonyNihongo-0.3.0-debug.hap`。
