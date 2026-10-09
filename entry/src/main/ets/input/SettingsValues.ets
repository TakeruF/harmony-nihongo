export class SettingsValues {
  haptics: boolean = true;
  halfSpace: boolean = false;
  threeModes: boolean = true;
  flickOnly: boolean = false;
  keitaiOnly: boolean = false;
  set(key: string, value: boolean): void {
    if (key === 'imeHaptics') { this.haptics = value; }
    else if (key === 'imeHalfSpace') { this.halfSpace = value; }
    else if (key === 'imeThreeModes') { this.threeModes = value; }
    else if (key === 'imeFlickOnly') { this.flickOnly = value; if (value) { this.keitaiOnly = false; } }
    else if (key === 'imeKeitaiOnly') { this.keitaiOnly = value; if (value) { this.flickOnly = false; } }
  }
  valid(): boolean {
    return typeof this.haptics === 'boolean' && typeof this.halfSpace === 'boolean' && typeof this.threeModes === 'boolean' &&
      typeof this.flickOnly === 'boolean' && typeof this.keitaiOnly === 'boolean' && !(this.flickOnly && this.keitaiOnly);
  }
}
