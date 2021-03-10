import { t } from "../../vendor/t";

export type Empty<T extends unknown[]> = T extends [unknown, ...unknown[]]
  ? never
  : T;

type Flatten<T extends unknown[], U extends unknown[]> = T extends Empty<T>
  ? U
  : U extends Empty<U>
  ? T
  : [...T, ...U];

export type ResolvedType<T, K extends keyof T> = T[K] extends t.check<infer U>
  ? U
  : T;

export type CollectionCallback<Tuple extends unknown[], Return = void> = (
  entity: number,
  ...component: Tuple
) => Return;

export type Event<T extends Callback> =
  | {
      connect(callback: T): { disconnect(): void } | RBXScriptConnection;
    }
  | RBXScriptSignal<T>;

export type Entity = number;

export type ComponentTuple<
  Required extends unknown[],
  Updated extends unknown[],
  Optional extends unknown[]
> = Flatten<Flatten<Required, Updated>, Optional>;

export type Map<T, U> = {
  [K in keyof T]: T[K] extends keyof U ? ResolvedType<U, T[K]> : never;
};
