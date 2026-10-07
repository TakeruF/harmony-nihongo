import { InputMethodExtensionContext } from '@kit.IMEKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import nativeEngine from 'libnihongo.so';

// Dictionary and profile live inside the IME sandbox, including BASIC mode.
export class MozcEngine {
  private ready: boolean = false;
  async initialize(context: InputMethodExtensionContext): Promise<void> {
    const dictionary = context.filesDir + '/mozc-60fe4012.data';
    if (!fs.accessSync(dictionary)) {
      const data = await context.resourceManager.getRawFileContent('mozc.data');
      const temp = dictionary + '.tmp';
      const file = fs.openSync(temp, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      try {
        let offset = 0;
        while (offset < data.byteLength) {
          const written = fs.writeSync(file.fd, data.buffer.slice(offset), { length: data.byteLength - offset });
          if (written <= 0) { throw new Error('Dictionary write failed'); }
          offset += written;
        }
      } finally { fs.closeSync(file); }
      fs.renameSync(temp, dictionary);
    }
    this.ready = await nativeEngine.initializeMozc(dictionary, context.filesDir);
  }
  async convert(reading: string, privateMode: boolean = true): Promise<string[]> {
    if (!this.ready || reading.length === 0 || reading.length > 256) { return []; }
    return nativeEngine.convert(reading, privateMode);
  }
  async learn(reading: string, value: string): Promise<boolean> {
    if (!this.ready) { return false; }
    return nativeEngine.learn(reading, value);
  }
  async segments(reading: string, privateMode: boolean): Promise<string[][]> {
    if (!this.ready || reading.length === 0 || reading.length > 256) { return []; }
    return nativeEngine.segments(reading, privateMode);
  }
  async learnSegments(reading: string, values: string[], keys: string[]): Promise<boolean> {
    if (!this.ready) { return false; }
    return nativeEngine.learnSegments(reading, values, keys);
  }

  async resizeSegments(reading: string, lengths: number[], focus: number, delta: number, privateMode: boolean): Promise<string[][]> {
    if (!this.ready || reading.length === 0 || reading.length > 256) { return []; }
    return nativeEngine.resizeSegments(reading, lengths, focus, delta, privateMode);
  }

  async reverse(text: string): Promise<string> {
    if (!this.ready || text.length === 0 || text.length > 128) { return ''; }
    return nativeEngine.reverse(text);
  }

}
