# harmony-nihongo

Huawei HarmonyOS向けの日本語フリック入力IME。ArkTSのUI・入力制御と、C++の変換エンジンを分離して開発する。

2026-10-09に、新しいMac環境の `/Users/takeru/GitHub/harmony-nihongo` でDebugビルドを確認し、AndroidエミュレータのGboard日本語12キーを実測して表示・英字12キー・数字フリック・連打順を調整した。Harmonyエミュレータで170方向と21連打の入力結果を照合済み。逆順キー、絵文字の9列表示・日本語検索・履歴・肌の色選択も追加した。**全UI・動作・UXの完全一致は未完了。** [比較条件・変更・結果と残る差](docs/gboard-reference-2026-10-09.md)。

**クリップボード・絵文字入力・横画面対応・日本語QWERTY・Mozcの基本変換・予測候補・選択学習・文節ごとの候補選択・区切り調整・選択文字の再変換を導入。** Pura 70 / HarmonyOS 7で、フリック→未確定かな→かな確定、濁点・半濁点・小文字、途中編集・取消、プレビュー非対応の入力欄を実機検証した。Gboard参考のキー寸法・間隔と、横一列の候補帯を使用する。Mozcで実際の漢字候補を表示し、タップで全文を確定できる。候補の展開にも対応。かな入力中の␣キーで文節変換に入り、左右で文節を移動して候補を選び、確定キーで全文を確定できる。文節変換中の左右キー長押しで区切りを縮める・伸ばすことができる。

「あa1」を長押しすると、日本語12キーと日本語QWERTYを切り替えられる。QWERTYでは`kyouha → きょうは`のローマ字入力から同じMozc候補へ接続し、「日本語」スペースキーで文節変換に入る。短押しは英字・数字への切り替え。縦横の回転に合わせてキーと候補の寸法を更新し、選択中の入力方式を維持する。レイアウト選択は現在のIME表示中の状態として保持し、設定の永続化は共有領域の準備後に対応する。

「☺︎記」キーまたは未入力時の顔アイコンから、9カテゴリ1,898種類の絵文字を選べる。9列の一覧、日本語・英語検索、最近使った36件、長押しによる肌の色選択に対応。検索語はアプリの入力欄へ送らず、選択した絵文字だけを入力する。履歴は現在のIMEプロセス内で保持し、再起動後の永続化は未対応。絵文字の外観はOSの絵文字フォントを使用する。下部のキーで直前の入力方式へ戻るか、記号入力へ移る。

未入力時のクリップボードアイコンから、コピーしたテキストを貼り付けられる。0.13.0では実機Gboardを参照し、左上の戻る、右上のオン／オフ・編集、2列のカード、選択時の削除・固定・追加を導入した。標準の貼り付けボタンで読み取り、最大10件を保持する。固定したクリップとオン／オフ状態だけをIMEの専用領域へ保存し、通常の履歴はプロセス内で1時間保持する。追加画面では、かな・日本語QWERTY・絵文字をアプリの入力欄へ送らず編集できる。完全アクセスモードで使用する。

0.14.1では日本語の確定語の品詞情報をMozcへ渡す処理を修正し、「学校」「仕事」「日本語」「楽しい」「食べる」など、定型文表にない語にも確定後の予測が出るようにした。

0.14.0では「今日は」を確定した後も「いい天気」などの続きの候補を表示し、候補を連続して選べるようにした。よく使う言葉とその続きを端末内で学習し、再起動後も優先する。キーボードの歯車から、次の語句の予測・個人学習・シークレットを切り替え、学習データを削除できる。候補の長押しでその候補を非表示にできる。[調査・実装・検証](docs/gboard-prediction-2026-10-10.md)。

キー入力の設定はアプリの「設定」から開く。基礎モードでのアプリ設定共有にはHuaweiのdata-group-id承認が必要で、現在は標準設定で動作し、設定変更は無効。[共有領域の手順と申請文案](docs/settings-sharing.md)を用意した。

キー押下・変換候補の操作に短い触覚フィードバックを追加。振動は完全アクセスモードで利用でき、基礎モードでは呼び出さない。設定共有の準備までは標準でオン。[実装と検証](docs/haptics-2026-10-07.md)。

0.12.0では、フリック中の拡大表示、削除・カーソルの長押しリピート、入力欄に応じた数字キー・改行／検索表示、アイコン・配色を調整した。[洗練の範囲と検証](docs/gboard-polish-2026-10-08.md)。

出境易内のChatGPTで入力処理が止まる問題を再現し、カーソル読み取り・文字操作の完了通知が戻らない編集先向けの互換処理を追加した。この場合はキーボード内でかなを保持し、確定時に一度だけ入力する。外部の入力欄の実際の値で確認し、アプリ内の試験とは区別する。[外部アプリの互換性と検証](docs/external-editor-compatibility-2026-10-08.md)。

