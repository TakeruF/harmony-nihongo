export class EmojiCategory {
  label: string;
  icon: string;
  values: string[];
  constructor(label: string, icon: string, values: string[]) { this.label = label; this.icon = icon; this.values = values; }
}
// Small offline starter set. Each item is an entire Unicode emoji sequence.
export const emojiCategories: EmojiCategory[] = [
  new EmojiCategory('表情', '☺︎', ['😀','😃','😄','😁','😆','😅','😂','🤣','😊','🥰','😍','😘','😋','😎','🤔','🥺','😭','😤','😡','😱','😴','😇','🤗','🤩']),
  new EmojiCategory('気持ち', '♡', ['👍','👍🏽','👎','👏','🙌','🙏','💪','👋','✌️','🤝','❤️','🧡','💛','💚','💙','💜','🖤','🤍','💕','💖','💔','💯','✨','🎉']),
  new EmojiCategory('動物・自然', '♧', ['🐶','🐱','🐰','🐻','🐼','🐨','🐯','🦁','🐷','🐸','🐵','🐧','🐦','🐣','🐟','🐬','🦋','🐝','🌸','🌹','🌻','🌱','🍀','🌈']),
  new EmojiCategory('食べ物', '♨︎', ['🍎','🍊','🍋','🍌','🍉','🍇','🍓','🍒','🍑','🍍','🥑','🍙','🍚','🍜','🍣','🍛','🍕','🍔','🍟','🍰','🍦','🍫','☕','🍵']),
  new EmojiCategory('お出かけ', '⌂', ['🚗','🚕','🚌','🚃','🚄','🚲','✈️','🚀','⛵','🏠','🏫','🏢','🏥','🏪','⛩️','🗼','🗻','🌅','🌃','☀️','☁️','☔','❄️','🇯🇵']),
  new EmojiCategory('暮らし', '☆', ['📱','💻','⌨️','📷','📺','🎧','🎵','🎤','📚','✏️','📅','⏰','💡','🔑','🎁','🎈','⚽','⚾','🏀','🎮','👨‍👩‍👧‍👦','✅','❌','❓'])
];
