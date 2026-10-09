// ArkUI onChange reports committed text separately from its OS-managed preview.
// Bind the full visible value back to TextArea so a redraw cannot erase preview.
export function previewFieldValue(value: string, previewValue: string = '', offset: number = 0): string {
  if (previewValue.length === 0) { return value; }
  if (!Number.isInteger(offset) || offset < 0 || offset > value.length) { return value; }
  return value.slice(0, offset) + previewValue + value.slice(offset);
}
