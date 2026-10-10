import { KeyboardMetrics } from './KeyboardMetrics';
import { KeyboardPalette } from './KeyboardPalette';

@Component
export struct PanelBackButton {
  @Prop metrics: KeyboardMetrics;
  @Prop identifier: string = '';
  @Prop label: string = 'キーボードに戻る';
  @Prop editing: boolean = false;
  @Prop buttonBackground: string = KeyboardPalette.panelCard;
  onBack: () => void = () => {};
  build() {
    Button() {
      Image(this.editing ? $r('app.media.ic_close') : $r('app.media.ic_back'))
        .width(this.metrics.toolbarHeight * 0.38).height(this.metrics.toolbarHeight * 0.38)
    }.width(this.metrics.toolbarHeight * 0.7).height(this.metrics.toolbarHeight * 0.7)
      .padding(0).backgroundColor(this.buttonBackground).borderRadius(this.metrics.toolbarHeight)
      .id(this.identifier).accessibilityText(this.label).onClick(() => { this.onBack(); })
  }
}
