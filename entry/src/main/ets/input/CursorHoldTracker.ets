class HeldCursor {
  timer: number = -1;
  fired: boolean = false;
  tap: () => void;
  constructor(tap: () => void) { this.tap = tap; }
}
// Direction keys defer short presses only while in segment mode.
export class CursorHoldTracker {
  private contacts: Map<number, HeldCursor> = new Map();
  begin(id: number, tap: () => void, hold: () => void): void {
    this.end(id, true);
    const contact = new HeldCursor(tap);
    this.contacts.set(id, contact);
    contact.timer = setTimeout(() => {
      if (this.contacts.get(id) !== contact) { return; }
      contact.fired = true;
      hold();
    }, 450);
  }
  end(id: number, cancelled: boolean): void {
    const contact = this.contacts.get(id);
    if (!contact) { return; }
    clearTimeout(contact.timer);
    this.contacts.delete(id);
    if (!cancelled && !contact.fired) { contact.tap(); }
  }
  clear(): void { this.contacts.forEach((_contact: HeldCursor, id: number) => { this.end(id, true); }); }
}
