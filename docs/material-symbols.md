# Google Material Symbols

2026-10-10 に、手描きの既存 UI アイコン 41 個を Google 公式の Material Symbols SVG へ置換し、タブレット用の Keyboard と Caps Lock を追加した。計 43 ファイル／33 種類。

## スタイルと出典

- [Google Fonts のアイコン一覧](https://fonts.google.com/icons)
- [Google 公式の Material Symbols ガイド](https://developers.google.com/fonts/docs/material_symbols)
- [Google 公式リポジトリの固定リビジョン](https://github.com/google/material-design-icons/tree/49d4db35df873165d6bd6ba09b063c7dafbac2f4)
- Material Symbols Rounded、optical size 24、weight 400、grade 0、fill 0。
- 各 SVG の形状を維持し、現在の色を root `fill` に指定する。選択／非選択の形状は同じで、色による状態表示を維持する。
- `push_pin` のみ、上流に `viewBox` がないため `viewBox="0 0 24 24"` を追加。
- UI のリソース名・アクセシビリティラベル・操作は維持。SVG は HAP に同梱され、表示時にネットワークやアイコンフォントを必要としない。

出典の commit、各取得元ファイルの SHA-256、同梱 SVG の SHA-256、色は [`tools/fixtures/material-symbols.json`](../tools/fixtures/material-symbols.json) に記録。

## ライセンス

Google の Material Symbols は Apache License 2.0。ライセンス全文は [`licenses/MATERIAL-SYMBOLS-LICENSE.txt`](../licenses/MATERIAL-SYMBOLS-LICENSE.txt)、変更内容と帰属は [`licenses/MATERIAL-SYMBOLS-NOTICE.txt`](../licenses/MATERIAL-SYMBOLS-NOTICE.txt) に保存。両方をまとめた `entry/src/main/resources/rawfile/material-symbols-notices.txt` を HAP に同梱する。SVG 冒頭にも変更の注記を残す。

## リソース対応

| 既存リソース | Material Symbol | 色 | 取得元 |
| --- | --- | --- | --- |
| `ic_activity.svg` | `sports_soccer` | `#737782` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/sports_soccer/materialsymbolsrounded/sports_soccer_24px.svg) |
| `ic_activity_selected.svg` | `sports_soccer` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/sports_soccer/materialsymbolsrounded/sports_soccer_24px.svg) |
| `ic_add.svg` | `add` | `#29283F` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/add/materialsymbolsrounded/add_24px.svg) |
| `ic_back.svg` | `arrow_back` | `#29283F` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/arrow_back/materialsymbolsrounded/arrow_back_24px.svg) |
| `ic_backspace.svg` | `backspace` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/backspace/materialsymbolsrounded/backspace_24px.svg) |
| `ic_caps_lock.svg` | `keyboard_capslock` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/keyboard_capslock/materialsymbolsrounded/keyboard_capslock_24px.svg) |
| `ic_check.svg` | `check` | `#29283F` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/check/materialsymbolsrounded/check_24px.svg) |
| `ic_clipboard.svg` | `content_paste` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/content_paste/materialsymbolsrounded/content_paste_24px.svg) |
| `ic_clipboard_toggle.svg` | `toggle_on` | `#29283F` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/toggle_on/materialsymbolsrounded/toggle_on_24px.svg) |
| `ic_close.svg` | `close` | `#29283F` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/close/materialsymbolsrounded/close_24px.svg) |
| `ic_delete.svg` | `delete` | `#29283F` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/delete/materialsymbolsrounded/delete_24px.svg) |
| `ic_edit.svg` | `edit` | `#29283F` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/edit/materialsymbolsrounded/edit_24px.svg) |
| `ic_emoji.svg` | `sentiment_satisfied` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/sentiment_satisfied/materialsymbolsrounded/sentiment_satisfied_24px.svg) |
| `ic_emoji_inactive.svg` | `sentiment_satisfied` | `#737782` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/sentiment_satisfied/materialsymbolsrounded/sentiment_satisfied_24px.svg) |
| `ic_enter.svg` | `keyboard_return` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/keyboard_return/materialsymbolsrounded/keyboard_return_24px.svg) |
| `ic_flag.svg` | `flag` | `#737782` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/flag/materialsymbolsrounded/flag_24px.svg) |
| `ic_flag_selected.svg` | `flag` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/flag/materialsymbolsrounded/flag_24px.svg) |
| `ic_food.svg` | `restaurant` | `#737782` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/restaurant/materialsymbolsrounded/restaurant_24px.svg) |
| `ic_food_selected.svg` | `restaurant` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/restaurant/materialsymbolsrounded/restaurant_24px.svg) |
| `ic_globe.svg` | `language` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/language/materialsymbolsrounded/language_24px.svg) |
| `ic_hide.svg` | `keyboard_arrow_down` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/keyboard_arrow_down/materialsymbolsrounded/keyboard_arrow_down_24px.svg) |
| `ic_keyboard.svg` | `keyboard` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/keyboard/materialsymbolsrounded/keyboard_24px.svg) |
| `ic_left.svg` | `arrow_left` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/arrow_left/materialsymbolsrounded/arrow_left_24px.svg) |
| `ic_nature.svg` | `pets` | `#737782` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/pets/materialsymbolsrounded/pets_24px.svg) |
| `ic_nature_selected.svg` | `pets` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/pets/materialsymbolsrounded/pets_24px.svg) |
| `ic_object.svg` | `lightbulb` | `#737782` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/lightbulb/materialsymbolsrounded/lightbulb_24px.svg) |
| `ic_object_selected.svg` | `lightbulb` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/lightbulb/materialsymbolsrounded/lightbulb_24px.svg) |
| `ic_person.svg` | `accessibility_new` | `#737782` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/accessibility_new/materialsymbolsrounded/accessibility_new_24px.svg) |
| `ic_person_selected.svg` | `accessibility_new` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/accessibility_new/materialsymbolsrounded/accessibility_new_24px.svg) |
| `ic_pin.svg` | `push_pin` | `#29283F` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/push_pin/materialsymbolsrounded/push_pin_24px.svg) |
| `ic_recent.svg` | `schedule` | `#737782` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/schedule/materialsymbolsrounded/schedule_24px.svg) |
| `ic_recent_selected.svg` | `schedule` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/schedule/materialsymbolsrounded/schedule_24px.svg) |
| `ic_right.svg` | `arrow_right` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/arrow_right/materialsymbolsrounded/arrow_right_24px.svg) |
| `ic_search.svg` | `search` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/search/materialsymbolsrounded/search_24px.svg) |
| `ic_settings.svg` | `settings` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/settings/materialsymbolsrounded/settings_24px.svg) |
| `ic_shift.svg` | `shift` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/shift/materialsymbolsrounded/shift_24px.svg) |
| `ic_space.svg` | `space_bar` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/space_bar/materialsymbolsrounded/space_bar_24px.svg) |
| `ic_symbol.svg` | `favorite` | `#737782` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/favorite/materialsymbolsrounded/favorite_24px.svg) |
| `ic_symbol_selected.svg` | `favorite` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/favorite/materialsymbolsrounded/favorite_24px.svg) |
| `ic_tab.svg` | `keyboard_tab` | `#45464F` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/keyboard_tab/materialsymbolsrounded/keyboard_tab_24px.svg) |
| `ic_travel.svg` | `directions_car` | `#737782` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/directions_car/materialsymbolsrounded/directions_car_24px.svg) |
| `ic_travel_selected.svg` | `directions_car` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/directions_car/materialsymbolsrounded/directions_car_24px.svg) |
| `ic_undo.svg` | `undo` | `#1A1B21` | [SVG](https://github.com/google/material-design-icons/blob/49d4db35df873165d6bd6ba09b063c7dafbac2f4/symbols/web/undo/materialsymbolsrounded/undo_24px.svg) |

## 検証

- 43 SVG の XML 構文、path の存在、viewBox、24px 寸法、既存色、manifest の同梱 SHA-256 を検証。
- 33 種類の上流 SVG と path 属性を照合し、形状が改変されていないことを検証。
- 全アイコンを 16px／24px／32px でラスタライズして、空の画像・画面外の形状がないことを確認。
- 絵文字カテゴリの選択／非選択は、同じ形状で `#737782`／`#1A1B21` であることを検証。
- 確認用一覧は `artifacts/material-symbols-2026-10-10/contact-sheet.png`、構造検証記録は同フォルダーの `validation.json`。
- HarmonyOS でのビルドと端末表示の検証は、タブレット対応の検証記録を参照。
