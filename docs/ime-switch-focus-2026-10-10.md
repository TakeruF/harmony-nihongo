# 他の入力法から切り替えた際のフォーカス維持

Huawei Pura 70（ADY-AL10、HarmonyOS 7.0.0.109）に更新インストールし、ChatGPTで報告された症状を再現した。今回のキーボード側の修正だけでは未解消。ネイティブ入力欄では縦横とも切り替え後に再タップせず入力できるが、ChatGPTでは再タップが必要。

`ImeController`の`inputStop`と`keyboardHide`は、通知を受けるたびに`Panel.hide()`を呼んでいた。OpenHarmonyの[InputMethodAbility実装](https://github.com/openharmony/inputmethod_imf/blob/master/frameworks/native/inputmethod_ability/src/input_method_ability.cpp)では、アプリからの`HidePanel`は`Trigger::IME_APP`として扱われ、`NotifyPanelStatusInfo`から`HideKeyboardSelf()`へ伝わる。終了中の入力法については、入力欄のフォーカスを失わせるため非表示処理を避けるというコメントもある。この追加の入力終了要求を除く修正を行ったが、実機ではそれだけで症状は解消しなかった。

修正では、この2つの通知はセッション・表示状態の更新のみを行い、パネルの非表示はフレームワークに任せた。明示的にキーボードを閉じる操作は、引き続き`KeyboardController.hide()`を呼ぶ。

また、`inputStart`は入力欄への接続であり、表示要求とは区別した。`keyboardShow`を受け、入力欄が接続され、パネルが準備できた場合にだけ表示する。非同期のパネル作成が終わる前に非表示・接続終了・Ability終了が起きても、古いパネルを表示しない。入力欄の属性は表示通知より先に取得されても保持し、検索・数字などのキーを正しく準備する。

検証結果：

- 修正前に追加したホストテストは、接続終了時に追加の非表示要求が発生して失敗した。
- 修正後の通知順序・遅延したパネル準備・接続終了・明示的な閉じる操作の回帰テストは成功した。
- `tools/test-*.cjs`全14本が成功した。
- `python3 tools/build.py`でDebug HAPを生成し、`hap-sign-tool verify-app`の署名・ダイジェスト検証が成功した。
- HAP内部の`module.json`と端末の`bm dump`で、実際のバージョンは`0.14.1` / `100015`と確認した。当初の生成物名・記録の`0.13.0`表記は古い値だったため訂正。署名済みHAPと検証記録は[artifacts/ime-switch-focus-2026-10-10](../artifacts/ime-switch-focus-2026-10-10)に保存。
- HDCポート8710で接続を確認し、署名済みHAPの更新インストールに成功。インストール時刻の更新と`FULL_EXPERIENCE_MODE`を確認した。
- ネイティブのアプリ所有テスト欄で、Huawei入力法からの切り替え後にフォーカスを維持し、再タップなしの「あ」の入力と削除に成功。縦・横の計6チェックを実施し、最後に空欄・縦画面へ戻した。
- ChatGPTの空欄でシステムの地球儀長押しからHarmony Nihongoを選択。再タップせず入力した場合は入力欄へ届かず、再タップ後の通常入力では「あ」が表示された。送信は行わず、試験文字は削除済み。
- 別のサードパーティ入力法との比較は、途中でその入力法が有効な一覧から消えたため完了していない。その他のAndroid互換アプリとChatGPTの横画面は未検証。

端末ログの17:33:45の切り替えでは、入力法サービスがAndroid互換ブリッジのPID 8824について`IsFocused ... is not focused`と`StopClientInput`を出した後、当キーボードのプロセスが起動した。新しい接続の`StartInputInner`は`showKeyboard:0`となり、`EDITOR_ATTACHED`より前に入力接続が終了している。これはキーボード側の表示処理だけでは防げない、OSの入力法切り替えとAndroid互換ブリッジの間の問題を示唆する。OS内部の根本原因や、すべての互換アプリへの影響は断定していない。

時系列は`chatgpt-switch-timeline.txt`、フィルタ済みログは`live-switch.log`、入力欄への反映・再タップ後の反映は`chatgpt-*.jpeg`、ネイティブ試験は`native-switch-results.json`に保存。ローカルSDKの公開`KeyboardController`/`InputClient`には他アプリの入力欄を再フォーカスするAPIが見当たらず、現時点で公開IME APIだけによる復旧方法は確認できていない。実用上の回避は切り替え後に入力欄を一度タップすること。

外部入力欄がアクセシビリティツリーに公開される環境では、空の入力欄を他の入力法で開き、システムの入力法選択からHarmony Nihongoへ切り替え、次のコマンドで再タップせず確認できる。今回のChatGPTはツリーに入力欄を公開しなかったため、このスクリプトの合格結果は得ていない。画面と端末ログによる検証を実施した。スクリプトは送信せず試験文字だけを削除し、フォーカスが失われていた場合は再タップせず失敗する。

```sh
HDC_SERVER_PORT=8710 python3 tools/test-external-editor-device.py \
  --name chatgpt-switch-focus --after-ime-switch --live-preview --basic
```

通常の入力開始、他入力法への戻り、縦横回転、複数回の往復切り替えも確認する。既存のユーザー入力や下書きがある欄では実行しない。
