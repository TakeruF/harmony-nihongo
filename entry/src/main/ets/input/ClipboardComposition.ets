import { KanaComposition } from './KanaComposition';

// Local clip editing must keep the catalog's emoji sequences and combining marks intact.
export function clipboardTextBoundaries(text: string): number[] {
  const boundaries: number[] = [0];
  let offset = 0;
  let previous = -1;
  let regionalRun = 0;
  // Explicit UTF-16 scanning keeps code-point boundaries consistent across runtimes.
  while (offset < text.length) {
    const code = text.codePointAt(offset) ?? 0;
    const length = code > 0xFFFF ? 2 : 1;
    const character = text.slice(offset, offset + length);
    const regional = code >= 0x1F1E6 && code <= 0x1F1FF;
    const extend = /\p{Mark}/u.test(character) || code === 0x200D ||
      (code >= 0x1F3FB && code <= 0x1F3FF) || (code >= 0xE0020 && code <= 0xE007F);
    const connected = extend || previous === 0x200D || (regional && regionalRun % 2 === 1) ||
      (code === 0x0A && previous === 0x0D);
    if (offset > 0 && !connected) { boundaries.push(offset); }
    regionalRun = regional ? regionalRun + 1 : 0;
    offset += length; previous = code;
  }
  if (offset > 0) { boundaries.push(offset); }
  return boundaries;
}

export class ClipboardComposition extends KanaComposition {
  backspace(): void {
    const boundaries = clipboardTextBoundaries(this.reading.slice(0, this.cursor));
    const count = this.cursor - (boundaries.length > 1 ? boundaries[boundaries.length - 2] : 0);
    for (let index = 0; index < count; index++) { super.backspace(); }
  }
  move(delta: number): void {
    const boundaries = clipboardTextBoundaries(this.reading);
    const index = boundaries.findIndex((position: number) => position >= this.cursor);
    const target = boundaries[Math.max(0, Math.min(boundaries.length - 1, index + delta))];
    super.move(target - this.cursor);
  }
}
