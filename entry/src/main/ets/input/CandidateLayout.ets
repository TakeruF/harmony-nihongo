export class CandidateChoice {
  value: string;
  context: number;
  constructor(value: string, context: number) { this.value = value; this.context = context; }
}
export class CandidateRow {
  context: number = 0;
  values: string[] = [];
  spans: number[] = [];
}
// Four columns; long whole-reading candidates occupy enough adjacent columns.
export function candidateRows(values: string[], width: number, fontSize: number = 17, context: number = 0): CandidateRow[] {
  const rows: CandidateRow[] = [];
  const cellWidth = width / 4;
  let row = new CandidateRow();
  let used = 0;
  for (let i = 0; i < values.length; i++) {
    const value = values[i];
    let units = 0;
    for (let j = 0; j < value.length; j++) { units += value.charCodeAt(j) < 128 ? 0.55 : 1; }
    const span = Math.min(4, Math.max(1, Math.ceil((units * fontSize + 20) / cellWidth)));
    if (used + span > 4) { rows.push(row); row = new CandidateRow(); used = 0; }
    row.values.push(value); row.spans.push(span); used += span;
    if (used === 4) { rows.push(row); row = new CandidateRow(); used = 0; }
  }
  if (row.values.length > 0) { rows.push(row); }
  rows.forEach((item: CandidateRow) => { item.context = context; });
  return rows;
}
