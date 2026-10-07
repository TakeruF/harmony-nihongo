// A conversion snapshot stays separate from the editable original kana.
export class SegmentComposition {
  readonly reading: string;
  private readings: string[] = [];
  private choices: string[][] = [];
  private selected: number[] = [];
  focus: number = 0;
  constructor(reading: string, rows: string[][]) {
    this.reading = reading;
    if (rows.length === 0 || rows.length > 64 || rows.map((row: string[]) => row[0]).join('') !== reading) {
      throw new Error('Invalid segment reading');
    }
    rows.forEach((row: string[]) => {
      if (row.length < 2 || row.some((value: string) => value.length === 0)) { throw new Error('Invalid segment candidates'); }
      this.readings.push(row[0]);
      this.choices.push(row.slice(1).filter((value: string, index: number, values: string[]) => values.indexOf(value) === index));
      this.selected.push(0);
    });
  }
  get keys(): string[] { return this.readings.slice(); }
  get lengths(): number[] { return this.readings.map((value: string) => {
    let count = 0;
    for (let i = 0; i < value.length; i++, count++) {
      const code = value.charCodeAt(i);
      if (code >= 0xD800 && code <= 0xDBFF && i + 1 < value.length && value.charCodeAt(i + 1) >= 0xDC00 && value.charCodeAt(i + 1) <= 0xDFFF) { i++; }
    }
    return count;
  }); }
  resized(rows: string[][]): SegmentComposition {
    const next = new SegmentComposition(this.reading, rows);
    next.focus = Math.min(this.focus, next.count - 1);
    // Preserve selections only when both the reading and its position remain unchanged.
    let oldOffset = 0;
    for (let i = 0; i < this.count; i++) {
      let newOffset = 0;
      for (let j = 0; j < next.count; j++) {
        if (oldOffset === newOffset && this.readings[i] === next.readings[j]) {
          const index = next.choices[j].indexOf(this.choices[i][this.selected[i]]);
          if (index >= 0) { next.selected[j] = index; }
        }
        newOffset += next.readings[j].length;
      }
      oldOffset += this.readings[i].length;
    }
    return next;
  }
  get count(): number { return this.choices.length; }
  get candidates(): string[] { return this.choices[this.focus].slice(); }
  get value(): string { return this.choices[this.focus][this.selected[this.focus]]; }
  get values(): string[] { return this.choices.map((row: string[], index: number) => row[this.selected[index]]); }
  get text(): string { return this.values.join(''); }
  select(value: string): boolean {
    const index = this.choices[this.focus].indexOf(value);
    if (index < 0) { return false; }
    this.selected[this.focus] = index;
    return true;
  }
  move(delta: number): void { this.focus = Math.max(0, Math.min(this.count - 1, this.focus + delta)); }
}
