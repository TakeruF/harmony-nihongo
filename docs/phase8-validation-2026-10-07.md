# 横画面対応の実装・検証

対象: Huawei Pura70 / HarmonyOS 7、SDK API26、署名済みデバッグ版0.9.0（versionCode100008）。

## 変更

- 画面幅と縦方向の寸法を分離。縦画面のGboard参考の寸法比を保ち、横画面では高さを画面高の55%以内に調整する。
- `display.on('change')`でパネルを再調整する。リサイズ処理を直列化し、破棄済みのパネル・IMEライフサイクルからの更新を捨てる。
- Pura70では横画面のIMEに画面全幅ではなく中央の領域が割り当てられる。実際のUI領域を`onAreaChange`で取得し、その幅と高さに全キーと候補を収める。画面の物理幅だけを使わない。
- 12キー・日本語QWERTY・英字・数字・記号の寸法が共通の計算を使う。候補は横一列を維持し、展開時は4列のスクロール一覧を使う。
- 回転で入力方式を強制変更しない。未確定文字列・候補・選択中の方式を維持する。レイアウト更新時は未完了のタッチを処理し、長押しのタイマーを片付ける。

## 検証方法

`node tools/test-keyboard-metrics.cjs`は縦画面の元寸法との一致、列の総幅、横画面・OSによって制限された領域への縦方向の収まりを検証する。既存の入力コントローラー、かな・ローマ字、長押し、振動の回帰テストも実行する。

`python3 tools/test-landscape-device.py`は実機の完全アクセスモードでアプリ所有の入力欄とシステムIMEを操作する。実機の画面回転、全キーの配置、候補表示と確定、回転途中の未確定文字、候補展開、数字入力を検証する。`EntryAbility`の`validationLandscape` Wantパラメーターは検証用アプリ窓の向きだけを指定し、端末の自動回転設定を変更しない。通常起動には適用しない。

画像・テスト結果・署名検証は`artifacts/phase8/`に保存する。外部アプリ・基礎モードでの横画面テストはこの段階では行っていない。アプリ設定の共有・永続化は引き続きdata-group-idの準備後に対応する。横向きで自動的にQWERTYへ切り替える設定は未導入。

## 最終パッケージ

`artifacts/phase8/HarmonyNihongo-0.9.0-debug.hap`

SHA-256: `34d82b9040f642e66f956bea746079a0654d6d0f93737dcae1462196bc0763c7`

`hap-sign-tool verify-app`でダイジェスト・署名の検証成功。実機へ更新インストールした。

APIの選定はローカルSDKの`@ohos.display.d.ts`、`@ohos.inputMethodEngine.d.ts`、ArkUIの宣言を確認した。[Huawei公式の入力法実装ガイド](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/inputmethod-application-guide)はWeb取得では本文が得られなかったため、実際のSDKと実機の挙動を根拠にした。

実機の横画面・回転テスト14項目すべてPASS。全キーの領域内配置、Mozc候補の一度だけの確定、未確定かなを保持した回転と入力継続、展開候補の確定、数字入力と縦画面への復帰を確認した。`landscape-kana.png`、`landscape-qwerty-candidates.png`、`landscape-expanded.png`、`portrait-return.png`を目視確認した。

最終HAPで縦画面の日本語QWERTY回帰テスト13項目もPASS（横画面と合わせて実機27項目）。未完のローマ字削除、n/nn、文節変換、プレビュー非対応の欄への一度だけの挿入、12キーへの復帰、英字・数字から日本語への切り替えを確認。72キーの実タッチ連続入力は12.775秒、約5.64キー/秒で、`がっこう`12回の48かなが欠落なく反映された。コントローラーのホスト検証と実タッチ速度を混同しない。結果は`artifacts/phase8/portrait-regression/`。
