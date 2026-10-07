# 文節ごとの候補選択（2026-10-07）

0.5.0 / versionCode 100004。Mozcは前段階と同じ60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98。

## 操作

| 操作 | 動作 |
| --- | --- |
| かな入力中の␣キー | Mozcで文節に分割し、変換した全文を未確定表示 |
| 左右キー | 選択する文節を移動。候補帯はその文節の候補を表示 |
| 候補タップ | 選択中の文節だけ置換。ほかの文節の選択を保持 |
| 確定キー | 選択した文節をつないで一度だけ全文を確定 |
| 変換中の取消／削除 | 元のかなに戻す。次の削除で一文字削除 |
| 変換中の次のかな入力 | 変換した文章を確定してから、新しいかな入力を開始 |

通常の候補を直接タップして全文確定する既存の操作も維持。候補帯は一段で、文節の選択中の候補は青で表示。キー寸法・間隔・背景は前段階と同じ。候補の展開は右端の矢印で開く。

## 実装

C++のStartConversionから文節ごとの読み・候補を取得。ArkTSのSegmentCompositionは元のかなと各文節の選択を分けて保持し、全文を組み立てる。文節の読みを結合して元の入力に一致しない結果は採用しない。

文節取得はN-API workerへ送り、編集キューで待たない。取得開始時のrevisionと入力先の世代を検査し、入力が進んだ後／入力欄変更後の結果を捨てる。候補UIにも表示時のcontextを保持し、左右移動前の古い候補クリックを拒否する。

正常に全文を確定した後だけ、元のSegmentsに対応する選択をすべて検証してCommitSegmentValue、FinishConversion、Sync/Waitを実行する。通常テキストと汎用入力欄（PATTERN_TEXT=0、PATTERN_NULL=-1）で学習する。パスワードなどの別属性／取得失敗・未知の属性ではincognito modeを使い、学習しない。プレビュー非対応の入力欄では確定まで送信せず、失敗した送信では文節選択を保持する。

Mozcの対応APIは[固定版のConverterInterface](https://github.com/google/mozc/blob/60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98/src/converter/converter_interface.h)を確認した。現段階は自動分割した文節の選択に対応し、境界の伸縮・再変換・前文脈からの次語予測は未実装。

## 検証

- tools/test-conversion-controller.cjs: 文節の複数選択を保持、一度だけの全文確定、左右移動前の候補context拒否、取消・削除による復帰、次のかな、プレビュー非対応、送信失敗時の選択保持、遅延結果と入力欄変更。従来の高速入力・学習のテストもPASS。
- tools/test-mozc-engine.py: 同じC++アダプターと実際のMozcをmacOSで実行。「わたしは／はしを／わたる」の分割と複数文節の選択・学習、不正候補／文節数不一致の拒否を検証。予測・下位候補学習・別プロセスでの学習保存もPASS。生成物はartifacts/phase4。
- tools/test-kana.cjs、tools/test-haptics.cjs、tools/test-native.py: PASS。

ビルド・署名・実機の確認結果は後述。

実機でアプリの通常TextAreaがPATTERN_NULL（-1）を返すことを確認。段階3ではPATTERN_TEXTのみ許可していたため、この一般入力欄で学習が無効になっていた。段階4で公式に定義された汎用入力欄も許可し、パスワード属性・未知の属性・取得失敗は除外する。定数の意味は[公式OpenHarmony IME API](https://github.com/openharmony/docs/blob/master/en/application-dev/reference/apis-ime-kit/js-apis-inputmethodengine.md#constants)も照合した。

## 実機の結果

DevEco BUILD SUCCESSFUL、hap-sign-tool verify-app成功、Pura 70への更新インストール成功。署名済みHAPはartifacts/phase4/HarmonyNihongo-0.5.0-debug.hap。SHA256: 8e57877467ac471caee5299d703fea69548c5a8cc1e5cbb271fd449a4bfac875。

Pura 70 / HarmonyOS 7.0.0.109 / API26、縦画面、FULL_EXPERIENCE_MODEで10項目PASS（artifacts/phase4/device-results.json）。IMEの表示内容をスクリーンショットとUIツリーで照合し、実際のフリック・候補タップ・左右キーで操作した。

- 「わたしは／はしを／わたる」から「わたしは／箸を／渡る」を個別選択し、全文を一度だけ確定。続けて「あ」が欠けずに入力される。
- 取消で元のかなへ戻り、再度の取消で消える。
- プレビュー非対応の入力欄では確定まで空欄。確定後に全文が一度だけ送られ、検索アクションは発火しない。
- 「にほ」から予測候補「日本」をタップで確定。
- MOZC_LEARNING saved=1を確認。アプリ／IMEプロセスを再起動して同じかなを変換すると、選択済みの「わたしは箸を渡る」が最初に表示される。

最終UIはartifacts/phase4/segments-final-ime.png。従来のキー寸法・間隔と一段の候補帯を維持し、追加の未確定行やカーソル記号は表示していない。今回は完全アクセスモードで検証し、段階4の基礎モード・他社アプリ・横画面・パスワード入力欄の実機再検証は行っていない。
