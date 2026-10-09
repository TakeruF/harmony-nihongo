import { UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
export default class EntryAbility extends UIAbility {
  private stage?: window.WindowStage;
  private landscape: boolean = false;
  private orientation(): void { this.stage?.getMainWindowSync().setPreferredOrientation(this.landscape ? window.Orientation.LANDSCAPE : window.Orientation.PORTRAIT); }
  onCreate(want: Want): void { this.landscape = want.parameters?.validationLandscape === true; }
  onNewWant(want: Want): void { this.landscape = want.parameters?.validationLandscape === true; this.orientation(); }
  onWindowStageCreate(stage: window.WindowStage): void { this.stage = stage; this.orientation(); stage.loadContent('pages/Index'); }
}
