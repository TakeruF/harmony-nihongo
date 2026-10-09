export class KanaComposition {
  reading: string = '';
  cursor: number = 0;
  private lastTap: string = '';
  private lastTapTime: number = 0;
  private lastTapCursor: number = -1;
  private tapIndex: number = 0;

  get canReverse(): boolean { return this.lastTap.length > 0 && this.cursor === this.lastTapCursor && this.cursor > 0; }
  reverseTap(timestamp: number = Date.now()): void {
    if (!this.canReverse) { return; }
    const group = this.lastTap; const values = group.split('|');
    const index = (this.tapIndex + values.length - 1) % values.length;
    this.backspace(); this.insert(values[index]);
    this.tapIndex = index; this.lastTap = group; this.lastTapTime = timestamp; this.lastTapCursor = this.cursor;
  }
  insert(value: string): void {
    this.lastTap = '';
    this.reading = this.reading.slice(0, this.cursor) + value + this.reading.slice(this.cursor);
    this.cursor += value.length;
  }
  backspace(): void {
    this.lastTap = '';
    if (this.cursor === 0) { return; }
    this.reading = this.reading.slice(0, this.cursor - 1) + this.reading.slice(this.cursor);
    this.cursor--;
  }
  move(delta: number): void { this.lastTap = ''; this.cursor = Math.max(0, Math.min(this.reading.length, this.cursor + delta)); }
  transform(kind: string): void {
    this.lastTap = '';
    if (this.cursor === 0) { return; }
    const character = this.reading.charAt(this.cursor - 1);
    if (kind === 'case') {
      if (/^[a-zA-Z]$/.test(character)) {
        const replacement = character === character.toLowerCase() ? character.toUpperCase() : character.toLowerCase();
        this.reading = this.reading.slice(0, this.cursor - 1) + replacement + this.reading.slice(this.cursor);
      }
      return;
    }
    let cycles: string[] = [];
    if (kind === 'variant') {
      cycles = ['あぁ','いぃ','うぅゔ','えぇ','おぉ','かが','きぎ','くぐ','けげ','こご','さざ','しじ','すず','せぜ','そぞ',
        'ただ','ちぢ','つっづ','てで','とど','はばぱ','ひびぴ','ふぶぷ','へべぺ','ほぼぽ','やゃ','ゆゅ','よょ','わゎ'];
    } else if (kind === 'voice') {
      cycles = ['かが','きぎ','くぐ','けげ','こご','さざ','しじ','すず','せぜ','そぞ',
        'ただ','ちぢ','つづ','てで','とど','はばぱ','ひびぴ','ふぶぷ','へべぺ','ほぼぽ','うゔ'];
    } else {
      cycles = ['あぁ','いぃ','うぅ','えぇ','おぉ','つっ','やゃ','ゆゅ','よょ','わゎ','かゕ','けゖ'];
    }
    for (const cycle of cycles) {
      const index = cycle.indexOf(character);
      if (index >= 0) {
        const replacement = cycle.charAt((index + 1) % cycle.length);
        this.reading = this.reading.slice(0, this.cursor - 1) + replacement + this.reading.slice(this.cursor);
        return;
      }
    }
  }
  tap(values: string[], timestamp: number): void {
    const group = values.join('|');
    const repeated = group === this.lastTap && timestamp >= this.lastTapTime && timestamp - this.lastTapTime < 700 &&
      this.cursor === this.lastTapCursor && this.cursor > 0;
    const index = repeated ? (this.tapIndex + 1) % values.length : 0;
    if (repeated) { this.backspace(); }
    this.insert(values[index]);
    this.tapIndex = index; this.lastTap = group; this.lastTapTime = timestamp; this.lastTapCursor = this.cursor;
  }
  clear(): void { this.reading = ''; this.cursor = 0; this.lastTap = ''; }
  display(): string { return this.reading.slice(0, this.cursor) + '│' + this.reading.slice(this.cursor); }
}
