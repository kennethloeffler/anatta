import Matcher = require("./Entity/Matcher");
import Registry = require("./Entity/Registry");
import { Event } from "./Core/Types"

interface Anatta {
  loadSystems(container: Instance): void
}

export interface System<Components> {
  getRegistry(): Registry<Components>;
  match(): Matcher<Components, unknown[], unknown[], unknown[]>;
  on<T extends Callback>(event: Event<T>, callback: T): void;
}

export function define<Components>(components: Components): Anatta
