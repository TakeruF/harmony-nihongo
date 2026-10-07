// Cursor reads do not modify the editor. A missing reply can safely disable live
// preview before any text mutation, while keeping local conversion available.
export function probePreviewCursor(read: () => Promise<number>, timeout: number = 400): Promise<number | undefined> {
  return new Promise<number | undefined>((resolve, reject) => {
    let settled = false;
    const timer = setTimeout(() => { settled = true; resolve(undefined); }, timeout);
    read().then((index: number) => {
      if (settled) { return; }
      settled = true; clearTimeout(timer); resolve(index);
    }).catch((error: Error) => {
      if (settled) { return; }
      settled = true; clearTimeout(timer); reject(error);
    });
  });
}
