import { CollectionCallback, Event } from "../Core/Types";

interface Collection<Tuple extends unknown[]> {
  each(callback: CollectionCallback<Tuple>): void;

  attach(callback: CollectionCallback<Tuple, (RBXScriptConnection | Instance)[]>): void;

  added: Event<CollectionCallback<Tuple>>;

  removed: Event<CollectionCallback<Tuple>>;
}

export = Collection;
