# HarmonyOS日本語IMEの技術調査

調査日: 2026-10-07（Asia/Tokyo）

2026-10-07追記：段階0の実装・署名・基礎モードのIME内Native呼び出しを実機確認した。詳細は[実機検証記録](phase0-validation-2026-10-07.md)。その後、段階2でMozcのOHOS ARM64ビルド、IME基礎モードの辞書読み込み・漢字変換を確認した。[段階2の実装と証拠](phase2-validation-2026-10-07.md)。以下の本文は当初の調査記録で、未検証という記載は調査時点の状態。

## 結論と証拠の範囲

第三者IME用の公開APIは存在する。ArkTSのIME拡張と、同じプロセス内に組み込むMozc C++エンジンを組み合わせる構成を採用候補とする。

**基礎モードの第三者IMEから最小の独自ネイティブモジュールを呼べることは実機確認済み。MozcのHarmonyOS向けビルドと辞書読み込みは未検証。** 一般的なNode-APIの提供を、IME拡張の全モードでの実行保証に読み替えない。

| 項目 | 今回確認したこと | 残る検証 |
| --- | --- | --- |
| 第三者IME | 公式APIで実装し、署名済みHAPをPura 70で有効化・呼び出し成功 | 他の端末・OS・入力先での互換性 |
| 未確定文字 | API 12以降にプレビューAPI。非対応の入力先もある | ArkUI・Web・他社アプリでの置換、確定、取消 |
| ArkTS/C++ | IME基礎モードで独自.soとC++ランタイムを読み込み、計算・かなUTF-8往復成功 | Mozcの依存ライブラリ・辞書読み込み |
| Mozc | 現行ソースにプロセス内SessionHandlerとかな列置換コマンド | OHOS ABI向け移植、辞書生成、変換結果 |
| 学習保存 | IME独立サンドボックスは基礎モードでも読み書き可能 | 再起動後の永続化、削除、エンジンの保存先設定 |
| 配布 | IME登録手順と共有サンドボックス申請手順を確認 | このアプリのAGC署名・現行審査条件・配布可否 |

APIがあること、コンパイルできること、実機で動くこと、公開審査が通ることは別の検証とする。

## 調査対象と開発環境

- 検証端末: HUAWEI Pura 70。調査開始時は未接続だったが、ユーザーが接続した後にHDCで以下を確認した。

| 端末パラメータ | 実測値 |
| --- | --- |
| `const.product.model` | `ADY-AL10` |
| `const.product.software.version` | `ADY-AL10 7.0.0.109(SP6C00E105R5P2)` |
| `const.ohos.apiversion` | `26` |
| `const.ohos.fullname` | `OpenHarmony-7.0.0.105` |
| `const.product.cpu.abilist` | `arm64-v8a` |
| `const.ohos.releasetype` | `Release` |

端末内部の`fullname`表記と製品OSのバージョン表示は別々に記録する。`Release`という端末パラメータだけで一般公開状況を断定しない。

