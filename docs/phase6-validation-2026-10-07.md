# 選択文字の再変換（2026-10-07）

0.7.0 / versionCode 100006。Mozc固定版60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98。

## 操作

確定済みの文字を入力欄で選択すると、キーボード左上の取消キーが「再変換」に変わる。再変換を押すとMozcで読みを取得し、文節候補を表示する。候補を選んで確定キーで選択した範囲だけを置き換える。取消または削除では元の文字へ戻す。

一段の候補帯とキー寸法・間隔は維持。未確定中のかな入力・文節選択・左右長押しの区切り調整も従来どおり。

## 実装

InputClientには選択文字を直接取得する関数がないため、selectByRangeSyncで一時的に選択範囲の末尾へカーソルを置き、getForwardSyncで指定長の文字を読み、finallyで元の選択範囲へ戻す。読み取り時に本文は変更しない。自分の選択操作による通知と外部の選択変更を扱い分け、選択範囲の現状も確認する。

MozcのStartReverseConversionで読みを求めてから、既存の文節変換へ渡す。処理はworker上で行い、編集キューを待たせない。入力先の世代・入力revision・選択epoch・範囲を検査し、プレビュー適用前に元の選択文字を再び照合する。

プレビュー対応の入力欄では選択を保持した状態でデフォルト範囲（-1, -1）を指定してsetPreviewTextを呼び、後続の候補選択はそのプレビュー内を更新する。取消では元の文字をプレビューへ戻して終了する。非対応の入力欄では元の文字を残したまま候補を保持し、確定時に再照合して選択範囲へのinsertTextで置き換える。先に元の文字を削除する処理は行わない。

対象は通常・汎用の入力属性、選択範囲1〜128 UTF-16単位、得られた読み256単位以下。読みが取得できない／APIが失敗する／選択文字が変わった場合は置き換えない。逆変換の読みは辞書による推定なので、語の読みを一意に決められるとは限らない。端末や入力先が提供する選択通知・プレビューに依存する。

SDK26の宣言と[公式IME API](https://github.com/openharmony/docs/blob/master/en/application-dev/reference/apis-ime-kit/js-apis-inputmethodengine.md)、[固定版Mozc](https://github.com/google/mozc/blob/60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98/src/converter/converter_interface.h)を照合した。

## 検証

- tools/test-mozc-engine.py: 実際のMozcで「橋」→「はし」を取得し、「箸」が候補に含まれることを確認。予測、学習保存、文節選択・区切り調整もPASS。記録はartifacts/phase6。
- tools/test-conversion-controller.cjs: 「前橋後」の選択部分「橋」だけを「箸」へ変更。前後を保持し、一度だけ確定。取消で原文復元。非対応プレビューで確定まで原文保持、送信失敗時の選択保持。読み取り失敗・選択／本文／入力先変更時に置き換えない。従来の入力・文節・長押し関連もPASS。
- tools/test-cursor-hold.cjs、tools/test-kana.cjs、tools/test-native.py: PASS。

ビルド・署名・実機の結果は後述。

実機の選択中TextAreaでは絶対範囲を指定した初回プレビューが401で拒否された。ArkUIの[プレビュー実装](https://github.com/openharmony/arkui_ace_engine/blob/master/frameworks/core/components_ng/pattern/text_field/text_field_pattern.cpp)では選択中は選択範囲を置き換えるため、選択を保持してデフォルト範囲を使うよう修正した。これは実機での挙動を優先した対応。

## ビルド・実機の結果

DevEco BUILD SUCCESSFUL、hap-sign-tool verify-app成功、Pura 70への最終版更新インストール成功。署名済みHAP: artifacts/phase6/HarmonyNihongo-0.7.0-debug.hap。SHA256: 6878bda7b84a4171e94bfb55750dcfeff2efe0c00ebdd9d690e57f2b5b2b837a。

Pura 70 / HarmonyOS 7.0.0.109 / API26 / FULL_EXPERIENCE_MODE / 縦画面で10項目PASS（artifacts/phase6/device-results.json）。実際のフリック・漢字候補選択で「前　橋　後」を入力し、長押しで「橋」だけを選択して再変換した。

- 選択時に「再変換」キーが表示され、候補を取得できる。
- 「箸」へ変更しても前後の「前」「後」と空白が残る。取消で「橋」に復元できる。
- 確定後の全文は「前　箸　後」で重複しない。次の「あ」も入力できる。
- プレビュー非対応の単行入力では確定まで元の「橋」を残す。取消では変更せず、確定で選択した「橋」だけを「箸」に置き換える。
- 再変換の確定では検索アクションを送らない。

最新UIはartifacts/phase6/reconversion-ime.png（候補選択中）。selected-ime.pngは再変換キーが表示された選択状態。初回失敗のreconvert-preview.pngは修正前の記録として区別する。今回はアプリ自身の二種類の入力欄で確認し、他社アプリ・基礎モード・横画面・異常な入力先の実機検証は行っていない。
