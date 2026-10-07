// Ratios measured from the supplied 940 px-wide Gboard screenshots.
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
  constructor(width: number, height: number = width * 3, availablePanelHeight: number = height) {
    const scale = Math.min(width, height) / 940;
    const verticalScale = Math.min(width / 940, height * 0.55 / 688, availablePanelHeight / 688);
    this.margin = 11 * scale;
    this.gap = 12 * scale;
    this.alphaGap = 26 * verticalScale;
    this.numberGap = 16 * verticalScale;
    this.alphaHeight = 110 * verticalScale;
    this.numberHeight = 121 * verticalScale;
    this.alphaWidth = (width - this.margin * 2 - this.gap * 9) / 10;
    this.numberWidth = (width - this.margin * 2 - this.gap * 4) / 5;
    this.toolbarHeight = 136 * verticalScale;
    this.panelHeight = 688 * verticalScale;
    this.bottomPadding = Math.min(8, 20 * verticalScale);
  }
}
