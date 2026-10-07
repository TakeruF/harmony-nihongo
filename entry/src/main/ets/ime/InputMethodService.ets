import { InputMethodExtensionAbility } from '@kit.IMEKit';
import { imeController } from './ImeController';
export default class InputMethodService extends InputMethodExtensionAbility {
  onCreate(): void { imeController.start(this.context); }
  onDestroy(): void { imeController.stop(); }
}
