// Gboard 14.2 default light theme, measured at 1080 x 2400 / 420 dpi.
// Constants below are normalized to the existing 940-unit layout reference.
export class KeyboardMetrics {
  readonly margin: number;
  readonly gap: number;
  readonly alphaGap: number;
  readonly numberGap: number;
  readonly alphaHeight: number;
  readonly numberHeight: number;
  readonly alphaWidth: number;
  readonly numberWidth: number;
  readonly toolbarHeight: number;
  readonly panelHeight: number;
  readonly bottomPadding: number;
  readonly popupInset: number;
  constructor(width: number, height: number = width * 3, availablePanelHeight: number = height) {
    const reference = 940 / 1080;
    const panel = 772 * reference;
    const scale = Math.min(width, height) / 940;
    const verticalScale = Math.min(width / 940, height * 0.55 / panel, availablePanelHeight / panel);
    this.margin = 12 * reference * scale;
    this.gap = 12 * reference * scale;
    this.alphaGap = 26 * verticalScale;
    this.numberGap = 15 * reference * verticalScale;
    this.alphaHeight = 110 * verticalScale;
    this.numberHeight = 140 * reference * verticalScale;
    this.alphaWidth = (width - this.margin * 2 - this.gap * 9) / 10;
    this.numberWidth = (width - this.margin * 2 - this.gap * 4) / 5;
    this.toolbarHeight = 144 * reference * verticalScale;
    this.panelHeight = panel * verticalScale;
    this.bottomPadding = 23 * reference * verticalScale;
    // Top-row popups cross the toolbar edge. Reserve a transparent strip for them.
    this.popupInset = 30 * verticalScale + 5;
  }
}
