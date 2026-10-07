import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SettingsValues } from '../input/SettingsValues';
import { SETTINGS_GROUP_ID } from './SharedSettingsConfig';

class KeyboardSettings {
  private values: SettingsValues = new SettingsValues();
  private path: string = '';
  private owner: boolean = false;
  private linked: boolean = false;
  async load(context: common.Context, owner: boolean): Promise<void> {
    this.owner = owner;
    this.linked = false;
    this.path = '';
    this.values = new SettingsValues();
    this.publish();
    AppStorage.setOrCreate('settingsLinked', false);
    try {
      if (SETTINGS_GROUP_ID.length > 0) {
        const directory = await context.getGroupDir(SETTINGS_GROUP_ID);
        this.path = directory + '/keyboard-settings.json';
        this.linked = true;
      } else if (owner) {
        this.path = context.filesDir + '/keyboard-settings.json';
      }
      this.refresh();
      if (owner && this.path.length > 0 && !fs.accessSync(this.path)) { this.save(); }
      AppStorage.setOrCreate('settingsLinked', this.linked);
    } catch (err) {
      this.linked = false;
      AppStorage.setOrCreate('settingsLinked', false);
      hilog.error(0x0001, 'NihongoIME', 'SETTINGS_LOAD_FAILED code=%{public}d', (err as BusinessError).code);
    }
  }
  refresh(): void {
    if (this.path.length === 0) { return; }
    try {
      if (!fs.accessSync(this.path)) { return; }
      if (fs.statSync(this.path).size > 1024) { throw new Error('Invalid settings size'); }
      const parsed = JSON.parse(fs.readTextSync(this.path)) as SettingsValues;
      const values = new SettingsValues();
      // Settings saved before haptics was added retain the default.
      if (parsed.haptics !== undefined) { values.haptics = parsed.haptics; }
      values.halfSpace = parsed.halfSpace; values.threeModes = parsed.threeModes;
      values.flickOnly = parsed.flickOnly; values.keitaiOnly = parsed.keitaiOnly;
      if (!values.valid()) { throw new Error('Invalid settings values'); }
      this.values = values;
      this.publish();
    } catch (err) {
      hilog.error(0x0001, 'NihongoIME', 'SETTINGS_READ_FAILED code=%{public}d', (err as BusinessError).code);
    }
  }
  enabled(key: string): boolean { return AppStorage.get<boolean>(key) === true; }
  set(key: string, value: boolean): void {
    if (!this.owner || !this.linked) { return; }
    const next = new SettingsValues();
    next.haptics = this.values.haptics;
    next.halfSpace = this.values.halfSpace; next.threeModes = this.values.threeModes;
    next.flickOnly = this.values.flickOnly; next.keitaiOnly = this.values.keitaiOnly;
    next.set(key, value);
    try { this.save(next); this.values = next; this.publish(); }
    catch (err) { AppStorage.setOrCreate('settingsError', '設定を保存できませんでした。'); }
  }
  private save(values: SettingsValues = this.values): void {
    const temporary = this.path + '.tmp';
    const file = fs.openSync(temporary, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
    try { fs.writeSync(file.fd, JSON.stringify(values)); } finally { fs.closeSync(file); }
    fs.renameSync(temporary, this.path);
  }
  private publish(): void {
    AppStorage.setOrCreate('imeHaptics', this.values.haptics);
    AppStorage.setOrCreate('imeHalfSpace', this.values.halfSpace);
    AppStorage.setOrCreate('imeThreeModes', this.values.threeModes);
    AppStorage.setOrCreate('imeFlickOnly', this.values.flickOnly);
    AppStorage.setOrCreate('imeKeitaiOnly', this.values.keitaiOnly);
  }
}
export const keyboardSettings = new KeyboardSettings();
