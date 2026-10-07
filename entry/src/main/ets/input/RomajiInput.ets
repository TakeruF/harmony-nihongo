// Incremental romaji decoder. Pending letters are visible, but never queried as kana.
export class RomajiInput {
  private buffer: string = '';
  // After nn, the second n may start na/nya, without showing another n.
  private carryN: boolean = false;
  private static table: Record<string, string> = {
    'a':'あ','i':'い','u':'う','e':'え','o':'お',
    'ka':'か','ki':'き','ku':'く','ke':'け','ko':'こ', 'kya':'きゃ','kyu':'きゅ','kyo':'きょ',
    'sa':'さ','si':'し','su':'す','se':'せ','so':'そ','shi':'し','sha':'しゃ','shu':'しゅ','sho':'しょ','sya':'しゃ','syu':'しゅ','syo':'しょ',
    'ta':'た','ti':'ち','tu':'つ','te':'て','to':'と','chi':'ち','tsu':'つ','cha':'ちゃ','chu':'ちゅ','cho':'ちょ','tya':'ちゃ','tyu':'ちゅ','tyo':'ちょ','cya':'ちゃ','cyu':'ちゅ','cyo':'ちょ',
    'na':'な','ni':'に','nu':'ぬ','ne':'ね','no':'の','nya':'にゃ','nyu':'にゅ','nyo':'にょ',
    'ha':'は','hi':'ひ','hu':'ふ','he':'へ','ho':'ほ','fu':'ふ','hya':'ひゃ','hyu':'ひゅ','hyo':'ひょ',
    'ma':'ま','mi':'み','mu':'む','me':'め','mo':'も','mya':'みゃ','myu':'みゅ','myo':'みょ',
    'ya':'や','yu':'ゆ','yo':'よ','ra':'ら','ri':'り','ru':'る','re':'れ','ro':'ろ','rya':'りゃ','ryu':'りゅ','ryo':'りょ','wa':'わ','wo':'を','wi':'うぃ','we':'うぇ',
    'ga':'が','gi':'ぎ','gu':'ぐ','ge':'げ','go':'ご','gya':'ぎゃ','gyu':'ぎゅ','gyo':'ぎょ',
    'za':'ざ','zi':'じ','zu':'ず','ze':'ぜ','zo':'ぞ','ji':'じ','ja':'じゃ','ju':'じゅ','jo':'じょ','jya':'じゃ','jyu':'じゅ','jyo':'じょ','zya':'じゃ','zyu':'じゅ','zyo':'じょ',
    'da':'だ','di':'ぢ','du':'づ','de':'で','do':'ど','dya':'ぢゃ','dyu':'ぢゅ','dyo':'ぢょ',
    'ba':'ば','bi':'び','bu':'ぶ','be':'べ','bo':'ぼ','bya':'びゃ','byu':'びゅ','byo':'びょ',
    'pa':'ぱ','pi':'ぴ','pu':'ぷ','pe':'ぺ','po':'ぽ','pya':'ぴゃ','pyu':'ぴゅ','pyo':'ぴょ',
    'xa':'ぁ','xi':'ぃ','xu':'ぅ','xe':'ぇ','xo':'ぉ','la':'ぁ','li':'ぃ','lu':'ぅ','le':'ぇ','lo':'ぉ',
    'xya':'ゃ','xyu':'ゅ','xyo':'ょ','lya':'ゃ','lyu':'ゅ','lyo':'ょ','xtu':'っ','xtsu':'っ','ltu':'っ','ltsu':'っ','xwa':'ゎ','lwa':'ゎ','xka':'ゕ','xke':'ゖ',
    'fa':'ふぁ','fi':'ふぃ','fe':'ふぇ','fo':'ふぉ','fyu':'ふゅ','va':'ゔぁ','vi':'ゔぃ','vu':'ゔ','ve':'ゔぇ','vo':'ゔぉ',
    'she':'しぇ','je':'じぇ','che':'ちぇ','thi':'てぃ','thu':'てゅ','dhi':'でぃ','dhu':'でゅ','tsa':'つぁ','tsi':'つぃ','tse':'つぇ','tso':'つぉ',
    'tcha':'っちゃ','tchu':'っちゅ','tcho':'っちょ',
    '-':'ー',',':'、','.':'。','/':'・',"n'":'ん'
  };
  get pending(): string { return this.carryN ? '' : this.buffer; }
  reset(): void { this.buffer = ''; this.carryN = false; }
  finish(): string {
    const result = this.carryN ? '' : (this.buffer === 'n' ? 'ん' : this.buffer);
    this.reset(); return result;
  }
  erase(): boolean {
    if (this.pending.length === 0) { this.reset(); return false; }
    this.buffer = this.buffer.slice(0, -1); return true;
  }
  feed(letter: string): string {
    let output = '';
    for (const character of letter.toLowerCase()) {
      if (this.carryN) {
        this.carryN = false;
        if ('aiueoy'.indexOf(character) < 0) { this.buffer = ''; }
      }
      this.buffer += character;
      while (this.buffer.length > 0) {
        const direct = RomajiInput.table[this.buffer];
        if (direct !== undefined) { output += direct; this.buffer = ''; break; }
        if (this.buffer === 'nn') { output += 'ん'; this.buffer = 'n'; this.carryN = true; break; }
        if (this.buffer.length > 1 && this.buffer[0] === 'n' && 'aiueoy'.indexOf(this.buffer[1]) < 0) {
          output += 'ん'; this.buffer = this.buffer.slice(1); continue;
        }
        if (this.buffer.length > 1 && this.buffer[0] === this.buffer[1] && 'aiueon'.indexOf(this.buffer[0]) < 0 && /[a-z]/.test(this.buffer[0])) {
          output += 'っ'; this.buffer = this.buffer.slice(1); continue;
        }
        if (this.buffer === 'n' || Object.keys(RomajiInput.table).some((key: string) => key.startsWith(this.buffer))) { break; }
        output += this.buffer[0]; this.buffer = this.buffer.slice(1);
      }
    }
    return output;
  }
}
