import { ResolvedType } from "../Core/Types";

type ComponentReturn<Components> = <Typename extends keyof Components>(
  this: Registry<Components>,
  entity: number,
  component: Typename,
  data: ResolvedType<Components, Typename>
) => ResolvedType<Components, Typename>;

interface Registry<Components> {
  create(): number;

  createFrom(entity: number): number;

  destroy(entity: number): void;

  isValid(entity: number): boolean;

  isStub(entity: number): boolean;

  visit(callback: (component: string) => void, entity?: number): void;

  has(entity: number, ...components: (keyof Components)[]): boolean;

  any(entity: number, ...components: (keyof Components)[]): boolean;

  add: ComponentReturn<Components>;

  getOrAdd: ComponentReturn<Components>;

  replace: ComponentReturn<Components>;

  addOrReplace: ComponentReturn<Components>;

  remove(entity: number, component: keyof Components): void;

  multiRemove(entity: number, ...components: (keyof Components)[]): void;

  tryRemove(entity: number, component: keyof Components): boolean;

  get<Typename extends keyof Components>(
    entity: number,
    component: Typename
  ): ResolvedType<Components, Typename> | undefined;

  multiAdd(
    entity: number,
    componentMap: {
      [Typename in keyof Partial<Components>]: ResolvedType<
        Components,
        Typename
      >;
    }
  ): number;

  tryAdd<Typename extends keyof Components>(
    entity: number,
    component: Typename,
    data: ResolvedType<Components, Typename>
  ): ResolvedType<Components, Typename> | undefined;

  raw<Typename extends keyof Components>(
    component: Typename
  ): LuaTuple<[number[], ResolvedType<Components, Typename>[]]>;

  each(func: (entity: number) => void): void;

  countEntities(): number;

  count(component: keyof Components): number;

  hasDefined(component: keyof Components): boolean;
}

export = Registry;
