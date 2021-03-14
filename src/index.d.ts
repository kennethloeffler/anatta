import { Event, ComponentTuple, Map } from "./Core/Types";
import Collection = require("./Entity/Collection");
import PureCollection = require("./Entity/PureCollection");
import Registry = require("./Entity/Registry");
import { t } from "../vendor/t"

export interface System<
  Components,
  Required extends unknown[]=[],
  Updated extends unknown[]=[],
  Optional extends unknown[]=[]
> {
  registry: Registry<Components>;

  unload(): void;

  on<T extends Callback>(event: Event<T>, callback: T): void;

  all<Typenames extends (keyof Components)[]>(
    ...componentNames: Typenames
  ): System<Components, Map<Typenames, Components>, Updated, Optional>;

  any<Typenames extends (keyof Components)[]>(
    ...componentNames: Typenames
  ): System<
    Components,
    Required,
    Updated,
    Map<Typenames, Components>
  >;

  updated<Typenames extends (keyof Components)[]>(
    ...componentNames: Typenames
  ): System<Components, Required, Map<Typenames, Components>, Optional>;

  except<Typenames extends (keyof Components)[]>(
    ...componentNames: Typenames
  ): System<Components, Required, Updated, Optional>;

  collect(): Collection<ComponentTuple<Required, Updated, Optional>>;

  pure(): PureCollection<ComponentTuple<Required, never, Optional>>;
}

interface Anatta {
  loadSystems(container: Instance): void
}

export function define(components: { [componentName: string]: t.check<unknown> }): Anatta
