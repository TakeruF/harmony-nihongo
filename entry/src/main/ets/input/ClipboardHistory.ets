export class ClipboardItem {
  id: number;
  text: string;
  expiresAt: number;
  pinned: boolean;
  constructor(id: number, text: string, expiresAt: number, pinned: boolean = false) {
    this.id = id; this.text = text; this.expiresAt = expiresAt; this.pinned = pinned;
  }
}
// User-requested reads only. No filesystem, background listener, or clipboard writes.
export class ClipboardHistory {
  private values: ClipboardItem[] = [];
  private nextId: number = 0;
  enabled: boolean = true;
  snapshot(now: number = Date.now()): ClipboardItem[] {
    this.values = this.values.filter((item: ClipboardItem) => item.pinned || item.expiresAt > now);
    return this.values.slice();
  }
  remember(text: string, now: number = Date.now()): ClipboardItem | undefined {
    if (!this.enabled || text.length === 0 || text.length > 16384) { return undefined; }
    this.snapshot(now);
    const existing = this.values.find((item: ClipboardItem) => item.text === text);
    const pinned = existing?.pinned ?? false;
    if (!existing && this.values.filter((item: ClipboardItem) => item.pinned).length >= 10) { return undefined; }
    this.values = this.values.filter((item: ClipboardItem) => item.text !== text);
    const item = new ClipboardItem(++this.nextId, text, now + 60 * 60 * 1000, pinned);
    this.values = [item, ...this.values];
    while (this.values.length > 10) {
      const removable = this.values.map((value: ClipboardItem) => value.pinned).lastIndexOf(false);
      this.values.splice(removable, 1);
    }
    return item;
  }
  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
    if (!enabled) { this.values = this.values.filter((item: ClipboardItem) => item.pinned); }
  }
  pin(ids: number[], pinned: boolean, now: number = Date.now()): void {
    this.values = this.snapshot(now).map((item: ClipboardItem) => ids.includes(item.id) ?
      new ClipboardItem(item.id, item.text, now + 60 * 60 * 1000, pinned) : item);
  }
  restorePinned(texts: string[]): void {
    this.values = this.values.filter((item: ClipboardItem) => !item.pinned);
    texts.filter((text: string, index: number) => text.length > 0 && text.length <= 16384 && texts.indexOf(text) === index)
      .slice(0, 10).forEach((text: string) => {
        this.values = this.values.filter((item: ClipboardItem) => item.text !== text);
        this.values.push(new ClipboardItem(++this.nextId, text, 0, true));
      });
    this.values = this.values.slice(-10);
  }
  remove(id: number): void { this.values = this.values.filter((item: ClipboardItem) => item.id !== id); }
  clear(): void { this.values = []; }
}
export const clipboardHistory = new ClipboardHistory();
