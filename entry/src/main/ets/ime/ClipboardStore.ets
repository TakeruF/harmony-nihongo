import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { clipboardHistory, ClipboardItem } from '../input/ClipboardHistory';

class ClipboardSavedValues {
  enabled: boolean = true;
  pinned: string[] = [];
}

// Only explicit pins persist. This store is opened only in FULL security mode.
class ClipboardStore {
  private path: string = '';
  load(context: common.Context): void {
    if (this.path.length > 0) { return; }
    try {
      this.path = context.filesDir + '/clipboard-pins.json';
      if (!fs.accessSync(this.path)) { return; }
      if (fs.statSync(this.path).size > 700000) { throw new Error('Invalid clipboard storage'); }
      const saved = JSON.parse(fs.readTextSync(this.path)) as ClipboardSavedValues;
      if (typeof saved.enabled !== 'boolean' || !Array.isArray(saved.pinned) ||
        !saved.pinned.every((text: string) => typeof text === 'string')) { throw new Error('Invalid clipboard storage'); }
      clipboardHistory.setEnabled(saved.enabled); clipboardHistory.restorePinned(saved.pinned);
    } catch (_err) { /* Ignore malformed stored data; an explicit edit can replace it. */ }
  }
  stop(): void { this.path = ''; }
  save(): boolean {
    if (this.path.length === 0) { return false; }
    try {
      const saved = new ClipboardSavedValues(); saved.enabled = clipboardHistory.enabled;
      saved.pinned = clipboardHistory.snapshot().filter((item: ClipboardItem) => item.pinned).map((item: ClipboardItem) => item.text);
      const temporary = this.path + '.tmp';
      const file = fs.openSync(temporary, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try { fs.writeSync(file.fd, JSON.stringify(saved)); } finally { fs.closeSync(file); }
      fs.renameSync(temporary, this.path); return true;
    } catch (_err) { return false; }
  }
}
export const clipboardStore = new ClipboardStore();
