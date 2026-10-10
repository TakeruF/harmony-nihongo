// Diagnostic only: no startListening, audio capture, microphone permission or input writes.
import { speechRecognizer } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

async function probe(language: string, online: number): Promise<void> {
  let engine: speechRecognizer.SpeechRecognitionEngine | undefined;
  const label = language + ' mode=' + online;
  hilog.info(0x0001, 'VoiceCapability', 'BEGIN %{public}s', label);
  try {
    engine = await speechRecognizer.createEngine({ language: language, online: online,
      extraParams: { locate: 'CN', recognizerMode: 'short' } });
    hilog.info(0x0001, 'VoiceCapability', 'CREATED %{public}s', label);
    engine.setListener({
      onStart: (_session: string, _message: string) => {},
      onEvent: (_session: string, _code: number, _message: string) => {},
      onResult: (_session: string, _result: speechRecognizer.SpeechRecognitionResult) => {},
      onComplete: (_session: string, _message: string) => {},
      onError: (_session: string, code: number, message: string) => {
        hilog.info(0x0001, 'VoiceCapability', 'LISTENER_ERROR %{public}s code=%{public}d message=%{public}s', label, code, message);
      }
    });
    const languages = await engine.listLanguages({ sessionId: 'nihongo_capability_probe', extraParams: { online: online } });
    hilog.info(0x0001, 'VoiceCapability', 'LANGUAGES %{public}s %{public}s', label, JSON.stringify(languages));
  } catch (error) {
    const failure = error as BusinessError;
    hilog.info(0x0001, 'VoiceCapability', 'FAILED %{public}s code=%{public}d message=%{public}s', label, failure.code, failure.message);
  } finally {
    if (engine) {
      try { engine.shutdown(); }
      catch (error) {
        const failure = error as BusinessError;
        hilog.info(0x0001, 'VoiceCapability', 'SHUTDOWN_FAILED %{public}s code=%{public}d', label, failure.code);
      }
    }
    hilog.info(0x0001, 'VoiceCapability', 'END %{public}s', label);
  }
}

export async function probeSpeechCapabilities(): Promise<void> {
  await probe('zh-CN', 1);
  await probe('ja-JP', 1);
  await probe('ja-JP', 0);
  hilog.info(0x0001, 'VoiceCapability', 'DONE');
}