- [クリップボードの操作・検証](docs/phase10-validation-2026-10-07.md)
- [Gboardのパネル配置と0.13.0の実機検証](docs/gboard-panels-2026-10-10.md)
- [地球儀キー撤去・濁点の連続入力・絵文字カテゴリ色の修正](docs/keyboard-icon-fix-2026-10-10.md)
- [絵文字の操作・検証](docs/phase9-validation-2026-10-07.md)
- [MVPの到達点と残りの作業](docs/remaining-work.md)
- [横画面の実装・検証](docs/phase8-validation-2026-10-07.md)
- [日本語QWERTYの操作・検証](docs/phase7-validation-2026-10-07.md)
- [選択文字の再変換・検証](docs/phase6-validation-2026-10-07.md)
- [文節の伸縮・検証](docs/phase5-validation-2026-10-07.md)
- [文節変換の操作と検証](docs/phase4-validation-2026-10-07.md)
- [予測・学習の実装と検証](docs/phase3-validation-2026-10-07.md)
- [Mozc変換の実装・検証](docs/phase2-validation-2026-10-07.md)
- [かな入力の実装・検証](docs/phase1-validation-2026-10-07.md)
- [最初のIME・C++検証](docs/phase0-validation-2026-10-07.md)
- [連続入力の修正・検証](docs/rapid-input-2026-10-07.md)
- [公式資料・SDK・Mozcソースの調査結果](docs/feasibility-2026-10-07.md)
- [実装順序とMVPの受け入れ条件](docs/mvp-plan.md)

## タブレット

短辺と利用できる幅が600 vp以上の画面では、12キーの高さを一定にし、候補帯を含む本体を324 vpに収める。上部の「QWERTY／12キー」ボタンで日本語・英字の配列を選べる。日本語QWERTYはTab、Caps Lock、左Shift、長音キーと広い空白キーを備え、英字QWERTYは左右のShiftに対応する。600 vp未満の狭い画面は従来の配列を使う。

[タブレットの観察・検証記録](docs/tablet-2026-10-10.md) ／ [Material Symbolsアイコンの出典とライセンス](docs/material-symbols.md)。タブレット実機の検証は未実施。

## ビルド

macOS ARM64のDevEco StudioとHarmonyOS SDK、Nativeツールチェーン、Xcodeを使用する。初回に固定版MozcとBazel 9を取得し、ホストでOSS辞書、HarmonyOS用ツールチェーンでARM64ライブラリを生成する。Android NDKは使用しない。

```sh
node tools/test-personalization.cjs
node tools/test-clipboard-history.cjs
node tools/test-clipboard-store.cjs
node tools/test-clipboard-composition.cjs
node tools/test-emoji-catalog.cjs
node tools/test-keyboard-metrics.cjs
node tools/test-romaji.cjs
node tools/test-kana.cjs
node tools/test-conversion-controller.cjs
node tools/test-cursor-hold.cjs
node tools/test-key-repeat.cjs
node tools/test-preview-cursor.cjs
node tools/test-haptics.cjs
python3 tools/test-native.py
python3 tools/build.py
python3 tools/test-mozc-engine.py
```

初回ビルドで`build-profile.template.json5`からローカル設定を作る。実機へインストールするにはDevEcoのProject Structure → Signing Configsでデバッグ署名を設定し、ProductsのdefaultにそのSigning Configを指定して再ビルドする。署名設定・秘密情報・生成物はGitの対象外。

0.12.1では互換環境内ChatGPTでも変換前のかなを入力欄に表示し、未変換でアプリ側から送信できるようにした。[動作と実機証跡](docs/chatgpt-live-composition-2026-10-08.md)。

実機用の最新署名済みデバッグHAPは`artifacts/general-prediction-2026-10-10/HarmonyNihongo-0.14.1-debug.hap`。一般の単語からの予測の検証記録と画面も同じフォルダーに保存。0.14.0の予測・学習の検証記録は`artifacts/prediction-2026-10-10/`に保存。濁点の連続入力と絵文字カテゴリ色の修正の画面・検証ログは`artifacts/keyboard-icon-fix-2026-10-10/`に保存。クリップボードの検証記録は`artifacts/gboard-panel-parity-2026-10-10/`、日本語QWERTYのUIは`artifacts/phase7/qwerty-candidates.png`、再変換のUIは`artifacts/phase6/reconversion-ime.png`、文節選択のUIは`artifacts/phase4/segments-final-ime.png`、基本変換の候補は`artifacts/phase2/candidates.png`に保存。アプリ設定は段階1の`settings.png`で確認。端末にはインストール済みで、Harmony Nihongoを選択している。
