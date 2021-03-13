import { CollectionCallback } from "../Core/Types";

interface PureCollection<Tuple extends unknown[]> {
  each(callback: CollectionCallback<Tuple, void>): void;
  update(callback: CollectionCallback<Tuple, LuaTuple<Tuple>>): void
}

export = PureCollection;
