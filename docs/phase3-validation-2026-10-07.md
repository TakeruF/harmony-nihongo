# 予測変換・選択学習（2026-10-07）

0.4.0 / versionCode 100003。Mozcは段階2と同じ60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98。

かなを直接Composerへ渡し、全文変換に加えてStartPredictionを呼ぶ。最良の全文変換を先頭に残し、上位の補完候補を近くに並べる。部分読みだけを消費する候補は除外する。一段の候補帯と展開表示、キー寸法は維持。

候補ごとに生成時のSegmentsと選択インデックスを保持する（直近4回）。入力先への確定に成功してからCommitSegmentValue、FinishConversion、Engine::Sync/Waitを呼び、IME自身のfilesDirへ保存する。変換・保存はN-APIのworker上で直列化し、ArkTSの編集キューは保存を待たない。入力欄変更・読みに変更がある古い候補は従来の世代・revision検査で拒否する。

入力属性がPATTERN_TEXTと確認できた場合に選択学習を有効にする。それ以外／属性取得失敗時はMozcのincognito modeを使用し、選択学習を呼ばない。生かなの確定、取消、失敗した入力送信も学習しない。学習管理画面・履歴消去・文節編集・再変換・前文脈からの次語予測は未実装。

## 検証

- tools/test-conversion-controller.cjs: 80文字の編集キュー、遅れた候補・古い候補クリックの拒否、プレビューと非対応入力先への一度だけの確定、送信失敗時のかな保持、確定成功後だけの学習、private mode／生かな確定時の非学習。
- tools/test-kana.cjs、tools/test-native.py、tools/test-haptics.cjs: PASS。
- tools/test-mozc-engine.py: 実際の同一Mozc C++アダプターをmacOSで実行。private queryでは学習対象を保持せず、不正な候補の学習を拒否することも確認。隔離した一時プロファイルを使い、予測・学習による順位変化・別プロセスでの永続化を検証。記録はartifacts/phase3。
- Pura 70のshellから追加実行ファイルを実行する試験はPermission deniedとなったため、Mozc単体試験を実機の成功とは扱わない。

ビルド・署名・インストール、IMEとの実機接続については後述の記録を参照。

## ビルド・実機の状態

DevEcoの最終BUILD SUCCESSFUL、hap-sign-tool verify-app成功、Pura 70への更新インストール成功。署名済みHAPはartifacts/phase3/HarmonyNihongo-0.4.0-debug.hap。SHA256: f42beada6c9ecc51a0d204fd7383b35dc7fcb4cc37371b12b36ac2a38aad3128。

最終のIME経由の予測・学習テストは端末がロックされており、アプリの入力欄を取得できず停止した。prediction-ime.pngはロック画面の記録。これはIMEの失敗を示す結果ではなく、今回の実機接続テストは未完了。段階2でのIME変換の実機成功とは区別する。

ホストの学習試験では「はし」の「箸」は初期候補番号6。選択後は先頭へ上がり、別プロセスでも候補番号0を保持した。予測試験の「にほ」は「日本」「日本人」「日本語」などを含む。いずれも実際のMozc出力で、候補を固定したモックではない。

## 段階4での後続確認

0.5.0でIME経由の予測候補確定と学習の保存・再起動後の反映を実機確認した。通常のTextAreaは汎用属性PATTERN_NULL（-1）を返すため、段階3のPATTERN_TEXTだけを許可する判定では学習しなかった。0.5.0で汎用入力欄も対象にした。詳細は[文節変換と実機検証](phase4-validation-2026-10-07.md)。この後続確認を0.4.0の実機成功としては扱わない。
