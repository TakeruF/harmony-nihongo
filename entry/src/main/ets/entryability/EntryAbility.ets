import { UIAbility, Want } from '@kit.AbilityKit';
import { keyboardSettings } from '../ime/KeyboardSettings';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
export default class EntryAbility extends UIAbility {
  private stage?: window.WindowStage;
  private initialPage: string = 'pages/Index';
  private validationOrientation?: boolean;
  // App-owned test window only; never changes system rotation preferences.
  private applyValidationOrientation(): void {
    if (this.validationOrientation === undefined || !this.stage) { return; }
    this.stage.getMainWindowSync().setPreferredOrientation(this.validationOrientation ?
      window.Orientation.LANDSCAPE : window.Orientation.PORTRAIT).catch((err: BusinessError) => {
        hilog.error(0x0001, 'NihongoApp', 'ORIENTATION_FAILED code=%{public}d', err.code);
      });
  }
  onCreate(want: Want): void {
    if (typeof want.parameters?.validationLandscape === 'boolean') { this.validationOrientation = want.parameters.validationLandscape; }
    AppStorage.setOrCreate('settingsError', '');
    keyboardSettings.load(this.context, true).catch((err: BusinessError) => {
      hilog.error(0x0001, 'NihongoApp', 'SETTINGS_LOAD_FAILED code=%{public}d', err.code);
    });
    if (want.parameters?.openSettings === true) { this.initialPage = 'pages/Settings'; }
  }
  onNewWant(want: Want): void {
    if (typeof want.parameters?.validationLandscape === 'boolean') {
      this.validationOrientation = want.parameters.validationLandscape; this.applyValidationOrientation();
    }
    if (want.parameters?.openSettings === true) { this.stage?.loadContent('pages/Settings'); }
  }
  onForeground(): void { keyboardSettings.refresh(); }
  onWindowStageCreate(stage: window.WindowStage): void {
    this.stage = stage;
    this.applyValidationOrientation();
    try {
      stage.loadContent(this.initialPage, (err: BusinessError) => {
        if (err.code) { hilog.error(0x0001, 'NihongoApp', 'PAGE_LOAD_FAILED code=%{public}d', err.code); }
      });
    } catch (err) { hilog.error(0x0001, 'NihongoApp', 'PAGE_LOAD_FAILED'); }
  }
}
