import { Entity, ResolvedType } from "../Core/Types";

type ComponentReturn<Components> = <Typename extends keyof Components>(
  this: Registry<Components>,
  entity: Entity,
  component: Typename,
  data: ResolvedType<Components, Typename>
) => ResolvedType<Components, Typename>;

interface Registry<Components> {
  create(): Entity;

  createFrom(entity: Entity): Entity;

  destroy(entity: Entity): void;

  isValid(entity: Entity): boolean;

  isStub(entity: Entity): boolean;

  visit(callback: (component: string) => void, entity?: Entity): void;

  has(entity: Entity, ...components: (keyof Components)[]): boolean;

  any(entity: Entity, ...components: (keyof Components)[]): boolean;

  add: ComponentReturn<Components>;

  getOrAdd: ComponentReturn<Components>;

  replace: ComponentReturn<Components>;

  addOrReplace: ComponentReturn<Components>;

  remove(entity: Entity, component: keyof Components): void;

  multiRemove(entity: Entity, ...components: (keyof Components)[]): void;

  tryRemove(entity: Entity, component: keyof Components): boolean;

  get<Typename extends keyof Components>(
    entity: Entity,
    component: Typename
  ): ResolvedType<Components, Typename> | undefined;

  multiAdd(
    entity: Entity,
    componentMap: {
      [Typename in keyof Partial<Components>]: ResolvedType<
        Components,
        Typename
      >;
    }
  ): Entity;

  tryAdd<Typename extends keyof Components>(
    entity: Entity,
    component: Typename,
    data: ResolvedType<Components, Typename>
  ): ResolvedType<Components, Typename> | undefined;

  raw<Typename extends keyof Components>(
    component: Typename
  ): LuaTuple<[Entity[], ResolvedType<Components, Typename>[]]>;

  each(func: (entity: Entity) => void): void;

  countEntities(): number;

  count(component: keyof Components): number;

  hasDefined(component: keyof Components): boolean;
}

export = Registry;
