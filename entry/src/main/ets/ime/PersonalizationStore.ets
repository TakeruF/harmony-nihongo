import { InputMethodExtensionContext } from '@kit.IMEKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { Personalization, PersonalizationValues } from '../input/Personalization';

class PersonalizationStore {
  model: Personalization = new Personalization();
  private path: string = '';
  load(context: InputMethodExtensionContext): void {
    this.path = context.filesDir + '/personalization-v1.json';
    this.model = new Personalization();
    try {
      if (fs.accessSync(this.path) && fs.statSync(this.path).size <= 700000) {
        this.model.restore(JSON.parse(fs.readTextSync(this.path)) as PersonalizationValues);
      }
    } catch (_) { /* Malformed profiles use defaults. */ }
    this.publish();
  }
  save(): boolean {
    if (this.path.length === 0) { return false; }
    try {
      const file = fs.openSync(this.path + '.tmp', fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        const bytes = new util.TextEncoder().encodeInto(JSON.stringify(this.model.values));
        let offset = 0;
        while (offset < bytes.byteLength) {
          const written = fs.writeSync(file.fd, bytes.buffer.slice(offset), { length: bytes.byteLength - offset });
          if (written <= 0) { throw new Error('Profile write failed'); }
          offset += written;
        }
      } finally { fs.closeSync(file); }
      fs.renameSync(this.path + '.tmp', this.path);
      this.publish(); return true;
    } catch (_) { AppStorage.setOrCreate('imeError', '学習設定を保存できませんでした'); return false; }
  }
  publish(): void {
    AppStorage.setOrCreate('imeNextWord', this.model.values.nextWord);
    AppStorage.setOrCreate('imePersonalized', this.model.values.learning);
    AppStorage.setOrCreate('imePrivate', this.model.privateMode);
    AppStorage.setOrCreate('imeLearnedCount', this.model.values.words.length);
  }
}
export const personalizationStore = new PersonalizationStore();
