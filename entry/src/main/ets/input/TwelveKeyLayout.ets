// Measured from Gboard 14.2 Japanese 12-key; center, left, up, right, down.
export class TwelveKeyGroup {
  readonly label: string;
  readonly hint: string;
  readonly values: string[];
  constructor(label: string, hint: string, values: string[]) {
    this.label = label; this.hint = hint; this.values = values;
  }
}
export class TwelveKeyLayout {
  static alphabetTapValues(values: string[]): string[] {
    const present = values.filter((value: string) => value.length > 0);
    const letters = present.filter((value: string) => /^[a-z]$/.test(value));
    if (letters.length === 0) { return present; }
    return letters.concat(letters.map((value: string) => value.toUpperCase()),
      present.filter((value: string) => /^[0-9]$/.test(value)));
  }

  static readonly numbers: TwelveKeyGroup[][] = [
    [new TwelveKeyGroup("1", "☆♪→", ["1", "☆", "♪", "→", ""]), new TwelveKeyGroup("2", "¥$€", ["2", "¥", "$", "€", ""]), new TwelveKeyGroup("3", "%゜#", ["3", "%", "゜", "#", ""])],
    [new TwelveKeyGroup("4", "○*・", ["4", "○", "*", "・", ""]), new TwelveKeyGroup("5", "+×÷", ["5", "+", "×", "÷", ""]), new TwelveKeyGroup("6", "<=>", ["6", "<", "=", ">", ""])],
    [new TwelveKeyGroup("7", "「」:", ["7", "「", "」", ":", ""]), new TwelveKeyGroup("8", "〒々〆", ["8", "〒", "々", "〆", ""]), new TwelveKeyGroup("9", "^|\\", ["9", "^", "|", "\\", ""])]
  ];
  static readonly brackets: TwelveKeyGroup = new TwelveKeyGroup("()[]", ")[]", ["(", ")", "[", "]", ""]);
  static readonly zero: TwelveKeyGroup = new TwelveKeyGroup("0", "〜…@", ["0", "〜", "…", "@", ""]);
  static readonly numberPunctuation: TwelveKeyGroup = new TwelveKeyGroup(".,-/", ",-/", [".", ",", "-", "/", ""]);
  static readonly alphabet: TwelveKeyGroup[][] = [
    [new TwelveKeyGroup('@-_/', '1', ['@','-','_','/','1']),
      new TwelveKeyGroup('ABC', '2', ['a','b','c','','2']),
      new TwelveKeyGroup('DEF', '3', ['d','e','f','','3'])],
    [new TwelveKeyGroup('GHI', '4', ['g','h','i','','4']),
      new TwelveKeyGroup('JKL', '5', ['j','k','l','','5']),
      new TwelveKeyGroup('MNO', '6', ['m','n','o','','6'])],
    [new TwelveKeyGroup('PQRS', '7', ['p','q','r','s','7']),
      new TwelveKeyGroup('TUV', '8', ['t','u','v','','8']),
      new TwelveKeyGroup('WXYZ', '9', ['w','x','y','z','9'])]
  ];
  static readonly quotes: TwelveKeyGroup = new TwelveKeyGroup("'\":;", '0', ["'", '\"', ':', ';', '0']);
  static readonly alphabetPunctuation: TwelveKeyGroup = new TwelveKeyGroup('.,?!', '', ['.',',','?','!','']);
}
