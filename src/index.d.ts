import Matcher = require("./Entity/Matcher");
import Registry = require("./Entity/Registry");
import { Event } from "./Core/Types"
import { t } from "../vendor/t"

interface Anatta {
  loadSystems(container: Instance): void
}

export interface System<Components> {
  getRegistry(): Registry<Components>;
  match(): Matcher<Components, unknown[], unknown[], unknown[]>;
  on<T extends Callback>(event: Event<T>, callback: T): void;
}

export function define(components: { [componentName: string]: t.check<unknown> }): Anatta
