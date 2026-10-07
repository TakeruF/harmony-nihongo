# 文節の伸縮（2026-10-07）

0.6.0 / versionCode 100005。Mozc固定版60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98。

## 操作

かな入力後に␣で文節変換へ入る。左右キーの短押しは文節移動、左の長押しは選択中の文節を一文字縮める、右の長押しは一文字伸ばす。長押しは450msで一回だけ認識し、先に文節移動を実行しない。通常のかな編集時の左右キーは従来どおり。

候補は一段の帯に表示し、候補を選んで確定キーで全文を確定する。キー寸法・間隔・背景は維持。区切り調整用の追加行やカーソル記号は表示しない。

## 実装

現在の文節長・対象文節・増減をN-API workerへ送り、MozcのResizeSegmentsで現在の区切りを再現してからResizeSegmentで対象を調整する。文節長はUnicodeの文字数で数え、UTF-16のサロゲートペアを二文字に数えない。読み全体の一致をC++とArkTSの両側で確認する。

一文字の文節は縮めず、最後の文節は伸ばさない。対応範囲は現在の読みに対する64文節以下、各文節255文字以下。失敗や空の結果では現在の選択を維持する。

位置と読みが一致する文節では、以前選んだ候補が新しい候補にも存在する場合に選択を保持する。変更された文節では新しい候補を使う。文節移動・取消・入力欄変更・次の文字入力が先に行われた場合、遅れた伸縮結果は適用しない。編集キューはMozcの処理を待たない。

学習では候補の値だけでなく各文節の読みも照合し、同じ全文の別の区切りを学習しない。確定成功後だけ保存する。元のかなへの取消やプレビュー非対応の入力先への対応は維持。

[固定版MozcのConverterInterface](https://github.com/google/mozc/blob/60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98/src/converter/converter_interface.h)と実装を照合した。確定済み文字列の再変換は今回の範囲外。

## 検証

- tools/test-mozc-engine.py: 実際のMozcと同じC++アダプターをmacOSで実行。文節の縮小・拡大、全文の読み保持、調整後の候補の学習、異なる区切りの学習拒否、不正な文節長・最後の文節の拡大拒否。予測・選択学習・プロセス再起動後の保存・文節選択もPASS。
- tools/test-conversion-controller.cjs: Unicode文字数、変わらない文節の選択保持、縮小、フォーカス移動／取消後の遅延結果拒否、最小文節の保護。従来の80文字キュー・確定・プレビュー非対応・送信失敗・入力欄変更もPASS。
- tools/test-cursor-hold.cjs: 短押し、長押しで一度だけ伸縮、余分な移動なし、キャンセル、複数タッチ、後片付け。
- tools/test-kana.cjs、tools/test-haptics.cjs、tools/test-native.py: PASS。

ビルド・署名・実機の確認結果は後述。

## ビルド・実機の状態

DevEco BUILD SUCCESSFUL、hap-sign-tool verify-app成功、Pura 70への更新インストール成功。署名済みHAP: artifacts/phase5/HarmonyNihongo-0.6.0-debug.hap。SHA256: eb080dffdc17be49b9548025f973f6eb22d0d2d90a3c35b0ff8862e79ace7029。

実機の画面はロックされており、アプリの入力欄を取得できなかったため、長押しの実機テストは入力操作を始める前に停止した（artifacts/phase5/device-status.json）。ホストでのMozc・入力制御・ジェスチャー試験を、0.6.0の実機操作成功とは扱わない。

ロック解除後は tools/test-resize-device.py で短押し／長押し、ほかの文節の選択保持、伸縮後の一度だけの全文確定、学習、次のかな、元のかなへの取消を検証できる。候補UIツリーで操作対象を選ぶため、この実機テストはFULL_EXPERIENCE_MODEを前提にする。端末のモードをテストから変更しない。

## ロック解除後の実機確認

後続の再変換実装中に端末が利用可能になり、0.6.0をインストールした状態でtools/test-resize-device.pyを実行した。Pura 70 / FULL_EXPERIENCE_MODEで5項目PASS。短押し・長押し、文節縮小・拡大、他の文節の選択保持、全文の一度だけの確定、学習保存、次のかな、取消による元のかな復元を確認した。記録はartifacts/phase5/device-results.json、device-status.json、shrink-ime.png。
