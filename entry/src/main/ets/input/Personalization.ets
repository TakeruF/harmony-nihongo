export class LearnedWord {
  reading: string = '';
  value: string = '';
  previous: string = '';
  count: number = 0;
  used: number = 0;
}

export class PersonalizationValues {
  version: number = 1;
  nextWord: boolean = true;
  learning: boolean = true;
  words: LearnedWord[] = [];
  blocked: string[] = [];
}

// Small offline fallback for everyday continuations. Mozc supplies broader suggestions.
const CONTINUATIONS: string[][] = [
  ['今日は', 'いい天気', '晴れ', 'ありがとう', 'よろしくお願いします'],
  ['明日は', '仕事', '休み', 'よろしくお願いします'],
  ['昨日は', 'ありがとう', 'お疲れ様でした'],
  ['私は', '学生です', '元気です'], ['今は', '大丈夫です', '忙しいです'],
  ['これから', '行きます', '帰ります'], ['今から', '行きます', '帰ります'],
  ['おはよう', 'ございます'], ['ありがとう', 'ございます', 'ございました'],
  ['お疲れ', '様です', '様でした'], ['よろしく', 'お願いします'],
  ['よろしくお願いします', '。', '！'], ['いい天気', 'ですね', 'です'],
  ['晴れ', 'です', 'ですね'], ['学生です', '。'], ['大丈夫', 'です'],
  ['お世話に', 'なっております'], ['おめでとう', 'ございます'],
  ['こんにちは', '！', '。'], ['こんばんは', '！', '。'],
  ['ございます', '。', '！'], ['お願いします', '。', '！'],
  ['です', '。', 'ね', 'が'], ['でした', '。'], ['ます', '。'], ['ました', '。']
];

export class Personalization {
  values: PersonalizationValues = new PersonalizationValues();
  privateMode: boolean = false; // Always reset at process restart, never saved.
  get personalized(): boolean { return this.values.learning && !this.privateMode; }
  restore(saved: PersonalizationValues): boolean {
    if (!saved || saved.version !== 1 || typeof saved.nextWord !== 'boolean' || typeof saved.learning !== 'boolean' ||
        !Array.isArray(saved.words) || saved.words.length > 512 || !Array.isArray(saved.blocked) || saved.blocked.length > 128 ||
        !saved.blocked.every((value: string) => this.validText(value)) ||
        !saved.words.every((word: LearnedWord) => typeof word === 'object' && word !== null && this.validText(word.reading) && this.validText(word.value) &&
          typeof word.previous === 'string' && word.previous.length <= 128 &&
          Number.isInteger(word.count) && word.count > 0 && word.count <= 10000 && Number.isFinite(word.used) && word.used >= 0)) { return false; }
    this.values = saved;
    return true;
  }
  private validText(text: string): boolean {
    return typeof text === 'string' && text.length > 0 && text.length <= 128 && !/[\u0000-\u001f]/.test(text);
  }
  remember(reading: string, value: string, previous: string, now: number = Date.now()): boolean {
    if (!this.personalized || !this.validText(reading) || !this.validText(value) || this.values.blocked.indexOf(value) >= 0) { return false; }
    if (!this.validText(previous)) { previous = ''; }
    const word = this.values.words.find((item: LearnedWord) => item.reading === reading && item.value === value && item.previous === previous);
    if (word) { word.count = Math.min(10000, word.count + 1); word.used = now; }
    else {
      const next = new LearnedWord(); next.reading = reading; next.value = value; next.previous = previous; next.count = 1; next.used = now;
      this.values.words.push(next);
    }
    this.values.words.sort((a: LearnedWord, b: LearnedWord) => b.used - a.used);
    this.values.words = this.values.words.slice(0, 512);
    return true;
  }
  rank(reading: string, base: string[]): string[] {
    const learned = this.personalized ? this.values.words.filter((word: LearnedWord) => word.reading.startsWith(reading)) : [];
    learned.sort((a: LearnedWord, b: LearnedWord) => b.count - a.count || b.used - a.used);
    return this.filter(learned.map((word: LearnedWord) => word.value).concat(base));
  }
  next(previous: string, base: string[]): string[] {
    if (!this.values.nextWord || this.privateMode || previous.length === 0) { return []; }
    const learned = this.personalized ? this.values.words.filter((word: LearnedWord) => word.previous === previous) : [];
    learned.sort((a: LearnedWord, b: LearnedWord) => b.count - a.count || b.used - a.used);
    const fallback = CONTINUATIONS.find((row: string[]) => row[0] === previous);
    return this.filter(learned.map((word: LearnedWord) => word.value).concat(fallback ? fallback.slice(1) : [], base)).slice(0, 32);
  }
  readingFor(value: string, previous: string): string {
    const word = this.personalized ? this.values.words.find((item: LearnedWord) => item.value === value && item.previous === previous) : undefined;
    return word?.reading ?? value;
  }
  private filter(values: string[]): string[] {
    return values.filter((value: string, index: number) => this.validText(value) && values.indexOf(value) === index &&
      (this.privateMode || this.values.blocked.indexOf(value) < 0)).slice(0, 64);
  }
  forget(value: string): void {
    if (!this.validText(value) || this.privateMode) { return; }
    this.values.words = this.values.words.filter((word: LearnedWord) => word.value !== value);
    this.values.blocked = [value].concat(this.values.blocked.filter((item: string) => item !== value)).slice(0, 128);
  }
  clear(): void { this.values.words = []; this.values.blocked = []; }
}
