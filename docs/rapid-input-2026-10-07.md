# 連続入力の取りこぼし修正

Pura 70 / HarmonyOS 7.0.0.109で2026-10-07に検証。

## 修正

文字キーと操作キーを、クリック認識完了時の送信からTouchType.Down時の送信へ変更。changedTouchesを扱い、次の指が前の指の離脱を待たずに入力できる。Touch/Mouse由来の後続onClickは入力しない。キーボード・アクセシビリティ由来のクリック経路は維持。

見た目のキー寸法・間隔は維持し、タッチ判定を隙間の中央まで拡張。入力先への送信は既存の直列キューを使い、文字の順序と入力先の世代チェックを維持する。

この変更で入力は押した時点で確定するため、押してから指を滑らせても元のキーを入力する。日本語フリックを追加するときは、かなキー用の指ID・移動・離脱による認識を別途実装する。

APIは手元のAPI26 SDKのTouchEvent、ClickEvent、SourceType、responseRegion定義を確認。公式参照：[タッチイベント](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-events-touch)、[クリックイベント](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-events-click)。

## 実機検証

| テスト | 修正前 | 修正後 |
| --- | --- | --- |
| 中央の短いタップ60回 | 60/60 | 60/60 |
| 隙間へのタッチ10回 | 0/10 | 10/10 |
| 押下から離脱まで横にずれる操作10回 | 0/10 | 10/10 |
| 実際のInputClientへ10ms間隔で80文字 | 未実施 | 80/80、順序一致 |

タッチ試験はuinputで押下時間20msのイベントを注入。コマンド自身の待ち時間を含め全80操作は約18秒かかっており、これは毎秒100タップの試験ではない。入力送信の10ms試験は一時的なQA用タイマーから同じimeController.insertを呼び、実際のIMEプロセスと入力欄で80文字の完全一致を確認した。QA処理は最終ソースと端末へ入れるHAPから除去。

実際の人による両手の高速タイピングとアクセシビリティ操作は、この自動試験では未検証。今回、隙間と移動による欠落を再現し、その改善を確認した。

数値と文字列の証拠はローカル`artifacts/rapid-input/{before,after,burst}.json`。タッチ試験の再実行は、Pura 70を縦向きにし、Harmony Nihongoを選択してから`python3 tools/test-rapid-input.py`。このスクリプトは自作アプリのテスト入力欄をリセットする。
