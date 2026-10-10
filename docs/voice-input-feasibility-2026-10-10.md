# Huaweiの日本語音声入力とGboard参照の調査

2026-10-10に、Harmony NihongoへHuaweiの日本語音声認識を接続できるかを調査した。**現時点では公開APIによる日本語認識の実装は成立しない。音声ボタン・録音権限・認識処理は追加していない。**

## 公開APIの確認

[Huawei公式 speechRecognizer API](https://developer.huawei.com/consumer/cn/doc/doccenter-references/api/hms-ai-speechrecognizer)をブラウザで直接確認。ページの更新日時は2026-09-23 11:54。API全バージョンを含む最新ドキュメントとして表示されていた。

- `@kit.CoreSpeechKit`の`speechRecognizer`は中国語・オフラインのみ。
- `CreateEngineParams.language`は現在`zh-CN`のみ。
- `CreateEngineParams.online`は現在`1`（オフライン）のみ。
- `SpeechRecognitionEngine.listLanguages()`の記載上の返却値は`['zh-CN']`。
- `ja-JP`の指定や`online: 0`への変更で日本語サービスを使える、という根拠はない。

ローカルSDKの`hms/ets/api/@hms.ai.speechRecognizer.d.ts`で`createEngine`、`listLanguages`、`setListener`、`startListening`、`finish`、`cancel`、`shutdown`の実在を確認した。`language`の型が`string`であること自体は日本語対応の証拠ではない。`@kit.SpeechKit`のローカル定義ではTextReaderとAICaptionが公開されており、小艺入力法の日本語音声認識エンジンを直接呼び出すAPIは確認できなかった。

[Huawei公式 小艺入力法の音声入力ガイド](https://consumer.huawei.com/cn/support/content/zh-cn15964517/)には日本語対応が記載されている。ただし適用バージョンはHarmonyOS 1〜4系・EMUI等であり、この説明だけでPura 70のHarmonyOS 7や他社IME向け公開APIの対応を判断できない。入力法内の機能と開発者向けAPIは区別する。

追加調査で、[現行の小艺入力法の機能紹介](https://consumer.huawei.com/cn/support/content/zh-cn16081394/)を発見し、Chromeで本文を確認した。これはスマホ・タブレット、HarmonyOS 5.0以降向けで、日本語を含む4外国語の音声入力を明記している。したがって「小艺入力法の日本語機能が現行HarmonyOSにもある」点は公式資料で裏付けられた。これは外部IMEへ開放されたAPIの証拠とは別で、上記の公開API・実機問い合わせ結果を変更するものではない。

## Gboardの参照

[Google公式 音声入力ガイド](https://support.google.com/gboard/answer/2781851?co=GENIE.Platform%3DAndroid&hl=ja)で、上部マイクから開始し、話して入力する操作を確認した。マイクによる一時停止の説明は音声ツールバーの項目にある。

Androidエミュレータ`emulator-5554`のGboard `15.1.08.726012951-preload-arm64-v8a` / `163542534`を、比較専用アプリの空の入力欄で参照した。この端末の参照時の配列・言語は英語QWERTYで、日本語12キーや日本語の音声認識結果は今回未検証。

- 上部右端に円形のマイクボタン。
- 初回は録音権限の選択画面。検証では「Only this time」を選択。
- 開始後はキーボードを残し、候補帯が音声の状態表示`Speak now`へ変わる。
- タブレットでは左上に戻る、右上に`Minimize`とマイクが出る。
- 再度マイクを押した直後の画面は`Initializing...`だったため、その画面を停止済みの証拠とは扱わない。

参照画面は[artifacts/voice-input-2026-10-10](../artifacts/voice-input-2026-10-10/)へ保存した。音声の文字化・認識精度・停止後の確定・再開は実入力では証明していない。参照後に比較アプリとGboardのプロセスを停止し、画面サイズ1920×1200・density 160・ハードウェアキーボード接続時のIME表示設定0へ復元した。

## 実機と実装判断

最初はPura 70が未接続だったが、ユーザーが接続した後、ADY-AL10で実機問い合わせを実施した。端末の`const.ohos.fullname`は`OpenHarmony-7.0.0.105`。録音・音声データ送信・入力欄への書き込みは行わず、エンジンの初期化と対応言語問い合わせだけを行った。

| 実機への要求 | 結果 |
| --- | --- |
| `language: 'zh-CN', online: 1` | 初期化成功。`listLanguages()`は`["zh-CN"]` |
| `language: 'ja-JP', online: 1` | 初期化失敗。`1002200001` / `Asr CreateEngineParams is wrong!` |
| `language: 'ja-JP', online: 0` | 初期化失敗。同じエラー |

診断ソースは`tools/fixtures/speech-capability-probe.ets`。一時的にUIAbilityから呼び出す診断HAPを生成して実機で実行し、ログの`DONE`まで確認した。結果は`artifacts/voice-input-2026-10-10/device-capabilities.log`へ保存。公開SDKの日本語非対応は公式記載と実機結果の両方で確認できた。小艺入力法自体の日本語認識は今回試験していない。

診断呼び出しとアプリ内の診断ソースを除去した通常版を再ビルドし、診断版・通常版の署名とSHA-256ダイジェストを公式ツールで検証した。通常版0.14.1を再インストールし、起動とバージョンを確認。録音権限は追加していない。ユーザーが選択していた小艺入力法の設定は変更していない。

現状、Huaweiの日本語エンジンを呼ぶボタンを追加すると、実際には認識できないUIになる。別の日本語対応エンジンを採用する場合は、Gboardを参照した開始・認識中・停止・再開・戻るのUIと入力制御を実装できるが、認識基盤の選択と別途検証が必要。小艺入力法への切替だけでは、Harmony Nihongoのキーボードを保ったまま音声認識する動作にはならず、外部からマイクを開始する公開手段も確認できていない。

## Chromeでの追加調査

ユーザーの依頼で小红书を開き、「华为 日语 语音输入」を検索した。検索時にログインを要求されたため、ユーザーのQRログイン後、検索結果と次の3投稿の本文・表示されたコメントをChromeで確認した。投稿は利用者・開発者による報告として扱い、公式APIの証明とは区別する。

| 投稿 | 確認できた内容と限界 |
| --- | --- |
| [华为手机日语离线语音](https://www.xiaohongshu.com/explore/68145689000000002002a07b)（2025-05-02、奥观海） | Huawei端末で日本語のオフライン音声ソフトを探す質問。MOJi辞書で動かせなかったとの内容で、表示された3コメントにも検証可能な解決法はなかった。成功事例ではない。 |
| [小艺输入法1.2.4.430正式版上线应用市场](https://www.xiaohongshu.com/explore/6a4914b6000000000f02a1c9)（07-04、快乐小猫猫☺） | 掲載されたAppGallery更新画面は2026/7/1、1.2.4.430。日本語を含むキーボード言語への音声認識言語の自動適応と、音声機能の快捷工具栏への既定追加を記載。投稿にはAI生成の可能性の表示もあり、実機での同版確認や外部IME向けAPIの根拠にはしない。 |
| [鸿蒙原生 AI 输入法🔥语音转写直接碾压同类](https://www.xiaohongshu.com/explore/6aaa88c7000000002b000806)（09-16、流声 AI 输入法） | 投稿者はHarmonyOSネイティブの音声IME、リアルタイム文字化、フィラー削除、2文体とキーボード配列を説明。認識サービス名・API・コード・日本語対応は記載されていない。Huaweiの日本語エンジンを借りているとの推定はできない。 |

続いて外部アプリ向け事例を探すため「鸿蒙 语音识别 日语 API」をサイト内検索したが、ページ利用不可とSecurity Verificationが表示された。この検索結果は確認できておらず、検索範囲を網羅したとは扱わない。認証回避・コメント投稿・作者への連絡・外部ソフトのインストールは行っていない。

公開検索とChromeで、次の情報も確認した。

- [Huawei公式 スマホ・タブレット向け機能紹介](https://consumer.huawei.com/cn/support/content/zh-cn16081394/)：HarmonyOS 5.0以降の小艺入力法にも日本語音声入力がある。中国語音声を日本語へ翻訳する機能とは別に外国語の音声入力を列挙している。
- [Huawei公式 PC向け機能紹介](https://consumer.huawei.com/cn/support/content/zh-cn16050946/)：PC版にも日本語音声入力を記載。ただしPC限定の資料で、スマホや外部IMEのAPIへ一般化しない。
- [Huawei公式 外付けキーボードの音声キー説明](https://consumer.huawei.com/cn/support/content/zh-cn15956866/)：他社IME使用時は他社IME自身の転写機能を呼ぶと説明。外付け音声キーから小艺の認識基盤だけを借りられる、という根拠にはならない。
- [天坦社区のHarmonyOS 6.1利用報告](https://bbs.tatans.cn/topic/124404)：第三者IME「简单输入法」がシステムのオフラインモデルを使い、オンラインの小艺入力法とは認識性能が異なるとの利用者報告。一次の使用体験として確認したが、認識エンジンの実装・日本語対応の技術的証明ではない。
- [讯飞の語音听写サービス](https://www.xfyun.cn/service/voicedictation)と[流式WebAPI仕様](https://www.xfyun.cn/doc/asr/voicedictation/API.html)：日本語対応とOS非依存のWebSocket接続を公式資料で確認。代替エンジンの候補であり、小艺と同じエンジンという証拠はない。日本語の利用権限・アカウント・API認証とネットワーク接続が必要。日本語の利用条件・料金やPura 70のIMEからの動作は未検証。

掲示板の自動生成らしい回答には`ohos.intent.action.VOICE_RECOGNITION`を`startAbilityForResult`で呼ぶという提案もあったが、公開SDKの型定義で該当アクションは確認できなかった。SDKに存在する`SOURCE_TYPE_VOICE_RECOGNITION`等は録音の音源種別であり、小艺の日本語認識を起動するAPIではない。根拠のないアクション指定を実装案として採用しない。

現時点の追加調査でも、小艺の日本語音声認識を外部IMEから直接呼んで成功した、検証可能なコード付き事例は確認できていない。
