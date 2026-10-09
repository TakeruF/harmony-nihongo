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


export class EmojiEntry {
  value: string = '';
  name: string = '';
  keywords: string = '';
  variants: string[] = [];
}
export class SearchableEmojiCategory {
  label: string = '';
  icon: string = '';
  entries: EmojiEntry[] = [];
}
export class EmojiCatalogData { categories: SearchableEmojiCategory[] = []; }

// Kept inside the current IME process; no background clipboard or storage access.
export class EmojiHistory {
  private values: EmojiEntry[] = [];
  remember(entry: EmojiEntry): void {
    this.values = [entry, ...this.values.filter((value: EmojiEntry) => value.value !== entry.value)].slice(0, 36);
  }
  snapshot(): EmojiEntry[] { return this.values.slice(); }
}
export const emojiHistory = new EmojiHistory();

function normalizeEmojiQuery(value: string): string {
  return value.normalize('NFKC').toLowerCase().replace(/[ァ-ヶ]/g, (character: string) => String.fromCharCode(character.charCodeAt(0) - 0x60));
}

export function searchEmoji(categories: SearchableEmojiCategory[], query: string): EmojiEntry[] {
  const tokens = normalizeEmojiQuery(query).trim().split(/\s+/).filter((token: string) => token.length > 0);
  if (tokens.length === 0) { return []; }
  return categories.reduce((all: EmojiEntry[], category: SearchableEmojiCategory) => all.concat(category.entries), [])
    .filter((entry: EmojiEntry) => {
      const text = normalizeEmojiQuery(entry.value + ' ' + entry.name + ' ' + entry.keywords);
      return tokens.every((token: string) => text.indexOf(token) >= 0);
    });
}
