export class ClipboardItem {
  id: number;
  text: string;
  expiresAt: number;
  constructor(id: number, text: string, expiresAt: number) { this.id = id; this.text = text; this.expiresAt = expiresAt; }
}
// User-requested reads only. No filesystem, background listener, or clipboard writes.
export class ClipboardHistory {
  private values: ClipboardItem[] = [];
  private nextId: number = 0;
  snapshot(now: number = Date.now()): ClipboardItem[] {
    this.values = this.values.filter((item: ClipboardItem) => item.expiresAt > now);
    return this.values.slice();
  }
  remember(text: string, now: number = Date.now()): ClipboardItem | undefined {
    if (text.length === 0 || text.length > 16384) { return undefined; }
    this.snapshot(now);
    this.values = this.values.filter((item: ClipboardItem) => item.text !== text);
    const item = new ClipboardItem(++this.nextId, text, now + 60 * 60 * 1000);
    this.values = [item, ...this.values].slice(0, 10);
    return item;
  }
  remove(id: number): void { this.values = this.values.filter((item: ClipboardItem) => item.id !== id); }
  clear(): void { this.values = []; }
}
export const clipboardHistory = new ClipboardHistory();
