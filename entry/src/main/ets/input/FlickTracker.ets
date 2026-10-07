export class FlickOutput {
  value: string;
  session: number;
  tapValues: string[];
  pressedAt: number;
  constructor(value: string, session: number, tapValues: string[] = [], pressedAt: number = 0) { this.value = value; this.session = session; this.tapValues = tapValues; this.pressedAt = pressedAt; }
}
class Contact {
  id: number;
  values: string[];
  x: number;
  y: number;
  selected: number = 0;
  session: number;
  pressedAt: number = Date.now();
  ready: boolean = false;
  cancelled: boolean = false;
  constructor(id: number, values: string[], x: number, y: number, session: number) {
    this.id = id; this.values = values; this.x = x; this.y = y; this.session = session;
  }
}
// Keep press order even when two fingers are released in the opposite order.
export class FlickTracker {
  private contacts: Contact[] = [];
  flickEnabled: boolean = true;
  begin(id: number, values: string[], x: number, y: number, session: number): void {
    if (this.contacts.some((contact: Contact) => contact.id === id && !contact.ready)) { return; }
    this.contacts.push(new Contact(id, values, x, y, session));
  }
  move(id: number, x: number, y: number): string {
    const contact = this.contacts.find((item: Contact) => item.id === id && !item.ready);
    if (!contact) { return ''; }
    const dx = x - contact.x;
    const dy = y - contact.y;
    contact.selected = !this.flickEnabled || Math.max(Math.abs(dx), Math.abs(dy)) < 12 ? 0 :
      (Math.abs(dx) >= Math.abs(dy) ? (dx < 0 ? 1 : 3) : (dy < 0 ? 2 : 4));
    return contact.values[contact.selected];
  }
  end(id: number, x: number, y: number, cancelled: boolean = false): FlickOutput[] {
    this.move(id, x, y);
    const contact = this.contacts.find((item: Contact) => item.id === id && !item.ready);
    if (contact) { contact.ready = true; contact.cancelled = cancelled; }
    return this.drain();
  }
  flush(): FlickOutput[] {
    this.contacts.forEach((contact: Contact) => { contact.ready = true; });
    return this.drain();
  }
  cancelAll(): void { this.contacts = []; }
  private drain(): FlickOutput[] {
    const result: FlickOutput[] = [];
    while (this.contacts.length > 0 && this.contacts[0].ready) {
      const contact = this.contacts.shift();
      if (contact && !contact.cancelled && contact.values[contact.selected] !== '') {
        result.push(new FlickOutput(contact.values[contact.selected], contact.session, contact.selected === 0 ? contact.values : [], contact.pressedAt));
      }
    }
    return result;
  }
}
