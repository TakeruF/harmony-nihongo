import { inputMethodEngine, InputMethodExtensionContext } from '@kit.IMEKit';
import { display } from '@kit.ArkUI';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import nativeProbe from 'libnihongo.so';
import { keyboardSettings } from './KeyboardSettings';
import { ReconversionSelection } from '../input/ReconversionSelection';
import { SegmentComposition } from '../input/SegmentComposition';
import { RomajiInput } from '../input/RomajiInput';
import { clipboardHistory } from '../input/ClipboardHistory';
import { KanaComposition } from '../input/KanaComposition';
import { probePreviewCursor } from '../input/PreviewCursorProbe';
import { KeyboardMetrics } from './KeyboardMetrics';
import { MozcEngine } from './MozcEngine';

class KanaSession {
  composition: KanaComposition = new KanaComposition();
  romaji: RomajiInput = new RomajiInput();
  reconversion?: ReconversionSelection;
  conversion?: SegmentComposition;
  preview: boolean = false;
  supported: boolean = true;
  dispatchOnlyEditor: boolean = false;
  anchor: number = -1;
  updating: boolean = false;
}

// Owns OS state. All editor operations are serialized and bound to a client generation.
class ImeController {
  private context?: InputMethodExtensionContext;
  private engine: MozcEngine = new MozcEngine();
  private revision: number = 0;
  private selectionBegin: number = -1;
  private selectionEnd: number = -1;
  private selectionEpoch: number = 0;
  private editorActionEpoch: number = 0;
  private editorEnterType: number = inputMethodEngine.ENTER_KEY_TYPE_UNSPECIFIED;
  private operationErrorEpoch: number = 0;
  private expectedSelections: ReconversionSelection[] = [];
  private selectionTimer: number = -1;
  private candidateTimer: number = -1;
  private candidateBusy: boolean = false;
  private candidates: string[] = [];
  private learningAllowed: boolean = false;
  private clipboardAllowed: boolean = false;
  get canUseClipboard(): boolean { return this.active && this.visible && this.clipboardAllowed; }
  private candidateReading: string = '';
  private kana: KanaSession = new KanaSession();
  get sessionId(): number { return this.generation; }
  private delegate = inputMethodEngine.getKeyboardDelegate();
  private ability = inputMethodEngine.getInputMethodAbility();
  private panel?: inputMethodEngine.Panel;
  private layoutQueue: Promise<void> = Promise.resolve();
  private onDisplayChange = (_id: number): void => {
    this.resizePanel().catch((err: BusinessError) => { this.report(err); });
  };
  private resizePanel(): Promise<void> {
    const panel = this.panel;
    const lifecycle = this.lifecycle;
    this.layoutQueue = this.layoutQueue.catch(() => {}).then(async () => {
      if (!panel || !this.active || lifecycle !== this.lifecycle || panel !== this.panel) { return; }
      const screen = display.getDefaultDisplaySync();
      const width = screen.width / screen.densityPixels;
      const height = screen.height / screen.densityPixels;
      const metrics = new KeyboardMetrics(width, height);
      let popupInset = deviceInfo.sdkApiVersion >= 21 ? metrics.popupInset : 0;
      let panelLeft = 0;
      let panelRight = 0;
      let keyboardHeight = metrics.panelHeight;
      if (popupInset > 0) {
        try {
          // Rotation rectangles must each fit their own screen orientation.
          const systemInsets = await panel.getSystemPanelCurrentInsets(screen.id);
          if (!this.active || lifecycle !== this.lifecycle || panel !== this.panel) { return; }
          const systemBottom = Math.max(0, systemInsets.bottom);
          panelLeft = Math.max(0, systemInsets.left);
          panelRight = Math.max(0, systemInsets.right);
          const portraitActive = screen.width <= screen.height;
          const portraitWidth = Math.min(screen.width, screen.height);
          const portraitHeight = Math.max(screen.width, screen.height);
          const portrait = new KeyboardMetrics((portraitWidth - (portraitActive ? panelLeft + panelRight : 0)) / screen.densityPixels, portraitHeight / screen.densityPixels);
          const landscape = new KeyboardMetrics((portraitHeight - (portraitActive ? 0 : panelLeft + panelRight)) / screen.densityPixels, portraitWidth / screen.densityPixels);
          const current = portraitActive ? portrait : landscape;
          keyboardHeight = current.panelHeight; popupInset = current.popupInset;
          const portraitInset = Math.ceil(portrait.popupInset * screen.densityPixels);
          const landscapeInset = Math.ceil(landscape.popupInset * screen.densityPixels);
          const portraitKeys = Math.round(portrait.panelHeight * screen.densityPixels);
          const landscapeKeys = Math.round(landscape.panelHeight * screen.densityPixels);
          panel.adjustPanelRect(inputMethodEngine.PanelFlag.FLG_FIXED, {
            portraitRect: { left: 0, top: 0, width: portraitWidth, height: portraitKeys + portraitInset + systemBottom },
            landscapeRect: { left: 0, top: 0, width: portraitHeight, height: landscapeKeys + landscapeInset + systemBottom },
            portraitAvoidY: portraitInset, landscapeAvoidY: landscapeInset,
            portraitInputRegion: [{ left: portraitActive ? panelLeft : 0, top: portraitInset,
              width: portraitWidth - (portraitActive ? panelLeft + panelRight : 0), height: portraitKeys }],
            landscapeInputRegion: [{ left: portraitActive ? 0 : panelLeft, top: landscapeInset,
              width: portraitHeight - (portraitActive ? 0 : panelLeft + panelRight), height: landscapeKeys }]
          });
        } catch (_) {
          if (!this.active || lifecycle !== this.lifecycle || panel !== this.panel) { return; }
          popupInset = 0; panelLeft = 0; panelRight = 0; keyboardHeight = metrics.panelHeight;
          await panel.resize(screen.width, Math.round(metrics.panelHeight * screen.densityPixels));
          hilog.info(0x0001, 'NihongoIME', 'POPUP_PANEL_FALLBACK');
        }
      } else {
        await panel.resize(screen.width, Math.round(metrics.panelHeight * screen.densityPixels));
      }
      if (!this.active || lifecycle !== this.lifecycle || panel !== this.panel) { return; }
      AppStorage.setOrCreate('imeKeyboardHeight', keyboardHeight);
      AppStorage.setOrCreate('imePanelLeft', panelLeft / screen.densityPixels);
      AppStorage.setOrCreate('imePanelRight', panelRight / screen.densityPixels);
      AppStorage.setOrCreate('imePopupInset', popupInset);
      AppStorage.setOrCreate('imeScreenWidth', width);
      AppStorage.setOrCreate('imeScreenHeight', height);
    });
    return this.layoutQueue;
  }
  private client?: inputMethodEngine.InputClient;
  private keyboard?: inputMethodEngine.KeyboardController;
  private generation: number = 0;
  private lifecycle: number = 0;
  private active: boolean = false;
  private visible: boolean = false;
  private ready: boolean = false;
  private queue: Promise<void> = Promise.resolve();
  private onStart = (keyboard: inputMethodEngine.KeyboardController, client: inputMethodEngine.InputClient): void => {
    this.generation++;
    AppStorage.setOrCreate('imeEditorSession', this.generation);
    AppStorage.setOrCreate('imeEditorWindowId', -1);
    this.queue = Promise.resolve();
    this.clearSelection();
    keyboardSettings.refresh();
    this.kana = new KanaSession();
    this.publishKana();
    this.client = client;
    this.editorEnterType = inputMethodEngine.ENTER_KEY_TYPE_UNSPECIFIED;
    const state = this.kana;
    this.queue = Promise.resolve().then(() => this.prepareEditorIo(client, state));
    AppStorage.setOrCreate('imeEnterLabel', '改行');
    AppStorage.setOrCreate('imeForceNumber', false);
    this.learningAllowed = false;
    const generation = this.generation;
    const actionEpoch = ++this.editorActionEpoch;
    client.getEditorAttribute().then((attr: inputMethodEngine.EditorAttribute) => {
      if (generation !== this.generation || actionEpoch !== this.editorActionEpoch) { return; }
      if (actionEpoch === this.editorActionEpoch && this.visible) { this.publishEditorAction(attr); }
      // PATTERN_NULL is the documented generic editor type, not a failed attribute query.
      this.learningAllowed = attr.inputPattern === inputMethodEngine.PATTERN_TEXT ||
        attr.inputPattern === inputMethodEngine.PATTERN_NULL;
      hilog.info(0x0001, 'NihongoIME', 'EDITOR_LEARNING pattern=%{public}d text=%{public}d allowed=%{public}d',
        attr.inputPattern, inputMethodEngine.PATTERN_TEXT, this.learningAllowed ? 1 : 0);
      this.publishKana();
    }).catch((err: BusinessError) => {
      hilog.info(0x0001, 'NihongoIME', 'EDITOR_ATTRIBUTE_FAILED code=%{public}d', err.code);
    });
    hilog.info(0x0001, 'NihongoIME', 'EDITOR_ATTACHED');
    this.keyboard = keyboard;
    this.visible = true;
    AppStorage.setOrCreate('imeVisible', true);
    AppStorage.setOrCreate('imeError', '');
    this.showPanel();
    this.probe();
  };
  private onStop = (): void => {
    this.generation++;
    AppStorage.setOrCreate('imeEditorSession', this.generation);
    AppStorage.setOrCreate('imeEditorWindowId', -1);
    this.queue = Promise.resolve();
    this.clearSelection();
    this.kana = new KanaSession();
    this.publishKana();
    this.client = undefined;
    this.keyboard = undefined;
    this.visible = false;
    AppStorage.setOrCreate('imeVisible', false);
    this.panel?.hide().catch((err: BusinessError) => { this.report(err); });
  };
  private onShow = (): void => { this.visible = true; AppStorage.setOrCreate('imeVisible', true); this.showPanel(); };
  private onHide = (): void => {
    this.visible = false;
    AppStorage.setOrCreate('imeVisible', false);
    this.panel?.hide().catch((err: BusinessError) => { this.report(err); });
  };
  private onSelection = (_oldBegin: number, _oldEnd: number, begin: number, end: number): void => {
    const state = this.kana;
    const start = Math.min(begin, end);
    const finish = Math.max(begin, end);
    const expected = this.expectedSelections.findIndex((range: ReconversionSelection) => range.start === start && range.end === finish);
    if (expected >= 0) {
      this.expectedSelections.splice(0, expected + 1);
      if (state.composition.reading.length === 0) { this.selectionBegin = start; this.selectionEnd = finish; this.publishSelection(); }
      return;
    }
    this.expectedSelections = [];
    if (state.updating) { return; }
    this.selectionBegin = start; this.selectionEnd = finish; this.selectionEpoch++;
    if (state.composition.reading.length === 0) { this.publishSelection(); return; }
    if (state.dispatchOnlyEditor && state.preview) {
      // The bridge does not report a reliable composing anchor. A cleared
      // editor (for example after the app's Send button) must retire the reading.
      if (begin === 0 && end === 0 && (_oldBegin > 0 || _oldEnd > 0)) {
        this.retireBridgeComposition(state);
      }
      return;
    }
    if (!state.preview) {
      // Local-only composition must not follow an externally moved editor caret.
      this.generation++; this.kana = new KanaSession(); this.publishKana(); return;
    }
    if (begin === end && begin === state.anchor + (state.conversion?.text.length ?? state.composition.reading.length)) { return; }
    if (begin === end && begin >= state.anchor && begin <= state.anchor + (state.conversion?.text.length ?? state.composition.reading.length)) {
      state.composition.cursor = Math.min(begin - state.anchor, state.composition.reading.length);
      if (state.conversion) {
        state.conversion = undefined;
        this.enqueue((client: inputMethodEngine.InputClient) => this.previewKana(client, state));
        return;
      }
      this.publishKana();
      return;
    }
    // The editor finalizes preview when its selection leaves the composing range.
    // Invalidate pending editing and flicks so they cannot reopen it elsewhere.
    this.generation++;
    this.kana = new KanaSession();
    this.publishKana();
  };
  private retireBridgeComposition(state: KanaSession): void {
    if (state !== this.kana) { return; }
    const next = new KanaSession();
    next.dispatchOnlyEditor = state.dispatchOnlyEditor;
    next.supported = state.supported;
    this.generation++;
    this.kana = next;
    this.publishKana();
  }
  private onTextChange = (text: string): void => {
    const state = this.kana;
    if (state.dispatchOnlyEditor && state.preview && !state.updating && text.length === 0) {
      this.retireBridgeComposition(state);
    }
  };
  private publishEditorAction(attr: inputMethodEngine.EditorAttribute): void {
    AppStorage.setOrCreate('imeEditorWindowId', typeof attr.windowId === 'number' ? attr.windowId : -1);
    const pattern = attr.inputPattern;
    AppStorage.setOrCreate('imeForceNumber', typeof pattern === 'number' &&
      (pattern === inputMethodEngine.PATTERN_NUMBER || pattern === inputMethodEngine.PATTERN_PHONE ||
      pattern === inputMethodEngine.PATTERN_DATETIME));
    if (attr.isTextPreviewSupported === false && !this.kana.preview) {
      this.kana.supported = false;
      hilog.info(0x0001, 'NihongoIME', 'PREVIEW_DISABLED_BY_EDITOR');
    }
    if (typeof attr.enterKeyType !== 'number') { return; }
    const type = attr.enterKeyType;
    this.editorEnterType = type;
    AppStorage.setOrCreate('imeEnterLabel', type === inputMethodEngine.ENTER_KEY_TYPE_SEARCH ? '検索' :
      (type === inputMethodEngine.ENTER_KEY_TYPE_SEND ? '送信' :
      (type === inputMethodEngine.ENTER_KEY_TYPE_NEXT ? '次へ' :
      (type === inputMethodEngine.ENTER_KEY_TYPE_DONE ? '完了' :
      (type === inputMethodEngine.ENTER_KEY_TYPE_GO ? '移動' :
      (type === inputMethodEngine.ENTER_KEY_TYPE_PREVIOUS ? '前へ' : '改行'))))));
  }
  private onEditorAttribute = (attr: inputMethodEngine.EditorAttribute): void => {
    if (!this.active || !this.visible) { return; }
    // The framework updates attributes without restarting a shared InputClient.
    this.editorActionEpoch++;
    this.publishEditorAction(attr);
    this.learningAllowed = attr.inputPattern === inputMethodEngine.PATTERN_TEXT ||
      attr.inputPattern === inputMethodEngine.PATTERN_NULL;
    this.publishSelection();
  };
  private onMode = (mode: inputMethodEngine.SecurityMode): void => { this.updateMode(mode); this.probe(); };