- 対象: HuaweiのネイティブHarmonyOSアプリとStageモデル。AndroidのInputMethodService/JNIや古いJava/FAモデルを実装の出発点にしない。
- 手元のSDK: `/Applications/DevEco-Studio.app/Contents/sdk/default`。
- `sdk-pkg.json`: API 26、SDK `26.0.0.23`、`Beta1`。これはローカル環境の状態で、2026-10-07時点の最新安定版という意味ではない。
- HuaweiのHarmonyOS 7 Developer Beta1告知ではAPI 26と説明される。その初期招募の対応機種一覧にPura 70は載っていないが、今回接続されたPura 70では上記ビルドとAPI 26を実測できた。過去の招募一覧だけで現在の端末対応を判断しない。[公式告知](https://developer.huawei.com/consumer/cn/activity/developerbeta/harmonyos-developer-beta-7-1)
- リポジトリは初期状態で、アプリソースとコミットはまだなかった。

## 第三者IMEの実装経路

公式APIリファレンスは`@ohos.inputMethodEngine`を、システムIMEと第三者IMEの両方に向けたサービス側APIと説明している。入力欄を利用する一般アプリ側の`inputMethod.getController()`と混同しない。[APIリファレンス](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-inputmethodengine)

基本経路:

1. `@kit.IMEKit`から`InputMethodExtensionAbility`と`inputMethodEngine`をインポート。
2. `InputMethodExtensionAbility`を継承し、作成・破棄時の処理を実装。
3. `module.json5`の`extensionAbilities`で`type: "inputMethod"`と`exported: true`を設定。
4. メタデータ`ohos.extension.input_method`から`$profile:input_method_config`を参照し、入力法のサブタイプを定義。
5. `getInputMethodAbility()`で能力オブジェクトを取得し、`inputStart`で`InputClient`と`KeyboardController`を取得。
6. `createPanel(context, { type: SOFT_KEYBOARD, flag: FLG_FIXED })`と`setUiContent()`でArkUIページを表示。
7. `inputStop`・破棄時にクライアント参照、イベント、パネル、変換セッションを整理。

公式手順は上記の構成を示す。キーボードを通常アプリの画面だけに表示するデモでは、システムIMEとして動くことの検証にならない。[実装ガイド](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/inputmethod-application-guide)

| 操作 | InputClient API | 注意 |
| --- | --- | --- |
| 確定文字送信 | `insertText(text)` | 返却値・例外を処理する |
| Backspace | `deleteForward(length)` | このAPIではカーソル前を削除する |
| Delete | `deleteBackward(length)` | このAPIではカーソル後を削除する |
| Enterの送信 | `sendKeyFunction(editorAttribute.enterKeyType)` | 検索・送信・改行など入力欄の意味と合わせる |
| カーソル前後の取得 | `getForward` / `getBackward` | カーソル前/後。取得失敗も扱う |
| 未確定文字置換 | `setPreviewText(text, range)` | API 12以降、入力先の対応が必要 |
| プレビューの確定 | `finishTextPreview()` | 同じ文字をさらにinsertTextすると重複し得る |

削除方向は名前の印象ではなく公式の定義に従う。[APIリファレンス](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-inputmethodengine)

## 基礎モードと保存先

公式の安全モード資料で確認した制約:

- 基礎モードでは、ネットワーク・マイク・クリップボード等の機能や外部へのデータ送出が制限される。
- 他のUIAbility/ExtensionAbilityの起動を前提にしない。実装ガイドは子プロセス作成・IPCへの管控も説明する。
- IMEの独立サンドボックスは読み書き可能。メインアプリとは独立している。
- 共有サンドボックスは基礎モードではIME側から読み取りのみ、完整体验模式では読み書き可能。
- 共有する場合はAGCの「输入法应用内数据共享」を申請し、発行された`data-group-id`をprofileとIMEの`dataGroupIds`に設定する。
- 安全モードは`InputMethodAbility.getSecurityMode()`で取得し、`securityModeChange`も扱う。

したがって、**変換エンジンはIMEプロセス内で完結させる**。デスクトップ版の`mozc_server`を別プロセスで起動する方式を採用しない。固定辞書を同梱し、学習はIME独立サンドボックスへ保存する方針。設定UIからの学習履歴管理・個人辞書共有には、この境界の設計が別途必要になる。[安全モード](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ime-kit-security)、[実装ガイドの制約](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/inputmethod-application-guide)

音声・クリップボード・振動などは単に「後で追加」ではなく、安全モードと権限条件に応じた機能になる。まず基本入力とオフライン変換を成立させる。

## 未確定文字と確定処理

`EditorAttribute.isTextPreviewSupported`で対応を判定し、実際のエラー`12800011`（text preview not supported）にも備える。

対応する入力先では、次の操作を順番に実行する設計とする:

```text
かな編集 → setPreviewText("きょうは", { start: -1, end: -1 })
候補選択 → setPreviewText("今日は", { start: -1, end: -1 })
確定     → finishTextPreview()
```

非対応なら、未確定かなはIME内に表示し、候補の確定時にだけ`insertText("今日は")`を送る。対応経路と非対応経路で二重挿入を起こさない。取消はプレビューを空文字に置き換える経路を含め、入力先別に検証する。[APIリファレンス](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-inputmethodengine)

公式FAQは2026-06-26時点で未確定文字への下線表示を未対応と説明している。MVPで下線を必須にしない。HarmonyOS 7の対象ビルドで再確認する。[プレビューFAQ](https://developer.huawei.com/consumer/cn/doc/doccenter-dev-faq/faqs-ime-7)

確定済み文書全体の正本は入力先アプリ。Input Controllerには未確定かな、ローカルカーソル、変換状態、限定的な周辺文脈を保持する。確定済み文書のコピーを独自に更新し続ける設計は、外部編集との不整合を起こすため避ける。

## ArkTSとC++の接続

HuaweiのNode-APIは、ArkTSからNativeモジュールをimportし、`.so`とその依存を読み込み、登録されたC/C++メソッドを呼ぶ仕組みを提供する。Node.jsサーバーを起動する意味ではない。[Node-API概要](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/napi-introduction)

候補は`libnihongo.so`という独自Node-APIモジュール。内部にMozcコアをリンクし、UIからprotobufやMozc固有型を隠す。

ただし、公式FAQにはExtensionによるモジュールのblocklistや、restricted workerでの.so読み込み制限が記載されている。最小の独自モジュールは実機の基礎モードで動いたが、これがMozcの各依存モジュールに適用されるかは未確認。**通常のUIAbilityで.soが動いた証拠だけでIME対応としない。** 基礎モードのIME内で小さな関数を呼び、依存.soと辞書読み込みまで段階的に確認する。[Node-API FAQ](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/napi-faq-about-common-basic)

最初のネイティブ検証は整数加算、UTF-8かな往復、ファイル読み取り。変換はUIスレッドを止めない実行方式を検証し、同一セッションへの操作を直列化する。`napi_env`/`napi_value`を別スレッドに直接持ち出さない。[Node-API規約](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/napi-guidelines)

## Mozcの移植

確認したコミット: `60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98`（コミット日時2026-10-06 JST）。今後の移植はこのようにSHAを固定し、masterの更新で再現性を失わないようにする。

### プロセス内エンジン

現行Android JNIコードは、`DataManager::CreateFromFile()` → `Engine::CreateEngine()` → `SessionHandler`という構成で、`EvalCommand()`を呼ぶ。HarmonyOSではこのC++構造を参考にし、JNIをNode-APIラッパーに置き換える。Android用バイナリを流用せず、HarmonyOS NDKのABI・libc・C++ランタイム向けにビルドする。[Android側コード](https://github.com/google/mozc/blob/60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98/src/android/jni/mozcjni.cc)

### かな列入力

現行`commands.proto`には`UPDATE_COMPOSITION`が存在する。`CompositionEvent.composition_string`に読み、`probability`に確率を与える。かな列を丸ごと渡すMVPラッパーの候補になる。

ただし、これは元々手書き入力用。`Session::UpdateCompositionInternal()`はComposerをリセットし、Undo状態をクリアする。変換中の`CONVERSION`状態では受け付けない。全置換を通常フリック入力に利用した場合の予測・学習・カーソル・空文字・変換取消の挙動を検証する。高度な編集では増分`SEND_KEY`と`key_string`を使う方式も比較する。[プロトコル](https://github.com/google/mozc/blob/60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98/src/protocol/commands.proto)、[セッション実装](https://github.com/google/mozc/blob/60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98/src/session/session.cc)

`SessionCommand.id`は候補リストの配列インデックスではなく、Mozcが返す候補ID。候補選択と確定も異なる操作（`SELECT_CANDIDATE` / `SUBMIT_CANDIDATE`）。ArkTS APIでは候補IDと候補世代を扱い、古い非同期応答の候補を確定しない。[プロトコル](https://github.com/google/mozc/blob/60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98/src/protocol/commands.proto)

### ビルドと辞書

- 上流は現在Bazel主体。現行Android手順のNDK r29、JNI、Androidログ依存をHarmonyOSへそのまま流用しない。
- 現行`.bazelrc`はC++20。Abseil・protobufなどの依存も同じターゲットと整合するビルドが必要。
- 確認範囲のプラットフォーム定義にHarmonyOS/OHOS向けターゲットはない。上流でそのままビルドできるとは言えない。
- ホスト側の辞書生成ツール・protobuf生成と、端末側ライブラリのクロスコンパイルを分ける。ターゲット用プログラムをMac上で実行しない。
- OSS辞書ビルドには`mozc.data`生成ターゲットがある。辞書もエンジンと同じSHAから生成し、読み込み失敗を正常な変換成功として扱わない。
- 最初はBazelのOHOS toolchain/platform対応を調査する。大量のソースを独自CMakeに手作業で列挙する方法は、移植の範囲を理解してから判断する。

[Androidビルド手順](https://github.com/google/mozc/blob/60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98/docs/build_mozc_for_android.md)、[ビルド定義](https://github.com/google/mozc/blob/60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98/src/.bazelrc)、[OSS辞書生成](https://github.com/google/mozc/blob/60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98/src/data_manager/oss/BUILD.bazel)

### 製品とライセンスの境界

MozcはGoogle日本語入力のOSS部分で、同一の辞書・製品品質を保証するものではない。GoogleのMozcコードはBSD 3-Clauseだが、辞書と第三者依存の通知・ライセンスは別に確認する。製品内に必要な通知を同梱する。[上流README](https://github.com/google/mozc)、[辞書の通知](https://github.com/google/mozc/blob/60fe4012e5eaa26805dbbb8e5548cbe6db4aaf98/src/data/dictionary_oss/README.txt)

## 配布について未確定のこと

IMEの基本実装ガイドは、独自のシステム署名や非公開IME APIを必須とする手順を示していない。一方、これだけでは本アプリの開発者アカウントで公開審査を通せる証拠にならない。

開発署名での有効化、AGCの招待テスト、一般公開を段階分けする。共有サンドボックス申請は基本IME登録と別の条件。今回、ユーザーのAGCアプリや審査画面は確認していない。

## 調査方法と鮮度

Huawei公式ページは動的描画で検索ツールから本文が取れないものがあった。サイトの公開JSで使われる`getDocumentById`を確認し、公開ドキュメントAPIから本文とメタデータを取得した。非公式転載を根拠には使用していない。

| Huawei資料 | `displayUpdateTime`（サイト表記） |
| --- | --- |
| IME実装ガイド | 2026-09-09 06:54:05 |
| inputMethodEngine API | 2026-09-09 06:54:05 |
| IME安全モード | 2026-06-16 09:03:21 |
| Node-API概要 | 2026-09-14 10:46:18 |
| Node-API規約 | 2026-07-28 11:23:46 |
| Node-API基本FAQ | 2026-09-14 10:46:18 |

SDK内の`@ohos.inputMethodEngine.d.ts`、`@ohos.InputMethodExtensionAbility.d.ts`、`@kit.IMEKit.d.ts`とMozcの固定コミットを照合した。型定義と資料の一致は実機の実行証拠ではない。
