import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

class KeyboardHaptics {
  private effect: vibrator.VibrateEffect = { type: 'time', duration: 10 };
  private initialized: boolean = false;
  private reported: boolean = false;

  initialize(): void {
    if (AppStorage.get<boolean>('imeHapticsAllowed') !== true) { return; }
    if (this.initialized) { return; }
    this.initialized = true;
    try {
      if (vibrator.isSupportEffectSync('haptic.clock.timer')) {
        this.effect = { type: 'preset', effectId: 'haptic.clock.timer', count: 1 };
      }
    } catch (err) { this.report(err as BusinessError); }
  }

  // Never await vibration in the input queue. Touch usage respects system haptic settings.
  tap(): void {
    if (AppStorage.get<boolean>('imeHapticsAllowed') !== true || AppStorage.get<boolean>('imeHaptics') === false) { return; }
    this.initialize();
    try {
      vibrator.startVibration(this.effect, { usage: 'touch' })
        .catch((err: BusinessError) => { this.report(err); });
    } catch (err) { this.report(err as BusinessError); }
  }

  private report(err: BusinessError): void {
    if (this.reported) { return; }
    this.reported = true;
    hilog.warn(0x0001, 'NihongoIME', 'HAPTIC_UNAVAILABLE code=%{public}d', err.code);
  }
}

export const keyboardHaptics = new KeyboardHaptics();