  start(context: InputMethodExtensionContext): void {
    this.context = context;
    const settingsReady = keyboardSettings.load(context, false).catch((err: BusinessError) => { this.report(err); });
    this.active = true;
    const lifecycle = ++this.lifecycle;
    AppStorage.setOrCreate('imeEngineReady', false);
    this.engine.initialize(context).then(() => {
      if (!this.active || lifecycle !== this.lifecycle) { return; }
      AppStorage.setOrCreate('imeEngineReady', true);
      hilog.info(0x0001, 'NihongoIME', 'MOZC_READY');
      this.publishKana();
    }).catch(() => {
      if (!this.active || lifecycle !== this.lifecycle) { return; }
      AppStorage.setOrCreate('imeEngineReady', false);
      hilog.error(0x0001, 'NihongoIME', 'MOZC_INIT_FAILED');
    });
    AppStorage.setOrCreate('imeNativeStatus', 'C++ 検証中');
    AppStorage.setOrCreate('imeCanOpenSettings', false);
    AppStorage.setOrCreate('imeHapticsAllowed', false);
    AppStorage.setOrCreate('imeMode', '基礎モード');
    AppStorage.setOrCreate('imeError', '');
    try { this.updateMode(this.ability.getSecurityMode()); } catch (err) { this.report(err as BusinessError); }
    this.probe();
    display.on('change', this.onDisplayChange);
    this.delegate.on('selectionChange', this.onSelection);
    this.delegate.on('textChange', this.onTextChange);
    this.delegate.on('editorAttributeChanged', this.onEditorAttribute);
    this.ability.on('inputStart', this.onStart);
    this.ability.on('inputStop', this.onStop);
    this.ability.on('keyboardShow', this.onShow);
    this.ability.on('keyboardHide', this.onHide);
    this.ability.on('securityModeChange', this.onMode);
    this.ability.createPanel(context, {
      type: inputMethodEngine.PanelType.SOFT_KEYBOARD,
      flag: inputMethodEngine.PanelFlag.FLG_FIXED
    }).then(async (panel: inputMethodEngine.Panel) => {
      await settingsReady;
      if (!this.active || lifecycle !== this.lifecycle) { await this.ability.destroyPanel(panel); return; }
      this.panel = panel;
      await this.resizePanel();
      await panel.setUiContent('ime/Keyboard');
      if (!this.active || lifecycle !== this.lifecycle) { return; }
      this.ready = true;
      if (this.active && this.visible) { await panel.show(); }
    }).catch((err: BusinessError) => { this.report(err); });
  }
  stop(): void {
    clipboardHistory.clear();
    this.context = undefined;
    this.active = false;
    this.lifecycle++;
    this.ready = false;
    this.onStop();
    display.off('change', this.onDisplayChange);
    this.delegate.off('selectionChange', this.onSelection);
    this.delegate.off('textChange', this.onTextChange);
    this.delegate.off('editorAttributeChanged', this.onEditorAttribute);
    this.ability.off('inputStart', this.onStart);
    this.ability.off('inputStop', this.onStop);
    this.ability.off('keyboardShow', this.onShow);
    this.ability.off('keyboardHide', this.onHide);
    this.ability.off('securityModeChange', this.onMode);
    const panel = this.panel;
    this.panel = undefined;
    if (panel) { this.ability.destroyPanel(panel).catch((err: BusinessError) => { this.report(err); }); }
  }
  private updateMode(mode: inputMethodEngine.SecurityMode): void {
    this.clipboardAllowed = mode === inputMethodEngine.SecurityMode.FULL;
    if (!this.clipboardAllowed) { clipboardHistory.clear(); }
    AppStorage.setOrCreate('imeClipboardAllowed', this.clipboardAllowed);
    AppStorage.setOrCreate('imeHapticsAllowed', mode === inputMethodEngine.SecurityMode.FULL);
    AppStorage.setOrCreate('imeCanOpenSettings', mode !== inputMethodEngine.SecurityMode.BASIC);
    AppStorage.setOrCreate('imeMode', mode === inputMethodEngine.SecurityMode.BASIC ? '基礎モード' : '完全アクセス');
  }
  private probe(): void {
    try {
      const valid = nativeProbe.add(20, 22) === 42 && nativeProbe.echo('きょうは') === 'きょうは';
      AppStorage.setOrCreate('imeNativeStatus', valid ? 'C++ OK' : 'C++ NG');
      hilog.info(0x0001, 'NihongoIME', 'NATIVE_PROBE %{public}s mode=%{public}d',
        valid ? 'PASS' : 'FAIL', this.ability.getSecurityMode());
    } catch (err) { this.report(err as BusinessError); AppStorage.setOrCreate('imeNativeStatus', 'C++ NG'); }
  }
  private showPanel(): void {
    if (!this.ready) { return; }
    this.panel?.show().catch((err: BusinessError) => { this.report(err); });
  }
  private enqueue(action: (client: inputMethodEngine.InputClient) => Promise<boolean>): void {
    const client = this.client;
    const generation = this.generation;
    if (!client) { return; }
    this.queue = this.queue.then(async () => {
      if (generation !== this.generation || !this.active) { return; }
      const errorEpoch = this.operationErrorEpoch;
      const success = await action(client);
      hilog.info(0x0001, 'NihongoIME', 'EDITOR_OPERATION success=%{public}d', success ? 1 : 0);
      if (generation !== this.generation) { return; }
      if (!success || errorEpoch === this.operationErrorEpoch) {
        AppStorage.setOrCreate('imeError', success ? '' : '入力先への送信に失敗しました');
      }
    }).catch((err: BusinessError) => {
      if (generation === this.generation) { this.report(err); }
    });
  }
  private clearSelection(): void {
    this.selectionBegin = -1; this.selectionEnd = -1; this.selectionEpoch++;
    this.expectedSelections = [];
    if (this.selectionTimer >= 0) { clearTimeout(this.selectionTimer); this.selectionTimer = -1; }
  }
  private publishSelection(): void {
    const length = this.selectionEnd - this.selectionBegin;
    AppStorage.setOrCreate('imeCanReconvert', this.learningAllowed && this.kana.composition.reading.length === 0 &&
      !this.kana.dispatchOnlyEditor && this.selectionBegin >= 0 && length > 0 && length <= 128);
  }
  private expectSelection(start: number, end: number): void {
    this.expectedSelections.push(new ReconversionSelection(start, end, ''));
    if (this.expectedSelections.length > 8) { this.expectedSelections.shift(); }
    if (this.selectionTimer >= 0) { clearTimeout(this.selectionTimer); }
    this.selectionTimer = setTimeout(() => { this.expectedSelections = []; this.selectionTimer = -1; }, 300);
  }
  private readSelection(client: inputMethodEngine.InputClient, start: number, end: number): string {
    if (client !== this.client || start < 0 || end <= start || end - start > 128) { return ''; }
    // No text is modified. Synchronous calls keep the temporary caret move in one JS turn.
    this.expectSelection(end, end);
    client.selectByRangeSync({ start: end, end: end });
    try { return client.getForwardSync(end - start); }
    finally {
      if (client === this.client) {
        this.expectSelection(start, end);
        client.selectByRangeSync({ start: start, end: end });
      }
    }
  }
  private publishKana(): void {
    const composition = this.kana.composition;
    this.publishSelection();
    this.revision++;
    this.candidates = [];
    this.candidateReading = '';
    const conversion = this.kana.conversion;
    AppStorage.setOrCreate('imeCandidateContext', this.revision);
    AppStorage.setOrCreate('imeSegmentValue', conversion?.value ?? '');
    AppStorage.setOrCreate('imeSegmentMode', conversion !== undefined);
    AppStorage.setOrCreate('imeCandidates', conversion ? conversion.candidates : (composition.reading.length > 0 ? [composition.reading] : []));
    if (conversion) {
      if (this.candidateTimer >= 0) { clearTimeout(this.candidateTimer); this.candidateTimer = -1; }
    } else { this.scheduleConversion(); }
    AppStorage.setOrCreate('imeReading', composition.reading);
    AppStorage.setOrCreate('imeCanReverse', composition.canReverse && !this.kana.conversion);
    AppStorage.setOrCreate('imeCompositionDisplay', composition.reading.length > 0 ? composition.display() : '');
  }
  private scheduleConversion(): void {
    if (this.candidateTimer >= 0) { clearTimeout(this.candidateTimer); }
    this.candidateTimer = setTimeout(() => { this.updateCandidates(); }, 40);
  }
  private async updateCandidates(): Promise<void> {
    this.candidateTimer = -1;
    if (this.candidateBusy || !this.active || this.kana.conversion !== undefined) { return; }
    const reading = this.kana.composition.reading;
    if (reading.length === 0 || this.kana.romaji.pending.length > 0) { return; }
    const revision = this.revision;
    const generation = this.generation;
    this.candidateBusy = true;
    try {
      const values = await this.engine.convert(reading, !this.learningAllowed);
      if (revision !== this.revision || generation !== this.generation || !this.active) { return; }
      this.candidates = values.filter((value: string, index: number) => value.length > 0 && values.indexOf(value) === index && value !== reading);
      this.candidateReading = reading;
      AppStorage.setOrCreate('imeCandidates', this.candidates.length > 0 ?
        [this.candidates[0], reading].concat(this.candidates.slice(1)) : [reading]);
    } catch (_) {
      hilog.error(0x0001, 'NihongoIME', 'MOZC_CONVERSION_FAILED');
    } finally {
      this.candidateBusy = false;
      if (revision !== this.revision && this.active) { this.scheduleConversion(); }
    }
  }
  selectCandidate(value: string, reading: string, session: number, context: number = -1): void {
    if (session !== this.generation) { return; }
    this.enqueue(async (client: inputMethodEngine.InputClient) => {
      if (context >= 0 && context !== this.revision) { return true; }
      if (reading !== this.kana.composition.reading) { return true; }
      if (this.kana.conversion) {
        if (!this.kana.conversion.select(value)) { return true; }
        return this.previewKana(client, this.kana);
      }
      if (reading !== this.kana.composition.reading ||
          (value !== reading && (this.candidateReading !== reading || this.candidates.indexOf(value) < 0))) { return Promise.resolve(true); }
      return this.commitState(client, this.kana, value);
    });
  }
  private async previewKana(client: inputMethodEngine.InputClient, state: KanaSession): Promise<boolean> {
    if (!this.ownsEditor(client, state)) { return true; }
    if (state === this.kana) { this.publishKana(); }
    if (!state.supported) { return true; }
    if (state.composition.reading.length === 0 && !state.preview) { return true; }
    state.updating = true;
    try {
      if (state.dispatchOnlyEditor) {
        await this.dispatchEditorOperation(client, () =>
          client.setPreviewText(state.conversion?.text ?? state.composition.reading,
            { start: -1, end: -1 }).then(() => true));
        state.preview = true;
        if (state.composition.reading.length === 0) {
          await this.dispatchEditorOperation(client, () => client.finishTextPreview().then(() => true));
          state.preview = false;
        }
        return true;
      }
      if (!state.preview) {
        const anchor = state.reconversion ? state.reconversion.start :
          await probePreviewCursor(() => client.getTextIndexAtCursor());
        if (!this.ownsEditor(client, state)) { return true; }
        if (anchor === undefined) {
          state.supported = false;
          state.dispatchOnlyEditor = true;
          hilog.info(0x0001, 'NihongoIME', 'PREVIEW_CURSOR_TIMEOUT_LOCAL_FALLBACK');
          return true;
        }
        state.anchor = anchor;
      }
      // Default range replaces the live selection when starting preview, then the preview itself.
      // Explicit absolute ranges are rejected for selected TextArea content on the tested device.
      await client.setPreviewText(state.conversion?.text ?? state.composition.reading, { start: -1, end: -1 });
      if (!this.ownsEditor(client, state)) { return true; }
      state.preview = true;
      if (state.composition.reading.length === 0) { await client.finishTextPreview(); state.preview = false; }
      return true;
    } catch (err) {
      const error = err as BusinessError;
      if (error.code === 12800011 && !state.preview) {
        state.supported = false;
        hilog.info(0x0001, 'NihongoIME', 'PREVIEW_LOCAL_FALLBACK');
        return true;
      }
      throw err as Error;
    } finally { state.updating = false; }
  }
  private ownsEditor(client: inputMethodEngine.InputClient, state: KanaSession): boolean {
    return this.active && client === this.client && state === this.kana;
  }
  private async prepareEditorIo(client: inputMethodEngine.InputClient, state: KanaSession): Promise<void> {
    if (!this.ownsEditor(client, state)) { return; }
    let cursor: number | undefined;
    try { cursor = await probePreviewCursor(() => client.getTextIndexAtCursor()); }
    catch (err) {
      // A cursor read may fail while the editor connects. It says nothing about
      // preview support; the next input will probe again before its first write.
      if (this.ownsEditor(client, state)) {
        hilog.info(0x0001, 'NihongoIME', 'CURSOR_PROBE_FAILED code=%{public}d', (err as BusinessError).code ?? 0);
      }
      return;
    }
    if (!this.ownsEditor(client, state) || cursor !== undefined) { return; }
    // Probe before ASCII, paste, delete, or kana can issue their first write.
    state.dispatchOnlyEditor = true;
    this.publishKana();
    hilog.info(0x0001, 'NihongoIME', 'EDITOR_DISPATCH_COMPATIBILITY');
  }
  private async commitState(client: inputMethodEngine.InputClient, state: KanaSession, selected?: string): Promise<boolean> {
    if (!this.ownsEditor(client, state)) { return false; }
    if (selected === state.composition.reading) { selected = undefined; }
    this.finishRomaji(state);
    if (state.composition.reading.length === 0) { return true; }
    const reading = state.composition.reading;
    const conversion = state.conversion;
    const value = selected === undefined ? (conversion?.text ?? reading) : selected;
    const learn = value !== reading && this.learningAllowed && !state.dispatchOnlyEditor &&
      (conversion !== undefined || selected !== undefined);
    state.updating = true;
    try {
      if (state.preview) {
        if (state.dispatchOnlyEditor) {
          await this.dispatchEditorOperation(client, () => client.setPreviewText(value, { start: -1, end: -1 }).then(() => true));
          await this.dispatchEditorOperation(client, () => client.finishTextPreview().then(() => true));
        } else {
          await client.setPreviewText(value, { start: -1, end: -1 });
          if (!this.ownsEditor(client, state)) { return false; }
          await client.finishTextPreview();
        }
      }
      else {
        if (state.reconversion && this.readSelection(client, state.reconversion.start, state.reconversion.end) !== state.reconversion.original) { return false; }
        if (!await this.insertEditorText(client, value)) { return false; }
      }
      if (!this.ownsEditor(client, state)) { return false; }
      state.preview = false;
      state.composition.clear();
      state.romaji.reset();
      state.conversion = undefined;
      state.reconversion = undefined;
      this.clearSelection();
      if (learn) {
        (conversion ? this.engine.learnSegments(reading, conversion.values, conversion.keys) : this.engine.learn(reading, value)).then((saved: boolean) => {
          hilog.info(0x0001, 'NihongoIME', 'MOZC_LEARNING saved=%{public}d', saved ? 1 : 0);
        }).catch(() => { hilog.error(0x0001, 'NihongoIME', 'MOZC_LEARNING_FAILED'); });
      }
      if (state === this.kana) { this.publishKana(); }
      return true;
    } finally { state.updating = false; }
  }
  private insertEditorText(client: inputMethodEngine.InputClient, text: string): Promise<boolean> {
    // Android compatibility bridges can apply async mutations without replying.
    // Dispatch once in queue order. Never retry an unacknowledged write, and do
    // not call blocking Sync APIs against an editor that does not reply.
    if (this.kana.dispatchOnlyEditor) { return this.dispatchEditorOperation(client, () => client.insertText(text)); }
    return client.insertText(text);
  }
  private deleteEditorText(client: inputMethodEngine.InputClient): Promise<boolean> {
    if (this.kana.dispatchOnlyEditor) { return this.dispatchEditorOperation(client, () => client.deleteForward(1)); }
    return client.deleteForward(1);
  }
  private dispatchEditorOperation(client: inputMethodEngine.InputClient, operation: () => Promise<boolean>): Promise<boolean> {
    const state = this.kana;
    const session = this.generation;
    operation().then((success: boolean) => {
      if (!success && session === this.generation && this.ownsEditor(client, state)) {
        this.operationErrorEpoch++;
        AppStorage.setOrCreate('imeError', '入力先が操作を受け付けませんでした');
      }
    }).catch((err: BusinessError) => {
      if (session === this.generation && this.ownsEditor(client, state)) { this.report(err); }
    });
    return Promise.resolve(true);
  }
  kanaInput(value: string, session: number, tapValues: string[] = [], pressedAt: number = Date.now()): void {
    if (session !== this.generation) { return; }
    this.enqueue(async (client: inputMethodEngine.InputClient) => {
      const state = this.kana;
      if (state.conversion && !await this.commitState(client, state)) { return false; }
      this.finishRomaji(state);
      if (tapValues.length > 0 && !keyboardSettings.enabled('imeFlickOnly')) {
        state.composition.tap(tapValues, pressedAt);
      } else { state.composition.insert(value); }
      return this.previewKana(client, state);
    });
  }
  private removePending(state: KanaSession): void {
    for (let index = 0; index < state.romaji.pending.length; index++) { state.composition.backspace(); }
  }
  private finishRomaji(state: KanaSession): void {
    if (state.romaji.pending.length === 0) { state.romaji.reset(); return; }
    this.removePending(state);
    state.composition.insert(state.romaji.finish());
  }
  romajiInput(letter: string, session: number): void {
    if (session !== this.generation) { return; }
    this.enqueue(async (client: inputMethodEngine.InputClient) => {
      const state = this.kana;
      if (state.conversion && !await this.commitState(client, state)) { return false; }
      this.removePending(state);
      const value = state.romaji.feed(letter);
      state.composition.insert(value + state.romaji.pending);
      return this.previewKana(client, state);
    });
  }
  transformKana(kind: string): void {
    this.enqueue(async (client: inputMethodEngine.InputClient) => {
      const state = this.kana;
      state.conversion = undefined;
      this.finishRomaji(state);
      state.composition.transform(kind);
      return this.previewKana(client, state);
    });
  }
  reconvertSelection(): void {
    this.enqueue(async (client: inputMethodEngine.InputClient) => {
      if (!this.learningAllowed || this.kana.composition.reading.length > 0) { return true; }
      const start = this.selectionBegin;
      const end = this.selectionEnd;
      if (start < 0 || end <= start || end - start > 128) { return true; }
      const original = this.readSelection(client, start, end);
      if (original.length !== end - start) { return true; }
      const epoch = this.selectionEpoch;
      const revision = this.revision;
      const generation = this.generation;
      this.engine.reverse(original).then(async (reading: string) => {
        if (reading.length === 0 || reading.length > 256 || generation !== this.generation || epoch !== this.selectionEpoch || revision !== this.revision) { return; }
        const rows = await this.engine.segments(reading, !this.learningAllowed);
        if (rows.length === 0 || generation !== this.generation || epoch !== this.selectionEpoch || revision !== this.revision || this.selectionBegin !== start || this.selectionEnd !== end || !this.active) { return; }
        const conversion = new SegmentComposition(reading, rows);
        this.enqueue(async (current: inputMethodEngine.InputClient) => {
          if (epoch !== this.selectionEpoch || revision !== this.revision || this.selectionBegin !== start || this.selectionEnd !== end || this.readSelection(current, start, end) !== original) { return true; }
          const state = new KanaSession();
          state.composition.insert(reading);
          state.conversion = conversion;
          state.reconversion = new ReconversionSelection(start, end, original);
          this.kana = state;
          return this.previewKana(current, state);
        });
      }).catch(() => { hilog.error(0x0001, 'NihongoIME', 'MOZC_RECONVERSION_FAILED'); });
      return true;
    });
  }
  private async cancelReconversion(client: inputMethodEngine.InputClient, state: KanaSession): Promise<boolean> {
    const original = state.reconversion;
    if (!original) { return true; }
    state.updating = true;
    try {
      if (state.preview) {
        await client.setPreviewText(original.original, { start: -1, end: -1 });
        await client.finishTextPreview();
        this.clearSelection();
      }
      state.preview = false; state.reconversion = undefined; state.conversion = undefined; state.composition.clear();
      state.romaji.reset();
      if (state === this.kana) { this.publishKana(); }
      return true;
    } finally { state.updating = false; }
  }
  startSegmentConversion(): void {
    this.enqueue(async (_client: inputMethodEngine.InputClient) => {
      const state = this.kana;
      if (state.conversion || state.composition.reading.length === 0) { return true; }
      const hadPending = state.romaji.pending.length > 0;
      this.finishRomaji(state);
      if (hadPending) { await this.previewKana(_client, state); }
      const reading = state.composition.reading;
      const revision = this.revision;
      const generation = this.generation;
      this.engine.segments(reading, !this.learningAllowed).then((rows: string[][]) => {
        if (generation !== this.generation || revision !== this.revision || !this.active || rows.length === 0) { return; }
        const conversion = new SegmentComposition(reading, rows);
        this.enqueue(async (client: inputMethodEngine.InputClient) => {
          if (state !== this.kana || revision !== this.revision) { return true; }
          state.conversion = conversion;
          return this.previewKana(client, state);
        });
      }).catch(() => { hilog.error(0x0001, 'NihongoIME', 'MOZC_SEGMENTS_FAILED'); });
      return true;
    });
  }
  moveSegment(delta: number, session: number, context: number): void {
    if (session !== this.generation) { return; }
    this.enqueue(async (_client: inputMethodEngine.InputClient) => {
      if (context !== this.revision || !this.kana.conversion) { return true; }
      this.kana.conversion.move(delta); this.publishKana(); return true;
    });
  }
  resizeSegment(delta: number, session: number, context: number): void {
    if (session !== this.generation || (delta !== -1 && delta !== 1)) { return; }
    this.enqueue(async (_client: inputMethodEngine.InputClient) => {
      const state = this.kana;
      const conversion = state.conversion;
      if (!conversion || context !== this.revision) { return true; }
      const lengths = conversion.lengths;
      if (lengths[conversion.focus] + delta <= 0 || (delta > 0 && conversion.focus === conversion.count - 1)) { return true; }
      const revision = this.revision;
      this.engine.resizeSegments(conversion.reading, lengths, conversion.focus, delta, !this.learningAllowed).then((rows: string[][]) => {
        if (session !== this.generation || revision !== this.revision || !this.active || rows.length === 0) { return; }
        const next = conversion.resized(rows);
        this.enqueue(async (client: inputMethodEngine.InputClient) => {
          if (state !== this.kana || state.conversion !== conversion || revision !== this.revision) { return true; }
          state.conversion = next;
          return this.previewKana(client, state);
        });
      }).catch(() => { hilog.error(0x0001, 'NihongoIME', 'MOZC_RESIZE_FAILED'); });
      return true;
    });
  }
  commitKana(): void {
    this.enqueue((client: inputMethodEngine.InputClient) => this.commitState(client, this.kana));
  }
  reverseKana(): void {
    this.enqueue(async (client: inputMethodEngine.InputClient) => {
      const state = this.kana;
      if (state.conversion || !state.composition.canReverse) { return true; }
      state.composition.reverseTap();
      return this.previewKana(client, state);
    });
  }
  cancelKana(): void {
    this.enqueue(async (client: inputMethodEngine.InputClient) => {
      const state = this.kana;
      if (state.reconversion) { return this.cancelReconversion(client, state); }
      if (state.conversion) { state.conversion = undefined; return this.previewKana(client, state); }
      if (state.preview) {
        state.updating = true;
        try {
          if (state.dispatchOnlyEditor) {
            await this.dispatchEditorOperation(client, () => client.setPreviewText('', { start: -1, end: -1 }).then(() => true));
            await this.dispatchEditorOperation(client, () => client.finishTextPreview().then(() => true));
          } else { await client.setPreviewText('', { start: -1, end: -1 }); await client.finishTextPreview(); }
        }
        finally { state.updating = false; }
      }
      state.preview = false;
      state.composition.clear();
      state.romaji.reset();
      if (state === this.kana) { this.publishKana(); }
      return true;
    });
  }
  insertClipboard(text: string, session: number): void {
    if (session !== this.generation || !this.canUseClipboard || text.length === 0 || text.length > 16384) { return; }
    this.enqueue(async (client: inputMethodEngine.InputClient) => {
      if (!this.canUseClipboard || !await this.commitState(client, this.kana)) { return false; }
      if (session !== this.generation || !this.canUseClipboard) { return false; }
      return this.insertEditorText(client, text);
    });
  }
  insert(text: string): void {
    this.enqueue(async (client: inputMethodEngine.InputClient) => {
      const state = this.kana;
      if (!await this.commitState(client, state) || !this.ownsEditor(client, state)) { return false; }
      return this.insertEditorText(client, text);
    });
  }
  kanaSpace(): void {
    this.enqueue((client: inputMethodEngine.InputClient) => this.kana.composition.reading.length > 0 ?
      this.commitState(client, this.kana) : this.insertEditorText(client, keyboardSettings.enabled('imeHalfSpace') ? ' ' : '　'));
  }
  backspace(): void {
    this.enqueue(async (client: inputMethodEngine.InputClient) => {
      const state = this.kana;
      if (state.composition.reading.length === 0) { return this.deleteEditorText(client); }
      if (state.reconversion) { return this.cancelReconversion(client, state); }
      if (state.conversion) { state.conversion = undefined; return this.previewKana(client, state); }
      state.romaji.erase();
      state.composition.backspace();
      return this.previewKana(client, state);
    });
  }
  enter(): void {
    this.enqueue(async (client: inputMethodEngine.InputClient) => {
      const state = this.kana;
      if (state.composition.reading.length > 0) { return this.commitState(client, state); }
      if (state.dispatchOnlyEditor) {
        const type = this.editorEnterType;
        if (type === inputMethodEngine.ENTER_KEY_TYPE_NEWLINE || type === inputMethodEngine.ENTER_KEY_TYPE_UNSPECIFIED) {
          return this.insertEditorText(client, '\n');
        }
        return this.dispatchEditorOperation(client, () => client.sendKeyFunction(type));
      }
      const attr = await client.getEditorAttribute();
      if (!this.ownsEditor(client, state)) { return false; }
      return client.sendKeyFunction(attr.enterKeyType);
    });
  }
  moveLeft(): void { this.move(-1); }
  moveRight(): void { this.move(1); }
  private move(delta: number): void {
    this.enqueue(async (client: inputMethodEngine.InputClient) => {
      if (this.kana.conversion) {
        this.kana.conversion.move(delta); this.publishKana(); return true;
      }
      if (this.kana.composition.reading.length > 0) {
        this.finishRomaji(this.kana);
        this.kana.composition.move(delta); return this.previewKana(client, this.kana);
      }
      const direction = delta < 0 ? inputMethodEngine.Direction.CURSOR_LEFT : inputMethodEngine.Direction.CURSOR_RIGHT;
      if (this.kana.dispatchOnlyEditor) {
        await this.dispatchEditorOperation(client, () => client.moveCursor(direction).then(() => true));
      } else { await client.moveCursor(direction); }
      return true;
    });
  }
  openAppSettings(): void {
    if (this.ability.getSecurityMode() === inputMethodEngine.SecurityMode.BASIC) { return; }
    this.context?.startAbility({ bundleName: 'com.takeruf.harmonynihongo', abilityName: 'EntryAbility',
      parameters: { openSettings: true } }).catch((err: BusinessError) => { this.report(err); });
  }
  hide(): void { this.keyboard?.hide().catch((err: BusinessError) => { this.report(err); }); }
  private report(err: BusinessError): void {
    this.operationErrorEpoch++;
    AppStorage.setOrCreate('imeError', '操作に失敗しました (' + err.code + ')');
    hilog.error(0x0001, 'NihongoIME', 'OPERATION_FAILED code=%{public}d', err.code);
  }
}
export const imeController = new ImeController();
