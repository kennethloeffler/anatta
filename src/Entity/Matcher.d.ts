import { ComponentTuple, Map } from "../Core/Types";
import Collection = require("./Collection");
import ImmutableCollection = require("./ImmutableCollection");

interface Matcher<
  Components,
  Required extends unknown[],
  Updated extends unknown[],
  Optional extends unknown[]
> {
  all<Typenames extends (keyof Components)[]>(
    ...componentNames: Typenames
  ): Matcher<Components, Map<Typenames, Components>, Updated, Optional>;

  any<Typenames extends (keyof Components)[]>(
    ...componentNames: Typenames
  ): Matcher<
    Components,
    Required,
    Partial<Map<Typenames, Components>>,
    Updated
  >;

  updated<Typenames extends (keyof Components)[]>(
    ...componentNames: Typenames
  ): Matcher<Components, Required, Map<Typenames, Components>, Optional>;

  except<Typenames extends (keyof Components)[]>(
    ...componentNames: Typenames
  ): Matcher<Components, Required, Updated, Optional>;

  collect(): Collection<ComponentTuple<Required, Updated, Optional>>;

  immutable(): ImmutableCollection<ComponentTuple<Required, never, Optional>>;
}

export = Matcher;
