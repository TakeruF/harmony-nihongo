class RepeatedKey {
  timer: number = -1;
}

// Run once on press, then repeat while held. Never retain actions after release.
export class KeyRepeatTracker {
  private contacts: Map<number, RepeatedKey> = new Map();
  begin(id: number, action: () => void): void {
    this.end(id);
    const contact = new RepeatedKey();
    this.contacts.set(id, contact);
    action();
    const repeat = (): void => {
      if (this.contacts.get(id) !== contact) { return; }
      action();
      if (this.contacts.get(id) === contact) { contact.timer = setTimeout(repeat, 70); }
    };
    if (this.contacts.get(id) === contact) { contact.timer = setTimeout(repeat, 400); }
  }
  end(id: number): void {
    const contact = this.contacts.get(id);
    if (!contact) { return; }
    clearTimeout(contact.timer);
    this.contacts.delete(id);
  }
  clear(): void { this.contacts.forEach((_contact: RepeatedKey, id: number) => { this.end(id); }); }
}
