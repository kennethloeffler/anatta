import { CollectionCallback } from "../Core/Types";

interface ImmutableCollection<Tuple extends unknown[]> {
  each(callback: CollectionCallback<Tuple, void>): void;
  update(callback: CollectionCallback<Tuple, LuaTuple<Tuple>>): void
}

export = ImmutableCollection;
